import path from 'node:path';
import { defineConfig } from 'drizzle-kit';

try {
    process.loadEnvFile(path.resolve(__dirname, '../../.env'));
} catch {}

export default defineConfig({
    out: './drizzle',
    schema: 'db/schema.ts',
    dialect: 'postgresql',
    dbCredentials: {
        url: process.env.DATABASE_URL!
    },
    breakpoints: false // Only really needed for MySQL and SQLite
});