import { Server as SocketIOServer } from 'socket.io';
import { Server as HTTPServer } from 'node:http';
import { logger } from '../utils/logger.js';

export class SocketServer {
    io!: SocketIOServer;

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

            socket.on('ping', () => {
                socket.emit('pong');
            });

            socket.on('disconnect', () => {
                logger.debug(`WebSocket client disconnected: ${socket.id}`);
            });
        });

        logger.debug('WebSocket initialised');
    }
}