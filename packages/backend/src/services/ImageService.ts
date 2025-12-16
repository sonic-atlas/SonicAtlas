
import sharp from 'sharp';
import path from 'path';
import fsp from 'node:fs/promises';
import { logger } from '../utils/logger.js';

export class ImageService {
    static async processAndSaveCover(buffer: Buffer, outputDir: string, baseFilename: string): Promise<void> {
        try {
            await fsp.mkdir(outputDir, { recursive: true });

            const mainPath = path.join(outputDir, `${baseFilename}.webp`);
            await sharp(buffer)
                .webp({ quality: 80 })
                .toFile(mainPath);

            const thumbPath = path.join(outputDir, `${baseFilename}-small.webp`);
            await sharp(buffer)
                .resize({ width: 256, height: 256, fit: 'cover' })
                .webp({ quality: 80 })
                .toFile(thumbPath);

            logger.info(`Processed cover art: ${baseFilename} (Main & Small)`);

        } catch (error) {
            logger.error(`Failed to process cover art for ${baseFilename}: ${error}`);
            throw error;
        }
    }
}
