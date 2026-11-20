import sqlite3
import msgpack
from pathlib import Path
from collections import defaultdict
import json

mcat_path = Path(r"C:\Users\bdewe\OneDrive\Images\Lightroom\Lightroom Catalog Sync.lrdata\afb0cfb20b2a4bcb9b57d5ec165fc499\Managed Catalog.mcat")
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
            subtype = data.get("subtype") # 'collection_set' (dossier) or 'collection' (album)
            if name:
                nodes[doc_id] = {
                    "id": doc_id,
                    "name": name.strip(),
                    "parent_id": parent,
                    "is_folder": (subtype == "collection_set"),
                    "subtype": subtype
                }
        elif t == "album_asset":
            alb_id = data.get("album", {}).get("id")
            ass_id = data.get("asset", {}).get("id")
            if alb_id and ass_id:
                album_assets[alb_id].add(ass_id)
    except Exception:
        pass

conn.close()

# Propagate photo counts up the tree
children = defaultdict(list)
for n in nodes.values():
    if n["parent_id"] and n["parent_id"] in nodes:
        children[n["parent_id"]].append(n["id"])

def get_total_photos(node_id):
    direct = len(album_assets.get(node_id, set()))
    sub = sum(get_total_photos(cid) for cid in children[node_id])
    return direct + sub

for nid, n in nodes.items():
    n["direct_photos"] = len(album_assets.get(nid, set()))
    n["total_photos"] = get_total_photos(nid)

# Print root nodes and counts
roots = [n for n in nodes.values() if not n["parent_id"] or n["parent_id"] not in nodes]
print(f"Total nodes: {len(nodes)}")
print("Roots:")
for r in roots:
    print(f"  Root: {r['name']} (is_folder={r['is_folder']}, total={r['total_photos']})")
    for cid in children[r["id"]]:
        c = nodes[cid]
        print(f"    -> {c['name']} (is_folder={c['is_folder']}, total={c['total_photos']})")
