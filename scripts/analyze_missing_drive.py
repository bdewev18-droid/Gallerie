import sqlite3
from pathlib import Path
from collections import Counter

# Connect to DriveFS mirror_sqlite
p = Path(r"C:\Users\bdewe\AppData\Local\Google\DriveFS\118213793054156610633\mirror_sqlite.db")
conn = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
cur = conn.cursor()

cur.execute("SELECT local_stable_id, parent_local_stable_id, local_filename, local_type FROM mirror_item;")
rows = cur.fetchall()
conn.close()

item_map = {lid: (pid, fn, lt) for lid, pid, fn, lt in rows}

def get_full_path(lid):
    parts = []
    curr = lid
    while curr in item_map:
        pid, fn, lt = item_map[curr]
        if fn == "PHOTOS":
            break
        parts.append(fn)
        curr = pid
    return "/".join(reversed(parts))

drive_files = set()
for lid, (pid, fn, lt) in item_map.items():
    if lt != 0:
        drive_files.add(get_full_path(lid))

photos_dir = Path(r"D:\dowload chrome\PHOTOS")
missing_files = []

for f in photos_dir.rglob("*"):
    if f.is_file() and f.suffix.lower() != ".txt":
        rel = str(f.relative_to(photos_dir)).replace("\\", "/")
        if rel not in drive_files:
            missing_files.append((f, rel, f.stat().st_size, f.stat().st_mtime))

print(f"Total missing: {len(missing_files)}")
exts = Counter([f.suffix.lower() for f, _, _, _ in missing_files])
print("Missing extensions:", dict(exts))

# Check sizes
total_missing_bytes = sum(s for _, _, s, _ in missing_files)
print(f"Total missing size: {total_missing_bytes / (1024**3):.2f} GB")

# Check sample missing vs synced in the same folder
sample_missing = missing_files[0]
folder = sample_missing[0].parent
rel_folder = str(folder.relative_to(photos_dir)).replace("\\", "/")
print(f"\nChecking folder: {rel_folder}")
local_in_folder = [f.name for f in folder.iterdir() if f.is_file()]
synced_in_folder = [f for f in drive_files if f.startswith(rel_folder + "/")]
print(f"  Local files in folder: {len(local_in_folder)}")
print(f"  Drive files in folder: {len(synced_in_folder)}")
print(f"  Sample local in folder: {local_in_folder[:10]}")
print(f"  Sample drive in folder: {[f.split('/')[-1] for f in synced_in_folder[:10]]}")
