import sqlite3
import msgpack
from pathlib import Path
from collections import defaultdict

print("=== CHECKING MANAGED CATALOG.MCAT HIERARCHY ===")
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

nodes = {} # id -> {'name': str, 'parent_id': str, 'subtype': str, 'type': str}
album_assets = defaultdict(list)

for fullDocId_bytes, blob in cur:
    if not blob:
        continue
    try:
        data = msgpack.unpackb(blob, raw=False)
        t = data.get("type")
        doc_id = fullDocId_bytes.decode("utf-8")
        
        if t in ["album", "space_album", "space"]:
            name = data.get("name") or data.get("payload", {}).get("name")
            parent = data.get("parent", {}).get("id")
            subtype = data.get("subtype") # 'collection_set' vs 'collection'
            if name:
                nodes[doc_id] = {
                    "id": doc_id,
                    "name": name.strip(),
                    "parent_id": parent,
                    "subtype": subtype,
                    "type": t
                }
        elif t == "album_asset":
            alb_id = data.get("album", {}).get("id")
            ass_id = data.get("asset", {}).get("id")
            if alb_id and ass_id:
                album_assets[alb_id].append(ass_id)
    except Exception:
        pass

conn.close()

print(f"Total album/folder nodes found in MCAT: {len(nodes)}")

# Let's count photos in each node
for nid, node in nodes.items():
    node["photos"] = len(album_assets.get(nid, []))

# Find root nodes (parent_id is None or not in nodes)
roots = [n for n in nodes.values() if not n["parent_id"] or n["parent_id"] not in nodes]
print(f"Root nodes found: {len(roots)}")

# Function to print tree
children_map = defaultdict(list)
for n in nodes.values():
    if n["parent_id"] and n["parent_id"] in nodes:
        children_map[n["parent_id"]].append(n)

def print_tree(node, depth=0):
    indent = "  " * depth
    subtype_tag = f"[{node['subtype']}]" if node.get('subtype') else ""
    photos_tag = f"({node['photos']} photos)" if node['photos'] > 0 else "(dossier)"
    print(f"{indent}- {node['name']} {subtype_tag} {photos_tag}")
    for child in sorted(children_map.get(node["id"], []), key=lambda x: x["name"]):
        print_tree(child, depth + 1)

print("\n--- SAMPLE TREE STRUCTURE (First 15 roots) ---")
for r in sorted(roots, key=lambda x: x["name"])[:15]:
    print_tree(r, 0)
