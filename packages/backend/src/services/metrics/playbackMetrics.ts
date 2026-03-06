import client from 'prom-client';
import { register } from './registry.ts';

export const activePlaybackSessions = new client.Gauge({
    name: 'playback_sessions_active',
    help: 'Active playback sessions',
    registers: [register]
});

export const tracksStreamedTotal = new client.Counter({
    name: 'tracks_streamed_total',
    help: 'Total tracks streamed',
    labelNames: ['quality'],
    registers: [register]
});

export const streamBytesTotal = new client.Counter({
    name: 'stream_bytes_total',
    help: 'Total bytes stream',
    labelNames: ['quality'],
    registers: [register]
});