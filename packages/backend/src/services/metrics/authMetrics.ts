import client from 'prom-client';
import { register } from './registry.ts';

export const loginAttemptsTotal = new client.Counter({
    name: 'login_attempts_total',
    help: 'Total login attempts',
    labelNames: ['status'],
    registers: [register]
});