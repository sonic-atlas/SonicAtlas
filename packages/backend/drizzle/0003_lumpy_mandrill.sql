CREATE TABLE "albums" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"title" text NOT NULL,
	"artist" text,
	"year" integer,
	"coverArt" text,
	"createdAt" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "cache_entries" DISABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "transcode_jobs" DISABLE ROW LEVEL SECURITY;--> statement-breakpoint
DROP TABLE "cache_entries" CASCADE;--> statement-breakpoint
DROP TABLE "transcode_jobs" CASCADE;--> statement-breakpoint
ALTER TABLE "track_metadata" DROP CONSTRAINT "track_metadata_track_id_tracks_id_fk";
--> statement-breakpoint
ALTER TABLE "track_metadata" ADD COLUMN "album_id" uuid;--> statement-breakpoint
CREATE UNIQUE INDEX "album_unique_idx" ON "albums" USING btree ("title","artist");--> statement-breakpoint
ALTER TABLE "track_metadata" ADD CONSTRAINT "track_metadata_album_id_albums_id_fk" FOREIGN KEY ("album_id") REFERENCES "public"."albums"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "track_metadata" ADD CONSTRAINT "track_metadata_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "track_metadata" DROP COLUMN "album";--> statement-breakpoint
DROP TYPE "public"."cache_entries_quality_enum";--> statement-breakpoint
DROP TYPE "public"."transcode_jobs_status_enum";