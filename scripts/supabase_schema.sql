-- ====================================================================
-- DEWEVRE FAMILLY - SUPABASE COLLABORATIVE & AUTH SCHEMA
-- Collez et exécutez ce script dans l'éditeur SQL de Supabase (SQL Editor -> New query -> Run)
-- ====================================================================

-- 1. Table des dossiers et albums créés ou modifiés depuis l'application
CREATE TABLE IF NOT EXISTS public.custom_albums (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id TEXT DEFAULT NULL,
    is_folder BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_by_email TEXT DEFAULT NULL,
    created_by_name TEXT DEFAULT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.custom_albums ADD COLUMN IF NOT EXISTS created_by_email TEXT DEFAULT NULL;
ALTER TABLE public.custom_albums ADD COLUMN IF NOT EXISTS created_by_name TEXT DEFAULT NULL;

-- 2. Table des nouvelles photos/vidéos ajoutées depuis l'application
CREATE TABLE IF NOT EXISTS public.custom_photos (
    id BIGINT PRIMARY KEY,
    filename TEXT NOT NULL,
    year TEXT NOT NULL DEFAULT '2026',
    date_folder TEXT DEFAULT '',
    capture_date TEXT DEFAULT '',
    width INTEGER DEFAULT 0,
    height INTEGER DEFAULT 0,
    file_size BIGINT DEFAULT 0,
    is_video BOOLEAN DEFAULT FALSE,
    drive_id TEXT DEFAULT NULL,
    camera_model TEXT DEFAULT NULL,
    country TEXT DEFAULT NULL,
    city TEXT DEFAULT NULL,
    albums JSONB DEFAULT '[]'::jsonb,
    added_by_email TEXT DEFAULT NULL,
    added_by_name TEXT DEFAULT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.custom_photos ADD COLUMN IF NOT EXISTS added_by_email TEXT DEFAULT NULL;
ALTER TABLE public.custom_photos ADD COLUMN IF NOT EXISTS added_by_name TEXT DEFAULT NULL;

-- 3. Table des modifications sur les photos existantes (ajout/retrait d'albums, mise à la corbeille)
CREATE TABLE IF NOT EXISTS public.photo_overrides (
    photo_id BIGINT PRIMARY KEY,
    added_albums JSONB DEFAULT '[]'::jsonb,
    removed_albums JSONB DEFAULT '[]'::jsonb,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    updated_by_email TEXT DEFAULT NULL,
    updated_by_name TEXT DEFAULT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.photo_overrides ADD COLUMN IF NOT EXISTS updated_by_email TEXT DEFAULT NULL;
ALTER TABLE public.photo_overrides ADD COLUMN IF NOT EXISTS updated_by_name TEXT DEFAULT NULL;

-- 4. Table des "J'aime" (Likes) associés à chaque utilisateur connecté
CREATE TABLE IF NOT EXISTS public.photo_likes (
    photo_id BIGINT NOT NULL,
    user_email TEXT NOT NULL,
    user_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (photo_id, user_email)
);

-- Activer Row Level Security (RLS)
ALTER TABLE public.custom_albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_likes ENABLE ROW LEVEL SECURITY;

-- Autoriser la lecture et l'écriture pour les membres de l'application familiale
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON TABLE public.custom_albums TO anon, authenticated;
GRANT ALL ON TABLE public.custom_photos TO anon, authenticated;
GRANT ALL ON TABLE public.photo_overrides TO anon, authenticated;
GRANT ALL ON TABLE public.photo_likes TO anon, authenticated;

DROP POLICY IF EXISTS "Allow all on custom_albums" ON public.custom_albums;
CREATE POLICY "Allow all on custom_albums" ON public.custom_albums FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on custom_photos" ON public.custom_photos;
CREATE POLICY "Allow all on custom_photos" ON public.custom_photos FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on photo_overrides" ON public.photo_overrides;
CREATE POLICY "Allow all on photo_overrides" ON public.photo_overrides FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on photo_likes" ON public.photo_likes;
CREATE POLICY "Allow all on photo_likes" ON public.photo_likes FOR ALL USING (true) WITH CHECK (true);
