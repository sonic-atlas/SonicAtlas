CREATE EXTENSION IF NOT EXISTS pg_trgm;--> statement-breakpoint
DROP TRIGGER IF EXISTS track_metadata_search_update ON track_metadata;--> statement-breakpoint
DROP FUNCTION IF EXISTS update_track_metadata_search_vector;--> statement-breakpoint
CREATE FUNCTION update_track_metadata_search_vector() RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(NEW.artist, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(NEW.album, '')), 'B') ||
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
CREATE INDEX IF NOT EXISTS track_metadata_artist_trgm_idx ON track_metadata USING GIN(artist gin_trgm_ops);--> statement-breakpoint