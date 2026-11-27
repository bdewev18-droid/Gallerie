import sqlite3
import msgpack
from pathlib import Path
from collections import defaultdict
from bisect import bisect_left
from datetime import datetime
import re


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
        return (round(lat_f, 6), round(lon_f, 6))
    return None


def propagate_gps_by_time(conn: sqlite3.Connection, window_hours: float = 2.0) -> int:
    """Propagate GPS coordinates from geotagged photos (e.g. smartphones) to
    camera photos without GPS taken within +/- window_hours."""
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT id, capture_date, latitude, longitude FROM photos WHERE capture_date IS NOT NULL AND capture_date != '';"
    ).fetchall()

    geotagged = []
    missing = []
    for pid, dt_str, lat, lon in rows:
        ts = _parse_iso_ts(dt_str)
        if ts is None:
            continue
        if lat is not None and lon is not None:
            geotagged.append((ts, float(lat), float(lon)))
        else:
            missing.append((pid, ts))

    if not geotagged or not missing:
        return 0

    geotagged.sort(key=lambda item: item[0])
    geo_times = [item[0] for item in geotagged]
    max_delta = window_hours * 3600.0
    updates = []

    for pid, ts in missing:
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
            updates.append((best[1], best[2], "propagated", pid))

    if updates:
        cur.executemany(
            "UPDATE photos SET latitude = ?, longitude = ?, gps_source = ? WHERE id = ? AND latitude IS NULL;",
            updates,
        )
        conn.commit()
    return len(updates)

def enrich_photos():
    db_path = Path(r"d:\LRforIA\data\photos.db")
    mcat_path = Path(r"C:\Users\bdewe\OneDrive\Images\Lightroom\Lightroom Catalog Sync.lrdata\afb0cfb20b2a4bcb9b57d5ec165fc499\Managed Catalog.mcat")

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    existing_cols = [c[1] for c in cur.execute("PRAGMA table_info(photos)").fetchall()]
    needed_cols = {
        "camera_make": "TEXT",
        "camera_model": "TEXT",
        "iso": "INTEGER",
        "focal_length": "REAL",
        "aperture": "REAL",
        "exposure_time": "TEXT",
        "country": "TEXT",
        "city": "TEXT",
        "state_prov": "TEXT",
        "score": "INTEGER",
        "deleted_at": "TEXT",
        "latitude": "REAL",
        "longitude": "REAL",
        "gps_source": "TEXT",
    }
    for col, col_type in needed_cols.items():
        if col not in existing_cols:
            cur.execute(f"ALTER TABLE photos ADD COLUMN {col} {col_type};")
            print(f"Added column {col} ({col_type})")
    conn.commit()

    # Read all photos from DB
    cur.execute("SELECT id, filename, file_size, rel_path FROM photos;")
    rows = cur.fetchall()
    photos_by_name_size = {}
    photos_by_size = defaultdict(list)
    for pid, fn, fsize, rel in rows:
        photos_by_name_size[(fn.lower(), fsize)] = pid
        photos_by_size[fsize].append(pid)

    print(f"Loaded {len(rows)} photos from photos.db")

    # Read mcat
    print(f"Reading Lightroom catalog: {mcat_path}")
    mcat_conn = sqlite3.connect(f"file:{mcat_path}?mode=ro", uri=True)
    mcat_conn.text_factory = bytes
    mcat_cur = mcat_conn.cursor()

    mcat_cur.execute("""
    SELECT r.content 
    FROM revs r 
    JOIN docs d ON r.sequence = d.winningRevSequence 
    WHERE d.type = 'asset' AND d.deleted = 0;
    """)

    updates = []
    matched = 0

    def parse_ratio(val):
        if isinstance(val, (int, float)):
            return float(val)
        if isinstance(val, (list, tuple)) and len(val) == 2 and val[1] != 0:
            return round(val[0] / val[1], 2)
        return None

    def clean_name(name):
        return re.sub(r'__\d{4}-\d{2}-\d{2}T.*_(\.[a-zA-Z0-9]+)$', r'\1', name, flags=re.IGNORECASE)

    for (blob,) in mcat_cur:
        if not blob:
            continue
        try:
            data = msgpack.unpackb(blob, raw=False)
            import_src = data.get("importSource") or {}
            fn = import_src.get("fileName")
            fsize = import_src.get("fileSize")
            if not fn or not fsize:
                continue

            pid = photos_by_name_size.get((fn.lower(), fsize))
            if not pid:
                c_name = clean_name(fn)
                pid = photos_by_name_size.get((c_name.lower(), fsize))
            if not pid and len(photos_by_size.get(fsize, [])) == 1:
                pid = photos_by_size[fsize][0]

            if not pid:
                continue

            matched += 1

            xmp = data.get("xmp", {})
            tiff = xmp.get("tiff", {})
            exif = xmp.get("exif", {})
            loc = data.get("location", {})
            aesthetics = data.get("aesthetics", {})

            make = tiff.get("Make")
            model = tiff.get("Model")
            
            focal = parse_ratio(exif.get("FocalLength"))
            if not focal:
                focal = exif.get("FocalLengthIn35mmFilm")
            
            aperture = parse_ratio(exif.get("FNumber")) or parse_ratio(exif.get("ApertureValue"))
            iso = exif.get("ISOSpeedRatings")
            if isinstance(iso, list) and iso:
                iso = iso[0]
            
            exp_time = exif.get("ExposureTime")
            if isinstance(exp_time, (list, tuple)) and len(exp_time) == 2 and exp_time[0] != 0:
                if exp_time[0] == 1:
                    exp_str = f"1/{exp_time[1]}"
                else:
                    exp_str = f"{exp_time[0]}/{exp_time[1]}"
            else:
                exp_str = str(exp_time) if exp_time else None

            country = loc.get("country")
            city = loc.get("city")
            state_prov = loc.get("state")
            score = aesthetics.get("score")
            coords = _valid_coords(loc.get("latitude"), loc.get("longitude"))
            lat = coords[0] if coords else None
            lon = coords[1] if coords else None
            gps_src = "exif" if coords else None

            updates.append((
                make, model, iso, focal, aperture, exp_str,
                country, city, state_prov, score,
                lat, lon, gps_src,
                pid
            ))

        except Exception:
            pass

    mcat_conn.close()
    print(f"Matched {matched} photos with rich Lightroom metadata")

    print("Updating database in batch...")
    cur.executemany("""
    UPDATE photos SET 
        camera_make = COALESCE(?, camera_make),
        camera_model = COALESCE(?, camera_model),
        iso = COALESCE(?, iso),
        focal_length = COALESCE(?, focal_length),
        aperture = COALESCE(?, aperture),
        exposure_time = COALESCE(?, exposure_time),
        country = COALESCE(?, country),
        city = COALESCE(?, city),
        state_prov = COALESCE(?, state_prov),
        score = COALESCE(?, score),
        latitude = COALESCE(?, latitude),
        longitude = COALESCE(?, longitude),
        gps_source = COALESCE(?, gps_source)
    WHERE id = ?;
    """, updates)
    conn.commit()

    propagated_count = propagate_gps_by_time(conn, window_hours=2.0)
    print(f"Propagated GPS (+/- 2h) to {propagated_count} camera photos")

    print("Creating indexes on metadata columns...")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_photos_gdrive ON photos(gdrive_file_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_photos_country ON photos(country);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_photos_city ON photos(city);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_photos_camera ON photos(camera_model);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_photos_deleted ON photos(deleted_at);")
    conn.commit()

    cur.execute("SELECT count(*) FROM photos WHERE country IS NOT NULL;")
    print("Photos with Country:", cur.fetchone()[0])
    cur.execute("SELECT count(*) FROM photos WHERE camera_model IS NOT NULL;")
    print("Photos with Camera Model:", cur.fetchone()[0])
    cur.execute("SELECT count(*) FROM photos WHERE gdrive_file_id IS NOT NULL;")
    print("Photos with Google Drive ID:", cur.fetchone()[0])

    cur.execute("SELECT country, count(*) FROM photos WHERE country IS NOT NULL GROUP BY country ORDER BY count(*) DESC LIMIT 5;")
    print("Top Countries:", cur.fetchall())

    cur.execute("SELECT camera_model, count(*) FROM photos WHERE camera_model IS NOT NULL GROUP BY camera_model ORDER BY count(*) DESC LIMIT 5;")
    print("Top Cameras:", cur.fetchall())

    conn.close()
    print("Enrichment completed successfully!")

if __name__ == "__main__":
    enrich_photos()
