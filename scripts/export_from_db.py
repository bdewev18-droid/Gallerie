import sqlite3
import json
from pathlib import Path
from collections import defaultdict

def export_catalog():
    conn = sqlite3.connect(r'd:\LRforIA\data\photos.db')
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    print("Fetching albums from database...")
    cur.execute("""
    SELECT id, name, parent_id, is_folder, direct_count, total_count 
    FROM albums 
    WHERE lower(name) != 'videos' AND id != 'bb3d36f6161042d4a2ba6a500c4fe504'
    ORDER BY is_folder DESC, name ASC;
    """)
    albums = [
        {
            "id": r["id"],
            "name": r["name"],
            "parent_id": r["parent_id"],
            "is_folder": r["is_folder"],
            "direct_count": r["direct_count"],
            "count": r["total_count"]
        }
        for r in cur.fetchall()
    ]

    print("Fetching photo album mappings...")
    cur.execute("SELECT photo_id, album_id FROM photo_albums;")
    photo_albums = defaultdict(list)
    for r in cur.fetchall():
        photo_albums[r["photo_id"]].append(r["album_id"])

    print("Fetching photos from database...")
    cur.execute("""
    SELECT id, filename, year, date_folder, capture_date, width, height, file_size, gdrive_file_id, media_type 
    FROM photos 
    ORDER BY id ASC;
    """)
    rows = cur.fetchall()

    photo_years_count = defaultdict(int)
    video_years_count = defaultdict(int)
    photos = []

    for r in rows:
        y = r["year"] or "unknown_date"
        is_video = r["media_type"] == "video"

        if is_video:
            video_years_count[y] += 1
        else:
            photo_years_count[y] += 1

        p = {
            "id": r["id"],
            "fn": r["filename"],
            "y": y,
            "d": r["date_folder"] or "",
            "dt": r["capture_date"] or "",
            "w": r["width"] or 0,
            "h": r["height"] or 0,
            "s": r["file_size"] or 0,
            "m": "v" if is_video else "p",
            "al": photo_albums.get(r["id"], [])
        }
        if r["gdrive_file_id"]:
            p["gid"] = r["gdrive_file_id"]
        photos.append(p)

    conn.close()

    years = [{"year": y, "count": cnt} for y, cnt in sorted(photo_years_count.items(), key=lambda x: (x[0] == 'unknown_date', x[0]), reverse=True)]
    video_years = [{"year": y, "count": cnt} for y, cnt in sorted(video_years_count.items(), key=lambda x: (x[0] == 'unknown_date', x[0]), reverse=True)]

    catalog = {
        "albums": albums,
        "years": years,
        "video_years": video_years,
        "photos": photos,
        "gdrive_url": "https://drive.google.com/drive/folders/1w_szSK4yKM_j0Trk8lT5Zcpcxae_0_iO"
    }

    out_dir = Path(r"d:\LRforIA\assets\data")
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "catalog.json"
    print(f"Writing catalog JSON to {json_path}...")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, separators=(',', ':'))

    size_mb = json_path.stat().st_size / (1024 * 1024)
    print(f"Done! Catalog size: {size_mb:.2f} MB")
    print(f"Total items: {len(photos)} (Photos: {len(photos) - sum(video_years_count.values())}, Videos: {sum(video_years_count.values())})")
    print(f"Video years: {video_years}")

if __name__ == "__main__":
    export_catalog()
