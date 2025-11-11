import express from 'express';
import path from 'node:path';
import fsp from 'node:fs/promises';
import { getLocalIp } from './utils/ip.js';
import { pathToFileURL } from 'node:url';
import { healthRoute } from './utils/health.js';
import cors, { type CorsOptions } from 'cors';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { $envPath } from '@sonic-atlas/shared';
import { logger } from './utils/logger.js';
import compression from 'compression';
import http from 'node:http';
import { SocketServer } from './socket/ws.js';
import dotenv from 'dotenv';
dotenv.config({ quiet: true, path: $envPath });

const PORT = Number(process.env.BACKEND_PORT) || 3000;
const ip = getLocalIp();

const app = express();
app.disable('x-powered-by');

const allowedOrigins = (process.env.CORS_ORIGIN ?? `http://localhost:5173,http://${ip}:5173`)
    .split(',')
    .map(origin => origin.trim());

const corsOptions: CorsOptions = {
    origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
        if (!origin) {
            return callback(null, true);
        }
        if (allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            callback(null, false);
        }
    },
    methods: ['GET', 'POST', 'DELETE', 'PATCH', 'OPTIONS'],
    credentials: true,
    allowedHeaders: ['Content-Type', 'Authorization'],
    optionsSuccessStatus: 204
}

app.use(cors(corsOptions));
app.options(/.*/, cors(corsOptions));

app.use(compression({ filter: req => !req.path.startsWith('/api/stream') }));

app.use(express.json({
    limit: '10mb',
    type: ['application/json'],
    verify: (req) => {
        if ((req.url?.startsWith('/api/stream') && !req.url?.endsWith('/quality')) || req.url?.startsWith('/hls')) {
            throw new Error('Skip body parsing for stream');
        }
    },
}));

app.use('/api',
    //* IP rate limit
    rateLimit({
        windowMs: 1 * 60 * 1000,
        limit: Number(process.env.RATE_LIMIT_PER_MINUTE) ?? 100,
        skip: (req) => req.method === "OPTIONS",
    }),
    //* User rate limit
    rateLimit({
        windowMs: 60 * 60 * 1000,
        max: Number(process.env.USER_RATE_LIMIT_PER_HOUR) ?? 1000,
        keyGenerator: (req) => {
            if (req.user?.id) return req.user?.id;
            
            return ipKeyGenerator(req.ip!);
        },
        skip: (req) => req.method === "OPTIONS",
    })
);

/* Keeping as a backup, or for testing without auth idk
// HLS headers
const hlsPath = path.join($rootDir, process.env.STORAGE_PATH || 'storage', 'hls');
app.use('/hls', express.static(hlsPath, {
    fallthrough: false,
    setHeaders(res, path) {
        if (path.endsWith('.m3u8')) {
            res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
            res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        } else if (path.endsWith('.ts')) {
            res.setHeader('Content-Type', 'video/mp2t');
            res.setHeader('Cache-Control', 'public, max-age=3600');
        }
        res.setHeader('Accept-Ranges', 'bytes');
    },
}));
app.head('/hls{/*path}', (req, res) => res.sendStatus(200));
*/
app.head('/api/stream/:trackId{/*path}', (req, res) => res.sendStatus(200));

//* Health route. Not auto loading to not use the /api prefix
app.get('/health', healthRoute);
logger.info('Loaded route: /health');

//* Load api routes dynamically
const apiDir = path.join(import.meta.dirname, 'routes');
async function loadRoutes(dir: string) {
    const entries = await fsp.readdir(dir, { withFileTypes: true });

    await Promise.all(entries.map(async (entry) => {
        const fullPath = path.join(dir, entry.name);

        if (entry.isDirectory()) {
            await loadRoutes(fullPath);
        } else if (entry.isFile() && (entry.name.endsWith('.ts') || entry.name.endsWith('.js')) && !entry.name.startsWith('_')) {
            const relativePath = path.relative(apiDir, fullPath);
            const routePath = relativePath.replace(/\.ts/, '').replace(/\\/g, '/');

            try {
                const { default: router } = await import(pathToFileURL(fullPath).href);

                if (router) {
                    app.use(`/api/${routePath}`, router);
                    logger.info(`Loaded route: /api/${routePath}`);
                } else {
                    logger.warn(`No default export in ${relativePath}`);
                }
            } catch (err) {
                logger.error(`Failed to load ${relativePath}:\n${err}`);
            }
        }
    }));
}

const server = http.createServer(app);
export const socket = new SocketServer(server);

async function main() {
    await loadRoutes(apiDir);
    socket.setupSocket();

    app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
        logger.error(`Error: ${err.message}`);
        res.status(err.status || 500).json({ error: err.message });
    });

    server.listen(PORT, '0.0.0.0', () => {
        logger.info(`Server is running at:
Local:   \x1b[32m\x1b[4mhttp://localhost:${PORT}\x1b[0m
Network: \x1b[32m\x1b[4mhttp://${ip}:${PORT}\x1b[0m`);
    });
}

main().catch((err) => {
    logger.error(`Startup failed: ${err}`);
    process.exit(1);
});