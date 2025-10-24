import { Router } from 'express';
import { db } from '../../db/db.js';
import { authMiddleware, uploaderPerms } from '../middleware/auth.js';
import multer from 'multer';
import path from 'node:path';
import fsp from 'node:fs/promises';
import { playlistItems, trackMetadata, tracks } from '../../db/schema.js';
import { parseFile } from 'music-metadata';
import { eq } from 'drizzle-orm';
import { logger } from '../utils/logger.js';

const router = Router();
router.use(authMiddleware, uploaderPerms);

const uploadFolder = path.join(process.env.STORAGE_PATH ?? 'storage', 'uploads');

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
        cb(new Error(`Unsupported file MIME type: ${file.mimetype}.\nThe allowed list is ${allowedFiles}`));
    }
}

const upload = multer({ storage, fileFilter });

router.post('/upload', upload.single('audio'), async (req, res) => {
    if (!req.file) {
        return res.status(400); // TODO: Send json with error information
    }

    if (req.file.size > 500_000_000) {
        await fsp.unlink(req.file.path);
        return res.status(400).json({
            error: 'BAD_REQUEST',
            code: 'UPLOAD_001',
            message: 'File exceeds 500MB limit'
        });
    }

    try {
        const metadata = await parseFile(req.file.path);

        const meta = {
            // tracks
            duration: metadata.format.duration ?? null,
            sampleRate: metadata.format.sampleRate ?? null,

            // track_metadata
            title: metadata.common.title ?? path.parse(req.file.originalname).name,
            artist: metadata.common.artist ?? 'Unknown Artist',
            album: metadata.common.album ?? 'Unknown Album',
            year: metadata.common.year ?? null,
            genres: metadata.common.genre ?? null
        }

        let filename;

        let trackInfo = await db.transaction(async (tx) => {
            const [track] = await tx
                .insert(tracks)
                .values({
                    uploadedBy: req.user!.id,
                    filename: req.file!.filename,
                    originalFilename: req.file!.originalname,
                    duration: meta.duration,
                    sampleRate: meta.sampleRate,
                    fileSize: req.file!.size
                })
                .returning();

            const fileExt = path.extname(req.file!.originalname);
            filename = `${track!.id}${fileExt}`;
            const newPath = path.join(uploadFolder, filename);
            await fsp.rename(req.file!.path, newPath);

            await tx
                .update(tracks)
                .set({ filename })
                .where(eq(tracks.id, track!.id));

            const [metadata] = await tx.insert(trackMetadata).values({
                trackId: track!.id,
                title: meta.title,
                artist: meta.artist,
                album: meta.album,
                year: meta.year,
                genres: meta.genres
            }).returning();

            return track;
        });

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
        // TODO: Send json with error information
        await fsp.unlink(req.file.path);
        return res.status(500);
    }
});

router.delete('/:trackId', async (req, res) => {
    const { trackId } = req.params;

    try {
        const track = await db.query.tracks.findFirst({
            where: eq(tracks.id, trackId!)
        });

        if (!track) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                code: 'TRACK_001',
                message: 'Track not found'
            });
        }

        await db.transaction(async (tx) => {
            await tx.delete(tracks).where(eq(tracks.id, track.id));
            await tx.delete(trackMetadata).where(eq(trackMetadata.trackId, track.id));
            await tx.delete(playlistItems).where(eq(playlistItems.trackId, track.id));
        });

        return res.status(204);
    } catch (err) {
        logger.error(`(DELETE /api/tracks/${trackId}) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        return res.status(500);
    }
});

export default router;