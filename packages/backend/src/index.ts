import express from 'express';
import path from 'node:path';
import fs from 'node:fs';
import { getLocalIp } from './utils/ip.js';
import { pathToFileURL } from 'node:url';
import { healthRoute } from './utils/health.js';
import cors from 'cors';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { $envPath } from '@sonic-atlas/shared';
import { logger } from './utils/logger.js';
import dotenv from 'dotenv';
dotenv.config({ quiet: true, path: $envPath });

const PORT = Number(process.env.BACKEND_PORT) || 3000;

const app = express();
app.use(cors({
    origin: process.env.CORS_ORIGIN ?? 'http://localhost:5173',
    methods: ['GET', 'POST', 'DELETE', 'PATCH']
}));
app.use(express.json());
app.use('/api',
    //* IP rate limit
    rateLimit({
        windowMs: 1 * 60 * 1000,
        limit: Number(process.env.RATE_LIMIT_PER_MINUTE) ?? 100
    }),
    //* User rate limit
    rateLimit({
        windowMs: 60 * 60 * 1000,
        max: Number(process.env.USER_RATE_LIMIT_PER_HOUR) ?? 1000,
        keyGenerator: (req) => {
            if (req.user?.id) return req.user?.id;
            
            return ipKeyGenerator(req.ip!);
        }
    })
);

//* Health route. Not auto loading to not use the /api prefix
app.get('/health', healthRoute);
logger.info('Loaded route: /health');

//* Load api routes dynamically
const apiDir = path.join(import.meta.dirname, 'routes');
async function loadRoutes(dir: string) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);

        if (entry.isDirectory()) {
            loadRoutes(fullPath);
        } else if (entry.isFile() && entry.name.endsWith('.ts') && !entry.name.startsWith('_')) {
            const relativePath = path.relative(apiDir, fullPath);
            const routePath = relativePath.replace(/\.ts/, '').replace(/\\/g, '/');

            const routeModule = await import(pathToFileURL(fullPath).href);
            const router = routeModule.default;

            if (router) {
                app.use(`/api/${routePath}`, router);
                logger.info(`Loaded route: /api/${routePath}`);
            } else {
                logger.warn(`No default export in ${relativePath}`);
            }
        }
    }
}

await loadRoutes(apiDir);

const server = app.listen(PORT, '', () => {
    const ip = getLocalIp();
    logger.info(`Server is running at:
    Local:   \x1b[32m\x1b[4mhttp://localhost:${PORT}\x1b[0m
    Network: \x1b[32m\x1b[4mhttp://${ip}:${PORT}\x1b[0m
`);
});