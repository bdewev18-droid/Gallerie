import sqlite3
from pathlib import Path

# 1. Read DriveFS mirror_sqlite and mirror_metadata_sqlite
fs_base = Path(r"C:\Users\bdewe\AppData\Local\Google\DriveFS\118213793054156610633")

conn_mirror = sqlite3.connect(f"file:{fs_base / 'mirror_sqlite.db'}?mode=ro", uri=True)
cur_m = conn_mirror.cursor()
cur_m.execute("SELECT local_stable_id, stable_id, parent_local_stable_id, local_filename, local_type FROM mirror_item;")
mirror_rows = cur_m.fetchall()
conn_mirror.close()

# stable_id -> doc_id (Drive file id)
conn_meta = sqlite3.connect(f"file:{fs_base / 'mirror_metadata_sqlite.db'}?mode=ro", uri=True)
cur_meta = conn_meta.cursor()
cur_meta.execute("SELECT stable_id, id FROM items WHERE is_folder = 0;")
meta_rows = cur_meta.fetchall()
conn_meta.close()

stable_to_drive_id = {sid: drive_id for sid, drive_id in meta_rows}

item_map = {lid: (pid, fn, lt, sid) for lid, sid, pid, fn, lt in mirror_rows}

def get_rel_path(lid):
    parts = []
    curr = lid
    while curr in item_map:
        pid, fn, lt, sid = item_map[curr]
        if fn == "PHOTOS":
            break
        parts.append(fn)
        curr = pid
    return "/".join(reversed(parts))

drive_path_to_id = {}
for lid, (pid, fn, lt, sid) in item_map.items():
    if lt != 0 and sid in stable_to_drive_id:
        rel = get_rel_path(lid)
        drive_path_to_id[rel.lower()] = stable_to_drive_id[sid]

print(f"Total Google Drive File IDs mapped to relative paths: {len(drive_path_to_id)}")

# Check matching with photos in data/photos.db
db_path = Path(r"d:\LRforIA\data\photos.db")
conn_db = sqlite3.connect(db_path)
cur_db = conn_db.cursor()
cur_db.execute("SELECT id, rel_path, filename FROM photos;")
photos = cur_db.fetchall()

matched = 0
for pid, rel_path, fn in photos:
    clean_rel = rel_path.replace('\\', '/').lower()
    if clean_rel in drive_path_to_id:
        matched += 1

print(f"Total photos in DB: {len(photos)}")
print(f"Matched with exact Google Drive File ID: {matched} ({matched / len(photos) * 100:.2f}%)")
