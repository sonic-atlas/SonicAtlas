import { Router } from 'express';
import { db } from '../../db/db.js';
import { trackMetadata } from '../../db/schema.js';
import { sql } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';
import { logger } from '../utils/logger.js';

const router = Router();

router.get('/', authMiddleware, async (req, res) => {
    try {
        let { q, limit, offset } = req.query;

        q = q as string;

        const pq = q.split(/\s+/).map(word => `${word}:*`).join(' & ');

        const numLimit = Number(limit) || 50;
        const numOffset = Number(offset) || 0;

        const results = await preparedSearchQuery.execute({ q, pq, limit: numLimit, offset: numOffset });

        return res.json({ results, total: results.length, limit, offset });
    } catch (err) {
        logger.error(`(GET /api/search) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Search failed due to an internal error'
        });
    }
});

const preparedSearchQuery = db.query.trackMetadata.findMany({
    columns: {
        title: true,
        artist: true,
        albumId: true
    },
    extras: {
        id: sql`${trackMetadata.trackId}`.as('id'),
        rank: sql<number>`
            ts_rank(${trackMetadata.searchVector}, websearch_to_tsquery('english', ${sql.placeholder('q')}))
            + 0.5 * ts_rank(${trackMetadata.searchVector}, to_tsquery('english', ${sql.placeholder('pq')}))
        `.as('rank')
    },
    where: sql`
        (
          ${trackMetadata.searchVector} @@ websearch_to_tsquery('english', ${sql.placeholder('q')})
          OR ${trackMetadata.searchVector} @@ to_tsquery('english', ${sql.placeholder('pq')})
          OR ${trackMetadata.title} ILIKE '%' || ${sql.placeholder('q')} || '%'
          OR ${trackMetadata.artist} ILIKE '%' || ${sql.placeholder('q')} || '%'
        )
    `,
    orderBy: sql`rank DESC`,
    limit: sql.placeholder('limit'),
    offset: sql.placeholder('offset')
}).prepare('track_query_search');

export default router;