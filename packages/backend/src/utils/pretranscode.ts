import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { $rootDir, type Quality } from '@sonic-atlas/shared';
import { logger } from './logger.js';
import type { InferSelectModel } from 'drizzle-orm';
import type { tracks } from '../../db/schema.js';
import { getSourceQuality, qualityHierarchy } from '../routes/stream.js';
import { socket } from '../index.js';

const STORAGE_PATH = path.join($rootDir, process.env.STORAGE_PATH || 'storage', 'hls');
const useFmp4 = Boolean(process.env.HLS_USE_FMP4 ?? true);

const qualities: Record<Exclude<Quality, 'auto'>, { bitrate?: string, codec: string, maxRate?: string, sampleRate?: string, bufsize?: string, audioBitrate?: string | null }> = {
    efficiency: { bitrate: '128k', codec: 'aac', maxRate: '128k', bufsize: '256k' },
    high: { bitrate: '320k', codec: 'aac', maxRate: '320k', bufsize: '640k' },
    cd: { codec: 'flac', sampleRate: '44100', audioBitrate: null },
    hires: { codec: 'flac', audioBitrate: null }
}

export async function generateHLS(track: InferSelectModel<typeof tracks>, inputFile: string, socketRoom?: string) {
    const outputDir = path.join(STORAGE_PATH, track.id);
    fs.mkdirSync(outputDir, { recursive: true });

    const variantPlaylists: string[] = [];

    const sourceQuality = getSourceQuality(track);
    const sourceIndex = qualityHierarchy.indexOf(sourceQuality);
    const availableQualities = qualityHierarchy.slice(0, sourceIndex + 1);

    for (const [quality, opts] of Object.entries(qualities)) {
        if (availableQualities.indexOf(quality as Exclude<Quality, 'auto'>) === -1) continue;

        const qualityDir = path.join(outputDir, quality);
        fs.mkdirSync(qualityDir, { recursive: true });
        const playlistFile = path.join(qualityDir, `${quality}.m3u8`);

        const ffmpegArgs = [
            '-i', inputFile,
            '-vn',
            '-acodec', opts.codec,
            ...(opts.bitrate ? ['-b:a', opts.bitrate] : []),
            ...(opts.sampleRate ? ['-ar', opts.sampleRate] : []),
            '-f', 'hls',
            '-hls_time', '10',
            '-hls_playlist_type', 'vod',
            ...(useFmp4 ? [
                '-hls_segment_type', 'fmp4',
                '-hls_fmp4_init_filename', 'init.m4a'
            ] : []),
            '-hls_segment_filename', `segment_%04d.${useFmp4 ? 'm4s' : 'ts'}`,
            `${quality}.m3u8`
        ];

        logger.debug(`Transcoding ${quality} for ${track.id} in directory: ${qualityDir}`);
        if (socketRoom) {
            socket.io.to(socketRoom).emit('startTranscode', {
                id: track.id,
                quality
            });
        }

        // set current working directory to qualityDir and use just the filename above
        const ffmpeg = spawn('ffmpeg', ffmpegArgs, { cwd: qualityDir });

        ffmpeg.stderr.on('data', (data) => {
            const line = data.toString();
            const match = line.match(/time=(\d+:\d+:\d+\.\d+)/);
            if (match && socketRoom) {
                socket.io.to(socketRoom).emit('transcodeProgress', {
                    id: track.id,
                    quality,
                    time: match[1]
                });
            }
        });

        await new Promise((resolve, reject) => {
            ffmpeg.on('close', (code) => {
                if (code === 0) {
                    resolve(null);
                } else {
                    reject(new Error(`FFmpeg exited with code ${code}`));
                }
            });
        });

        if (useFmp4) { // Fix playlist file URI
            let playlist = fs.readFileSync(playlistFile, 'utf-8');
            playlist = playlist.replace(/#EXT-X-MAP:URI=".*init\.m4a"/, '#EXT-X-MAP:URI="init.m4a"');
            fs.writeFileSync(playlistFile, playlist);
        }

        variantPlaylists.push(playlistFile);

        if (socketRoom) {
            socket.io.to(socketRoom).emit('finishTranscode', {
                id: track.id,
                quality
            });
        }
    }

    const masterFile = path.join(outputDir, 'master.m3u8');
    const masterContent = Object.entries(qualities).map(([quality, opts]) => {
        const bandwidth = opts.bitrate ? parseInt(opts.bitrate) * 8 : quality === 'high' ? 5000000 : 1411000;
        return (
            `#EXT-X-STREAM-INF:BANDWIDTH=${bandwidth},NAME="${quality.toUpperCase()}"\n` +
            `${quality}/${quality}.m3u8`
        );
    }).join('\n');

    fs.writeFileSync(masterFile, `#EXTM3U\n${masterContent}\n`);

    if (socketRoom) {
        socket.io.to(socketRoom).emit('finishAllTranscodes', {
            id: track.id
        });
    }
}