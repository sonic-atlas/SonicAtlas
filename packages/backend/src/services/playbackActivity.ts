import { activePlaybackSessions } from './metrics/playbackMetrics.ts';

const sessions = new Map<string, number>();

export function registerPlaybackActivity(sessionId: string) {
    sessions.set(sessionId, Date.now());
}

setInterval(() => {
    const now = Date.now();

    for (const [session, lastSeen] of sessions) {
        if (now - lastSeen > 30000) {
            sessions.delete(session);
        }
    }

    activePlaybackSessions.set(sessions.size);
}, 5000);