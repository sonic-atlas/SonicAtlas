import { Router } from 'express';
import { db } from '../../db/db.js';
import { trackMetadata } from '../../db/schema.js';
import { sql } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.js';

const router = Router();

router.get('/', authMiddleware, async (req, res) => {
    try {
        let { q, limit, offset } = req.query;

        q = q as string;

        const pq = q.split(/\s+/).map(word => `${word}:*`).join(' & ');

        const results = await preparedSearchQuery.execute({ q, pq });

        return res.json({ results, total: results.length, limit, offset });
    } catch {
        return res.status(500);
    }
});

const preparedSearchQuery = db.query.trackMetadata.findMany({
    columns: {
        title: true,
        artist: true,
        album: true
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
          OR track_metadata.title ILIKE '%' || ${sql.placeholder('q')} || '%'
          OR track_metadata.artist ILIKE '%' || ${sql.placeholder('q')} || '%'
        )
    `,
    orderBy: sql`rank DEC`,
    limit: sql.placeholder('limit'),
    offset: sql.placeholder('offset')
}).prepare('track_query_search');

export default router;