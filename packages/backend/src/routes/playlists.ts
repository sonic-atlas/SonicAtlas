import { Router } from 'express';
import { db } from '../../db/db.ts';
import { authMiddleware, uploaderPerms } from '../middleware/auth.ts';
import { playlistItems, playlists } from '../../db/schema.ts';
import { eq, and, count } from 'drizzle-orm';
import { logger } from '../utils/logger.ts';
import { isUUID } from '../utils/isUUID.ts';

const router = Router();
router.use(authMiddleware);

router.post('/', uploaderPerms, async (req, res) => {
    const { name, description } = req.body;

    if (!name || !description) {
        return res.status(400).json({
            error: 'BAD_REQUEST',
            code: 'PLAYLISTS_001',
            message: 'Name and description are required'
        });
    }

    try {
        const [created] = await db
            .insert(playlists)
            .values({
                name,
                description
            })
            .returning();

        return res.status(201).json(created);
    } catch (err) {
        logger.error(`(POST /api/playlists) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Playlist creation failed due to an internal error'
        });
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
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Playlist fetching failed due to an internal error'
        });
    }
});

router.post('/:playlistId/tracks', uploaderPerms, async (req, res) => {
    const { playlistId } = req.params;
    const { trackId, position } = req.body;

    if (!trackId) {
        return res.status(400).json({
            error: 'BAD_REQUEST',
            code: 'PLAYLISTS_002',
            message: 'Track id is required'
        });
    }

    if (!isUUID(trackId)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'PLAYLISTS_003',
            message: 'Track id must be a valid UUID'
        });
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
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to add track to playlist due to an internal error'
        });
    }
});

router.delete('/:playlistId/tracks/:trackId', uploaderPerms, async (req, res) => {
    const { playlistId, trackId } = req.params;

    if (!isUUID(playlistId!) || !isUUID(trackId!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'PLAYLISTS_004',
            message: 'Playlist id and track id must be valid UUIDs'
        });
    }

    try {
        await db
            .delete(playlistItems)
            .where(and(
                eq(playlistItems.playlistId, playlistId!),
                eq(playlistItems.trackId, trackId!)
            ));

        return res.sendStatus(204);
    } catch (err) {
        logger.error(`(DELETE /api/playlists/${playlistId}/tracks/${trackId}) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Failed to remove track from playlist due to an internal error'
        });
    }
});

router.delete('/:playlistId', uploaderPerms, async (req, res) => {
    const { playlistId } = req.params;

    if (!isUUID(playlistId!)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'PLAYLISTS_005',
            message: 'Playlist id must be a valid UUID'
        });
    }

    try {
        const playlist = await db.query.playlists.findFirst({
            where: {
                id: playlistId
            }
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

        return res.sendStatus(204);
    } catch (err) {
        logger.error(`(DELETE /api/playlists/${playlistId}) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Playlist deletion failed due to an internal error'
        });
    }
});

export default router;