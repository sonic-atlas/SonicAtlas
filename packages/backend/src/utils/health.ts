import type { Request, Response, NextFunction } from 'express';
import { pgClient, /* redisClient, redisConnected */ } from '#db/db';
import { logger } from './logger.ts';

export async function healthRoute(req: Request, res: Response, next: NextFunction) {
    const [pgStatus, /* redisStatus, transcoderStatus */] = await Promise.all([checkPg(), /* checkRedis(), checkTranscoder() */]);
    const allOk = pgStatus === 'ok' /* && redisStatus === 'ok' && transcoderStatus === 'ok' */ ? 'ok' : 'not ok';
    const httpStatus = allOk === 'ok' ? 200 : 503;

    if (pgStatus === 'not ok') {
        logger.warn(`(GET /health) Postgres server is 'not ok'. This is most likely due to the server not currently running.`);
    } /* else if (transcoderStatus === 'not ok') {
        logger.warn(`(GET /health) Transcoder server is 'not ok'. This is because it isn't running.`);
    } */

    return res.status(httpStatus).json({
        status: allOk,
        backend: 'ok',
        database: pgStatus,
        // redis: redisStatus,
        // transcoder: transcoderStatus
    });
}

/* async function checkRedis(): Promise<'ok' | 'not ok'> {
    if (!redisConnected || !redisClient.isOpen) {
        return 'not ok';
    }

    try {
        const result = await redisClient.ping();

        if (result === 'PONG') {
            return 'ok';
        }
    } catch { }

    return 'not ok';
} */

async function checkPg(): Promise<'ok' | 'not ok'> {
    try {
        const result = await pgClient`SELECT 1;`;

        if (result.columns.length > 0) {
            return 'ok';
        }

        return 'not ok';
    } catch (err) {
        return 'not ok';
    }
}

/* async function checkTranscoder(): Promise<'ok' | 'not ok'> {
    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 3000);

        const response = await fetch(`${process.env.TRANSCODER_PATH ?? 'http://localhost:8000'}/health`, {
            signal: controller.signal
        });

        clearTimeout(timeoutId);

        if (!response.ok) {
            throw new Error(`HTTP error. Status: ${response.status}`);
        }

        const data = (await response.json()) as { status: string };

        if (data.status === 'ok') {
            return 'ok';
        }

        return 'not ok';
    } catch {
        return 'not ok';
    }
} */