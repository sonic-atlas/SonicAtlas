import client from 'prom-client';
import { register } from './registry.ts';

export const socketConnectionsActive = new client.Gauge({
    name: 'socket_connections_active',
    help: 'Total active WebSocket connections',
    registers: [register]
});

export const socketEventsTotal = new client.Counter({
    name: 'socket_events_total',
    help: 'Total socket events',
    labelNames: ['direction', 'event_type'],
    registers: [register]
});