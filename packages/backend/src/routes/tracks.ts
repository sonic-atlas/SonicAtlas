import { Router } from 'express';
import { db } from '../../db/db.js';
import { authMiddleware, uploaderPerms } from '../middleware/auth.js';
import multer from 'multer';
import path from 'node:path';
import fsp from 'node:fs/promises';
import { playlistItems, trackFormatEnum, trackMetadata, tracks } from '../../db/schema.js';
import { parseFile } from 'music-metadata';
import { eq } from 'drizzle-orm';

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

        await db.transaction(async (tx) => {
            const [track] = await tx.insert(tracks).values({
                uploadedBy: req.user!.id,
                filename: req.file!.filename,
                originalFilename: req.file!.originalname,
                duration: meta.duration,
                sampleRate: meta.sampleRate,
                fileSize: req.file!.size
            }).returning();

            const fileExt = path.extname(req.file!.originalname);
            const newPath = path.join(uploadFolder, `${track!.id}${fileExt}`);
            await fsp.rename(req.file!.path, newPath);

            await tx.update(tracks).set({ filename: `${track!.id}${fileExt}` }).where(eq(tracks.id, track!.id));

            await tx.insert(trackMetadata).values({
                trackId: track!.id,
                title: meta.title,
                artist: meta.artist,
                album : meta.album,
                year: meta.year,
                genres: meta.genres
            });
        });

        return res.status(201).json({
            filename: req.file!.originalname,
            uploadedAt: Date.now()
        });
    } catch { // TODO: Send json with error information, maybe logging?
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
    } catch { // TODO: Send json with error information, maybe logging?
        return res.status(500);
    }
});

export default router;