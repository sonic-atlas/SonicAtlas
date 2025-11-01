import { relations } from 'drizzle-orm';
import {
    bigint,
    customType,
    index,
    integer,
    pgEnum,
    pgTable,
    text,
    timestamp,
    uuid
} from 'drizzle-orm/pg-core';

export const trackFormatEnum = pgEnum('track_format_enum', ['flac', 'mp3', 'wav', 'aac']);

export const transcodeJobsStatusEnum = pgEnum('transcode_jobs_status_enum', ['queued', 'transcoding', 'completed', 'failed']);

export const cacheEntriesQualityEnum = pgEnum('cache_entries_quality_enum', ['efficiency', 'high', 'cd', 'hires']);

const tsvector = customType<{ data: string; notNull: false; default: false }>({
    dataType() {
        return 'tsvector';
    }
});

export const tracks = pgTable('tracks', {
    id: uuid().defaultRandom().primaryKey(),
    filename: text().notNull(),
    originalFilename: text('original_filename').notNull(),
    format: trackFormatEnum(),
    coverArtPath: text('cover_art_path'),
    duration: integer(),
    sampleRate: integer('sample_rate'),
    bitDepth: integer('bit_depth'),
    fileSize: bigint('file_size', { mode: 'number' }),
    uploadedAt: timestamp('uploaded_at').defaultNow()
});

export const trackMetadata = pgTable('track_metadata', {
    id: uuid().defaultRandom().primaryKey(),
    trackId: uuid('track_id').references(() => tracks.id),
    title: text(),
    artist: text(),
    album: text(),
    year: integer(),
    genres: text().array(),
    bitrate: integer(),
    codec: text(),
    searchVector: tsvector('search_vector')
});

export const cacheEntries = pgTable('cache_entries', {
    id: uuid().defaultRandom().primaryKey(),
    trackId: uuid('track_id').references(() => tracks.id),
    quality: cacheEntriesQualityEnum(),
    format: trackFormatEnum(),
    filepath: text().notNull(),
    fileSize: bigint('file_size', { mode: 'number' }),
    createdAt: timestamp('created_at').defaultNow(),
    expiresAt: timestamp('expires_at')
}, (table) => [
    index('cache_entries_track_id_quality_idx').on(table.trackId, table.quality)
]);

export const playlists = pgTable('playlists', {
    id: uuid().defaultRandom().primaryKey(),
    name: text().notNull(),
    description: text().notNull(),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow()
});

export const playlistItems = pgTable('playlist_items', {
    id: uuid().defaultRandom().primaryKey(),
    playlistId: uuid('playlist_id').references(() => playlists.id).notNull(),
    trackId: uuid('track_id').references(() => tracks.id),
    position: integer(),
    addedAt: timestamp('added_at').defaultNow()
}, (table) => [
    index('playlist_items_playlist_id_idx').on(table.playlistId)
]);

export const transcodeJobs = pgTable('transcode_jobs', {
    id: uuid().defaultRandom().primaryKey(),
    trackId: uuid('track_id').references(() => tracks.id),
    quality: text(),
    status: transcodeJobsStatusEnum(),
    startedAt: timestamp('started_at'),
    completedAt: timestamp('completed_at'),
    errorMessage: text()
});



//* ===============
//*    RELATIONS
//* ===============

//#region RELATIONS

export const trackRelations = relations(tracks, ({ many, one }) => ({
    metadata: one(trackMetadata, {
        fields: [tracks.id],
        references: [trackMetadata.trackId]
    }),
    playlistItems: many(playlistItems)
}));

export const trackMetadataRelations = relations(trackMetadata, ({ one }) => ({
    track: one(tracks, {
        fields: [trackMetadata.trackId],
        references: [tracks.id]
    })
}));

export const playlistRelations = relations(playlists, ({ many }) => ({
    items: many(playlistItems)
}));

export const playlistItemRelations = relations(playlistItems, ({ one }) => ({
    playlist: one(playlists, {
        fields: [playlistItems.playlistId],
        references: [playlists.id]
    }),
    track: one(tracks, {
        fields: [playlistItems.trackId],
        references: [tracks.id]
    })
}));

export const transcodeJobRelations = relations(transcodeJobs, ({ one }) => ({
    track: one(tracks, {
        fields: [transcodeJobs.trackId],
        references: [tracks.id]
    })
}));

//#endregion