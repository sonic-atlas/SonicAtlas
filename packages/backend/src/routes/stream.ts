import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { db } from '../../db/db.js';
import { eq } from 'drizzle-orm';
import { tracks } from '../../db/schema.js';
import path from 'node:path';
import fs from 'node:fs';
import mime from 'mime-types';

const router = Router();

router.get('/:trackId', authMiddleware, async (req, res) => {
    const { trackId } = req.params;
    const quality = (req.query.quality as string) || 'high';

    const validQualities = ['efficiency', 'high', 'cd', 'hires'];
    if (!validQualities.includes(quality)) {
        return res.status(400).json({ error: 'INVALID_QUALITY', message: `Unknown quality tier: ${quality}` });
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
        const transcodeUrl = `${process.env.TRANSCODER_PATH ?? 'http://localhost:8000'}/transcode/${track.id}`;
        const response = await fetch(transcodeUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ quality })
        });

        if (!response.ok) {
            return res.status(500); // TODO: Send json with error information
        }

        const data = await response.json();

        if (!(data as any).cache_path) {
            console.error(data);
            return res.status(500).json({
                code: 'TRANSCODE_001',
                message: 'Transcoding failed'
            });
        }

        const cachedPath = path.join(process.env.STORAGE_PATH || 'storage', (data as any).cache_path);
        if (!fs.existsSync(cachedPath)) {
            return res.status(404).json({
                error: 'TRANSCODE_CACHE_MISSING',
                code: 'TRANSCODE_002',
                message: 'Cached transcoded file not found'
            });
        }
        const contentType = mime.lookup(cachedPath) || 'application/octet-stream';

        const stat = fs.statSync(cachedPath);
        const range = req.headers.range;

        if (!range) {
            res.writeHead(200, {
                'Content-Length': stat.size,
                'Content-Type': contentType
            });
            fs.createReadStream(cachedPath).pipe(res);
            return;
        }

        const parts = range.replace(/bytes=/, '').split('-');
        const start = parseInt(parts[0]!, 10);
        const end = parts[1] ? parseInt(parts[1], 10) : stat.size - 1;

        if (isNaN(start) || start >= stat.size) {
            return res.status(416).set('Content-Range', `bytes */${stat.size}`).end();
        }

        const chunkSize = end - start + 1;
        const file = fs.createReadStream(cachedPath, { start, end });

        res.writeHead(206, {
            'Content-Range': `bytes ${start}-${end}/${stat.size}`,
            'Accept-Ranges': 'bytes',
            'Content-Length': chunkSize,
            'Content-Type': contentType
        });

        file.pipe(res);
    } catch { // TODO: Send json with error information, and maybe log.
        res.status(500);
    }
});

export default router;