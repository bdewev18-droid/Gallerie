import os
from pathlib import Path
from PIL import Image, ImageOps
import sqlite3
from concurrent.futures import ProcessPoolExecutor
import time

PHOTOS_DIR = Path(r"D:\dowload chrome\PHOTOS")
THUMBNAILS_DIR = Path(r"d:\LRforIA\data\thumbnails")
DB_PATH = Path(r"d:\LRforIA\data\photos.db")

THUMBNAILS_DIR.mkdir(parents=True, exist_ok=True)
Image.MAX_IMAGE_PIXELS = None # Disable decompression bomb check for panoramic photos

def make_thumbnail(photo_id: int, rel_path: str, max_size=(450, 450)) -> bool:
    target_path = THUMBNAILS_DIR / f"{photo_id}.webp"
    if target_path.exists() and target_path.stat().st_size > 0:
        return True

    src_path = PHOTOS_DIR / rel_path
    if not src_path.exists():
        return False

    suffix = src_path.suffix.lower()
    if suffix in ['.mp4', '.mov', '.avi']:
        return False # Handled as video placeholder

    try:
        with Image.open(src_path) as img:
            # Auto-orient based on EXIF tag
            img = ImageOps.exif_transpose(img)
            # Convert RGBA/P to RGB for clean WebP
            if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
                # Keep transparent or RGB
                pass
            elif img.mode != 'RGB':
                img = img.convert('RGB')
            img.thumbnail(max_size, Image.Resampling.BILINEAR)
            img.save(target_path, 'WEBP', quality=75, method=3)
            return True
    except Exception as e:
        return False

def _worker_task(args):
    photo_id, rel_path = args
    return make_thumbnail(photo_id, rel_path)

def batch_generate(max_workers=8, limit=None):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    query = "SELECT id, rel_path FROM photos WHERE has_thumbnail = 0"
    if limit:
        query += f" LIMIT {limit}"
    cur.execute(query)
    rows = cur.fetchall()
    conn.close()

    total = len(rows)
    print(f"Generating thumbnails for {total} photos with {max_workers} processes...")

    t0 = time.time()
    success = 0
    with ProcessPoolExecutor(max_workers=max_workers) as executor:
        for idx, res in enumerate(executor.map(_worker_task, rows, chunksize=50), 1):
            if res:
                success += 1
            if idx % 1000 == 0 or idx == total:
                elapsed = time.time() - t0
                rate = idx / elapsed if elapsed > 0 else 0
                print(f"Progress: {idx}/{total} ({rate:.1f} photos/s)...")

    print(f"Batch generation completed: {success}/{total} thumbnails created in {time.time()-t0:.1f}s.")

if __name__ == "__main__":
    batch_generate()
