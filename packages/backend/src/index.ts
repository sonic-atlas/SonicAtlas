import express from 'express';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import { pathToFileURL } from 'node:url';
import dotenv from 'dotenv';
dotenv.config({ quiet: true });

const PORT = Number(process.env.BACKEND_PORT) || 3000;

const app = express();
app.use(express.json());

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
                console.log(`\x1b[1m\x1b[34m[Express]\x1b[0m Loaded route: /api/${routePath}`);
            } else {
                console.warn(`\x1b[1m\x1b[34m[Express]\x1b[0m No default export in ${relativePath}`);
            }
        }
    }
}

await loadRoutes(apiDir);

const server = app.listen(PORT, '', () => {
    const ip = getLocalIp();
    console.log(`\x1b[1m\x1b[34m[Express]\x1b[0m Server is running at:`);
    console.log(`    Local:   \x1b[32m\x1b[4mhttp://localhost:${PORT}\x1b[0m`);
    console.log(`    Network: \x1b[32m\x1b[4mhttp://${ip}:${PORT}\x1b[0m`);
});

function getLocalIp() {
    const nets = os.networkInterfaces();
    for (const name of Object.keys(nets)) {
        const netInfos = nets[name];
        if (!netInfos) continue;
        for (const net of netInfos) {
            if (net.family === 'IPv4' && !net.internal) {
                return net.address;
            }
        }
    }
    return '127.0.0.1';
}