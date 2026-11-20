import sqlite3
import json
import gzip
from pathlib import Path

def export_catalog():
    db_path = Path("data/photos.db")
    if not db_path.exists():
        db_path = Path(r"d:\LRforIA\data\photos.db")

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    # 1. Albums
    cur.execute("""
    SELECT id, name, parent_id, photo_count 
    FROM albums 
    WHERE photo_count > 0 
    ORDER BY photo_count DESC;
    """)
    albums = [dict(r) for r in cur.fetchall()]

    # 2. Years
    cur.execute("""
    SELECT year, COUNT(*) as count 
    FROM photos 
    GROUP BY year 
    ORDER BY CASE WHEN year = 'unknown_date' THEN '9999' ELSE year END DESC;
    """)
    years = [dict(r) for r in cur.fetchall()]

    # 3. Photo-albums mapping
    cur.execute("SELECT photo_id, album_id FROM photo_albums;")
    photo_albums_map = {}
    for pid, aid in cur.fetchall():
        if pid not in photo_albums_map:
            photo_albums_map[pid] = []
        photo_albums_map[pid].append(aid)

    # 4. Photos (compact schema for mobile/web performance)
    cur.execute("""
    SELECT id, filename, year, date_folder, capture_date, width, height, file_size, camera_make, camera_model
    FROM photos
    ORDER BY CASE WHEN capture_date IS NOT NULL THEN capture_date ELSE rel_path END DESC;
    """)
    
    photos = []
    for r in cur.fetchall():
        camera = f"{r['camera_make'] or ''} {r['camera_model'] or ''}".strip()
        photos.append({
            "id": r["id"],
            "fn": r["filename"],
            "y": r["year"],
            "d": r["date_folder"] or "",
            "dt": r["capture_date"] or "",
            "w": r["width"] or 0,
            "h": r["height"] or 0,
            "s": r["file_size"] or 0,
            "c": camera if camera else None,
            "al": photo_albums_map.get(r["id"], [])
        })

    conn.close()

    catalog = {
        "albums": albums,
        "years": years,
        "photos": photos,
        "gdrive_url": "https://drive.google.com/drive/folders/1w_szSK4yKM_j0Trk8lT5Zcpcxae_0_iO"
    }

    out_dir = Path("assets/data")
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "catalog.json"
    
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, separators=(',', ':'))

    print(f"Exported {len(photos)} photos, {len(albums)} albums, {len(years)} years.")
    print(f"Catalog JSON size: {json_path.stat().st_size / (1024**2):.2f} MB")

if __name__ == "__main__":
    export_catalog()
