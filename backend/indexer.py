import sqlite3
import msgpack
import re
import os
from pathlib import Path
from PIL import Image
from PIL.ExifTags import TAGS
from typing import Dict, Any, Tuple
from database import get_connection, init_db

PHOTOS_DIR = Path(r"D:\dowload chrome\PHOTOS")
MCAT_PATH = Path(r"C:\Users\bdewe\OneDrive\Images\Lightroom\Lightroom Catalog Sync.lrdata\afb0cfb20b2a4bcb9b57d5ec165fc499\Managed Catalog.mcat")
GDRIVE_BASE_FOLDER = "https://drive.google.com/drive/folders/1w_szSK4yKM_j0Trk8lT5Zcpcxae_0_iO"

def parse_mcat(mcat_path: Path):
    print("Reading Lightroom catalog from:", mcat_path)
    conn = sqlite3.connect(f"file:{mcat_path}?mode=ro", uri=True)
    conn.text_factory = bytes
    cur = conn.cursor()

    cur.execute("""
    SELECT d.fullDocId, r.content 
    FROM revs r 
    JOIN docs d ON r.localDocId = d.localDocId 
    WHERE r.current=1 AND r.deleted=0;
    """)

    albums = {} # album_id -> {'name': name, 'parent_id': parent_id}
    album_assets = [] # (album_id, asset_id)
    assets_by_name_size = {} # (clean_name_lower, filesize) -> asset_dict
    assets_by_size = {} # filesize -> asset_dict (if unique)
    size_counts = {}

    for fullDocId_bytes, blob in cur:
        if not blob:
            continue
        try:
            data = msgpack.unpackb(blob, raw=False)
            t = data.get("type")
            doc_id = fullDocId_bytes.decode("utf-8")

            if t == "album":
                name = data.get("name") or data.get("payload", {}).get("name")
                parent = data.get("parent", {}).get("id")
                if name:
                    albums[doc_id] = {
                        "id": doc_id,
                        "name": name.strip(),
                        "parent_id": parent
                    }
            elif t == "album_asset":
                alb_id = data.get("album", {}).get("id")
                ass_id = data.get("asset", {}).get("id")
                if alb_id and ass_id:
                    album_assets.append((alb_id, ass_id))
            elif t == "asset":
                import_src = data.get("importSource") or {}
                fname = import_src.get("fileName")
                fsize = import_src.get("fileSize")
                if fname and fsize:
                    asset_obj = {
                        "id": doc_id,
                        "filename": fname,
                        "filesize": fsize,
                        "capture_date": data.get("captureDate"),
                        "width": import_src.get("originalWidth"),
                        "height": import_src.get("originalHeight")
                    }
                    assets_by_name_size[(fname.lower(), fsize)] = asset_obj
                    size_counts[fsize] = size_counts.get(fsize, 0) + 1
                    assets_by_size[fsize] = asset_obj
        except Exception:
            pass

    conn.close()

    # Filter unique sizes
    unique_size_assets = {sz: obj for sz, obj in assets_by_size.items() if size_counts[sz] == 1}

    # Map asset_id to set of album_ids
    asset_to_albums = {}
    for alb_id, ass_id in album_assets:
        if ass_id not in asset_to_albums:
            asset_to_albums[ass_id] = set()
        asset_to_albums[ass_id].add(alb_id)

    print(f"Extracted {len(albums)} albums, {len(assets_by_name_size)} assets from Lightroom.")
    return albums, assets_by_name_size, unique_size_assets, asset_to_albums

def clean_lr_filename(name: str) -> str:
    # Handles Lightroom exported suffixes like __2022-05-15T13_14_59.664_.JPG
    return re.sub(r'__\d{4}-\d{2}-\d{2}T.*_(\.[a-zA-Z0-9]+)$', r'\1', name, flags=re.IGNORECASE)

def extract_exif(path: Path) -> Dict[str, Any]:
    meta = {
        "width": None, "height": None, "capture_date": None,
        "camera_make": None, "camera_model": None, "iso": None,
        "focal_length": None, "aperture": None, "exposure_time": None
    }
    if path.suffix.lower() not in ['.jpg', '.jpeg', '.png', '.webp', '.tif', '.tiff']:
        return meta
    try:
        with Image.open(path) as img:
            meta["width"], meta["height"] = img.size
            exif = img.getexif()
            if exif:
                # 271: Make, 272: Model
                meta["camera_make"] = exif.get(271)
                meta["camera_model"] = exif.get(272)
                # 306: DateTime, 36867: DateTimeOriginal
                date_str = exif.get(36867) or exif.get(306)
                if date_str:
                    meta["capture_date"] = str(date_str)
    except Exception:
        pass
    return meta

def run_indexing():
    init_db()
    
    albums, assets_by_name_size, unique_size_assets, asset_to_albums = parse_mcat(MCAT_PATH)

    db = get_connection()
    cur = db.cursor()

    print("\nInserting albums into database...")
    for alb_id, alb_data in albums.items():
        cur.execute("""
        INSERT OR REPLACE INTO albums (id, name, parent_id, photo_count)
        VALUES (?, ?, ?, 0);
        """, (alb_id, alb_data["name"], alb_data["parent_id"]))
    db.commit()

    print(f"\nScanning photos from {PHOTOS_DIR}...")
    all_files = [f for f in PHOTOS_DIR.rglob("*") if f.is_file() and f.suffix.lower() != '.txt']
    print(f"Found {len(all_files)} photos/videos to index.")

    photos_to_insert = []
    photo_album_links = []
    fts_entries = []

    matched_lr = 0

    for idx, f in enumerate(all_files, start=1):
        if idx % 5000 == 0:
            print(f"Processing {idx}/{len(all_files)}...")

        rel_path = str(f.relative_to(PHOTOS_DIR)).replace('\\', '/')
        parts = rel_path.split('/')
        year = parts[0] if len(parts) > 0 else "unknown_date"
        date_folder = parts[1] if len(parts) > 2 else (parts[0] if len(parts) == 2 else "")
        fsize = f.stat().st_size
        filename = f.name

        clean_name = clean_lr_filename(filename)
        
        # Match against Lightroom asset
        matched_asset = (
            assets_by_name_size.get((filename.lower(), fsize)) or
            assets_by_name_size.get((clean_name.lower(), fsize)) or
            unique_size_assets.get(fsize)
        )

        width = None
        height = None
        capture_date = None
        cam_make = None
        cam_model = None
        iso = None
        focal_length = None
        aperture = None
        exposure_time = None

        matched_album_ids = set()

        if matched_asset:
            matched_lr += 1
            width = matched_asset.get("width")
            height = matched_asset.get("height")
            capture_date = matched_asset.get("capture_date")
            matched_album_ids = asset_to_albums.get(matched_asset["id"], set())

        # If width/height still missing, extract from file header quickly
        if not width or not capture_date:
            exif_meta = extract_exif(f)
            width = width or exif_meta["width"]
            height = height or exif_meta["height"]
            capture_date = capture_date or exif_meta["capture_date"]
            cam_make = exif_meta["camera_make"]
            cam_model = exif_meta["camera_model"]

        # Insert photo
        cur.execute("""
        INSERT OR REPLACE INTO photos (
            filename, rel_path, year, date_folder, file_size,
            width, height, capture_date, camera_make, camera_model,
            iso, focal_length, aperture, exposure_time, gdrive_url
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            filename, rel_path, year, date_folder, fsize,
            width, height, str(capture_date) if capture_date else None,
            cam_make, cam_model, iso, focal_length, aperture, exposure_time,
            GDRIVE_BASE_FOLDER
        ))
        photo_id = cur.lastrowid

        # Record photo album associations
        album_names_list = []
        for alb_id in matched_album_ids:
            if alb_id in albums:
                album_names_list.append(albums[alb_id]["name"])
                photo_album_links.append((photo_id, alb_id))

        # Record FTS entry
        camera_str = f"{cam_make or ''} {cam_model or ''}".strip()
        albums_str = " ".join(album_names_list)
        fts_entries.append((photo_id, filename, year, date_folder, camera_str, albums_str))

    print("\nCommitting photos...")
    db.commit()

    print(f"Linking {len(photo_album_links)} photo-album relationships...")
    cur.executemany("""
    INSERT OR IGNORE INTO photo_albums (photo_id, album_id) VALUES (?, ?);
    """, photo_album_links)
    db.commit()

    print("Updating album photo counts...")
    cur.execute("""
    UPDATE albums SET photo_count = (
        SELECT COUNT(*) FROM photo_albums WHERE photo_albums.album_id = albums.id
    );
    """)
    db.commit()

    print("Populating Full-Text Search index...")
    cur.executemany("""
    INSERT INTO photos_fts (photo_id, filename, year, date_folder, camera, albums)
    VALUES (?, ?, ?, ?, ?, ?);
    """, fts_entries)
    db.commit()

    # Summary
    cur.execute("SELECT count(*) FROM photos;")
    p_cnt = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM albums WHERE photo_count > 0;")
    active_albs = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM photo_albums;")
    links_cnt = cur.fetchone()[0]

    db.close()
    print("\n" + "="*50)
    print("INDEXATION TERMINÉE AVEC SUCCÈS")
    print("="*50)
    print(f"Photos indexées : {p_cnt}")
    print(f"Correspondances Lightroom : {matched_lr} ({matched_lr/p_cnt*100:.1f}%)")
    print(f"Albums actifs avec photos : {active_albs}")
    print(f"Liaisons Photos <-> Albums : {links_cnt}")
    print("="*50)

if __name__ == "__main__":
    run_indexing()
