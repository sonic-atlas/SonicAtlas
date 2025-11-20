CREATE TYPE "public"."release_type_enum" AS ENUM('album', 'ep', 'single', 'compilation');--> statement-breakpoint
CREATE TABLE "release_tracks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"release_id" uuid NOT NULL,
	"track_id" uuid,
	"disc_number" integer DEFAULT 1,
	"track_number" integer,
	"added_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "releases" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"title" text NOT NULL,
	"primary_artist" text,
	"year" integer,
	"release_type" "release_type_enum",
	"cover_art_path" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
ALTER TABLE "playlist_items" DROP CONSTRAINT "playlist_items_playlist_id_playlists_id_fk";
--> statement-breakpoint
ALTER TABLE "playlist_items" DROP CONSTRAINT "playlist_items_track_id_tracks_id_fk";
--> statement-breakpoint
ALTER TABLE "albums" ADD COLUMN "cover_art" text;--> statement-breakpoint
ALTER TABLE "albums" ADD COLUMN "created_at" timestamp DEFAULT now();--> statement-breakpoint
ALTER TABLE "albums" ADD COLUMN "updated_at" timestamp DEFAULT now();--> statement-breakpoint
ALTER TABLE "track_metadata" ADD COLUMN "created_at" timestamp DEFAULT now();--> statement-breakpoint
ALTER TABLE "track_metadata" ADD COLUMN "updated_at" timestamp DEFAULT now();--> statement-breakpoint
ALTER TABLE "release_tracks" ADD CONSTRAINT "release_tracks_release_id_releases_id_fk" FOREIGN KEY ("release_id") REFERENCES "public"."releases"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "release_tracks" ADD CONSTRAINT "release_tracks_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "release_tracks_release_id_idx" ON "release_tracks" USING btree ("release_id");--> statement-breakpoint
CREATE INDEX "release_tracks_release_disc_track_idx" ON "release_tracks" USING btree ("release_id","disc_number","track_number");--> statement-breakpoint
ALTER TABLE "playlist_items" ADD CONSTRAINT "playlist_items_playlist_id_playlists_id_fk" FOREIGN KEY ("playlist_id") REFERENCES "public"."playlists"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "playlist_items" ADD CONSTRAINT "playlist_items_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "track_metadata_track_id_idx" ON "track_metadata" USING btree ("track_id");--> statement-breakpoint
CREATE INDEX "track_metadata_album_id_idx" ON "track_metadata" USING btree ("album_id");--> statement-breakpoint
ALTER TABLE "albums" DROP COLUMN "coverArt";--> statement-breakpoint
ALTER TABLE "albums" DROP COLUMN "createdAt";