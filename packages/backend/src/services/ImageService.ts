import sharp from 'sharp';
import path from 'path';
import fsp from 'node:fs/promises';
import { logger } from '../utils/logger.ts';
import { storageBytes } from './metrics/storageMetrics.ts';

export class ImageService {
    static async processAndSaveCover(buffer: Buffer, outputDir: string, baseFilename: string): Promise<void> {
        try {
            await fsp.mkdir(outputDir, { recursive: true });

            const mainPath = path.join(outputDir, `${baseFilename}.webp`);
            await sharp(buffer)
                .webp({ quality: 80 })
                .toFile(mainPath);

            const stat = await fsp.stat(mainPath);
            storageBytes.labels({ type: 'metadata', quality: 'none' }).inc(stat.size);
            
            const thumbPath = path.join(outputDir, `${baseFilename}-small.webp`);
            await sharp(buffer)
            .resize({ width: 256, height: 256, fit: 'cover' })
            .webp({ quality: 80 })
            .toFile(thumbPath);
            
            const thumbStat = await fsp.stat(thumbPath);
            storageBytes.labels({ type: 'metadata', quality: 'none' }).inc(thumbStat.size);

            logger.info(`Processed cover art: ${baseFilename} (Main & Small)`);
        } catch (error) {
            logger.error(`Failed to process cover art for ${baseFilename}: ${error}`);
            throw error;
        }
    }
}
