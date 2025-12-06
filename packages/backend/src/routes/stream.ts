import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { db } from '../../db/db.js';
import { type InferSelectModel } from 'drizzle-orm';
import { tracks } from '../../db/schema.js';
import path from 'node:path';
import { isUUID } from '../utils/isUUID.js';
import { $rootDir } from '@sonic-atlas/shared';
import fs from 'node:fs';
import fsp from 'node:fs/promises';

const router = Router();
router.use(authMiddleware);

type ValidQualities = 'efficiency' | 'high' | 'cd' | 'hires';

export const qualityHierarchy: ValidQualities[] = ['efficiency', 'high', 'cd', 'hires'];

// Determine source quality based on track metadata
export function getSourceQuality(track: InferSelectModel<typeof tracks>): ValidQualities {
    const format = track.format?.toLowerCase();
    const bitDepth = track.bitDepth;
    const sampleRate = track.sampleRate || 44100;
    const fileSize = track.fileSize || 0;
    const duration = track.duration || 1;

    // Calculate approximate bitrate from file size if not provided
    const estimatedBitrate = (fileSize * 8) / duration;

    if (format === 'flac') {
        if (bitDepth && bitDepth > 16 || sampleRate > 48000) {
            return 'hires';
        }
        return 'cd';
    }

    if (format === 'mp3' || format === 'aac' || format === 'ogg' || format === 'opus') {
        if (estimatedBitrate >= 320000) {
            return 'high';
        }
        return 'efficiency';
    }

    if (format === 'wav') {
        if (sampleRate > 48000) return 'hires';
        return 'cd';
    }

    return 'cd';
}

router.get('/:trackId/quality', async (req, res) => {
    const { trackId } = req.params;

    if (!isUUID(trackId!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'TRACK_002',
            message: 'Track id must be a valid UUID'
        });
    }

    const track = await db.query.tracks.findFirst({
        where: {
            id: trackId
        }
    });

    if (!track) {
        return res.status(404).json({
            error: 'NOT_FOUND',
            code: 'TRACK_001',
            message: 'Track not found'
        });
    }

    const sourceQuality = getSourceQuality(track);
    const sourceIndex = qualityHierarchy.indexOf(sourceQuality);

    const availableQualities = qualityHierarchy.slice(0, sourceIndex + 1);

    return res.json({
        sourceQuality,
        availableQualities,
        track: {
            format: track.format,
            sampleRate: track.sampleRate,
            bitDepth: track.bitDepth
        }
    });
});

const hlsRoot = path.join($rootDir, process.env.STORAGE_PATH || 'storage', 'hls');

// I don't think there's any need to check if trackId is a UUID here. Don't need to add unnecessary latency.
// Master playlist, for ABR
router.get('/:trackId/master.m3u8', (req, res) => {
    const { trackId } = req.params;
    const filepath = path.join(hlsRoot, trackId!, 'master.m3u8');

    if (!fs.existsSync(filepath)) {
        return res.status(404).json({
            error: 'NOT_FOUND',
            code: 'STREAM_001',
            message: "Playlist 'master' not found"
        });
    }

    res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');

    fs.createReadStream(filepath).pipe(res);
});

// Routes for individual qualities
router.get('/:trackId/:quality/:filename.m3u8', (req, res) => {
    const { trackId, quality, filename } = req.params;
    const filepath = path.join(hlsRoot, trackId!, quality!, `${filename}.m3u8`);

    if (!fs.existsSync(filepath)) {
        return res.status(404).json({
            error: 'NOT_FOUND',
            code: 'STREAM_001',
            message: `Playlist '${quality}/${filename}' not found`
        });
    }

    res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');

    fs.createReadStream(filepath).pipe(res);
});

router.get('/:trackId/:quality/:segment', async (req, res) => {
    const { trackId, quality, segment } = req.params;
    const filepath = path.join(hlsRoot, trackId!, quality!, `${segment}`!);

    if (!fs.existsSync(filepath)) {
        return res.status(404).json({
            error: 'NOT_FOUND',
            code: 'STREAM_002',
            message: `Track segment '${segment}' not found`
        });
    }

    res.setHeader('Content-Type', segment.endsWith('.ts') ? 'video/mp2t' : 'audio/mp4');
    res.setHeader('Cache-Control', 'public, max-age=3600');
    res.setHeader('Accept-Ranges', 'bytes');

    const stat = await fsp.stat(filepath);
    res.setHeader('Content-Length', stat.size);

    fs.createReadStream(filepath).pipe(res);
});

export default router;