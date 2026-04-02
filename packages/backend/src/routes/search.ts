import { Router } from 'express';
import { db } from '#db/db';
import { trackMetadata, releases, releaseTracks, tracks } from '#db/schema';
import { sql, SQL } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth.ts';
import { logger } from '../utils/logger.ts';
import type { PgColumn } from 'drizzle-orm/pg-core';

const router = Router();

// Couldn't get drizzle to cooperate with .select so custom SQL it is
function genSearchSQL(qc: string, pq: string | null, limit: number, offset: number, whereClauses: SQL[]) {
    const conditions: SQL[] = [];

    if (qc) {
        conditions.push(sql`(
  ${trackMetadata.searchVector} @@ websearch_to_tsquery('english', ${qc})
  ${pq ? sql`OR ${trackMetadata.searchVector} @@ to_tsquery('english', ${pq})` : sql``}
  OR ${trackMetadata.title} ILIKE '%' || ${qc} || '%'
  OR ${trackMetadata.artist} ILIKE '%' || ${qc} || '%'
  OR ${releases.title} ILIKE '%' || ${qc} || '%'
)`);
    }

    if (whereClauses.length) {
        conditions.push(...whereClauses);
    }

    const whereSQL = conditions.length ? sql`WHERE ${sql.join(conditions, sql` AND `)}` : sql``;

    return sql`
SELECT ${trackMetadata.trackId},
       ${trackMetadata.title},
       ${trackMetadata.artist},
       ${releases.title},
       ${tracks.duration},
       ${releases.id},
       ${releases.primaryArtist},
       ${releases.year},
       ${releases.coverArtPath},
       ${tracks.uploadedAt},
       ${qc ? sql`ts_rank(${trackMetadata.searchVector}, websearch_to_tsquery('english', ${qc}))
           ${pq ? sql`+ 0.5 * ts_rank(${trackMetadata.searchVector}, to_tsquery('english', ${pq}))` : sql``}
           + 0.2 * similarity(${trackMetadata.title}, ${qc})
           + 0.2 * similarity(${trackMetadata.artist}, ${qc})` : sql`0`}
         AS "rank"
FROM ${trackMetadata}
  INNER JOIN ${tracks} ON ${trackMetadata.trackId} = ${tracks.id}
  LEFT JOIN ${releaseTracks} ON ${trackMetadata.trackId} = ${releaseTracks.trackId}
  LEFT JOIN ${releases} ON ${releaseTracks.releaseId} = ${releases.id}
${whereSQL}
ORDER BY rank DESC
LIMIT ${limit} OFFSET ${offset}
`;
}

router.get('/', authMiddleware, async (req, res) => {
    try {
        let { q, limit, offset } = req.query;

        q = (q as string || '').trim();

        const numLimit = Number.isFinite(Number(limit)) ? Number(limit) : 50;
        const numOffset = Number.isFinite(Number(offset)) ? Number(offset) : 0;

        const fieldRegex = /(\w+):([^\s]+)/g;
        const generalTerms: string[] = [];
        const filters: Record<string, string[]> = {}

        let match: RegExpExecArray | null;
        let remainingQuery = q;

        while ((match = fieldRegex.exec(q)) !== null) {
            // I hate this cast I hate TypeScript but I don't want a runtime check that will never not happen
            const [full, field, value] = match as unknown as [string, string, string];
            filters[field.toLowerCase()] = value.split(',');
            remainingQuery = remainingQuery.replace(full, '').trim();
        }

        generalTerms.push(...remainingQuery.split(/\s+/).filter(Boolean));

        // Sanitise the to_tsquery term so syntax errors don't occur and error by removing all tsquery operators
        const sanitiseTsTerm = (term: string) => term.toLowerCase().replace(/[^a-z0-9]+/g, '').trim();
        const pq = generalTerms.map(sanitiseTsTerm).filter(Boolean).map(word => `${word}:*`).join(' & ') || null;

        const qc = generalTerms.join(' '); // Combined 'q'uery btw

        const whereClauses: SQL[] = [];

        const handleNumberFields = (col: PgColumn, v: string) => {
            if (v.includes('..')) {
                const [start, end] = v.split('..');
                const startNum = Number(start);
                const endNum = Number(end);

                if (Number.isNaN(startNum) || Number.isNaN(endNum)) throw new Error('Invalid range');
                return sql`${col} BETWEEN ${startNum} AND ${endNum}`;
            } else if (v.startsWith('<')) {
                const num = Number(v.slice(1));
                if (Number.isNaN(num)) throw new Error('Invalid number');
                return sql`${col} < ${num}`;
            } else if (v.startsWith('>')) {
                const num = Number(v.slice(1));
                if (Number.isNaN(num)) throw new Error('Invalid number');
                return sql`${col} > ${num}`;
            } else {
                const num = Number(v);
                if (Number.isNaN(num)) throw new Error('Invalid number');
                return sql`${col} = ${num}`;
            }
        }

        for (const [field, values] of Object.entries(filters)) {
            switch (field) {
                case 'artist':
                    whereClauses.push(sql`${sql.join(values.map(v => sql`${trackMetadata.artist} ILIKE '%' || ${v} || '%'`), sql` OR `)})`);
                    break;
                case 'album':
                    whereClauses.push(sql`(${sql.join(values.map(v => sql`${releases.title} ILIKE '%' || ${v} || '%'`), sql` OR `)})`);
                    break;
                case 'genre':
                    whereClauses.push(sql`(${sql.join(values.map(v => sql`${trackMetadata.genres}::text ILIKE '%' || ${v} || '%'`), sql` OR `)})`);
                    break;
                case 'year':
                    whereClauses.push(sql`(${sql.join(values.map(v => {
                        return handleNumberFields(releases.year, v);
                    }), sql` OR `)})`);
                    break;
                case 'duration':
                    whereClauses.push(sql`(${sql.join(values.map(v => {
                        return handleNumberFields(tracks.duration, v);
                    }), sql` OR `)})`);
                    break;
            }
        }

        const testSQL = genSearchSQL(qc, pq, numLimit, numOffset, whereClauses);
        const testResults = await db.execute(testSQL);

        const results = testResults.map(t => {
            const coverArtPath = t.coverArtPath ? `/api/metadata/${t.id}/cover` : null;

            return {
                ...t,
                coverArtPath,
            };
        });

        return res.json({
            results,
            total: results.length,
            limit: numLimit,
            offset: numOffset
        });
    } catch (err) {
        logger.error(`(GET /api/search) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Search failed due to an internal error'
        });
    }
});

export default router;