import { Router, type NextFunction, type Request, type Response } from 'express';
import { db } from '../../db/db.ts';
import { authMiddleware, uploaderPerms } from '../middleware/auth.ts';
import multer from 'multer';
import path from 'node:path';
import fsp from 'node:fs/promises';
import fs from 'node:fs';
import { playlistItems, trackMetadata, tracks } from '../../db/schema.ts';
import { parseFile } from 'music-metadata';
import { eq, type InferSelectModel, desc } from 'drizzle-orm';
import { logger } from '../utils/logger.ts';
import { isUUID } from '../utils/isUUID.ts';
import { stripCoverArt } from '../utils/stripCoverArt.ts';
import { $rootDir } from '@sonic-atlas/shared';
import { generateHLS } from '../utils/pretranscode.ts';
import { ImageService } from '../services/ImageService.ts';

const router = Router();
router.use(authMiddleware, uploaderPerms);

const uploadFolder = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'originals');
fs.mkdirSync(uploadFolder, { recursive: true });

// GET all tracks
router.get('/', async (req, res) => {
    try {
        const allTracks = await db.query.tracks.findMany({
            with: {
                metadata: true,
                releaseTracks: {
                    with: {
                        release: true
                    }
                }
            },
            orderBy: (tracks) => [desc(tracks.uploadedAt)]
        });

        const tracksWithCovers = allTracks.map(track => {
            const hasReleaseCover = track.releaseTracks.some(rt => rt.release?.coverArtPath);
            const coverArtPath = track.coverArtPath ?? (hasReleaseCover ? `/api/metadata/${track.id}/cover` : null);

            const { releaseTracks, ...rest } = track;
            const primaryRelease = track.releaseTracks[0]?.release;

            return {
                ...rest,
                coverArtPath,
                releaseId: primaryRelease?.id,
                releaseTitle: primaryRelease?.title,
                releaseArtist: primaryRelease?.primaryArtist,
                releaseYear: primaryRelease?.year,
                album: primaryRelease?.title
            };
        });

        return res.json(tracksWithCovers);
    } catch (err) {
        logger.error(`(GET /api/tracks) Unknown Error Occurred:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to fetch tracks'
        });
    }
});

router.get('/:trackId', async (req, res) => {
    const { trackId: id } = req.params;

    try {
        const track = await db.query.tracks.findFirst({
            with: {
                metadata: true,
                releaseTracks: {
                    with: {
                        release: true
                    }
                }
            },
            where: {
                id
            }
        });

        if (!track) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                code: 'TRACK_001',
                message: 'Track not found'
            });
        }

        const hasReleaseCover = track.releaseTracks.some(rt => rt.release?.coverArtPath);
        const coverArtPath = track.coverArtPath ?? (hasReleaseCover ? `/api/metadata/${track.id}/cover` : null);

        const { releaseTracks, ...rest } = track;
        const primaryRelease = track.releaseTracks[0]?.release;

        return res.json({
            ...rest,
            coverArtPath,
            releaseId: primaryRelease?.id,
            releaseTitle: primaryRelease?.title,
            releaseArtist: primaryRelease?.primaryArtist,
            releaseYear: primaryRelease?.year,
            album: primaryRelease?.title
        });
    } catch (err) {
        logger.error(`(GET /api/track) Unknown Error Occurred:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to fetch track'
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
    destination: uploadFolder,
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

    const { socketId } = req.body;

    let filename;
    let fileRenamed = false;
    let newPath = '';
    let trackInfo: InferSelectModel<typeof tracks> | undefined = undefined;

    try {
        const metadata = await parseFile(req.file.path);
        const ext = path.extname(req.file.originalname).slice(1).toLowerCase() as any;

        const albumName = metadata.common.album?.trim() || null;
        const albumArtist =
            metadata.common.albumartist?.trim() ||
            metadata.common.artist?.trim() ||
            'Unknown Artist';

        logger.info(`Parsed metadata - Album: "${albumName}", AlbumArtist: "${albumArtist}", Title: "${metadata.common.title}"`);

        const meta = {
            // tracks
            duration: metadata.format.duration ? Math.round(metadata.format.duration) : null,
            sampleRate: metadata.format.sampleRate ?? null,
            bitDepth: metadata.format.bitsPerSample ?? null,
            format: ext,

            // track_metadata
            title: metadata.common.title ?? path.parse(req.file.originalname).name,
            artist: metadata.common.artist ?? 'Unknown Artist',
            album: albumName,
            albumArtist,
            year: metadata.common.year ?? null,
            genres: metadata.common.genre ?? null,
            bitrate: metadata.format.bitrate ?? null,
            codec: metadata.format.codec ?? null
        }

        logger.info(ext);

        trackInfo = await db.transaction(async (tx) => {
            const [track] = await tx
                .insert(tracks)
                .values({
                    filename: req.file!.filename,
                    originalFilename: req.file!.originalname,
                    duration: meta.duration,
                    sampleRate: meta.sampleRate,
                    bitDepth: meta.bitDepth,
                    format: ext,
                    fileSize: req.file!.size
                })
                .returning();

            filename = `${track!.id}${ext}`;
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
                year: meta.year,
                genres: meta.genres,
                bitrate: meta.bitrate ? Math.round(meta.bitrate) : null,
                codec: meta.codec ?? null
            });

            return track;
        });

        if (metadata.common.picture && metadata.common.picture.length > 0) {
            try {
                const picture = metadata.common.picture[0];
                if (picture && picture.data) {
                    const metadataFolder = path.join($rootDir, process.env.STORAGE_PATH || 'storage', 'metadata');

                    const coverName = `${trackInfo!.id}_cover`;
                    await ImageService.processAndSaveCover(Buffer.from(picture.data), metadataFolder, coverName);

                    await db
                        .update(tracks)
                        .set({ coverArtPath: `/api/metadata/${trackInfo!.id}/cover` })
                        .where(eq(tracks.id, trackInfo!.id));

                    logger.info(`Extracted and processed cover art for track ${trackInfo!.id}`);
                }
            } catch (coverErr) {
                logger.warn(`Failed to extract cover art: ${coverErr}`);
            }
        } else {
            logger.info(`No cover art found in metadata for track ${trackInfo!.id}`);
        }

        await generateHLS(trackInfo!, newPath, socketId);

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

// Custom error middleware for /upload route
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
            where: {
                id: trackId
            }
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