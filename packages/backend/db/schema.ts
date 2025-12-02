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

export const releaseTypeEnum = pgEnum('release_type_enum', ['album', 'ep', 'single', 'compilation']);

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
    trackId: uuid('track_id').references(() => tracks.id, { onDelete: 'set null' }),
    title: text(),
    artist: text(),
    year: integer(),
    genres: text().array(),
    bitrate: integer(),
    codec: text(),
    searchVector: tsvector('search_vector'),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow()
}, (table) => [
    index('track_metadata_track_id_idx').on(table.trackId),
]);

export const releases = pgTable('releases', {
    id: uuid().defaultRandom().primaryKey(),
    title: text().notNull(),
    primaryArtist: text('primary_artist'),
    year: integer(),
    releaseType: releaseTypeEnum('release_type'),
    coverArtPath: text('cover_art_path'),
    createdAt: timestamp('created_at').defaultNow(),
    updatedAt: timestamp('updated_at').defaultNow()
});

export const releaseTracks = pgTable('release_tracks', {
    id: uuid().defaultRandom().primaryKey(),
    releaseId: uuid('release_id').references(() => releases.id, { onDelete: 'set null' }).notNull(),
    trackId: uuid('track_id').references(() => tracks.id, { onDelete: 'set null' }),
    discNumber: integer('disc_number').default(1),
    trackNumber: integer('track_number'),
    addedAt: timestamp('added_at').defaultNow()
}, (table) => [
    index('release_tracks_release_id_idx').on(table.releaseId),
    index('release_tracks_release_disc_track_idx').on(
        table.releaseId,
        table.discNumber,
        table.trackNumber
    )
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
    playlistId: uuid('playlist_id').references(() => playlists.id, { onDelete: 'set null' }).notNull(),
    trackId: uuid('track_id').references(() => tracks.id, { onDelete: 'set null' }),
    position: integer(),
    addedAt: timestamp('added_at').defaultNow()
}, (table) => [
    index('playlist_items_playlist_id_idx').on(table.playlistId)
]);

//* ===============
//*    RELATIONS
//* ===============

//#region RELATIONS

export const trackRelations = relations(tracks, ({ many, one }) => ({
    metadata: one(trackMetadata, {
        fields: [tracks.id],
        references: [trackMetadata.trackId]
    }),
    playlistItems: many(playlistItems),
    releaseTracks: many(releaseTracks)
}));

export const trackMetadataRelations = relations(trackMetadata, ({ one }) => ({
    track: one(tracks, {
        fields: [trackMetadata.trackId],
        references: [tracks.id]
    }),
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

export const releaseRelations = relations(releases, ({ many }) => ({
    releaseTracks: many(releaseTracks)
}));

export const releaseTrackRelations = relations(releaseTracks, ({ one }) => ({
    release: one(releases, {
        fields: [releaseTracks.releaseId],
        references: [releases.id]
    }),
    track: one(tracks, {
        fields: [releaseTracks.trackId],
        references: [tracks.id]
    })
}));

//#endregion