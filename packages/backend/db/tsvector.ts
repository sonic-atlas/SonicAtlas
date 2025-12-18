import type { PgColumn } from 'drizzle-orm/pg-core';
import { SQL, sql } from 'drizzle-orm';

export function tsVectorColumn(opts: Record<string, PgColumn[]>): SQL {
    const parts = Object.entries(opts).flatMap(([r, cols]) => cols.map(c => {
        const colExpr = c.dataType.startsWith('array') ? sql`array_to_string(${c}, ' ')` : c;

        return sql`setweight(to_tsvector('english', coalesce(${colExpr}, '')), ${sql.raw(`'${r}'`)})`
    }));

    const joined = parts.reduce((acc, part) => (acc ? sql`${acc} || ${part}` : part), undefined as any);

    return joined;
}