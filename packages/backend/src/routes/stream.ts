import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { db } from '../../db/db.js';
import { eq } from 'drizzle-orm';
import { tracks, transcodeJobs } from '../../db/schema.js';
import path from 'node:path';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import mime from 'mime-types';
import { logger } from '../utils/logger.js';
import { isUUID } from '../utils/isUUID.js';
import { $rootDir } from '@sonic-atlas/shared';
import { pipeline } from 'node:stream/promises';

const router = Router();

type ValidQualities = 'efficiency' | 'high' | 'cd' | 'hires';

router.get('/:trackId', async (req, res) => {
    const { trackId } = req.params;
    const quality = (req.query.quality as ValidQualities) || 'high';

    if (!isUUID(trackId!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'TRACK_002',
            message: 'Track id must be a valid UUID'
        });
    }

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

    try {
        await db
            .insert(transcodeJobs)
            .values({
                trackId: track.id,
                quality: quality,
                status: 'transcoding',
                startedAt: new Date()
            });

        const transcodeUrl = `${'http://localhost:8000'}/transcode/${track.id}`;
        const response = await fetch(transcodeUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ quality })
        });

        await db.update(transcodeJobs).set({ completedAt: new Date() }).where(eq(transcodeJobs.trackId, track.id));

        if (!response.ok) {
            await db.update(transcodeJobs).set({ status: 'failed' }).where(eq(transcodeJobs.trackId, track.id));
            return res.status(500).json({
                error: 'INTERNAL_SERVER_ERROR',
                message: 'Track transcoding failed due to an internal error'
            });
        }

        const data = await response.json();

        if (!(data as any).cache_path) {
            await db.update(transcodeJobs).set({ status: 'failed' }).where(eq(transcodeJobs.trackId, track.id));

            return res.status(500).json({
                code: 'TRANSCODE_001',
                message: 'Transcoding failed'
            });
        }

        await db.update(transcodeJobs).set({ status: 'completed' }).where(eq(transcodeJobs.trackId, track.id));

        const cachedPath = path.join($rootDir, process.env.STORAGE_PATH || 'storage', (data as any).cache_path);

        // No fs.existsSync needed to check if path exists.
        // fsp.stat will throw if the file isn't found.
        let stat;
        try {
            stat = await fsp.stat(cachedPath);
        } catch {
            return res.status(404).json({
                error: 'TRANSCODE_CACHE_MISSING',
                code: 'TRANSCODE_002',
                message: 'Cached transcoded file not found'
            });
        }

        const contentType = mime.lookup(cachedPath) || 'application/octet-stream';
        const range = req.headers.range;

        if (!range) {
            res.writeHead(200, {
                'Content-Length': stat.size,
                'Content-Type': contentType
            });
            return await pipeline(fs.createReadStream(cachedPath), res);
        }

        const parts = range.replace(/bytes=/, '').split('-');
        const start = parseInt(parts[0]!, 10);
        const end = parts[1] ? parseInt(parts[1], 10) : stat.size - 1;

        if (isNaN(start) || start >= stat.size) {
            return res.status(416).set('Content-Range', `bytes */${stat.size}`).end();
        }

        const chunkSize = end - start + 1;

        res.writeHead(206, {
            'Content-Range': `bytes ${start}-${end}/${stat.size}`,
            'Accept-Ranges': 'bytes',
            'Content-Length': chunkSize,
            'Content-Type': contentType
        });

        res.setHeaders(new Map([
            ['Cache-Control', 'public, max-age=86400'],
            ['ETag', `"${track.id}-${quality}-${stat.mtimeMs}"`]
        ]));

        try {
            return await pipeline(fs.createReadStream(cachedPath, { start, end, highWaterMark: 512 * 1024 }), res);
        } catch (e) {
            if (!res.headersSent) res.status(500).end();
        }
    } catch (err) {
        logger.error(`(GET /api/stream) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Track streaming failed due to an internal error'
        });
    }
});

export default router;