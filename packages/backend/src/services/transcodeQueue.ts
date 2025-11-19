import { generateHLS } from '../utils/pretranscode.js';
import { socket } from '../index.js';
import { logger } from '../utils/logger.js';
import type { InferSelectModel } from 'drizzle-orm';
import type { tracks } from '$db/schema.js';

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
