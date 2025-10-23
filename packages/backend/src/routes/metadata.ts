import { Router } from 'express';
import { db } from '../../db/db.js';
import { authMiddleware, uploaderPerms } from '../middleware/auth.js';
import { eq } from 'drizzle-orm';
import { trackMetadata } from '../../db/schema.js';

const router = Router();

router.get('/:trackId', authMiddleware, async (req, res) => {
    const { trackId } = req.params;
    
    try {
        const metadataRaw = await db.query.trackMetadata.findFirst({
            where: eq(trackMetadata.trackId, trackId!),
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

        return res.json({ ...rest, ...track });
    } catch {
        return res.status(500);
    }
});

router.patch('/:trackId', authMiddleware, uploaderPerms, async (req, res) => {
    const { trackId } = req.params;
    const { title, artist, album } = req.body;

    try {
        const metadata = await db.query.trackMetadata.findFirst({
            where: eq(trackMetadata?.trackId, trackId!)
        });
    
        if (!metadata) {
            return res.status(404); // TODO: Send json with error information
        }

        const updated = await db.update(trackMetadata).set({ title, artist, album }).where(eq(trackMetadata.id, metadata.id)).returning();

        return res.json(200).json(updated);
    } catch {// TODO: Send json with error information, maybe logging?
        res.status(500);
    }
});

router.get('/:trackId/cover', async (req, res) => {
    // TODO
});

export default router;