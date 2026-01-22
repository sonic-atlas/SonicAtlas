import { generateHLS } from '../utils/pretranscode.ts';
import { socket } from '../index.ts';
import { logger } from '../utils/logger.ts';
import type { InferSelectModel } from 'drizzle-orm';
import type { tracks } from '$db/schema.ts';
import fs from 'node:fs/promises';

type TranscodeJob = {
    track: InferSelectModel<typeof tracks>;
    filePath: string;
    socketId?: string;
};

const MAX_CONCURRENT_TRANSCODES = Number(process.env.MAX_CONCURRENT_TRANSCODES) || 4;
const queue: TranscodeJob[] = [];
let activeTranscodes = 0;

export function enqueueTranscodeJob(job: TranscodeJob) {
    queue.push(job);
    processQueue();
}

async function processQueue() {
    if (activeTranscodes >= MAX_CONCURRENT_TRANSCODES || queue.length === 0) {
        return;
    }

    const job = queue.shift();
    if (!job) return;

    activeTranscodes++;

    const { track, filePath, socketId } = job;

    try {
        if (socketId) {
            socket.io.to(socketId).emit('transcode:started', { trackId: track.id });
        }

        logger.info(`Starting background transcode for track ${track.id}`);
        await generateHLS(track, filePath, socketId);

        try {
            await fs.unlink(filePath);
            logger.info(`Deleted original file for track ${track.id}: ${filePath}`);
        } catch (unlinkErr) {
            logger.error(`Failed to delete original file for track ${track.id}: ${unlinkErr}`);
        }

        if (socketId) {
            socket.io.to(socketId).emit('transcode:done', { trackId: track.id });
        }
        logger.info(`Finished background transcode for track ${track.id}`);

    } catch (err) {
        logger.error(`Transcode failed for track ${track.id}: ${err}`);
        if (socketId) {
            socket.io.to(socketId).emit('transcode:error', { trackId: track.id, error: String(err) });
        }
    } finally {
        activeTranscodes--;
        processQueue();
    }
}
