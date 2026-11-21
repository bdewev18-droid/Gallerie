-- ====================================================================
-- MEDIAS FAMILLY - SUPABASE DATABASE SCHEMA
-- Compatible with PostgreSQL 15+ / Supabase Cloud
-- ====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABLE: albums (Lightroom thematic collections and folders)
CREATE TABLE IF NOT EXISTS public.albums (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id TEXT REFERENCES public.albums(id) ON DELETE SET NULL,
    is_folder BOOLEAN DEFAULT FALSE,
    direct_count INTEGER DEFAULT 0,
    total_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_albums_parent ON public.albums(parent_id);
CREATE INDEX IF NOT EXISTS idx_albums_name ON public.albums(name);

-- 3. TABLE: photos (Photos and Videos metadata)
CREATE TABLE IF NOT EXISTS public.photos (
    id BIGINT PRIMARY KEY,
    filename TEXT NOT NULL,
    rel_path TEXT NOT NULL,
    year TEXT,
    date_folder TEXT,
    capture_date TIMESTAMPTZ,
    width INTEGER DEFAULT 0,
    height INTEGER DEFAULT 0,
    file_size BIGINT DEFAULT 0,
    media_type TEXT DEFAULT 'photo',
    gdrive_file_id TEXT,
    camera_make TEXT,
    camera_model TEXT,
    focal_length NUMERIC,
    aperture NUMERIC,
    iso INTEGER,
    exposure_time TEXT,
    country TEXT,
    city TEXT,
    state_prov TEXT,
    score NUMERIC,
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_photos_capture_date ON public.photos(capture_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_photos_gdrive_id ON public.photos(gdrive_file_id);
CREATE INDEX IF NOT EXISTS idx_photos_media_type ON public.photos(media_type);
CREATE INDEX IF NOT EXISTS idx_photos_deleted_at ON public.photos(deleted_at);
CREATE INDEX IF NOT EXISTS idx_photos_country ON public.photos(country);
CREATE INDEX IF NOT EXISTS idx_photos_camera ON public.photos(camera_model);
CREATE INDEX IF NOT EXISTS idx_photos_year ON public.photos(year);

-- 4. TABLE: photo_albums (Many-to-Many mapping)
CREATE TABLE IF NOT EXISTS public.photo_albums (
    photo_id BIGINT REFERENCES public.photos(id) ON DELETE CASCADE,
    album_id TEXT REFERENCES public.albums(id) ON DELETE CASCADE,
    PRIMARY KEY (photo_id, album_id)
);

CREATE INDEX IF NOT EXISTS idx_pa_album ON public.photo_albums(album_id);
CREATE INDEX IF NOT EXISTS idx_pa_photo ON public.photo_albums(photo_id);

-- 5. FUNCTION: 30-Day Trash Auto-Purge
CREATE OR REPLACE FUNCTION public.purge_expired_trash()
RETURNS INTEGER AS $$
DECLARE
    purged_count INTEGER;
BEGIN
    DELETE FROM public.photos
    WHERE deleted_at IS NOT NULL
      AND deleted_at < NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS purged_count = ROW_COUNT;
    RETURN purged_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. VIEWS FOR AGGREGATES
CREATE OR REPLACE VIEW public.v_filter_stats AS
SELECT
    (SELECT COUNT(*) FROM public.photos WHERE deleted_at IS NULL AND gdrive_file_id IS NOT NULL) AS drive_synced,
    (SELECT COUNT(*) FROM public.photos WHERE deleted_at IS NULL AND gdrive_file_id IS NULL) AS drive_pending,
    (SELECT COUNT(*) FROM public.photos WHERE deleted_at IS NOT NULL) AS trash_count;

-- 7. ROW LEVEL SECURITY (RLS)
ALTER TABLE public.albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_albums ENABLE ROW LEVEL SECURITY;

-- Allow public read access (for anon client like web/mobile app)
CREATE POLICY "Public read albums" ON public.albums FOR SELECT USING (true);
CREATE POLICY "Public read photos" ON public.photos FOR SELECT USING (true);
CREATE POLICY "Public read photo_albums" ON public.photo_albums FOR SELECT USING (true);

-- Allow authenticated/service key write access
CREATE POLICY "Service write albums" ON public.albums FOR ALL USING (auth.role() = 'service_role' OR auth.role() = 'authenticated');
CREATE POLICY "Service write photos" ON public.photos FOR ALL USING (auth.role() = 'service_role' OR auth.role() = 'authenticated');
CREATE POLICY "Service write photo_albums" ON public.photo_albums FOR ALL USING (auth.role() = 'service_role' OR auth.role() = 'authenticated');
