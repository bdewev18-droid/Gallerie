import os
import sys
import json
import sqlite3
import urllib.request
import urllib.error
from pathlib import Path

"""
Script to synchronize SQLite photos.db to Supabase PostgreSQL.
Usage:
    python scripts/sync_to_supabase.py <SUPABASE_URL> <SUPABASE_SERVICE_ROLE_KEY>

Or set environment variables:
    SUPABASE_URL=https://xyz.supabase.co
    SUPABASE_KEY=eyJ...
"""

BATCH_SIZE = 500

def post_batch(url, api_key, table, records):
    endpoint = f"{url.rstrip('/')}/rest/v1/{table}"
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }
    data = json.dumps(records).encode("utf-8")
    req = urllib.request.Request(endpoint, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        error_msg = e.read().decode("utf-8")
        print(f"Error posting batch to {table}: HTTP {e.code} - {error_msg}")
        raise

def sync():
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_KEY")

    if len(sys.argv) >= 3:
        supabase_url = sys.argv[1]
        supabase_key = sys.argv[2]

    if not supabase_url or not supabase_key:
        print("Missing Supabase credentials!")
        print("Usage: python scripts/sync_to_supabase.py <SUPABASE_URL> <SUPABASE_SERVICE_ROLE_KEY>")
        print("Or export SUPABASE_URL and SUPABASE_KEY in your environment.")
        sys.exit(1)

    db_path = Path(r"d:\LRforIA\data\photos.db")
    if not db_path.exists():
        print(f"Database not found at {db_path}")
        sys.exit(1)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    print("=== SYNCING TO SUPABASE ===")
    
    # 1. Sync Albums
    print("\n1. Syncing Albums...")
    cur.execute("SELECT id, name, parent_id, is_folder, direct_count, total_count FROM albums;")
    albums = [dict(r) for r in cur.fetchall()]
    for i in range(0, len(albums), BATCH_SIZE):
        batch = albums[i:i + BATCH_SIZE]
        post_batch(supabase_url, supabase_key, "albums", batch)
        print(f"  Uploaded albums {i + 1} to {min(i + BATCH_SIZE, len(albums))} of {len(albums)}")

    # 2. Sync Photos
    print("\n2. Syncing Photos...")
    cur.execute("""
    SELECT id, filename, rel_path, year, date_folder, capture_date, width, height, file_size,
           media_type, gdrive_file_id, camera_make, camera_model, focal_length, aperture,
           iso, exposure_time, country, city, state_prov, score, deleted_at
    FROM photos;
    """)
    photos = [dict(r) for r in cur.fetchall()]
    for i in range(0, len(photos), BATCH_SIZE):
        batch = photos[i:i + BATCH_SIZE]
        post_batch(supabase_url, supabase_key, "photos", batch)
        print(f"  Uploaded photos {i + 1} to {min(i + BATCH_SIZE, len(photos))} of {len(photos)}")

    # 3. Sync Photo-Album mappings
    print("\n3. Syncing Photo Albums...")
    cur.execute("SELECT photo_id, album_id FROM photo_albums;")
    mappings = [dict(r) for r in cur.fetchall()]
    for i in range(0, len(mappings), BATCH_SIZE):
        batch = mappings[i:i + BATCH_SIZE]
        post_batch(supabase_url, supabase_key, "photo_albums", batch)
        print(f"  Uploaded photo_albums {i + 1} to {min(i + BATCH_SIZE, len(mappings))} of {len(mappings)}")

    conn.close()
    print("\n✔ All records successfully synchronized to Supabase!")

if __name__ == "__main__":
    sync()
