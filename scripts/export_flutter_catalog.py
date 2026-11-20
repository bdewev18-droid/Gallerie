import sqlite3
import msgpack
import re
import json
from pathlib import Path
from collections import defaultdict

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
    album_assets = defaultdict(set) # album_id -> set of asset_ids
    assets_by_name_size = {} # (fname.lower(), fsize) -> asset_id
    assets_by_size = {} # fsize -> asset_id
    size_counts = defaultdict(int)
    asset_meta = {} # asset_id -> dict

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

    # Filter out empty nodes (0 photos anywhere in subtree)
    active_nodes = {nid: n for nid, n in nodes.items() if n.get("total_count", 0) > 0}
    print(f"Active nodes with photos in tree: {len(active_nodes)} (out of {len(nodes)})")

    # Map asset_id to all album_ids (including parent folders)
    # So searching or clicking a parent folder can find its photos!
    asset_to_all_albums = defaultdict(set)
    for alb_id, asset_set in album_assets.items():
        if alb_id not in active_nodes:
            continue
        # Find all ancestor folders
        ancestors = [alb_id]
        curr = active_nodes[alb_id].get("parent_id")
        while curr and curr in active_nodes:
            ancestors.append(curr)
            curr = active_nodes[curr].get("parent_id")

        for ass_id in asset_set:
            for anc in ancestors:
                asset_to_all_albums[ass_id].add(anc)

    # Scan PHOTOS directory
    photos_dir = Path(r"D:\dowload chrome\PHOTOS")
    all_files = [f for f in photos_dir.rglob("*") if f.is_file() and f.suffix.lower() != '.txt']
    print(f"Scanning {len(all_files)} files from {photos_dir}...")

    photos = []
    years_count = defaultdict(int)

    def clean_name(name):
        return re.sub(r'__\d{4}-\d{2}-\d{2}T.*_(\.[a-zA-Z0-9]+)$', r'\1', name, flags=re.IGNORECASE)

    for idx, f in enumerate(all_files, start=1):
        rel_path = str(f.relative_to(photos_dir)).replace('\\', '/')
        parts = rel_path.split('/')
        year = parts[0] if len(parts) > 0 else "unknown_date"
        date_folder = parts[1] if len(parts) > 2 else (parts[0] if len(parts) == 2 else "")
        fsize = f.stat().st_size
        fn = f.name
        years_count[year] += 1

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
            dt = asset_meta[ass_id]["dt"]
            w = asset_meta[ass_id]["w"]
            h = asset_meta[ass_id]["h"]
            albums_for_photo = list(asset_to_all_albums.get(ass_id, []))

        photos.append({
            "id": idx,
            "fn": fn,
            "y": year,
            "d": date_folder,
            "dt": dt,
            "w": w,
            "h": h,
            "s": fsize,
            "al": albums_for_photo
        })

    years = [{"year": y, "count": cnt} for y, cnt in sorted(years_count.items(), key=lambda x: (x[0] == 'unknown_date', x[0]), reverse=True)]

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
    ]

    catalog = {
        "albums": albums_list,
        "years": years,
        "photos": photos,
        "gdrive_url": "https://drive.google.com/drive/folders/1w_szSK4yKM_j0Trk8lT5Zcpcxae_0_iO"
    }

    out_dir = Path("assets/data")
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "catalog.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, separators=(',', ':'))

    print(f"Hierarchical Catalog exported: {len(photos)} photos, {len(albums_list)} albums/folders.")
    print(f"Catalog size: {json_path.stat().st_size / (1024**2):.2f} MB")

if __name__ == "__main__":
    export_hierarchical_catalog()
