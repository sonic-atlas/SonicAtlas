import { io, type Socket } from 'socket.io-client';
import { env } from '$env/dynamic/public';

class SocketStore {
    socket: Socket | null = $state(null);
    id: string | undefined = $state(undefined);

    connect() {
        if (this.socket) return;

        let url = env.PUBLIC_API_URL;
        if (!url && typeof window !== 'undefined') {
            const protocol = window.location.protocol;
            const hostname = window.location.hostname;
            url = `${protocol}//${hostname}:3000`;
        }

        if (!url) url = 'http://localhost:3000';

        console.log('Connecting to socket at:', url);

        this.socket = io(url, {
            path: '/ws',
            transports: ['websocket'],
            autoConnect: true
        });

        this.socket.on('connect', () => {
            this.id = this.socket?.id;
            console.log('Socket connected:', this.id);
        });

        this.socket.on('disconnect', () => {
            this.id = undefined;
            console.log('Socket disconnected');
        });
    }
}

export const socket = new SocketStore();
