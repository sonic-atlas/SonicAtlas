ALTER TABLE "albums" DISABLE ROW LEVEL SECURITY;--> statement-breakpoint
DROP TABLE "albums" CASCADE;--> statement-breakpoint
ALTER TABLE "track_metadata" DROP CONSTRAINT IF EXISTS "track_metadata_album_id_albums_id_fk";
--> statement-breakpoint
DROP INDEX IF EXISTS "track_metadata_album_id_idx";--> statement-breakpoint
ALTER TABLE "track_metadata" DROP COLUMN IF EXISTS "album_id";--> statement-breakpoint
DROP TRIGGER IF EXISTS track_metadata_search_update ON track_metadata;--> statement-breakpoint
DROP FUNCTION IF EXISTS update_track_metadata_search_vector;--> statement-breakpoint
CREATE FUNCTION update_track_metadata_search_vector() RETURNS trigger AS $$
DECLARE
  release_title text;
BEGIN
  -- Try to find a release title linked to this track
  SELECT r.title INTO release_title
  FROM releases r
  JOIN release_tracks rt ON r.id = rt.release_id
  WHERE rt.track_id = NEW.track_id
  LIMIT 1;
  
  NEW.search_vector :=
    setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(NEW.artist, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(release_title, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(array_to_string(NEW.genres, ' '), '')), 'C') ||
    setweight(to_tsvector('english', coalesce(NEW.year::text, '')), 'D');
  RETURN NEW;
END
$$ language plpgsql;--> statement-breakpoint
CREATE TRIGGER track_metadata_search_update
BEFORE INSERT OR UPDATE ON track_metadata
FOR EACH ROW EXECUTE FUNCTION update_track_metadata_search_vector();--> statement-breakpoint
CREATE INDEX IF NOT EXISTS track_metadata_search_vector_idx ON track_metadata USING GIN (search_vector);--> statement-breakpoint
CREATE INDEX IF NOT EXISTS track_metadata_title_trgm_idx ON track_metadata USING GIN(title gin_trgm_ops);--> statement-breakpoint
CREATE INDEX IF NOT EXISTS track_metadata_artist_trgm_idx ON track_metadata USING GIN(artist gin_trgm_ops);