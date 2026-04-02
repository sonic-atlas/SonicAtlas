ALTER TABLE "tracks" ALTER COLUMN "format" SET DATA TYPE text;--> statement-breakpoint
DROP TYPE "track_format_enum";--> statement-breakpoint
CREATE TYPE "track_format_enum" AS ENUM('mp3', 'flac', 'wav', 'ogg', 'opus', 'aac', 'wma');--> statement-breakpoint
ALTER TABLE "tracks" ALTER COLUMN "format" SET DATA TYPE "track_format_enum" USING "format"::"track_format_enum";