import { randomUUID } from 'node:crypto';
import { logger } from '../utils/logger.ts';
import type { FileManifestEntry, ReleaseUploadMetadata } from '@sonic-atlas/shared';

const CHUNK_SIZE = 50 * 1024 * 1024; // 50 MB
const SESSION_TTL_MS = 2 * 60 * 60 * 1000; // 2 hours
const CLEANUP_INTERVAL_MS = 30 * 60 * 1000; // 30 minutes
const MAX_BUFFERED_BYTES = 1024 * 1024 * 1024; // 1 GB per session

export type { FileManifestEntry, ReleaseUploadMetadata } from '@sonic-atlas/shared';

export interface UploadFileState {
    fileId: string;
    fileName: string;
    fileSize: number;
    mimeType: string;
    needsChunking: boolean;
    totalChunks: number;
    receivedChunks: Set<number>;
    buffers: Buffer[];
    completed: boolean;
    trackId?: string;
}


export interface UploadSession {
    uploadId: string;
    releaseMetadata: ReleaseUploadMetadata;
    files: Map<string, UploadFileState>;
    coverFileId?: string;
    totalBufferedBytes: number;
    releaseCoverPath: string | null;
    releaseId?: string;
    createdAt: Date;
    expiresAt: Date;
}

const sessions = new Map<string, UploadSession>();

export function createSession(
    releaseMetadata: ReleaseUploadMetadata,
    manifest: FileManifestEntry[],
    coverFileName?: string,
): UploadSession {
    const uploadId = randomUUID();
    const now = new Date();

    const files = new Map<string, UploadFileState>();

    for (const entry of manifest) {
        const fileId = randomUUID();
        const needsChunking = entry.fileSize > CHUNK_SIZE;
        const totalChunks = needsChunking
            ? Math.ceil(entry.fileSize / CHUNK_SIZE)
            : 1;

        files.set(fileId, {
            fileId,
            fileName: entry.fileName,
            fileSize: entry.fileSize,
            mimeType: entry.mimeType,
            needsChunking,
            totalChunks,
            receivedChunks: new Set(),
            buffers: [],
            completed: false,
        });
    }

    let coverFileId: string | undefined;
    if (coverFileName) {
        for (const [id, file] of files.entries()) {
            if (file.fileName === coverFileName) {
                coverFileId = id;
                break;
            }
        }
    }

    const session: UploadSession = {
        uploadId,
        releaseMetadata,
        files,
        ...(coverFileId ? { coverFileId } : {}),
        totalBufferedBytes: 0,
        releaseCoverPath: null,
        createdAt: now,
        expiresAt: new Date(now.getTime() + SESSION_TTL_MS),
    };

    sessions.set(uploadId, session);
    logger.info(`Upload session created: ${uploadId} (${files.size} files)`);
    return session;
}

export function getSession(uploadId: string): UploadSession | undefined {
    const session = sessions.get(uploadId);
    if (session && session.expiresAt < new Date()) {
        cleanupSession(uploadId);
        return undefined;
    }
    return session;
}

export function addChunk(
    session: UploadSession,
    fileId: string,
    chunkIndex: number,
    data: Buffer,
): { ok: true } | { ok: false; error: string } {
    const file = session.files.get(fileId);
    if (!file) {
        return { ok: false, error: 'Unknown fileId' };
    }

    if (file.completed) {
        return { ok: false, error: 'File already completed' };
    }

    if (chunkIndex < 0 || chunkIndex >= file.totalChunks) {
        return { ok: false, error: `Invalid chunkIndex: ${chunkIndex}. Expected 0-${file.totalChunks - 1}` };
    }

    if (file.receivedChunks.has(chunkIndex)) {
        return { ok: true };
    }

    if (session.totalBufferedBytes + data.length > MAX_BUFFERED_BYTES) {
        return { ok: false, error: 'Session memory limit exceeded (1 GB)' };
    }

    file.buffers[chunkIndex] = data;
    file.receivedChunks.add(chunkIndex);
    session.totalBufferedBytes += data.length;

    return { ok: true };
}

export function isFileComplete(file: UploadFileState): boolean {
    return file.receivedChunks.size === file.totalChunks;
}

export function assembleFile(file: UploadFileState): Buffer {
    return Buffer.concat(file.buffers);
}

export function markFileProcessed(
    session: UploadSession,
    fileId: string,
    trackId: string,
): void {
    const file = session.files.get(fileId);
    if (!file) return;

    file.completed = true;
    file.trackId = trackId;

    const freedBytes = file.buffers.reduce((sum, b) => sum + (b?.length ?? 0), 0);
    file.buffers = [];
    session.totalBufferedBytes -= freedBytes;
}

export function allFilesComplete(session: UploadSession): boolean {
    for (const file of session.files.values()) {
        if (!file.completed) return false;
    }
    return true;
}

export function cleanupSession(uploadId: string): void {
    sessions.delete(uploadId);
    logger.info(`Upload session cleaned up: ${uploadId}`);
}

export function getSessionStatus(session: UploadSession) {
    const files: Array<{
        fileId: string;
        fileName: string;
        needsChunking: boolean;
        totalChunks: number;
        receivedChunks: number;
        completed: boolean;
        trackId?: string;
    }> = [];

    for (const [fileId, file] of session.files.entries()) {
        files.push({
            fileId,
            fileName: file.fileName,
            needsChunking: file.needsChunking,
            totalChunks: file.totalChunks,
            receivedChunks: file.receivedChunks.size,
            completed: file.completed,
            ...(file.trackId ? { trackId: file.trackId } : {}),
        });
    }

    return {
        uploadId: session.uploadId,
        files,
        allComplete: allFilesComplete(session),
    };
}

function cleanupExpired(): void {
    const now = new Date();
    let cleaned = 0;
    for (const [id, session] of sessions.entries()) {
        if (session.expiresAt < now) {
            sessions.delete(id);
            cleaned++;
        }
    }
    if (cleaned > 0) {
        logger.info(`Cleaned up ${cleaned} expired upload session(s)`);
    }
}

setInterval(cleanupExpired, CLEANUP_INTERVAL_MS);

export { CHUNK_SIZE };
