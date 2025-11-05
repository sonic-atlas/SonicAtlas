// Drizzle & postgres
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema.js';
import { $envPath } from '@sonic-atlas/shared';
import dotenv from 'dotenv';
dotenv.config({ quiet: true, path: $envPath });

let DATABASE_URL = process.env.DATABASE_URL!;

export const pgClient = postgres(DATABASE_URL);

export const db = drizzle(pgClient, { schema });

/* // Redis
import { createClient } from 'redis';

export const redisClient = createClient({
    url: process.env.REDIS_URL!,
    disableOfflineQueue: true
});

export let redisConnected = false;

redisClient.connect().then(() => {
    redisConnected = true;
});

redisClient.on('error', (err) => console.error('Redis Client Error:', err));

*/