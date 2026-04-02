import { Router } from 'express';
import { db } from '#db/db';
import { releases, tracks, releaseTracks, trackMetadata } from '#db/schema';
import { eq, sql } from 'drizzle-orm';
import multer from 'multer';
import path from 'node:path';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import { authMiddleware } from '../middleware/auth.ts';
import { logger } from '../utils/logger.ts';
import { $rootDir } from '@sonic-atlas/shared';
import { ImageService } from '../services/ImageService.ts';
import { processTrackFile, type ProcessTrackOptions } from '../utils/processTrackFile.ts';
import {
    createSession,
    getSession,
    addChunk,
    isFileComplete,
    assembleFile,
    markFileProcessed,
    allFilesComplete,
    cleanupSession,
    getSessionStatus,
    CHUNK_SIZE,
    type UploadSession,
} from '../services/uploadSession.ts';
import type { FileManifestEntry, ReleaseUploadMetadata } from '@sonic-atlas/shared';

const router = Router();
router.use(authMiddleware);

const uploadFolder = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'originals');
const metadataFolder = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'metadata');

fs.mkdirSync(uploadFolder, { recursive: true });
fs.mkdirSync(metadataFolder, { recursive: true });

const storage = multer.memoryStorage();
const upload = multer({
    storage,
    limits: { fileSize: CHUNK_SIZE + 2 * 1024 * 1024 },
});

// POST /api/uploads/init

router.post('/init', async (req, res) => {
    try {
        const { releaseMetadata, files, coverFileName } = req.body as {
            releaseMetadata: ReleaseUploadMetadata;
            files: FileManifestEntry[];
            coverFileName?: string;
        };

        if (!releaseMetadata || !files?.length) {
            return res.status(400).json({
                error: 'BAD_REQUEST',
                message: 'releaseMetadata and files[] are required',
            });
        }

        const session = createSession(releaseMetadata, files, coverFileName);

        const filesPlan = Array.from(session.files.entries()).map(([fileId, f]) => ({
            fileId,
            fileName: f.fileName,
            needsChunking: f.needsChunking,
            totalChunks: f.totalChunks,
            chunkSize: CHUNK_SIZE,
        }));

        return res.status(201).json({
            uploadId: session.uploadId,
            files: filesPlan,
        });
    } catch (err) {
        logger.error(`(POST /api/uploads/init) Error: ${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to create upload session',
        });
    }
});

// POST /api/uploads/:uploadId/file — complete small file (≤ 50 MB)

router.post('/:uploadId/file', upload.single('file'), async (req, res) => {
    try {
        const session = getSession(req.params.uploadId!);
        if (!session) {
            return res.status(404).json({ error: 'NOT_FOUND', message: 'Upload session not found or expired' });
        }

        const { fileId } = req.body;
        const file = session.files.get(fileId);

        if (!file) {
            return res.status(400).json({ error: 'BAD_REQUEST', message: 'Unknown fileId' });
        }

        if (file.completed) {
            return res.status(409).json({ error: 'CONFLICT', message: 'File already processed' });
        }

        if (!req.file?.buffer) {
            return res.status(400).json({ error: 'BAD_REQUEST', message: 'No file data received' });
        }

        // Prevent file names being like '../../something_malicious'
        const sanitizedFileName = path.basename(file.fileName);
        const tmpFileName = `${Date.now()}-${sanitizedFileName}`;
        const filePath = path.join(uploadFolder, tmpFileName);
        await fsp.writeFile(filePath, req.file.buffer);

        if (!session.releaseId) {
            await createReleaseForSession(session);
        }

        const result = await processTrackFile(buildProcessOpts(session, file.fileName, filePath));

        if (!result) {
            return res.status(500).json({ error: 'INTERNAL_SERVER_ERROR', message: 'Failed to process file' });
        }

        if (result.releaseCoverUrl) {
            session.releaseCoverPath = result.releaseCoverUrl;
        }

        markFileProcessed(session, fileId, result.track.id);

        return res.json({
            fileId,
            trackId: result.track.id,
            status: 'processing',
        });
    } catch (err) {
        logger.error(`(POST /api/uploads/:uploadId/file) Error: ${err}`);
        return res.status(500).json({ error: 'INTERNAL_SERVER_ERROR', message: 'File upload failed' });
    }
});

// POST /api/uploads/:uploadId/chunk

router.post('/:uploadId/chunk', upload.single('chunk'), async (req, res) => {
    try {
        const session = getSession(req.params.uploadId!);
        if (!session) {
            return res.status(404).json({ error: 'NOT_FOUND', message: 'Upload session not found or expired' });
        }

        const { fileId, chunkIndex } = req.body;
        const index = parseInt(chunkIndex);

        if (!req.file?.buffer) {
            return res.status(400).json({ error: 'BAD_REQUEST', message: 'No chunk data received' });
        }

        const result = addChunk(session, fileId, index, req.file.buffer);

        if (!result.ok) {
            const status = result.error.includes('memory limit') ? 413 : 400;
            return res.status(status).json({ error: 'BAD_REQUEST', message: result.error });
        }

        const file = session.files.get(fileId)!;

        return res.json({
            received: index,
            chunksReceived: file.receivedChunks.size,
            totalChunks: file.totalChunks,
            complete: isFileComplete(file),
        });
    } catch (err) {
        logger.error(`(POST /api/uploads/:uploadId/chunk) Error: ${err}`);
        return res.status(500).json({ error: 'INTERNAL_SERVER_ERROR', message: 'Chunk upload failed' });
    }
});

// POST /api/uploads/:uploadId/file/:fileId/complete

router.post('/:uploadId/file/:fileId/complete', async (req, res) => {
    try {
        const session = getSession(req.params.uploadId!);
        if (!session) {
            return res.status(404).json({ error: 'NOT_FOUND', message: 'Upload session not found or expired' });
        }

        const file = session.files.get(req.params.fileId!);
        if (!file) {
            return res.status(400).json({ error: 'BAD_REQUEST', message: 'Unknown fileId' });
        }

        if (file.completed) {
            return res.status(409).json({ error: 'CONFLICT', message: 'File already processed', trackId: file.trackId });
        }

        if (!isFileComplete(file)) {
            return res.status(400).json({
                error: 'BAD_REQUEST',
                message: `File incomplete: received ${file.receivedChunks.size}/${file.totalChunks} chunks`,
            });
        }

        const assembled = assembleFile(file);
        const sanitizedFileName = path.basename(file.fileName);
        const tmpFileName = `${Date.now()}-${sanitizedFileName}`;
        const filePath = path.join(uploadFolder, tmpFileName);
        await fsp.writeFile(filePath, assembled);

        if (!session.releaseId) {
            await createReleaseForSession(session);
        }

        const result = await processTrackFile(buildProcessOpts(session, file.fileName, filePath));

        if (!result) {
            return res.status(500).json({ error: 'INTERNAL_SERVER_ERROR', message: 'Failed to process assembled file' });
        }

        if (result.releaseCoverUrl) {
            session.releaseCoverPath = result.releaseCoverUrl;
        }

        markFileProcessed(session, file.fileId, result.track.id);

        return res.json({
            fileId: file.fileId,
            trackId: result.track.id,
            status: 'processing',
        });
    } catch (err) {
        logger.error(`(POST /api/uploads/:uploadId/file/:fileId/complete) Error: ${err}`);
        return res.status(500).json({ error: 'INTERNAL_SERVER_ERROR', message: 'File completion failed' });
    }
});

// POST /api/uploads/:uploadId/complete — finalize release

router.post('/:uploadId/complete', upload.single('cover'), async (req, res) => {
    try {
        const session = getSession(req.params.uploadId!);
        if (!session) {
            return res.status(404).json({ error: 'Upload session not found' });
        }

        if (!allFilesComplete(session)) {
            return res.status(400).json({ error: 'Not all files are complete' });
        }

        const release = await db.query.releases.findFirst({
            where: { id: session.releaseId },
        });

        if (!release) {
            throw new Error('Release not found');
        }

        // Process release cover if uploaded
        if (req.file) {
            try {
                const metadataFolder = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'metadata');
                const releaseCoverName = `release_${release.id}_cover`;

                // Process and save cover (from memory buffer)
                await ImageService.processAndSaveCover(
                    req.file.buffer,
                    metadataFolder,
                    releaseCoverName
                );

                const coverUrl = `/api/releases/${release.id}/cover`;

                // Update release with cover path
                await db.update(releases)
                    .set({ coverArtPath: coverUrl })
                    .where(eq(releases.id, release.id));

                // Update release object for response
                release.coverArtPath = coverUrl;

            } catch (err) {
                logger.error(`Failed to process release cover: ${err}`);
            }
        }

        // Fetch full track details from DB to populate frontend list correctly
        const dbTracks = await db
            .select({
                id: tracks.id,
                title: sql<string>`coalesce(${trackMetadata.title}, ${tracks.originalFilename})`,
                artist: trackMetadata.artist,
                discNumber: releaseTracks.discNumber,
                trackNumber: releaseTracks.trackNumber,
                duration: tracks.duration,
                coverArtPath: tracks.coverArtPath,
                transcodeStatus: sql<string>`'done'`
            })
            .from(releaseTracks)
            .innerJoin(tracks, eq(releaseTracks.trackId, tracks.id))
            .leftJoin(trackMetadata, eq(tracks.id, trackMetadata.trackId))
            .where(eq(releaseTracks.releaseId, release.id))
            .orderBy(releaseTracks.discNumber, releaseTracks.trackNumber);

        // Check HLS status for each track
        const hlsBaseDir = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'hls');

        const tracksWithStatus = await Promise.all(dbTracks.map(async (t) => {
            const hlsPath = path.join(hlsBaseDir, t.id, 'master.m3u8');
            let isDone = false;
            try {
                await fsp.access(hlsPath);
                isDone = true;
            } catch {
                isDone = false;
            }

            return {
                ...t,
                originalFilename: t.title, // Backward compat
                transcodeStatus: isDone ? 'done' : 'pending'
            };
        }));

        cleanupSession(req.params.uploadId!);

        return res.json({
            release,
            tracks: tracksWithStatus
        });
    } catch (err) {
        logger.error(`(POST /api/uploads/:uploadId/complete) Error: ${err}`);
        return res.status(500).json({ error: 'INTERNAL_SERVER_ERROR', message: 'Release finalization failed' });
    }
});

// GET /api/uploads/:uploadId/status

router.get('/:uploadId/status', (req, res) => {
    const session = getSession(req.params.uploadId!);
    if (!session) {
        return res.status(404).json({ error: 'NOT_FOUND', message: 'Upload session not found or expired' });
    }

    return res.json(getSessionStatus(session));
});

function buildProcessOpts(session: UploadSession, fileName: string, filePath: string): ProcessTrackOptions {
    const opts: ProcessTrackOptions = {
        filePath,
        originalFilename: fileName,
        releaseId: session.releaseId!,
        releaseTitle: session.releaseMetadata.title,
        existingReleaseCoverPath: session.releaseCoverPath,
    };
    if (session.releaseMetadata.primaryArtist) opts.primaryArtist = session.releaseMetadata.primaryArtist;
    if (session.releaseMetadata.year) opts.year = session.releaseMetadata.year;
    if (session.releaseMetadata.extractAllCovers != null) opts.extractAllCovers = session.releaseMetadata.extractAllCovers;
    if (session.releaseMetadata.socketId) opts.socketId = session.releaseMetadata.socketId;
    return opts;
}

async function createReleaseForSession(session: UploadSession): Promise<void> {
    const meta = session.releaseMetadata;

    const [newRelease] = await db.insert(releases).values({
        title: meta.title || 'Untitled Release',
        primaryArtist: meta.primaryArtist ?? null,
        year: meta.year ? parseInt(meta.year) : new Date().getFullYear(),
        releaseType: (meta.releaseType as any) ?? 'album',
    }).returning();

    if (!newRelease) {
        throw new Error('Failed to create release record');
    }

    session.releaseId = newRelease.id;
}

export default router;
