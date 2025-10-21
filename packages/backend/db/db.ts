import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema.js';
import dotenv from 'dotenv';
dotenv.config({ quiet: true });

let DATABASE_URL = process.env.DATABASE_URL!;

const client = postgres(DATABASE_URL);

export const db = drizzle(client, { schema, logger: true });