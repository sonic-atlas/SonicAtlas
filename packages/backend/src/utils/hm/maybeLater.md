// https://discord.com/channels/@me/1335710827403284550/1434019748638887978

**Option 1**
*index.ts*
```ts
import cluster from 'node:cluster';
import os from 'node:os';

const numCPUs = process.env.BACKEND_CORES ? Number(process.env.BACKEND_CORES) > os.cpus().length ? os.cpus().length : Number(process.env.BACKEND_CORES) : 1;

const prefix = numCPUs > 1 ? `[Worker ${process.pid}] ` : '';

if (cluster.isPrimary) {
    logger.info(`Primary ${process.pid} running with ${numCPUs} worker${numCPUs > 1 ? 's' : ''}`);

    for (let i = 0; i < numCPUs; i++) {
        cluster.fork();
    }

    cluster.on('exit', (worker) => {
        logger.warn(`Worker ${worker.process.pid} died. Restarting...`);
        cluster.fork();
    });

    const shutdownWorkers = () => {
        for (const id in cluster.workers) {
            cluster.workers[id]?.kill('SIGTERM');
        }
    }

    process.on('SIGTERM', shutdownWorkers);
    process.on('SIGINT', shutdownWorkers);
} else {
    // [ExpressJS server code here. From]
    // [const app = express()] [to]
    // [const server = ...]
    // [Add ${prefix} to start of logs]

    const shutdown = () => {
        server.close(() => process.exit(0));

        setTimeout(() => process.exit(1), 30_000);
    }

    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
}
```



**Option 2**
*utils/transcoderPool.ts*
```ts
import Piscina from 'piscina';
import path from 'node:path';
import os from 'node:os';

export const transcoderPool = new Piscina({
    filename: path.resolve('./transcodeWorker.js),
    maxThreads: Math.max(1, os.cpus().length - 1) // Possibly use .env opt. This is max
});
```

*utils/transcodeWorker.ts*
```ts
import { spawn } from 'node:child_process';
import { once } from 'node:events';

interface TranscodeJob {
    inputPath: string;
    args: string[];
}

// With piping
export default async function* (
    { inputPath, args }: TranscodeJob,
    { signal }: { signal?: AbortSignal}
): AsyncGenerator<Buffer> {
    const ffmpeg = spawn('ffmpeg', ['-i', inputPath, ...args, 'pipe:1']);

    const abortHandler = () => {
        if (!ffmpeg.killed) {
            ffmpeg.kill('SIGKILL');
        }
    }

    if (signal) {
        if (signal.aborted) abortHandler();
        signal.addEventListeners('abort', abortHandler, { once: true });
    }

    ffmpeg.on('error', (err) => {
        throw err;
    });
    ffmpeg.stderr.on('data', (data) => {
        // [Maybe log]
    });

    try {
        for await (const chunk of ffmpeg.stdout) {
            if (signal?.aborted) break;
            yield chunk;
        }

        const [code] = await once(ffmpeg, 'close');
        if (code !== 0 && !signal?.aborted) {
            throw new Error(`FFmpeg exited with code ${code}`);
        }
    } finally {
        signal?.removeEventListener('abort', abortHandler);
    }
}

// Without piping
export default async function ({ inputPath, args }: TranscodeJob) {
    return new Promise<Buffer>(async (resolve, reject) => {
        const ffmpeg = spawn('ffmpeg', ['-i', inputPath, ...args, 'pipe:1']);
        const chunks: Buffer[] = [];

        ffmpeg.stdout.on('data', (chunk) => chunks.push(chunk));
        ffmpeg.on('error', reject);
        ffmpeg.stderr.on('data', (data) => {
            // [Maybe log]
        });

        const [code] = await once(ffmpeg, 'close');
        if (code === 0) resolve(Buffer.concat(chunks));
        else reject(new Error(`FFmpeg exited with code ${code}`));
    });
}
```

*routes/stream.ts*
```ts
import { transcoderPool } from '../utils/transcoderPool.js';

// [Inside route]
const ffmpegArgs = [
    '-vn',
    '-map',' 0:a',
    ...qualitySettings[actualQuality],
    '-f', actualQuality === 'efficiency' || actualQuality === 'high' ? 'adts' : 'flac';
];

res.setHeader('Accept-Ranges', 'none');
res.setHeader('Access-Control-Allow-Origin', process.env.CORS_ORIGIN || 'http://localhost:5173');
res.setHeader('Content-Type', qualityMimeTypes[actualQuality]);
res.setHeader('Cache-Control', 'no-cache');

// With piping
const ac = new AbortController();
req.on('close' () => {
    ac.abort();
});

try {
    // With piping
    const stream = transcoderPool.run({ inputPath, args: fmmpegArgs }, { signal: ac.signal });

    for await (const chunk of stream as AsyncIterable<Buffer>) {
        if (!res.writableEnded) res.write(chunk);
        else break;
    }

    res.end();

    // Without piping
    const audioBuffer: Buffer = await transcoderPool.run({
        inputPath: originalPath,
        args: ffmpegArgs,
    });

    res.send(audioBuffer);
} catch (err) {
    // With piping
    if (ac.signal.aborted) return;

    ...
}

// With piping
req.on('close' () => {
    if (!res.writableEnded) res.end();
});
```

*index.ts*
```ts
import { transcoderPool } from './utils/transcoderPool.js';

process.on('SIGINT', async () => {
    await transcoderPool.destroy();
    process.exit(0);
});
```