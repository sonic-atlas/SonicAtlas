import { Router } from 'express';
import { db } from '../../db/db.ts';
import { trackMetadata, releases, releaseTracks, tracks } from '../../db/schema.ts';
import { sql, eq } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.ts';
import { logger } from '../utils/logger.ts';

const router = Router();

router.get('/', authMiddleware, async (req, res) => {
    try {
        let { q, limit, offset } = req.query;

        q = q as string;

        const pq = q.split(/\s+/).map(word => `${word}:*`).join(' & ');

        const numLimit = Number(limit) || 50;
        const numOffset = Number(offset) || 0;

        const rawResults = await preparedSearchQuery.execute({ q, pq, limit: numLimit, offset: numOffset });

        const results = rawResults.map(t => {
            const hasReleaseCover = !!t.coverArtPath;
            const coverArtPath = hasReleaseCover ? `/api/metadata/${t.id}/cover` : null;

            return {
                ...t,
                coverArtPath,
            };
        });

        return res.json({ results, total: results.length, limit, offset });
    } catch (err) {
        logger.error(`(GET /api/search) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Search failed due to an internal error'
        });
    }
});

const preparedSearchQuery = db.select({
    id: trackMetadata.trackId,
    title: trackMetadata.title,
    artist: trackMetadata.artist,
    album: releases.title,
    duration: tracks.duration,
    releaseId: releases.id,
    releaseTitle: releases.title,
    releaseArtist: releases.primaryArtist,
    releaseYear: releases.year,
    coverArtPath: releases.coverArtPath,
    createdAt: tracks.uploadedAt,
    rank: sql<number>`
        ts_rank(${trackMetadata.searchVector}, websearch_to_tsquery('english', ${sql.placeholder('q')}))
        + 0.5 * ts_rank(${trackMetadata.searchVector}, to_tsquery('english', ${sql.placeholder('pq')}))
    `.as('rank')
})
    .from(trackMetadata)
    .innerJoin(tracks, eq(trackMetadata.trackId, tracks.id))
    .leftJoin(releaseTracks, eq(trackMetadata.trackId, releaseTracks.trackId))
    .leftJoin(releases, eq(releaseTracks.releaseId, releases.id))
    .where(sql`
    (
        ${trackMetadata.searchVector} @@ websearch_to_tsquery('english', ${sql.placeholder('q')})
        OR ${trackMetadata.searchVector} @@ to_tsquery('english', ${sql.placeholder('pq')})
        OR ${trackMetadata.title} ILIKE '%' || ${sql.placeholder('q')} || '%'
        OR ${trackMetadata.artist} ILIKE '%' || ${sql.placeholder('q')} || '%'
        OR ${releases.title} ILIKE '%' || ${sql.placeholder('q')} || '%'
    )
`)
    .orderBy(sql`rank DESC`)
    .limit(sql.placeholder('limit'))
    .offset(sql.placeholder('offset'))
    .prepare('track_query_search');

export default router;