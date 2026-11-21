import sqlite3
import cv2
from pathlib import Path
from PIL import Image

PHOTOS_DIR = Path(r"D:\dowload chrome\PHOTOS")
THUMBNAILS_DIR = Path(r"d:\LRforIA\data\thumbnails")
THUMBNAILS_DIR.mkdir(parents=True, exist_ok=True)

conn = sqlite3.connect(r"d:\LRforIA\data\photos.db")
conn.row_factory = sqlite3.Row
cur = conn.cursor()

cur.execute("SELECT id, rel_path, filename FROM photos WHERE media_type = 'video';")
videos = cur.fetchall()
print(f"Generating thumbnails for {len(videos)} videos...")

generated = 0
for v in videos:
    vid_id = v["id"]
    rel_path = v["rel_path"]
    target_path = THUMBNAILS_DIR / f"{vid_id}.webp"
    
    if target_path.exists() and target_path.stat().st_size > 0:
        generated += 1
        continue

    src_path = PHOTOS_DIR / rel_path
    if not src_path.exists():
        continue

    try:
        cap = cv2.VideoCapture(str(src_path))
        success, frame = cap.read()
        cap.release()
        if success and frame is not None:
            # Convert BGR (OpenCV) to RGB (PIL)
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            img = Image.fromarray(frame_rgb)
            img.thumbnail((450, 450), Image.Resampling.BILINEAR)
            img.save(target_path, "WEBP", quality=80)
            generated += 1
    except Exception as e:
        print(f"Error for video {vid_id} ({rel_path}): {e}")

print(f"Successfully generated {generated}/{len(videos)} video thumbnails!")
conn.close()
