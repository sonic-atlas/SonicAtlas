import fs from 'node:fs';
import path from 'node:path';
import { defineConfig } from 'drizzle-kit';

const envPath = path.resolve(import.meta.dirname, '../../.env');
if (fs.existsSync(envPath)) {
    process.loadEnvFile(envPath);
}
export default defineConfig({
    out: './drizzle',
    schema: 'db/schema.ts',
    dialect: 'postgresql',
    dbCredentials: {
        url: process.env.DATABASE_URL!
    },
    breakpoints: false // Only really needed for MySQL and SQLite
});