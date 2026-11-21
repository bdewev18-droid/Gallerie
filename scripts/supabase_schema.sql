-- ====================================================================
-- DEWEVRE FAMILLY - SUPABASE COLLABORATIVE SCHEMA
-- Collez et exécutez ce script dans l'éditeur SQL de Supabase (SQL Editor -> New query -> Run)
-- ====================================================================

-- 1. Table des dossiers et albums créés ou modifiés depuis l'application
CREATE TABLE IF NOT EXISTS public.custom_albums (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id TEXT DEFAULT NULL,
    is_folder BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

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
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Table des modifications sur les photos existantes (ajout/retrait d'albums, mise à la corbeille)
CREATE TABLE IF NOT EXISTS public.photo_overrides (
    photo_id BIGINT PRIMARY KEY,
    added_albums JSONB DEFAULT '[]'::jsonb,
    removed_albums JSONB DEFAULT '[]'::jsonb,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ DEFAULT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activer Row Level Security (RLS)
ALTER TABLE public.custom_albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_overrides ENABLE ROW LEVEL SECURITY;

-- Autoriser la lecture et l'écriture pour les membres de l'application familiale (via la clé publishable/anon)
DROP POLICY IF EXISTS "Allow all on custom_albums" ON public.custom_albums;
CREATE POLICY "Allow all on custom_albums" ON public.custom_albums FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on custom_photos" ON public.custom_photos;
CREATE POLICY "Allow all on custom_photos" ON public.custom_photos FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on photo_overrides" ON public.photo_overrides;
CREATE POLICY "Allow all on photo_overrides" ON public.photo_overrides FOR ALL USING (true) WITH CHECK (true);
