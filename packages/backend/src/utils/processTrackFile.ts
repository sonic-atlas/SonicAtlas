import { db } from '#db/db';
import { releases, releaseTracks, tracks, trackMetadata, trackFormatEnum } from '#db/schema';
import { eq } from 'drizzle-orm';
import path from 'node:path';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import { parseFile } from 'music-metadata';
import { enqueueTranscodeJob } from '../services/transcodeQueue.ts';
import { stripCoverArt } from './stripCoverArt.ts';
import { $rootDir } from '@sonic-atlas/shared';
import { ImageService } from '../services/ImageService.ts';
import { logger } from './logger.ts';
import { storageBytes } from '../services/metrics/storageMetrics.ts';

const uploadFolder = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'originals');
const metadataFolder = path.join($rootDir, process.env.STORAGE_PATH ?? 'storage', 'metadata');

export interface ProcessTrackOptions {
    filePath: string;
    originalFilename: string;
    releaseId: string;
    primaryArtist?: string;
    releaseTitle?: string;
    year?: string;
    socketId?: string;
    extractAllCovers?: boolean;
    existingReleaseCoverPath?: string | null;
}

export interface ProcessedTrack {
    id: string;
    originalFilename: string;
    title: string;
    artist: string;
    discNumber: number;
    trackNumber: number | null;
    duration: number | null;
    transcodeStatus: 'pending';
}

export async function processTrackFile(opts: ProcessTrackOptions): Promise<{
    track: ProcessedTrack;
    releaseCoverUrl?: string | undefined;
} | null> {
    const {
        filePath,
        originalFilename,
        releaseId,
        primaryArtist,
        releaseTitle,
        year,
        socketId,
        extractAllCovers = false,
    } = opts;

    let existingReleaseCoverPath = opts.existingReleaseCoverPath ?? null;

    const maxAttempts = 3;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
            const metadata = await parseFile(filePath);
            const rawExt = path.extname(originalFilename).slice(1).toLowerCase();
            
            if (!(trackFormatEnum.enumValues as readonly string[]).includes(rawExt)) {
                throw new Error(`Unsupported audio format: ${rawExt}`);
            }
            
            const ext = rawExt as import('@sonic-atlas/shared').UploadAudioFormat;

            const meta = {
                duration: metadata.format.duration ? Math.round(metadata.format.duration) : null,
                sampleRate: metadata.format.sampleRate ?? null,
                bitDepth: metadata.format.bitsPerSample ?? null,
                format: ext,
                title: metadata.common.title ?? path.parse(originalFilename).name,
                artist: metadata.common.artist ?? primaryArtist ?? 'Unknown Artist',
                album: metadata.common.album ?? releaseTitle ?? 'Unknown Album',
                year: metadata.common.year ?? (year ? parseInt(year) : null),
                genres: metadata.common.genre ?? null,
                trackNo: metadata.common.track.no ?? null,
                diskNo: metadata.common.disk.no ?? 1,
            };

            const fileSize = (await fsp.stat(filePath)).size;
            storageBytes.labels('original').inc(fileSize);

            let releaseCoverUrl: string | undefined;

            const trackInfo = await db.transaction(async (tx) => {
                const [track] = await tx.insert(tracks).values({
                    filename: path.basename(filePath),
                    originalFilename,
                    duration: meta.duration,
                    sampleRate: meta.sampleRate,
                    bitDepth: meta.bitDepth,
                    format: meta.format,
                    fileSize,
                }).returning();

                if (!track) throw new Error('Failed to insert track');

                const fileExt = path.extname(originalFilename);
                const filename = `${track.id}${fileExt}`;
                const newPath = path.join(uploadFolder, filename);

                if (fs.existsSync(filePath)) {
                    await fsp.rename(filePath, newPath);
                } else if (!fs.existsSync(newPath)) {
                    throw new Error('Source file not found for processing');
                }

                await stripCoverArt(newPath);
                await tx.update(tracks).set({ filename }).where(eq(tracks.id, track.id));

                let trackNumber = meta.trackNo;
                if (!trackNumber) {
                    const match = originalFilename.match(/^(\d+)/);
                    if (match?.[1]) trackNumber = parseInt(match[1]);
                }

                await tx.insert(releaseTracks).values({
                    releaseId,
                    trackId: track.id,
                    discNumber: meta.diskNo || 1,
                    trackNumber,
                });

                await tx.insert(trackMetadata).values({
                    trackId: track.id,
                    title: meta.title,
                    artist: meta.artist,
                    year: meta.year,
                    genres: meta.genres,
                });

                if (metadata.common.picture?.length) {
                    try {
                        const picture = metadata.common.picture[0];
                        if (picture?.data) {
                            if (!existingReleaseCoverPath) {
                                const releaseCoverName = `release_${releaseId}_cover`;
                                await ImageService.processAndSaveCover(
                                    Buffer.from(picture.data),
                                    metadataFolder,
                                    releaseCoverName,
                                );

                                releaseCoverUrl = `/api/releases/${releaseId}/cover`;
                                existingReleaseCoverPath = releaseCoverUrl;

                                await tx.update(releases)
                                    .set({ coverArtPath: releaseCoverUrl })
                                    .where(eq(releases.id, releaseId));
                            }

                            if (extractAllCovers) {
                                const trackCoverName = `${track.id}_cover`;
                                await ImageService.processAndSaveCover(
                                    Buffer.from(picture.data),
                                    metadataFolder,
                                    trackCoverName,
                                );

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
                ...(socketId ? { socketId } : {}),
            });

            return {
                track: {
                    id: trackInfo.id,
                    originalFilename,
                    title: meta.title,
                    artist: meta.artist,
                    discNumber: meta.diskNo || 1,
                    trackNumber: meta.trackNo,
                    duration: meta.duration,
                    transcodeStatus: 'pending',
                },
                releaseCoverUrl,
            };
        } catch (err) {
            logger.error(`Failed to process file ${originalFilename} (attempt ${attempt}/${maxAttempts}): ${err}`);
            if (attempt >= maxAttempts) {
                logger.error(`Giving up on file ${originalFilename} after ${maxAttempts} attempts.`);
                return null;
            }
            await new Promise((resolve) => setTimeout(resolve, 1000));
        }
    }

    return null;
}
