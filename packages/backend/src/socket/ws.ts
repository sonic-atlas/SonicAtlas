import { Server as SocketIOServer } from 'socket.io';
import { Server as HTTPServer } from 'node:http';
import { logger } from '../utils/logger.ts';
import { socketConnectionsActive, socketEventsTotal } from '../services/metrics/socketMetrics.ts';

function normaliseEventName(event: unknown) {
    if (typeof event !== 'string') return 'unknown';
    if (event.length > 50) return 'other';
    return event;
}

export class SocketServer {
    readonly io!: SocketIOServer;

    constructor(server: HTTPServer) {
        this.io = new SocketIOServer(server, {
            path: '/ws',
            cors: {
                origin: '*',
                methods: ['GET', 'POST']
            }
        });
    }

    setupSocket() {
        this.io.on('connection', (socket) => {
            logger.debug(`New WebSocket client connected: ${socket.id}`);
            socketConnectionsActive.inc();

            socket.use((packet, next) => {
                const eventType = normaliseEventName(packet[0]);
                socketEventsTotal.inc({ direction: 'in', event_type: eventType, });
                next();
            });

            const originalEmit = socket.emit;
            socket.emit = function (eventName, ...args): boolean {
                socketEventsTotal.inc({ direction: 'out', event_type: String(eventName) });
                return originalEmit.apply(this, [eventName, ...args]);
            };

            socket.on('ping', () => {
                socket.emit('pong');
            });

            socket.on('disconnect', () => {
                logger.debug(`WebSocket client disconnected: ${socket.id}`);
                socketConnectionsActive.dec();
            });
        });

        logger.debug('WebSocket initialised');
    }
}