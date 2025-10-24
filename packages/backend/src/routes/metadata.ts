import { Router } from 'express';
import { db } from '../../db/db.js';
import { authMiddleware, uploaderPerms } from '../middleware/auth.js';
import { eq } from 'drizzle-orm';
import { trackMetadata } from '../../db/schema.js';
import path from 'node:path';
import fsp from 'node:fs/promises';
import { $rootDir } from '@sonic-atlas/shared';
import { logger } from '../utils/logger.js';

const router = Router();

router.get('/:trackId', authMiddleware, async (req, res) => {
    const { trackId } = req.params;

    try {
        const metadataRaw = await db.query.trackMetadata.findFirst({
            where: eq(trackMetadata.trackId, trackId!),
            columns: {
                searchVector: false,
                trackId: false
            },
            with: {
                track: {
                    columns: {
                        duration: true,
                        sampleRate: true,
                        bitDepth: true,
                        fileSize: true,
                        uploadedAt: true
                    }
                }
            }
        });

        if (!metadataRaw) return res.status(404);

        const { track, ...rest } = metadataRaw;

        return res.json({ ...rest, ...track });
    } catch (err) {
        logger.error(`(GET /api/metadata/${trackId}) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        return res.status(500);
    }
});

router.patch('/:trackId', authMiddleware, uploaderPerms, async (req, res) => {
    const { trackId } = req.params;
    const { title, artist, album } = req.body;

    try {
        const metadata = await db.query.trackMetadata.findFirst({
            where: eq(trackMetadata?.trackId, trackId!)
        });
    
        if (!metadata) {
            return res.status(404); // TODO: Send json with error information
        }

        const updated = await db.update(trackMetadata).set({ title, artist, album }).where(eq(trackMetadata.id, metadata.id)).returning();

        return res.json(200).json(updated);
    } catch (err) {
        logger.error(`(PATCH /api/metadata/${trackId}) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        res.status(500);
    }
});

// $rootdir
const storagePath = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'metadata');

router.get('/:trackId/cover', async (req, res) => {
    const { trackId } = req.params;
    const coverFile = path.join(storagePath, `${trackId}_cover.jpg`);

    try {
        await fsp.access(coverFile);

        res.setHeader('Content-Type', 'image/jpeg');
        res.setHeader('Cache-Control', 'public, max-age=31536000');

        return res.sendFile(coverFile);
    } catch (err) {
        //? Maybe log here?
        // logger.error(`(GET /api/metadata/${trackId}/cover) An Error Occured:\n${err}`);

        return res.status(404).json({
            error: 'NOT_FOUND',
            code: 'COVER_001',
            message: 'No cover art found'
        });
    }
});

export default router;