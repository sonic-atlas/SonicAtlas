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
SELECT ${trackMetadata.trackId} AS id,
       ${trackMetadata.title},
       ${trackMetadata.artist},
       ${releases.title} AS "releaseTitle",
       ${tracks.duration},
       ${releases.id} AS "releaseId",
       ${releases.primaryArtist} AS "releaseArtist",
       ${releases.year} AS "releaseYear",
       ${releases.coverArtPath} AS "releaseCoverArtPath",
       ${tracks.coverArtPath} AS "trackCoverArtPath",
       ${tracks.uploadedAt} AS "uploadedAt",
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

function parseStringField(values: string[], column: PgColumn): SQL[] {
    const orGroups: { and: string[], not: string[] }[] = [];

    for (const raw of values) {
        const tokens = raw.split('+').map(v => v.trim().replace(/^["']|["']$/g, ''));

        let and: string[] = [];
        let not: string[] = [];

        for (const t of tokens) {
            if (!t) continue;

            if (t.startsWith('-')) {
                not.push(t.slice(1));
            } else {
                and.push(t);
            }
        }

        if (and.length || not.length) {
            orGroups.push({ and, not });
        }
    }

    const sqlGroups = orGroups.map(g => {
        const andPart = g.and.length
            ? sql`(${sql.join(
                g.and.map(x =>
                    sql`${column}::text ILIKE '%' || ${x} || '%'`
                ),
                sql` AND `
            )})`
            : sql``;

        const notPart = g.not.length
            ? sql`NOT (${sql.join(
                g.not.map(x =>
                    sql`${column}::text ILIKE '%' || ${x} || '%'`
                ),
                sql` OR `
            )})`
            : sql``;

        return g.not.length ? g.and.length ? sql`(${andPart} AND ${notPart})` : notPart : andPart;
    });

    return sqlGroups;
}

router.get('/', authMiddleware, async (req, res) => {
    try {
        let { q, limit, offset } = req.query;

        q = (q as string || '').trim();

        const numLimit = Number.isFinite(Number(limit)) ? Number(limit) : 50;
        const numOffset = Number.isFinite(Number(offset)) ? Number(offset) : 0;

        const fieldRegex = /(-?)(\w+):(["'].*?["']|[^ ]+)/g;
        const generalTerms: string[] = [];
        const filters: Record<string, { values: string[], negated: boolean }> = {}

        let match: RegExpExecArray | null;
        let remainingQuery = q;

        while ((match = fieldRegex.exec(q)) !== null) {
            const [full, neg, field, value] = match;
            
            const key = field!.toLowerCase();
            const isNegated = neg === '-';

            if (!filters[key]) filters[key] = { values: [], negated: isNegated };
            
            filters[key].values.push(
                ...value!
                    .split(',')
                    .flatMap(v => v.split('+'))
                    .map(v => v.trim().replace(/^["']|["']$/g, ''))
                    .filter(Boolean)
            );

            // Make whole field negated if one instance of it is negated
            // Can change later to allow field:name -field:name2
            filters[key].negated = filters[key].negated || isNegated;
            
            remainingQuery = remainingQuery.replace(full, '');
        }

        remainingQuery = remainingQuery.replace(/\s+/, ' ').trim();
        generalTerms.push(...remainingQuery.split(' ').filter(Boolean));

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

        const handleStringField = (field: string, col: PgColumn) => {
            const groups = parseStringField(filters[field]!.values, col);

            if (groups.length) {
                if (filters[field]!.negated) {
                    whereClauses.push(sql`NOT ${sql.join(groups, sql` AND `)}`);
                } else {
                    whereClauses.push(sql.join(groups, sql` AND `));
                }
            }
        }

        for (const [field, { values }] of Object.entries(filters)) {

            switch (field) {
                case 'artist':
                    handleStringField('artist', trackMetadata.artist);
                    break;
                case 'album':
                    handleStringField('album', releases.title);
                    break;
                case 'genre':
                    handleStringField('genre', trackMetadata.genres);
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
            const hasReleaseCover = !!t.releaseCoverArtPath;
            const coverArtPath = t.trackCoverArtPath ?? (hasReleaseCover ? `/api/metadata/${t.id}/cover` : null);

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
