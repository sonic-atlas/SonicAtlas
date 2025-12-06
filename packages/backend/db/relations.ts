import { defineRelations } from 'drizzle-orm';
import * as s from './schema.js';

export const relations = defineRelations(s, (r) => ({
    tracks: {
        metadata: r.one.trackMetadata({
            from: r.tracks.id,
            to: r.trackMetadata.trackId,
            optional: false
        }),
        playlistItems: r.many.playlistItems(),
        releaseTracks: r.many.releaseTracks()
    },
    trackMetadata: {
        track: r.one.tracks({
            from: r.trackMetadata.trackId,
            to: r.tracks.id,
            optional: false
        })
    },
    playlists: {
        items: r.many.playlistItems()
    },
    playlistItems: {
        playlist: r.one.playlists({
            from: r.playlistItems.trackId,
            to: r.playlists.id
        }),
        track: r.one.tracks({
            from: r.playlistItems.trackId,
            to: r.tracks.id
        })
    },
    releases: {
        releaseTracks: r.many.releaseTracks()
    },
    releaseTracks: {
        release: r.one.releases({
            from: r.releaseTracks.releaseId,
            to: r.releases.id
        }),
        track: r.one.tracks({
            from: r.releaseTracks.trackId,
            to: r.tracks.id
        })
    }
}));