import type { Request, Response, NextFunction } from 'express';
import { pgClient } from '#db/db';
import { logger } from './logger.ts';
import { exec } from 'node:child_process';
import pkg from '../../package.json' with { type: 'json' }

type HealthComponentRes = 'ok' | 'not ok' | 'err';

export async function healthRoute(req: Request, res: Response, next: NextFunction) {
    const start = performance.now();

    const checks = await Promise.allSettled([
        checkPg(),
        checkFrontend(), 
        checkFFmpeg()
    ]);
    const [pgStatus, feStatus, ffStatus] = checks.map(c => c.status === 'fulfilled' ? c.value : 'err');

    const critOk = pgStatus === 'ok';
    const allOk = critOk && feStatus === 'ok' && ffStatus === 'ok'
    const status = allOk ? 'ok' : critOk ? 'degraded' : 'down';
    const httpStatus = critOk ? 200 : 503;

    if (pgStatus === 'not ok') {
        logger.warn(`(GET /health) Postgres server is 'not ok'. This is most likely due to the server not currently running.`);
    }
    if (feStatus === 'not ok') {
        logger.warn(`(GET /health) Frontend is 'not ok'. It appears the website cannot be reached.`);
    }
    if (ffStatus === 'not ok') {
        logger.warn(`(GET /health) FFmpeg is 'not ok'. This error appeared when checking via 'ffmpeg -version'.`);
    }

    const duration = performance.now() - start;

    return res.status(httpStatus).json({
        status: status,
        version: pkg.version,
        uptime: process.uptime(),
        responseTimeMs: duration,

        backend: 'ok',
        postgres: pgStatus,
        frontend: feStatus,
        ffmpeg: ffStatus
    });
}

async function checkPg(): Promise<HealthComponentRes> {
    try {
        const result = await pgClient`SELECT 1 as health;`;
        return result.length ? 'ok' : 'not ok';
    } catch {
        return 'err';
    }
}

async function checkFrontend(): Promise<HealthComponentRes> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3000);

    try {
        const url = process.env.CORS_ORIGIN ?? 'http://localhost:5173';

        const res = await fetch(url, { signal: controller.signal });
        if (!res.ok) {
            return 'not ok';
        }

        return 'ok';
    } catch {
        return 'err';
    } finally {
        clearTimeout(timeout);
    }
}

async function checkFFmpeg(): Promise<HealthComponentRes> {
    try {
        return new Promise((resolve) => {
            exec('ffmpeg -version', (err) => {
                resolve(err ? 'not ok' : 'ok');
            });
        });
    } catch {
        return 'err';
    }
}