import { Router } from 'express';
import { db } from '../../db/db.js';
import { authMiddleware, uploaderPerms } from '../middleware/auth.js';
import { playlistItems, playlists } from '../../db/schema.js';
import { sql, eq, and, count } from 'drizzle-orm';
import { logger } from '../utils/logger.js';

const router = Router();
router.use(authMiddleware);

router.post('/', uploaderPerms, async (req, res) => {
    const { name, description } = req.body;

    if (!name || !description) {
        return res.status(400); // TODO: Send json with error information
    }

    try {
        const [created] = await db
            .insert(playlists)
            .values({
                name,
                description,
                userId: req.user?.id!
            })
            .returning();

        return res.status(201).json(created);
    } catch (err) {
        logger.error(`(POST /api/playlists) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        return res.status(500);
    }
});

router.get('/', async (req, res) => {
    try {
        const playlists = await db.query.playlists.findMany({
            extras: {
                trackCount: count().as('trackCount')
            }
        });

        return res.json({
            playlists
        });
    } catch (err) {
        logger.error(`(GET /api/playlists) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        return res.status(500);
    }
});

router.post('/:playlistId/tracks', uploaderPerms, async (req, res) => {
    const { playlistId } = req.params;
    const { trackId, position } = req.body;

    if (!trackId) {
        return res.status(400); // TODO: Send json with error information
    }

    try {
        const [created] = await db
            .insert(playlistItems)
            .values({
                playlistId: playlistId!,
                trackId,
                position
            })
            .returning();

        return res.status(201).json(created);
    } catch (err) {
        logger.error(`(POST /api/playlists/${playlistId}/tracks) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        return res.status(500);
    }
});

router.delete('/:playlistId/tracks/:trackId', uploaderPerms, async (req, res) => {
    const { playlistId, trackId } = req.params;

    try {
        await db
            .delete(playlistItems)
            .where(and(
                eq(playlistItems.playlistId, playlistId!),
                eq(playlistItems.trackId, trackId!)
            ));

        return res.status(204);
    } catch (err) {
        logger.error(`(DELETE /api/playlists/${playlistId}/tracks/${trackId}) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        return res.status(500);
    }
});

router.delete('/:playlistId', uploaderPerms, async (req, res) => {
    const { playlistId } = req.params;

    try {
        const playlist = await db.query.playlists.findFirst({
            where: eq(playlists.id, playlistId!)
        });

        if (!playlist) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                message: 'Playlist not found'
            });
        }

        await db.transaction(async (tx) => {
            await tx.delete(playlists).where(eq(playlists.id, playlist.id));
            await tx.delete(playlistItems).where(eq(playlistItems.playlistId, playlist.id));
        });

        return res.status(204);
    } catch (err) {
        logger.error(`(DELETE /api/playlists/${playlistId}) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        return res.status(500);
    }
});

export default router;