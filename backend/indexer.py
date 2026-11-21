import sqlite3
import msgpack
import re
import os
from pathlib import Path
from collections import defaultdict
from database import DB_PATH, get_connection, init_db

PHOTOS_DIR = Path(r"D:\dowload chrome\PHOTOS")
MCAT_PATH = Path(r"C:\Users\bdewe\OneDrive\Images\Lightroom\Lightroom Catalog Sync.lrdata\afb0cfb20b2a4bcb9b57d5ec165fc499\Managed Catalog.mcat")
GDRIVE_BASE_FOLDER = "https://drive.google.com/drive/folders/1w_szSK4yKM_j0Trk8lT5Zcpcxae_0_iO"

def get_drive_file_ids():
    fs_base = Path(r"C:\Users\bdewe\AppData\Local\Google\DriveFS\118213793054156610633")
    if not fs_base.exists():
        return {}
    try:
        conn_mirror = sqlite3.connect(f"file:{fs_base / 'mirror_sqlite.db'}?mode=ro", uri=True)
        cur_m = conn_mirror.cursor()
        cur_m.execute("SELECT local_stable_id, stable_id, parent_local_stable_id, local_filename, local_type FROM mirror_item;")
        mirror_rows = cur_m.fetchall()
        conn_mirror.close()

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
        return drive_path_to_id
    except Exception as e:
        print(f"Error reading DriveFS: {e}")
        return {}

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

    nodes = {}
    album_assets = defaultdict(set)
    assets_by_name_size = {}
    assets_by_size = {}
    size_counts = defaultdict(int)
    asset_meta = {}

    for fullDocId_bytes, blob in cur:
        if not blob:
            continue
        try:
            data = msgpack.unpackb(blob, raw=False)
            t = data.get("type")
            doc_id = fullDocId_bytes.decode("utf-8")

            if t in ["album", "space_album"]:
                name = data.get("name") or data.get("payload", {}).get("name")
                parent = data.get("parent", {}).get("id")
                subtype = data.get("subtype")
                if name:
                    nodes[doc_id] = {
                        "id": doc_id,
                        "name": name.strip(),
                        "parent_id": parent,
                        "is_folder": (subtype == "collection_set")
                    }
            elif t == "album_asset":
                alb_id = data.get("album", {}).get("id")
                ass_id = data.get("asset", {}).get("id")
                if alb_id and ass_id:
                    album_assets[alb_id].add(ass_id)
            elif t == "asset":
                import_src = data.get("importSource") or {}
                fname = import_src.get("fileName")
                fsize = import_src.get("fileSize")
                if fname and fsize:
                    assets_by_name_size[(fname.lower(), fsize)] = doc_id
                    size_counts[fsize] += 1
                    assets_by_size[fsize] = doc_id
                    asset_meta[doc_id] = {
                        "fn": fname,
                        "s": fsize,
                        "dt": data.get("captureDate") or "",
                        "w": import_src.get("originalWidth") or 0,
                        "h": import_src.get("originalHeight") or 0
                    }
        except Exception:
            pass

    conn.close()

    unique_size_assets = {sz: aid for sz, aid in assets_by_size.items() if size_counts[sz] == 1}

    # Map children
    children = defaultdict(list)
    for n in nodes.values():
        if n["parent_id"] and n["parent_id"] in nodes:
            children[n["parent_id"]].append(n["id"])

    # Recursive total photo counts
    def calc_photos(nid):
        direct = len(album_assets.get(nid, set()))
        sub = sum(calc_photos(cid) for cid in children[nid])
        nodes[nid]["direct_count"] = direct
        nodes[nid]["total_count"] = direct + sub
        return direct + sub

    roots = [n for n in nodes.values() if not n["parent_id"] or n["parent_id"] not in nodes]
    for r in roots:
        calc_photos(r["id"])

    # Filter out empty nodes (0 total photos)
    active_nodes = {nid: n for nid, n in nodes.items() if n.get("total_count", 0) > 0}
    print(f"Extracted {len(active_nodes)} active albums/thematic folders.")

    # Map each asset to its direct albums AND ancestor folders
    asset_to_all_nodes = defaultdict(set)
    for alb_id, asset_set in album_assets.items():
        if alb_id not in active_nodes:
            continue
        ancestors = [alb_id]
        curr = active_nodes[alb_id].get("parent_id")
        while curr and curr in active_nodes:
            ancestors.append(curr)
            curr = active_nodes[curr].get("parent_id")

        for ass_id in asset_set:
            for anc in ancestors:
                asset_to_all_nodes[ass_id].add(anc)

    return active_nodes, assets_by_name_size, unique_size_assets, asset_meta, asset_to_all_nodes

def clean_lr_filename(name: str) -> str:
    return re.sub(r'__\d{4}-\d{2}-\d{2}T.*_(\.[a-zA-Z0-9]+)$', r'\1', name, flags=re.IGNORECASE)

def run_indexing():
    db = get_connection()
    cur = db.cursor()

    # Recreate tables with is_folder & counts
    cur.executescript("""
    DROP TABLE IF EXISTS photo_albums;
    DROP TABLE IF EXISTS albums;
    DROP TABLE IF EXISTS photos_fts;
    DROP TABLE IF EXISTS photos;

    CREATE TABLE photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT NOT NULL,
        rel_path TEXT NOT NULL UNIQUE,
        year TEXT,
        date_folder TEXT,
        file_size INTEGER,
        width INTEGER,
        height INTEGER,
        capture_date TEXT,
        gdrive_file_id TEXT,
        gdrive_url TEXT,
        has_thumbnail INTEGER DEFAULT 0
    );

    CREATE TABLE albums (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        is_folder INTEGER DEFAULT 0,
        direct_count INTEGER DEFAULT 0,
        total_count INTEGER DEFAULT 0
    );

    CREATE TABLE photo_albums (
        photo_id INTEGER NOT NULL,
        album_id TEXT NOT NULL,
        PRIMARY KEY (photo_id, album_id),
        FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE,
        FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE
    );

    CREATE INDEX idx_photos_year ON photos(year);
    CREATE INDEX idx_photos_date_folder ON photos(date_folder);
    CREATE INDEX idx_photos_capture_date ON photos(capture_date);
    CREATE INDEX idx_photo_albums_album ON photo_albums(album_id);
    CREATE INDEX idx_albums_parent ON albums(parent_id);

    CREATE VIRTUAL TABLE photos_fts USING fts5(
        photo_id UNINDEXED,
        filename,
        year,
        date_folder,
        albums
    );
    """)
    db.commit()

    active_nodes, assets_by_name_size, unique_size_assets, asset_meta, asset_to_all_nodes = parse_mcat(MCAT_PATH)
    drive_map = get_drive_file_ids()

    print("\nInserting thematic folders and albums into database...")
    for nid, n in active_nodes.items():
        cur.execute("""
        INSERT INTO albums (id, name, parent_id, is_folder, direct_count, total_count)
        VALUES (?, ?, ?, ?, ?, ?);
        """, (
            nid,
            n["name"],
            n["parent_id"] if n["parent_id"] in active_nodes else None,
            1 if n["is_folder"] else 0,
            n.get("direct_count", 0),
            n.get("total_count", 0)
        ))
    db.commit()

    print(f"\nScanning photos from {PHOTOS_DIR}...")
    all_files = [f for f in PHOTOS_DIR.rglob("*") if f.is_file() and f.suffix.lower() != '.txt']
    print(f"Found {len(all_files)} files to index.")

    photo_album_links = []
    fts_entries = []

    matched_lr = 0
    matched_drive = 0

    for idx, f in enumerate(all_files, start=1):
        rel_path = str(f.relative_to(PHOTOS_DIR)).replace('\\', '/')
        clean_rel_path = rel_path.lower()
        parts = rel_path.split('/')
        year = parts[0] if len(parts) > 0 else "unknown_date"
        date_folder = parts[1] if len(parts) > 2 else (parts[0] if len(parts) == 2 else "")
        fsize = f.stat().st_size
        fn = f.name

        gid = drive_map.get(clean_rel_path)
        if gid:
            matched_drive += 1

        c_name = clean_lr_filename(fn)
        ass_id = (
            assets_by_name_size.get((fn.lower(), fsize)) or
            assets_by_name_size.get((c_name.lower(), fsize)) or
            unique_size_assets.get(fsize)
        )

        dt = None
        w = None
        h = None
        photo_nodes = set()

        if ass_id and ass_id in asset_meta:
            matched_lr += 1
            dt = asset_meta[ass_id]["dt"]
            w = asset_meta[ass_id]["w"]
            h = asset_meta[ass_id]["h"]
            photo_nodes = asset_to_all_nodes.get(ass_id, set())

        file_gdrive_url = f"https://drive.google.com/file/d/{gid}/view" if gid else GDRIVE_BASE_FOLDER

        cur.execute("""
        INSERT INTO photos (
            filename, rel_path, year, date_folder, file_size,
            width, height, capture_date, gdrive_file_id, gdrive_url
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            fn, rel_path, year, date_folder, fsize,
            w, h, dt, gid, file_gdrive_url
        ))
        photo_id = cur.lastrowid

        album_names = []
        for nid in photo_nodes:
            if nid in active_nodes:
                album_names.append(active_nodes[nid]["name"])
                photo_album_links.append((photo_id, nid))

        fts_entries.append((photo_id, fn, year, date_folder, " ".join(album_names)))

    print("Committing photos...")
    db.commit()

    print(f"Linking {len(photo_album_links)} photo-thematic album links...")
    cur.executemany("INSERT OR IGNORE INTO photo_albums (photo_id, album_id) VALUES (?, ?);", photo_album_links)
    db.commit()

    print("Populating FTS index...")
    cur.executemany("INSERT INTO photos_fts (photo_id, filename, year, date_folder, albums) VALUES (?, ?, ?, ?, ?);", fts_entries)
    db.commit()

    db.close()
    print("\n" + "="*50)
    print("INDEXATION TERMINÉE AVEC SUCCÈS")
    print(f"Photos indexées : {len(all_files)}")
    print(f"Dossiers/Albums thématiques : {len(active_nodes)}")
    print(f"Liaisons Photos <-> Thématiques : {len(photo_album_links)}")
    print(f"Photos liées à Google Drive HD : {matched_drive}")
    print("="*50)

if __name__ == "__main__":
    run_indexing()
