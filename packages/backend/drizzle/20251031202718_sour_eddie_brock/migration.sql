DROP TABLE IF EXISTS "invites" CASCADE;--> statement-breakpoint
DROP TABLE IF EXISTS "users" CASCADE;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "playlists" DROP CONSTRAINT IF EXISTS "playlists_user_id_users_id_fk";
EXCEPTION
 WHEN undefined_column THEN NULL;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "tracks" DROP CONSTRAINT IF EXISTS "tracks_uploaded_by_users_id_fk";
EXCEPTION
 WHEN undefined_column THEN NULL;
END $$;
--> statement-breakpoint
ALTER TABLE "track_metadata" ADD COLUMN IF NOT EXISTS "bitrate" integer;--> statement-breakpoint
ALTER TABLE "track_metadata" ADD COLUMN IF NOT EXISTS "codec" text;--> statement-breakpoint
ALTER TABLE "playlists" DROP COLUMN IF EXISTS "user_id";--> statement-breakpoint
ALTER TABLE "tracks" DROP COLUMN IF EXISTS "uploaded_by";--> statement-breakpoint
DROP TYPE IF EXISTS "public"."user_role_enum";