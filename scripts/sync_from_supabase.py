import sqlite3
import urllib.request
import json
from pathlib import Path

base = 'https://wnhewgsaedayonccynen.supabase.co/rest/v1'
key = 'sb_publishable_WZopMcHkGcXRFexLWqFl8g_xInYIwBm'
headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}'
}

def sync():
    db_path = Path(r"d:\LRforIA\data\photos.db")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    print("Fetching cloud records from Supabase...")

    # 1. Custom photos
    req_p = urllib.request.Request(f'{base}/custom_photos?select=*', headers=headers)
    with urllib.request.urlopen(req_p) as resp:
        custom_photos = json.loads(resp.read().decode())

    # 2. Overrides (trash & album modifications)
    req_o = urllib.request.Request(f'{base}/photo_overrides?select=*', headers=headers)
    with urllib.request.urlopen(req_o) as resp:
        overrides = json.loads(resp.read().decode())

    # 3. Custom albums
    req_a = urllib.request.Request(f'{base}/custom_albums?select=*', headers=headers)
    with urllib.request.urlopen(req_a) as resp:
        custom_albums = json.loads(resp.read().decode())

    print(f"Supabase data: {len(custom_photos)} custom photos, {len(overrides)} overrides, {len(custom_albums)} custom albums.")

    # Apply overrides (trash status)
    trash_updated = 0
    for ov in overrides:
        pid = ov['photo_id']
        is_del = ov.get('is_deleted', False)
        del_at = ov.get('deleted_at')
        if is_del:
            cur.execute('UPDATE photos SET deleted_at = ? WHERE id = ?', (del_at, pid))
            trash_updated += cur.rowcount
    print(f"Updated {trash_updated} trashed photos in photos.db.")

    # Insert custom photos
    inserted_photos = 0
    for cp in custom_photos:
        pid = cp['id']
        exists = cur.execute('SELECT id FROM photos WHERE id = ?', (pid,)).fetchone()
        if not exists:
            cur.execute('''
                INSERT INTO photos (
                    id, filename, rel_path, year, date_folder, capture_date,
                    width, height, file_size, media_type, gdrive_file_id,
                    country, city, camera_model
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                pid,
                cp.get('filename', ''),
                f"custom/{pid}_{cp.get('filename', '')}",
                cp.get('year', '2026'),
                cp.get('date_folder', ''),
                cp.get('capture_date', ''),
                cp.get('width', 0),
                cp.get('height', 0),
                cp.get('file_size', 0),
                'video' if cp.get('is_video') else 'photo',
                cp.get('drive_id'),
                cp.get('country'),
                cp.get('city'),
                cp.get('camera_model')
            ))
            inserted_photos += 1
    print(f"Inserted {inserted_photos} custom photos from Supabase into photos.db.")

    conn.commit()
    print("Database sync complete!")

if __name__ == "__main__":
    sync()
