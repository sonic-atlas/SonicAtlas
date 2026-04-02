import client from 'prom-client';
import { register } from './registry.ts';

export const httpRequestsTotal = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status'],
    registers: [register]
});

export const httpRequestDuration = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status'],
    buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 3, 5, 10],
    registers: [register]
});

export const inflightRequests = new client.Gauge({
    name: 'inflight_requests',
    help: 'Current in-flight HTTP requests',
    registers: [register]
});