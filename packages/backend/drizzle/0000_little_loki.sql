CREATE TYPE "public"."cache_entries_quality_enum" AS ENUM('efficiency', 'high', 'cd', 'hires');--> statement-breakpoint
CREATE TYPE "public"."track_format_enum" AS ENUM('flac', 'mp3', 'wav', 'aac');--> statement-breakpoint
CREATE TYPE "public"."transcode_jobs_status_enum" AS ENUM('queued', 'transcoding', 'completed', 'failed');--> statement-breakpoint
CREATE TYPE "public"."user_role_enum" AS ENUM('viewer', 'uploader', 'admin');--> statement-breakpoint
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
CREATE TABLE "invites" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"token" text NOT NULL,
	"created_by" uuid,
	"used_by" uuid,
	"expires_at" timestamp,
	"used_at" timestamp,
	"created_at" timestamp DEFAULT now(),
	CONSTRAINT "invites_token_unique" UNIQUE("token")
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
	"user_id" uuid,
	"name" text NOT NULL,
	"description" text NOT NULL,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "track_metdata" (
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
	"uploaded_by" uuid,
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
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"username" text NOT NULL,
	"password_hash" text NOT NULL,
	"role" "user_role_enum" DEFAULT 'viewer',
	"createdAt" timestamp DEFAULT now(),
	"created_at" timestamp,
	CONSTRAINT "users_username_unique" UNIQUE("username")
);
--> statement-breakpoint
ALTER TABLE "cache_entries" ADD CONSTRAINT "cache_entries_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invites" ADD CONSTRAINT "invites_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invites" ADD CONSTRAINT "invites_used_by_users_id_fk" FOREIGN KEY ("used_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "playlist_items" ADD CONSTRAINT "playlist_items_playlist_id_playlists_id_fk" FOREIGN KEY ("playlist_id") REFERENCES "public"."playlists"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "playlist_items" ADD CONSTRAINT "playlist_items_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "playlists" ADD CONSTRAINT "playlists_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "track_metdata" ADD CONSTRAINT "track_metdata_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tracks" ADD CONSTRAINT "tracks_uploaded_by_users_id_fk" FOREIGN KEY ("uploaded_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transcode_jobs" ADD CONSTRAINT "transcode_jobs_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "cache_entries_track_id_quality_idx" ON "cache_entries" USING btree ("track_id","quality");--> statement-breakpoint
CREATE INDEX "playlist_items_playlist_id_idx" ON "playlist_items" USING btree ("playlist_id");--> statement-breakpoint
CREATE INDEX "users_username_idx" ON "users" USING btree ("username");