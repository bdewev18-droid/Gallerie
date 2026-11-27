import sqlite3
from pathlib import Path
from typing import Optional, List, Dict, Any

DB_PATH = Path(r"d:\LRforIA\data\photos.db")

def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA foreign_keys=ON;")
    return conn

def init_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with get_connection() as conn:
        conn.executescript("""
        CREATE TABLE IF NOT EXISTS photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filename TEXT NOT NULL,
            rel_path TEXT NOT NULL UNIQUE,
            year TEXT,
            date_folder TEXT,
            file_size INTEGER,
            width INTEGER,
            height INTEGER,
            capture_date TEXT,
            camera_make TEXT,
            camera_model TEXT,
            iso INTEGER,
            focal_length REAL,
            aperture REAL,
            exposure_time TEXT,
            gdrive_file_id TEXT,
            gdrive_url TEXT,
            has_thumbnail INTEGER DEFAULT 0,
            media_type TEXT DEFAULT 'photo',
            latitude REAL,
            longitude REAL,
            gps_source TEXT
        );

        CREATE TABLE IF NOT EXISTS albums (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            photo_count INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS photo_albums (
            photo_id INTEGER NOT NULL,
            album_id TEXT NOT NULL,
            PRIMARY KEY (photo_id, album_id),
            FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE,
            FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_photos_year ON photos(year);
        CREATE INDEX IF NOT EXISTS idx_photos_date_folder ON photos(date_folder);
        CREATE INDEX IF NOT EXISTS idx_photos_capture_date ON photos(capture_date);
        CREATE INDEX IF NOT EXISTS idx_photo_albums_album ON photo_albums(album_id);
        CREATE INDEX IF NOT EXISTS idx_albums_parent ON albums(parent_id);

        -- Virtual Full Text Search Table
        CREATE VIRTUAL TABLE IF NOT EXISTS photos_fts USING fts5(
            photo_id UNINDEXED,
            filename,
            year,
            date_folder,
            camera,
            albums
        );
        """)
        conn.commit()

if __name__ == "__main__":
    init_db()
    print("Database initialized successfully at:", DB_PATH)
