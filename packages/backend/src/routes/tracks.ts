import { Router, type NextFunction, type Request, type Response } from 'express';
import { db } from '../../db/db.js';
import { authMiddleware, uploaderPerms } from '../middleware/auth.js';
import multer from 'multer';
import path from 'node:path';
import fsp from 'node:fs/promises';
import { playlistItems, trackMetadata, tracks } from '../../db/schema.js';
import { parseFile } from 'music-metadata';
import { eq } from 'drizzle-orm';
import { logger } from '../utils/logger.js';
import { isUUID } from '../utils/isUUID.js';
import { stripCoverArt } from '../utils/stripCoverArt.js';

const router = Router();
router.use(authMiddleware, uploaderPerms);

const uploadFolder = path.join(process.env.STORAGE_PATH ?? 'storage', 'originals');

// GET all tracks
router.get('/', async (req, res) => {
    try {
        const allTracks = await db.query.tracks.findMany({
            with: {
                metadata: true
            },
            orderBy: (tracks, { desc }) => [desc(tracks.uploadedAt)]
        });

        return res.json(allTracks);
    } catch (err) {
        logger.error(`(GET /api/tracks) Unknown Error Occurred:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to fetch tracks'
        });
    }
});

class UnsupportedMediaTypeError extends Error {
    statusCode = 415;
    constructor(message: string) {
        super(message);
        this.name = 'UnsupportedMediaTypeError'
    }
}

const storage = multer.diskStorage({
    destination(req, file, cb) {
        cb(null, uploadFolder);
    },
    filename(req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname);
    }
});

const allowedFiles = ['audio/flac', 'audio/mpeg', 'audio/wav', 'audio/aac'];

const fileFilter = (req: Express.Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
    if (allowedFiles.includes(file.mimetype)) {
        cb(null, true);
    } else {
        cb(new UnsupportedMediaTypeError(`Unsupported file MIME type: ${file.mimetype}. Allowed: ${allowedFiles}`));
    }
}

const upload = multer({ storage, fileFilter });

router.post('/upload', upload.single('audio'), async (req, res) => {
    if (!req.file) {
        return res.status(400).json({
            error: 'BAD_REQUEST',
            code: 'UPLOAD_002',
            message: 'File is required'
        });
    }

    if (req.file.size > 500_000_000) {
        await fsp.unlink(req.file.path);
        return res.status(400).json({
            error: 'BAD_REQUEST',
            code: 'UPLOAD_001',
            message: 'File exceeds 500MB limit'
        });
    }

    let filename;
    let fileRenamed = false;
    let newPath = '';

    try {
        const metadata = await parseFile(req.file.path);

        const format = (metadata.format.codec?.toLowerCase() || 
                       path.extname(req.file.originalname).slice(1).toLowerCase()) as any;

        const meta = {
            // tracks
            duration: metadata.format.duration ? Math.round(metadata.format.duration) : null,
            sampleRate: metadata.format.sampleRate ?? null,
            bitDepth: metadata.format.bitsPerSample ?? null,
            format: format,

            // track_metadata
            title: metadata.common.title ?? path.parse(req.file.originalname).name,
            artist: metadata.common.artist ?? 'Unknown Artist',
            album: metadata.common.album ?? 'Unknown Album',
            year: metadata.common.year ?? null,
            genres: metadata.common.genre ?? null,
            bitrate: metadata.format.bitrate ?? null,
            codec: metadata.format.codec ?? null
        }

        let trackInfo = await db.transaction(async (tx) => {
            const [track] = await tx
                .insert(tracks)
                .values({
                    filename: req.file!.filename,
                    originalFilename: req.file!.originalname,
                    duration: meta.duration,
                    sampleRate: meta.sampleRate,
                    bitDepth: meta.bitDepth,
                    format: meta.format,
                    fileSize: req.file!.size
                })
                .returning();

            const fileExt = path.extname(req.file!.originalname);
            filename = `${track!.id}${fileExt}`;
            newPath = path.join(uploadFolder, filename);
            await fsp.rename(req.file!.path, newPath);
            fileRenamed = true;

            await stripCoverArt(newPath);

            await tx
                .update(tracks)
                .set({ filename })
                .where(eq(tracks.id, track!.id));

            await tx.insert(trackMetadata).values({
                trackId: track!.id,
                title: meta.title,
                artist: meta.artist,
                album: meta.album,
                year: meta.year,
                genres: meta.genres
            });

            return track;
        });

        if (metadata.common.picture && metadata.common.picture.length > 0) {
            try {
                const picture = metadata.common.picture[0];
                if (picture && picture.data) {
                    const metadataFolder = path.join(process.env.STORAGE_PATH || 'storage', 'metadata');
                    await fsp.mkdir(metadataFolder, { recursive: true });
                    
                    let ext = 'jpg';
                    if (picture.format) {
                        if (picture.format.includes('png')) ext = 'png';
                        else if (picture.format.includes('jpeg') || picture.format.includes('jpg')) ext = 'jpg';
                        else if (picture.format.includes('webp')) ext = 'webp';
                    }
                    
                    const coverPath = path.join(metadataFolder, `${trackInfo!.id}_cover.${ext}`);
                    await fsp.writeFile(coverPath, picture.data);
                    
                    await db
                        .update(tracks)
                        .set({ coverArtPath: `/api/metadata/${trackInfo!.id}/cover` })
                        .where(eq(tracks.id, trackInfo!.id));
                        
                    logger.info(`Extracted cover art for track ${trackInfo!.id} (${ext}, ${picture.data.length} bytes)`);
                }
            } catch (coverErr) {
                logger.warn(`Failed to extract cover art: ${coverErr}`);
            }
        } else {
            logger.info(`No cover art found in metadata for track ${trackInfo!.id}`);
        }

        return res.status(201).json({
            id: trackInfo!.id,
            filename,
            metadata: {
                title: meta.title,
                artist: meta.artist,
                album: meta.album,
                year: meta.year,
                duration: meta.duration,
                sampleRate: meta.sampleRate
            },
            coverArtPath: `/api/metadata/${trackInfo!.id}/cover`,
            uploadedAt: Date.now()
        });
    } catch (err) {
        logger.error(`(POST /api/tracks/upload) Unknown Error Occured:\n${err}`);
        
        try {
            if (fileRenamed && newPath) {
                await fsp.unlink(newPath);
            } else if (req.file?.path) {
                await fsp.unlink(req.file.path);
            }
        } catch (unlinkErr) {
            logger.error(`Failed to clean up file after error: ${unlinkErr}`);
        }
        
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Track uploading failed due to an internal error'
        });
    }
});

router.use((err: any, req: Request, res: Response, next: NextFunction) => {
    if (err instanceof UnsupportedMediaTypeError) {
        return res.status(err.statusCode).json({
            error: 'UNSUPPORTED_MEDIA_TYPE',
            code: 'UPLOAD_003',
            message: err.message
        });
    } else if (err instanceof multer.MulterError) {
        return res.status(400).json({
            code: `MULTER_${err.code}`,
            message: err.message
        })
    }

    logger.error(`(POST /api/tracks/upload) Unknown Error Occured:\n${err}`);
    res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'File upload failed due to an internal server error'
    });
});

router.delete('/:trackId', async (req, res) => {
    const { trackId } = req.params;

    if (!isUUID(trackId!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'TRACK_002'
        });
    }

    try {
        const track = await db.query.tracks.findFirst({
            where: eq(tracks.id, trackId!)
        });

        if (!track) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                code: 'TRACK_001',
                message: 'Track id must be a valid UUID'
            });
        }

        await db.transaction(async (tx) => {
            await tx.delete(tracks).where(eq(tracks.id, track.id));
            await tx.delete(trackMetadata).where(eq(trackMetadata.trackId, track.id));
            await tx.delete(playlistItems).where(eq(playlistItems.trackId, track.id));
        });

        return res.sendStatus(204);
    } catch (err) {
        logger.error(`(DELETE /api/tracks/${trackId}) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Track deletion failed due to an internal error'
        });
    }
});

export default router;