import { spawn } from 'node:child_process';
import { logger } from './logger.js';
import path from 'node:path';
import fsp from 'node:fs/promises';

export async function stripCoverArt(inputPath: string): Promise<string> {
    const ext = path.extname(inputPath);
    const format = ext.toLowerCase().slice(1);
    
    if (!['flac', 'mp3', 'm4a', 'ogg'].includes(format)) {
        return inputPath;
    }

    const tempOutput = `${inputPath}.temp${ext}`;

    return new Promise((resolve, reject) => {
        const ffmpegArgs = [
            '-i', inputPath,
            '-map', '0:a',           // Only map audio streams
            '-c:a', 'copy',          // Copy audio codec (no re-encoding)
            '-vn',                   // No video/images
            '-map_metadata', '0',    // Preserve metadata
            '-map_metadata:s:a', '0:s:a', // Preserve audio stream metadata
            '-id3v2_version', '3',   // For MP3 files
            tempOutput
        ];

        const ffmpeg = spawn('ffmpeg', ffmpegArgs);

        let stderrData = '';

        ffmpeg.stderr.on('data', (data) => {
            stderrData += data.toString();
            logger.debug(`FFmpeg strip cover: ${data.toString()}`);
        });

        ffmpeg.on('error', (err) => {
            logger.error(`FFmpeg process error during cover strip: ${err.message}`);
            reject(err);
        });

        ffmpeg.on('close', async (code) => {
            if (code === 0) {
                try {
                    await fsp.unlink(inputPath);
                    await fsp.rename(tempOutput, inputPath);
                    logger.info(`Stripped cover art from: ${path.basename(inputPath)}`);
                    resolve(inputPath);
                } catch (err) {
                    logger.error(`Error replacing file after stripping cover: ${err}`);
                    reject(err);
                }
            } else {
                logger.error(`FFmpeg exited with code ${code}: ${stderrData}`);
                try {
                    await fsp.unlink(tempOutput);
                } catch {}
                reject(new Error(`FFmpeg exited with code ${code}`));
            }
        });
    });
}