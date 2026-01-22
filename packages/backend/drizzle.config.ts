import path from 'node:path';
import { defineConfig } from 'drizzle-kit';
process.loadEnvFile(path.resolve(__dirname, '../../.env'));

export default defineConfig({
    out: './drizzle',
    schema: 'db/schema.ts',
    dialect: 'postgresql',
    dbCredentials: {
        url: process.env.DATABASE_URL!
    }
});