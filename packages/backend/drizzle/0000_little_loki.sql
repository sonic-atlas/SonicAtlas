CREATE TYPE "public"."cache_entries_quality_enum" AS ENUM('efficiency', 'high', 'cd', 'hires');--> statement-breakpoint
CREATE TYPE "public"."track_format_enum" AS ENUM('flac', 'mp3', 'wav', 'aac');--> statement-breakpoint
CREATE TYPE "public"."transcode_jobs_status_enum" AS ENUM('queued', 'transcoding', 'completed', 'failed');--> statement-breakpoint
CREATE TABLE "cache_entries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"track_id" uuid,
	"quality" "cache_entries_quality_enum",
	"format" "track_format_enum",
	"filepath" text NOT NULL,
	"file_size" bigint,
	"created_at" timestamp DEFAULT now(),
	"expires_at" timestamp
);
--> statement-breakpoint
CREATE TABLE "playlist_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"playlist_id" uuid NOT NULL,
	"track_id" uuid,
	"position" integer,
	"added_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "playlists" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"description" text NOT NULL,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "track_metadata" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"track_id" uuid,
	"title" text,
	"artist" text,
	"album" text,
	"year" integer,
	"genres" text[],
	"search_vector" "tsvector"
);
--> statement-breakpoint
CREATE TABLE "tracks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"filename" text NOT NULL,
	"original_filename" text NOT NULL,
	"format" "track_format_enum",
	"cover_art_path" text,
	"duration" integer,
	"sample_rate" integer,
	"bit_depth" integer,
	"file_size" bigint,
	"uploaded_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "transcode_jobs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"track_id" uuid,
	"quality" text,
	"status" "transcode_jobs_status_enum",
	"started_at" timestamp,
	"completed_at" timestamp,
	"errorMessage" text
);
--> statement-breakpoint
ALTER TABLE "cache_entries" ADD CONSTRAINT "cache_entries_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "playlist_items" ADD CONSTRAINT "playlist_items_playlist_id_playlists_id_fk" FOREIGN KEY ("playlist_id") REFERENCES "public"."playlists"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "playlist_items" ADD CONSTRAINT "playlist_items_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "track_metadata" ADD CONSTRAINT "track_metadata_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transcode_jobs" ADD CONSTRAINT "transcode_jobs_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "cache_entries_track_id_quality_idx" ON "cache_entries" USING btree ("track_id","quality");--> statement-breakpoint
CREATE INDEX "playlist_items_playlist_id_idx" ON "playlist_items" USING btree ("playlist_id");