import { Router } from 'express';
import { db } from '../../db/db.js';
import { authMiddleware, uploaderPerms } from '../middleware/auth.js';
import { eq } from 'drizzle-orm';
import { trackMetadata } from '../../db/schema.js';
import path from 'node:path';
import fsp from 'node:fs/promises';
import { $rootDir } from '@sonic-atlas/shared';
import { logger } from '../utils/logger.js';
import { isUUID } from '../utils/isUUID.js';

const router = Router();

type Quality = 'efficiency' | 'high' | 'cd' | 'hires';

function determineSourceQuality(track: any): Quality {
    const format = track.format?.toLowerCase();
    const bitrate = track.bitDepth || 16;
    const sampleRate = track.sampleRate || 44100;

    if (format === 'flac') {
        if (bitrate > 16 || sampleRate > 48000) {
            return 'hires';
        }
        return 'cd';
    }

    if (format === 'mp3' || format === 'aac') {
        return 'high';
    }

    return 'cd';
}

router.get('/:trackId', authMiddleware, async (req, res) => {
    const { trackId } = req.params;

    if (!isUUID(trackId!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'METADATA_002',
            message: 'Track id must be a valid UUID'
        });
    }

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

        const sourceQuality = determineSourceQuality(track);

        return res.json({ ...rest, ...track, sourceQuality });
    } catch (err) {
        logger.error(`(GET /api/metadata/${trackId}) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Track metadata fetching failed due to an internal error'
        });
    }
});

router.patch('/:trackId', authMiddleware, uploaderPerms, async (req, res) => {
    const { trackId } = req.params;
    const { title, artist, album } = req.body;

    if (!isUUID(trackId!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'METADATA_002',
            message: 'Track id must be a valid UUID'
        });
    }

    try {
        const metadata = await db.query.trackMetadata.findFirst({
            where: eq(trackMetadata?.trackId, trackId!)
        });
    
        if (!metadata) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                code: 'METADATA_001',
                message: 'Track metadata not found'
            });
        }

        const updated = await db.update(trackMetadata).set({ title, artist, album }).where(eq(trackMetadata.id, metadata.id)).returning();

        return res.json(200).json(updated);
    } catch (err) {
        logger.error(`(PATCH /api/metadata/${trackId}) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Track metadata update failed due to an internal error'
        });
    }
});

const storagePath = path.join(process.env.STORAGE_PATH || '/storage', 'metadata');

router.get('/:trackId/cover', async (req, res) => {
    const { trackId } = req.params;

    if (!isUUID(trackId)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'COVER_003',
            message: 'Track id must be a valid UUID'
        })
    }

    const extensions = ['jpg', 'jpeg', 'png', 'webp'];
    
    for (const ext of extensions) {
        const coverFile = path.join(storagePath, `${trackId}_cover.${ext}`);
        
        try {
            await fsp.access(coverFile);
            
            const contentTypes: Record<string, string> = {
                'jpg': 'image/jpeg',
                'jpeg': 'image/jpeg',
                'png': 'image/png',
                'webp': 'image/webp'
            };

            res.setHeader('Content-Type', contentTypes[ext] || 'image/jpeg');
            res.setHeader('Cache-Control', 'public, max-age=31536000');

            return res.sendFile(coverFile);
        } catch (err) {
            continue;
        }
    }
    
    return res.status(404).json({
        error: 'NOT_FOUND',
        code: 'COVER_001',
        message: 'No cover art found'
    });
});

export default router;