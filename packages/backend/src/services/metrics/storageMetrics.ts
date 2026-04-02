import client from 'prom-client';
import { register } from './registry.ts';
import fs from 'node:fs/promises';
import path from 'node:path';

export async function rebuildStorageMetrics() {
    const base = process.env.STORAGE_PATH ?? 'storage';

    const [originals, hls, metadata] = await Promise.all([
        getFolderSize(`${base}/originals`),
        getFolderSize(`${base}/hls`),
        getFolderSize(`${base}/metadata`)
    ]);

    storageBytes.labels({ type: 'original', quality: 'none' }).set(originals);
    storageBytes.labels({ type: 'hls', quality: 'all' }).set(hls);
    storageBytes.labels({ type: 'metadata', quality: 'none' }).set(metadata);
}

export async function getFolderSize(root: string, concurrency = 64): Promise<number> {
    let total = 0;
    let active = 0;
    const dirs: string[] = [root];
    const statQueue: string[] = [];

    async function processStats(): Promise<void> {
        while (statQueue.length) {
            const file = statQueue.pop()!;
            active++;

            try {
                const stat = await fs.stat(file);
                total += stat.size;
            } catch {}

            active--;
        }
    }

    const workers: Promise<void>[] = [];
    for (let i = 0; i < concurrency; i++) {
        workers.push(processStats());
    }

    while (dirs.length) {
        const dir = dirs.pop()!;

        let entries;
        try {
            entries = await fs.readdir(dir, { withFileTypes: true });
        } catch {
            continue;
        }

        for (const entry of entries) {
            const full = path.join(dir, entry.name);

            if (entry.isDirectory()) {
                dirs.push(full);
            } else if (entry.isFile()) {
                statQueue.push(full);
            }
        }
    }

    await Promise.all(workers);

    return total;
}

export const storageBytes = new client.Gauge({
    name: 'storage_bytes',
    help: 'Total used storage by the chosen storage directory',
    labelNames: ['type', 'quality'],
    registers: [register]
});