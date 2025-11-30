import { Router, type Request } from 'express';
import { db } from '$db/db.js';
import { releases, releaseTracks, tracks, trackMetadata } from '$db/schema.js';
import { eq, desc, sql, and, ne } from 'drizzle-orm';
import { logger } from '../utils/logger.js';
import { isUUID } from '../utils/isUUID.js';
import { authMiddleware } from '../middleware/auth.js';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import fsp from 'node:fs/promises';
import { parseFile } from 'music-metadata';
import { enqueueTranscodeJob } from '../services/transcodeQueue.js';
import { stripCoverArt } from '../utils/stripCoverArt.js';
import { $envPath, $rootDir } from '@sonic-atlas/shared';
import dotenv from 'dotenv';

dotenv.config({ quiet: true, path: $envPath });

const router = Router();

// GET /api/releases/:id/cover
router.get('/:id/cover', async (req, res) => {
    const { id } = req.params;

    if (!isUUID(id!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'RELEASE_002',
            message: 'Release id must be a valid UUID'
        });
    }

    const extensions = ['jpg', 'jpeg', 'png', 'webp'];

    for (const ext of extensions) {
        const coverFile = path.join(metadataFolder, `release_${id}_cover.${ext}`);

        try {
            await fsp.access(coverFile);

            const contentTypes: Record<string, string> = {
                'jpg': 'image/jpeg',
                'jpeg': 'image/jpeg',
                'png': 'image/png',
                'webp': 'image/webp'
            }

            res.setHeader('Content-Type', contentTypes[ext] || 'image/jpeg');
            res.setHeader('Cache-Control', 'public, max-age=31536000');

            return res.sendFile(coverFile);
        } catch (err) {
            continue;
        }
    }

    return res.status(404).json({
        error: 'NOT_FOUND',
        code: 'COVER_001',
        message: 'No cover art found'
    });
});

router.use(authMiddleware);

const uploadFolder = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'originals');
const metadataFolder = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'metadata');

const storage = multer.diskStorage({
    destination: uploadFolder,
    filename(req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname);
    }
});

const allowedFiles = ['audio/flac', 'audio/mpeg', 'audio/wav', 'audio/aac', 'image/jpeg', 'image/png', 'image/webp'];

const fileFilter = (req: Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
    if (allowedFiles.includes(file.mimetype)) {
        cb(null, true);
    } else {
        cb(new Error(`Unsupported file MIME type: ${file.mimetype}`));
    }
};

const upload = multer({ storage, fileFilter });

// GET /api/releases
router.get('/', async (req, res) => {
    try {
        const allReleases = await db
            .select({
                id: releases.id,
                title: releases.title,
                primaryArtist: releases.primaryArtist,
                year: releases.year,
                releaseType: releases.releaseType,
                coverArtPath: releases.coverArtPath,
                createdAt: releases.createdAt,
                trackCount: sql<number>`count(${releaseTracks.id})::int`
            })
            .from(releases)
            .leftJoin(releaseTracks, eq(releases.id, releaseTracks.releaseId))
            .groupBy(releases.id)
            .orderBy(desc(releases.createdAt));

        return res.json(allReleases);
    } catch (err) {
        logger.error(`(GET /api/releases) Unknown Error Occurred:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to fetch releases'
        });
    }
});

// GET /api/releases/:id
router.get('/:id', async (req, res) => {
    const { id } = req.params;

    if (!isUUID(id!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'RELEASE_002',
            message: 'Release id must be a valid UUID'
        });
    }

    try {
        const release = await db.query.releases.findFirst({
            where: eq(releases.id, id!)
        });

        if (!release) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                code: 'RELEASE_001',
                message: 'Release not found'
            });
        }

        const releaseTracksData = await db
            .select({
                id: tracks.id,
                title: sql<string>`coalesce(${trackMetadata.title}, ${tracks.originalFilename})`,
                artist: trackMetadata.artist,
                discNumber: releaseTracks.discNumber,
                trackNumber: releaseTracks.trackNumber,
                duration: tracks.duration,
                coverArtPath: tracks.coverArtPath
            })
            .from(releaseTracks)
            .innerJoin(tracks, eq(releaseTracks.trackId, tracks.id))
            .leftJoin(trackMetadata, eq(tracks.id, trackMetadata.trackId))
            .where(eq(releaseTracks.releaseId, id!))
            .orderBy(
                releaseTracks.discNumber,
                releaseTracks.trackNumber,
                trackMetadata.title
            );

        const tracksWithCovers = releaseTracksData.map(track => ({
            ...track,
            coverArtPath: track.coverArtPath ?? (release.coverArtPath ? `/api/metadata/${track.id}/cover` : null)
        }));

        return res.json({
            release,
            tracks: tracksWithCovers
        });

    } catch (err) {
        logger.error(`(GET /api/releases/${id}) Unknown Error Occurred:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to fetch release details'
        });
    }
});



// POST /api/releases/upload
const uploadFields = upload.fields([
    { name: 'files[]', maxCount: 50 },
    { name: 'cover', maxCount: 1 }
]);

router.post('/upload', uploadFields, async (req, res) => {
    const files = (req.files as { [fieldname: string]: Express.Multer.File[] })['files[]'];
    const coverFile = (req.files as { [fieldname: string]: Express.Multer.File[] })['cover']?.[0];

    if (!files || files.length === 0) {
        return res.status(400).json({
            error: 'BAD_REQUEST',
            message: 'No files uploaded'
        });
    }

    const { releaseTitle, releaseType, primaryArtist, year, socketId, extractAllCovers } = req.body;
    const shouldExtractAllCovers = extractAllCovers === 'true';

    try {
        const [newRelease] = await db.insert(releases).values({
            title: releaseTitle || 'Untitled Release',
            primaryArtist: primaryArtist || null,
            year: year ? parseInt(year) : new Date().getFullYear(),
            releaseType: releaseType || 'album'
        }).returning();

        if (!newRelease) {
            throw new Error('Failed to create release');
        }

        if (coverFile) {
            try {
                await fsp.mkdir(metadataFolder, { recursive: true });
                const ext = path.extname(coverFile.originalname).replace('.', '') || 'jpg';
                const releaseCoverName = `release_${newRelease.id}_cover.${ext}`;
                const releaseCoverPath = path.join(metadataFolder, releaseCoverName);

                await fsp.rename(coverFile.path, releaseCoverPath);

                const coverUrl = `/api/releases/${newRelease.id}/cover`;
                await db.update(releases)
                    .set({ coverArtPath: coverUrl })
                    .where(eq(releases.id, newRelease.id));

                newRelease.coverArtPath = coverUrl;
            } catch (e) {
                logger.warn(`Failed to process uploaded release cover: ${e}`);
            }
        }

        const processedTracks: any[] = [];

        for (const file of files) {
            let attempts = 0;
            const maxAttempts = 3;
            let success = false;

            while (attempts < maxAttempts && !success) {
                attempts++;
                try {
                    const metadata = await parseFile(file.path);
                    const format = (metadata.format.codec?.toLowerCase() || path.extname(file.originalname).slice(1).toLowerCase()) as any;

                    const meta = {
                        duration: metadata.format.duration ? Math.round(metadata.format.duration) : null,
                        sampleRate: metadata.format.sampleRate ?? null,
                        bitDepth: metadata.format.bitsPerSample ?? null,
                        format,
                        title: metadata.common.title ?? path.parse(file.originalname).name,
                        artist: metadata.common.artist ?? primaryArtist ?? 'Unknown Artist',
                        album: metadata.common.album ?? releaseTitle ?? 'Unknown Album',
                        year: metadata.common.year ?? (year ? parseInt(year) : null),
                        genres: metadata.common.genre ?? null,
                        trackNo: metadata.common.track.no ?? null,
                        diskNo: metadata.common.disk.no ?? 1
                    };

                    const trackInfo = await db.transaction(async (tx) => {
                        const [track] = await tx.insert(tracks).values({
                            filename: file.filename,
                            originalFilename: file.originalname,
                            duration: meta.duration,
                            sampleRate: meta.sampleRate,
                            bitDepth: meta.bitDepth,
                            format: meta.format,
                            fileSize: file.size
                        }).returning();

                        if (!track) throw new Error('Failed to insert track');

                        const fileExt = path.extname(file.originalname);
                        const filename = `${track.id}${fileExt}`;
                        const newPath = path.join(uploadFolder, filename);


                        if (fs.existsSync(file.path)) {
                            await fsp.rename(file.path, newPath);
                        } else if (!fs.existsSync(newPath)) {
                            throw new Error('Source file not found for processing');
                        }

                        await stripCoverArt(newPath);

                        await tx.update(tracks).set({ filename }).where(eq(tracks.id, track.id));

                        await tx.insert(trackMetadata).values({
                            trackId: track.id,
                            title: meta.title,
                            artist: meta.artist,
                            albumId: null,
                            year: meta.year,
                            genres: meta.genres
                        });

                        // Guess track number from filename if not in metadata
                        let trackNumber = meta.trackNo;
                        if (!trackNumber) {
                            const match = file.originalname.match(/^(\d+)/);
                            if (match && match[1]) trackNumber = parseInt(match[1]);
                        }

                        await tx.insert(releaseTracks).values({
                            releaseId: newRelease.id,
                            trackId: track.id,
                            discNumber: meta.diskNo || 1,
                            trackNumber: trackNumber
                        });

                        if (metadata.common.picture && metadata.common.picture.length > 0) {
                            try {
                                const picture = metadata.common.picture[0];
                                if (picture && picture.data) {
                                    await fsp.mkdir(metadataFolder, { recursive: true });
                                    let ext = 'jpg';
                                    if (picture.format?.includes('png')) ext = 'png';
                                    else if (picture.format?.includes('webp')) ext = 'webp';

                                    if (!newRelease.coverArtPath) {
                                        const releaseCoverName = `release_${newRelease.id}_cover.${ext}`;
                                        const releaseCoverPath = path.join(metadataFolder, releaseCoverName);

                                        await fsp.writeFile(releaseCoverPath, picture.data);
                                        const coverUrl = `/api/releases/${newRelease.id}/cover`;

                                        await tx.update(releases)
                                            .set({ coverArtPath: coverUrl })
                                            .where(eq(releases.id, newRelease.id));

                                        newRelease.coverArtPath = coverUrl;
                                    }

                                    if (shouldExtractAllCovers) {
                                        const trackCoverPath = path.join(metadataFolder, `${track.id}_cover.${ext}`);
                                        await fsp.writeFile(trackCoverPath, picture.data);

                                        await tx.update(tracks)
                                            .set({ coverArtPath: `/api/metadata/${track.id}/cover` })
                                            .where(eq(tracks.id, track.id));
                                    }
                                }
                            } catch (e) {
                                logger.warn(`Failed to extract cover art for ${track.id}: ${e}`);
                            }
                        }

                        return { ...track, newPath };
                    });

                    enqueueTranscodeJob({
                        track: trackInfo as any,
                        filePath: trackInfo.newPath,
                        socketId
                    });

                    processedTracks.push({
                        id: trackInfo.id,
                        originalFilename: trackInfo.originalFilename,
                        title: meta.title,
                        artist: meta.artist,
                        discNumber: meta.diskNo || 1,
                        trackNumber: meta.trackNo,
                        duration: meta.duration,
                        transcodeStatus: 'pending'
                    });

                    success = true;

                } catch (fileErr) {
                    logger.error(`Failed to process file ${file.originalname} (Attempt ${attempts}/${maxAttempts}): ${fileErr}`);
                    if (attempts >= maxAttempts) {
                        logger.error(`Giving up on file ${file.originalname} after ${maxAttempts} attempts.`);
                    } else {
                        await new Promise(resolve => setTimeout(resolve, 1000));
                    }
                }
            }
        }

        return res.status(201).json({
            release: newRelease,
            tracks: processedTracks
        });

    } catch (err) {
        logger.error(`(POST /api/releases/upload) Error: ${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Upload failed'
        });
    }
});

// PATCH /api/releases/:id
router.patch('/:id', async (req, res) => {
    const { id } = req.params;
    const { title, primaryArtist, year, releaseType } = req.body;

    if (!isUUID(id!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'RELEASE_002',
            message: 'Release id must be a valid UUID'
        });
    }

    try {
        const [updatedRelease] = await db.update(releases)
            .set({
                title,
                primaryArtist,
                year: year ? parseInt(year) : undefined,
                releaseType,
                updatedAt: new Date()
            })
            .where(eq(releases.id, id!))
            .returning();

        if (!updatedRelease) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                code: 'RELEASE_001',
                message: 'Release not found'
            });
        }

        return res.json(updatedRelease);
    } catch (err) {
        logger.error(`(PATCH /api/releases/${id}) Error: ${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to update release'
        });
    }
});

// DELETE /api/releases/:id
router.delete('/:id', async (req, res) => {
    const { id } = req.params;

    if (!isUUID(id!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'RELEASE_002',
            message: 'Release id must be a valid UUID'
        });
    }

    try {
        const release = await db.query.releases.findFirst({
            where: eq(releases.id, id!)
        });

        if (!release) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                code: 'RELEASE_001',
                message: 'Release not found'
            });
        }

        const releaseTracksList = await db
            .select()
            .from(releaseTracks)
            .where(eq(releaseTracks.releaseId, id!));

        const trackIds = releaseTracksList.map(rt => rt.trackId).filter((id): id is string => id !== null);

        await db.delete(releaseTracks).where(eq(releaseTracks.releaseId, id!));

        await db.delete(releases).where(eq(releases.id, id!));

        const deletedFiles: string[] = [];
        const deletedFolders: string[] = [];
        const preservedTracks: string[] = [];
        const deletionErrors: string[] = [];

        try {
            const metadataDir = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'metadata');
            const entries = await fsp.readdir(metadataDir).catch(() => [] as string[]);
            for (const entry of entries) {
                if (entry.startsWith(`release_${id}_cover.`)) {
                    const p = path.join(metadataDir, entry);
                    try {
                        await fsp.unlink(p);
                        deletedFiles.push(p);
                    } catch (e) {
                        const msg = `Failed to remove release cover ${p}: ${e}`;
                        logger.warn(msg);
                        deletionErrors.push(msg);
                    }
                }
            }
        } catch (e) {
            const msg = `Failed to scan metadata dir for release cover files: ${e}`;
            logger.warn(msg);
            deletionErrors.push(msg);
        }

        for (const trackId of trackIds) {
            const [otherRelease] = await db.select().from(releaseTracks)
                .where(and(eq(releaseTracks.trackId, trackId), ne(releaseTracks.releaseId, id!)))
                .limit(1);

            if (!otherRelease) {
                const [track] = await db.select().from(tracks).where(eq(tracks.id, trackId));
                if (track) {
                    await db.delete(trackMetadata).where(eq(trackMetadata.trackId, trackId));

                    await db.delete(tracks).where(eq(tracks.id, trackId));

                    if (track.filename) {
                        const originalPath = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'originals', track.filename);
                        try {
                            if (fs.existsSync(originalPath)) {
                                await fsp.unlink(originalPath);
                                deletedFiles.push(originalPath);
                            }
                        } catch (e) {
                            const msg = `Failed to remove original file ${originalPath}: ${e}`;
                            logger.warn(msg);
                            deletionErrors.push(msg);
                        }
                    }

                    try {
                        const hlsPath = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'hls', track.id);
                        if (fs.existsSync(hlsPath)) {
                            await fsp.rm(hlsPath, { recursive: true, force: true });
                            deletedFolders.push(hlsPath);
                        }
                    } catch (e) {
                        const msg = `Failed to remove HLS ${track.id}: ${e}`;
                        logger.warn(msg);
                        deletionErrors.push(msg);
                    }

                    try {
                        const metadataDir = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'metadata');
                        const entries = await fsp.readdir(metadataDir).catch(() => [] as string[]);
                        for (const entry of entries) {
                            if (entry.startsWith(`${track.id}_cover.`)) {
                                const p = path.join(metadataDir, entry);
                                try {
                                    await fsp.unlink(p);
                                    deletedFiles.push(p);
                                } catch (e) {
                                    const msg = `Failed to remove track cover ${p}: ${e}`;
                                    logger.warn(msg);
                                    deletionErrors.push(msg);
                                }
                            }
                        }
                    } catch (e) {
                        const msg = `Failed to scan metadata dir for track covers for ${track.id}: ${e}`;
                        logger.warn(msg);
                        deletionErrors.push(msg);
                    }
                }
            } else {
                preservedTracks.push(trackId);
            }
        }

        if (deletionErrors.length > 0) {
            return res.status(500).json({
                success: true,
                message: 'Release removed from database, but some storage deletions failed. You can remove unused files manually to free storage.',
                deletedFiles,
                deletedFolders,
                preservedTracks,
                errors: deletionErrors
            });
        }

        const responseMsg = preservedTracks.length > 0
            ? 'Release deleted; some tracks were preserved because they belong to other releases.'
            : 'Release deleted and unused files removed.';

        return res.json({ success: true, message: responseMsg, deletedFiles, deletedFolders, preservedTracks });

    } catch (err) {
        logger.error(`(DELETE /api/releases/${id}) Error: ${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to delete release'
        });
    }
});

export default router;
