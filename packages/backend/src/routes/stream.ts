import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { db } from '../../db/db.js';
import { eq } from 'drizzle-orm';
import { tracks } from '../../db/schema.js';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { logger } from '../utils/logger.js';
import { isUUID } from '../utils/isUUID.js';
import { $rootDir } from '@sonic-atlas/shared';
import { verifyJwt } from '../utils/jwt.js';

const router = Router();

type ValidQualities = 'efficiency' | 'high' | 'cd' | 'hires';

// Custom auth middleware for streaming (supports token in query param)
router.use((req, res, next) => {
    const tokenParam = req.query.token as string;
    
    if (tokenParam) {
        // Verify JWT token from query param
        const decoded = verifyJwt(tokenParam);
        if (decoded && decoded.authenticated) {
            req.user = decoded;
            return next();
        }
    }
    
    // Fall back to standard auth middleware
    return authMiddleware(req, res, next);
});

// Quality settings for FFmpeg transcoding
const qualitySettings: Record<ValidQualities, string[]> = {
    efficiency: ['-c:a', 'aac', '-b:a', '128k'],
    high: ['-c:a', 'aac', '-b:a', '320k'],
    cd: ['-c:a', 'flac', '-sample_fmt', 's16', '-ar', '44100'],
    hires: ['-c:a', 'flac']
};

const qualityMimeTypes: Record<ValidQualities, string> = {
    efficiency: 'audio/aac',
    high: 'audio/aac',
    cd: 'audio/flac',
    hires: 'audio/flac'
};

const qualityHierarchy: ValidQualities[] = ['efficiency', 'high', 'cd', 'hires'];

// Determine source quality based on track metadata
function getSourceQuality(track: any): ValidQualities {
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

function shouldDownsample(requested: ValidQualities, source: ValidQualities): boolean {
    const requestedIndex = qualityHierarchy.indexOf(requested);
    const sourceIndex = qualityHierarchy.indexOf(source);
    return requestedIndex > sourceIndex;
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
        where: eq(tracks.id, trackId!)
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
        const sourceQuality = getSourceQuality(track);
        const requestedQuality = quality;
        
        const actualQuality = shouldDownsample(requestedQuality, sourceQuality) ? sourceQuality : requestedQuality;
        
        if (actualQuality !== requestedQuality) {
            logger.info(`Quality ${requestedQuality} exceeds source at ${actualQuality}`);
        }

        const storagePath = process.env.STORAGE_PATH || '/storage';
        const originalPath = path.join(storagePath, 'originals', track.filename);

        // Build FFmpeg command based on quality
        const ffmpegArgs = [
            '-i', originalPath,
            '-vn',
            '-map', '0:a',
            ...qualitySettings[actualQuality],
            '-f', actualQuality === 'efficiency' || actualQuality === 'high' ? 'adts' : 'flac',
            'pipe:1'
        ];

        const ffmpeg = spawn('ffmpeg', ffmpegArgs);

        res.setHeader('Content-Type', qualityMimeTypes[actualQuality]);
        res.setHeader('Accept-Ranges', 'none');
        res.setHeader('Access-Control-Allow-Origin', process.env.CORS_ORIGIN || 'http://localhost:5173');
        res.setHeader('Cache-Control', 'no-cache');

        ffmpeg.stdout.pipe(res);

        ffmpeg.stderr.on('data', (data) => {
            logger.debug(`FFmpeg: ${data.toString()}`);
        });

        ffmpeg.on('error', (err) => {
            logger.error(`FFmpeg process error: ${err.message}`);
            if (!res.headersSent) {
                res.status(500).json({
                    error: 'INTERNAL_SERVER_ERROR',
                    message: 'Transcoding failed'
                });
            }
        });

        ffmpeg.on('close', (code) => {
            if (code !== 0 && code !== null) {
                logger.error(`FFmpeg exited with code ${code}`);
            }
        });

        req.on('close', () => {
            if (!ffmpeg.killed) {
                ffmpeg.kill('SIGKILL');
            }
        });

    } catch (err) {
        logger.error(`(GET /api/stream) Unknown Error Occurred:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Track streaming failed due to an internal error'
        });
    }
});

export default router;