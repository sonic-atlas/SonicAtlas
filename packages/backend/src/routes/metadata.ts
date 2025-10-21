import { Router } from 'express';
import { db } from '../../db/db.js';
import { authMiddleware } from '../middleware/auth.js';
import { eq, getTableColumns } from 'drizzle-orm';
import { trackMetadata, tracks } from '../../db/schema.js';

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

router.patch('/:trackId', authMiddleware, async (req, res) => {

});

export default router;