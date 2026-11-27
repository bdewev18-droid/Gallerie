import sqlite3
import msgpack
import re
import json
from bisect import bisect_left
from datetime import datetime
from pathlib import Path
from collections import defaultdict


def _parse_iso_ts(raw: str):
    if not raw or not isinstance(raw, str):
        return None
    s = raw.strip()
    if not s:
        return None
    try:
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        return datetime.fromisoformat(s).replace(tzinfo=None).timestamp()
    except Exception:
        return None


def _valid_coords(lat, lon):
    if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
        return None
    lat_f = float(lat)
    lon_f = float(lon)
    if lat_f == 0.0 and lon_f == 0.0:
        return None
    if -90.0 <= lat_f <= 90.0 and -180.0 <= lon_f <= 180.0:
        return (round(lat_f, 5), round(lon_f, 5))
    return None


def _propagate_gps_on_catalog(photos: list, window_hours: float = 2.0) -> int:
    geotagged = []
    missing = []
    for p in photos:
        ts = _parse_iso_ts(p.get("dt", ""))
        if ts is None:
            continue
        if "lat" in p and "lon" in p:
            geotagged.append((ts, p["lat"], p["lon"]))
        else:
            missing.append((p, ts))
    if not geotagged or not missing:
        return 0
    geotagged.sort(key=lambda item: item[0])
    geo_times = [item[0] for item in geotagged]
    max_delta = window_hours * 3600.0
    count = 0
    for p, ts in missing:
        idx = bisect_left(geo_times, ts)
        best = None
        best_diff = max_delta + 1.0
        for cand_idx in (idx - 1, idx):
            if 0 <= cand_idx < len(geotagged):
                diff = abs(geotagged[cand_idx][0] - ts)
                if diff <= max_delta and diff < best_diff:
                    best_diff = diff
                    best = geotagged[cand_idx]
        if best is not None:
            p["lat"] = best[1]
            p["lon"] = best[2]
            count += 1
    return count

def get_drive_file_ids():
    fs_base = Path(r"C:\Users\bdewe\AppData\Local\Google\DriveFS\118213793054156610633")
    if not fs_base.exists():
        print("DriveFS folder not found, skipping drive mapping.")
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

        print(f"Loaded {len(drive_path_to_id)} Drive file IDs from DriveFS.")
        return drive_path_to_id
    except Exception as e:
        print(f"Error reading DriveFS: {e}")
        return {}

def export_hierarchical_catalog():
    mcat_path = Path(r"C:\Users\bdewe\OneDrive\Images\Lightroom\Lightroom Catalog Sync.lrdata\afb0cfb20b2a4bcb9b57d5ec165fc499\Managed Catalog.mcat")
    print(f"Reading Lightroom catalog: {mcat_path}")
    
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
                        "is_folder": (subtype == "collection_set"),
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
                    loc = data.get("location") or {}
                    coords = _valid_coords(loc.get("latitude"), loc.get("longitude"))
                    asset_meta[doc_id] = {
                        "fn": fname,
                        "s": fsize,
                        "dt": data.get("captureDate") or "",
                        "w": import_src.get("originalWidth") or 0,
                        "h": import_src.get("originalHeight") or 0,
                        "co": loc.get("country"),
                        "ci": loc.get("city"),
                        "lat": coords[0] if coords else None,
                        "lon": coords[1] if coords else None,
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

    # Calculate direct and total recursive photo counts
    def calc_photos(nid):
        direct = len(album_assets.get(nid, set()))
        sub = sum(calc_photos(cid) for cid in children[nid])
        nodes[nid]["direct_count"] = direct
        nodes[nid]["total_count"] = direct + sub
        return direct + sub

    roots = [n for n in nodes.values() if not n["parent_id"] or n["parent_id"] not in nodes]
    for r in roots:
        calc_photos(r["id"])

    active_nodes = {nid: n for nid, n in nodes.items() if n.get("total_count", 0) > 0}
    print(f"Active nodes with photos in tree: {len(active_nodes)}")

    asset_to_all_albums = defaultdict(set)
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
                asset_to_all_albums[ass_id].add(anc)

    # Load Drive file IDs
    drive_map = get_drive_file_ids()

    # Scan PHOTOS directory
    photos_dir = Path(r"D:\dowload chrome\PHOTOS")
    all_files = [f for f in photos_dir.rglob("*") if f.is_file() and f.suffix.lower() != '.txt']
    print(f"Scanning {len(all_files)} files from {photos_dir}...")

    photos = []
    years_count = defaultdict(int)

    def clean_name(name):
        return re.sub(r'__\d{4}-\d{2}-\d{2}T.*_(\.[a-zA-Z0-9]+)$', r'\1', name, flags=re.IGNORECASE)

    matched_drive = 0
    for idx, f in enumerate(all_files, start=1):
        rel_path = str(f.relative_to(photos_dir)).replace('\\', '/')
        clean_rel_path = rel_path.lower()
        parts = rel_path.split('/')
        year = parts[0] if len(parts) > 0 else "unknown_date"
        date_folder = parts[1] if len(parts) > 2 else (parts[0] if len(parts) == 2 else "")
        fsize = f.stat().st_size
        fn = f.name
        years_count[year] += 1

        # Match Drive File ID
        gid = drive_map.get(clean_rel_path)
        if gid:
            matched_drive += 1

        # Match asset
        c_name = clean_name(fn)
        ass_id = (
            assets_by_name_size.get((fn.lower(), fsize)) or
            assets_by_name_size.get((c_name.lower(), fsize)) or
            unique_size_assets.get(fsize)
        )

        dt = ""
        w = 0
        h = 0
        albums_for_photo = []

        if ass_id and ass_id in asset_meta:
            meta = asset_meta[ass_id]
            dt = meta["dt"]
            w = meta["w"]
            h = meta["h"]
            albums_for_photo = list(asset_to_all_albums.get(ass_id, []))

        ext = Path(fn).suffix.lower()
        is_video = ext in ['.mp4', '.mov', '.avi', '.m4v', '.mkv', '.3gp']

        photo_dict = {
            "id": idx,
            "fn": fn,
            "y": year,
            "d": date_folder,
            "dt": dt,
            "w": w,
            "h": h,
            "s": fsize,
            "m": "v" if is_video else "p",
            "al": albums_for_photo
        }
        if gid:
            photo_dict["gid"] = gid
        if ass_id and ass_id in asset_meta:
            meta = asset_meta[ass_id]
            if meta.get("co"):
                photo_dict["co"] = meta["co"]
            if meta.get("ci"):
                photo_dict["ci"] = meta["ci"]
            if meta.get("lat") is not None and meta.get("lon") is not None:
                photo_dict["lat"] = meta["lat"]
                photo_dict["lon"] = meta["lon"]

        photos.append(photo_dict)

    propagated = _propagate_gps_on_catalog(photos, window_hours=2.0)
    print(f"Photos linked with exact Google Drive File ID: {matched_drive} ({matched_drive/len(photos)*100:.1f}%)")
    print(f"Propagated GPS (+/- 2h) to {propagated} camera photos")

    video_years_count = defaultdict(int)
    photo_years_count = defaultdict(int)
    for p in photos:
        y = p["y"]
        if p.get("m") == "v":
            video_years_count[y] += 1
        else:
            photo_years_count[y] += 1

    years = [{"year": y, "count": cnt} for y, cnt in sorted(photo_years_count.items(), key=lambda x: (x[0] == 'unknown_date', x[0]), reverse=True)]
    video_years = [{"year": y, "count": cnt} for y, cnt in sorted(video_years_count.items(), key=lambda x: (x[0] == 'unknown_date', x[0]), reverse=True)]

    # Exclude Videos from photo albums
    albums_list = [
        {
            "id": n["id"],
            "name": n["name"],
            "parent_id": n["parent_id"] if n["parent_id"] in active_nodes else None,
            "is_folder": n["is_folder"],
            "direct_count": n.get("direct_count", 0),
            "count": n.get("total_count", 0)
        }
        for n in active_nodes.values()
        if n["id"] != "bb3d36f6161042d4a2ba6a500c4fe504" and n["name"].lower() != "videos"
    ]

    catalog = {
        "albums": albums_list,
        "years": years,
        "video_years": video_years,
        "photos": photos,
        "gdrive_url": "https://drive.google.com/drive/folders/1w_szSK4yKM_j0Trk8lT5Zcpcxae_0_iO"
    }

    out_dir = Path("assets/data")
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "catalog.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, separators=(',', ':'))

    print(f"Catalog saved: {json_path.stat().st_size / (1024**2):.2f} MB")

if __name__ == "__main__":
    export_hierarchical_catalog()
