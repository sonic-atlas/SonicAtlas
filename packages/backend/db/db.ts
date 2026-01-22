// Drizzle & postgres
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema.ts';
import { relations } from './relations.ts';

let DATABASE_URL = process.env.DATABASE_URL!;

export const pgClient = postgres(DATABASE_URL);

export const db = drizzle(DATABASE_URL, { schema, relations });

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