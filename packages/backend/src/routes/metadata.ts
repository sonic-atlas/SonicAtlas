import { Router } from 'express';
import { db } from '../../db/db.js';
import { authMiddleware, uploaderPerms } from '../middleware/auth.js';
import { eq, and } from 'drizzle-orm';
import { trackMetadata, releaseTracks } from '../../db/schema.js';
import path from 'node:path';
import fsp from 'node:fs/promises';
import { $rootDir } from '@sonic-atlas/shared';
import { logger } from '../utils/logger.js';
import { isUUID } from '../utils/isUUID.js';
import dotenv from 'dotenv';
import { $envPath } from '@sonic-atlas/shared';

dotenv.config({ quiet: true, path: $envPath });

const router = Router();

type Quality = 'efficiency' | 'high' | 'cd' | 'hires';

function determineSourceQuality(track: any): Quality {
    const format = track.format?.toLowerCase();
    const bitrate = track.bitDepth || 16;
    const sampleRate = track.sampleRate || 44100;

    if (format === 'flac') {
        if (bitrate > 16 || sampleRate > 48000) {
            return 'hires';
        }
        return 'cd';
    }

    if (format === 'mp3' || format === 'aac') {
        return 'high';
    }

    return 'cd';
}

router.get('/:trackId', authMiddleware, async (req, res) => {
    const { trackId } = req.params;

    if (!isUUID(trackId!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'METADATA_002',
            message: 'Track id must be a valid UUID'
        });
    }

    try {
        const metadataRaw = await db.query.trackMetadata.findFirst({
            where: {
                trackId
            },
            columns: {
                searchVector: false,
                trackId: false
            },
            with: {
                track: {
                    columns: {
                        duration: true,
                        sampleRate: true,
                        bitDepth: true,
                        fileSize: true,
                        uploadedAt: true
                    }
                }
            }
        });

        if (!metadataRaw) return res.status(404);

        const { track, ...rest } = metadataRaw;

        const sourceQuality = determineSourceQuality(track);

        let albumTitle: string | null = null;
        let albumArtist: string | null = null;

        try {
            const releaseTrack = await db.query.releaseTracks.findFirst({
                where: {
                    trackId
                },
                with: {
                    release: true
                }
            });
            if (releaseTrack?.release) {
                albumTitle = releaseTrack.release.title;
                albumArtist = releaseTrack.release.primaryArtist;
            }
        } catch (e) {
            // ignore
        }

        return res.json({
            ...rest,
            ...track,
            album: albumTitle,
            albumArtist: albumArtist,
            sourceQuality
        });
    } catch (err) {
        logger.error(`(GET /api/metadata/${trackId}) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Track metadata fetching failed due to an internal error'
        });
    }
});

router.patch('/:trackId', authMiddleware, uploaderPerms, async (req, res) => {
    const { trackId } = req.params;
    const { title, artist } = req.body;

    if (!isUUID(trackId!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'METADATA_002',
            message: 'Track id must be a valid UUID'
        });
    }

    try {
        const metadata = await db.query.trackMetadata.findFirst({
            where: {
                trackId
            }
        });

        if (!metadata) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                code: 'METADATA_001',
                message: 'Track metadata not found'
            });
        }

        const updated = await db
            .update(trackMetadata)
            .set({ title, artist })
            .where(eq(trackMetadata.id, metadata.id))
            .returning();

        if (req.body.releaseId && (req.body.discNumber !== undefined || req.body.trackNumber !== undefined)) {
            const { releaseId, discNumber, trackNumber } = req.body;
            await db.update(releaseTracks)
                .set({
                    discNumber: discNumber,
                    trackNumber: trackNumber
                })
                .where(and(
                    eq(releaseTracks.trackId, trackId!),
                    eq(releaseTracks.releaseId, releaseId)
                ));
        }

        return res.json(updated);
    } catch (err) {
        logger.error(`(PATCH /api/metadata/${trackId}) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Track metadata update failed due to an internal error'
        });
    }
});

const storagePath = path.join($rootDir, process.env.STORAGE_PATH || 'storage', 'metadata');

router.get('/:trackId/cover', async (req, res) => {
    const { trackId } = req.params;
    const { size } = req.query;

    if (!isUUID(trackId)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'COVER_003',
            message: 'Track id must be a valid UUID'
        })
    }

    const isSmall = size === 'small';

    const tryServe = async (filename: string, ext: string) => {
        const coverFile = path.join(storagePath, filename);
        try {
            await fsp.access(coverFile);

            res.setHeader('Content-Type', 'image/webp');
            res.setHeader('Cache-Control', 'public, max-age=31536000');
            res.sendFile(coverFile);
            return true;
        } catch {
            return false;
        }
    };

    let releaseId: string | null = null;
    try {
        const releaseTrack = await db.query.releaseTracks.findFirst({
            where: {
                trackId
            },
            columns: { releaseId: true },
            with: {
                release: {
                    columns: { id: true }
                }
            }
        });
        releaseId = releaseTrack?.releaseId ?? null;
    } catch (err) { }

    if (isSmall) {
        if (await tryServe(`${trackId}_cover-small.webp`, 'webp')) return;
    }
    if (await tryServe(`${trackId}_cover.webp`, 'webp')) return;
    for (const ext of ['jpg', 'jpeg', 'png']) {
        if (await tryServe(`${trackId}_cover.${ext}`, ext)) return;
    }

    if (releaseId) {
        const releaseBase = `release_${releaseId}_cover`;
        if (isSmall) {
            if (await tryServe(`${releaseBase}-small.webp`, 'webp')) return;
        }
        if (await tryServe(`${releaseBase}.webp`, 'webp')) return;
        for (const ext of ['jpg', 'jpeg', 'png']) {
            if (await tryServe(`${releaseBase}.${ext}`, ext)) return;
        }
    }

    return res.status(404).json({
        error: 'NOT_FOUND',
        code: 'COVER_001',
        message: 'No cover art found'
    });
});

export default router;