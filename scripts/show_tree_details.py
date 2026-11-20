import sqlite3, msgpack
from pathlib import Path
from collections import defaultdict

mcat_path = Path(r"C:\Users\bdewe\OneDrive\Images\Lightroom\Lightroom Catalog Sync.lrdata\afb0cfb20b2a4bcb9b57d5ec165fc499\Managed Catalog.mcat")
conn = sqlite3.connect(f"file:{mcat_path}?mode=ro", uri=True)
conn.text_factory = bytes
cur = conn.cursor()

cur.execute("SELECT d.fullDocId, r.content FROM revs r JOIN docs d ON r.localDocId = d.localDocId WHERE r.current=1 AND r.deleted=0;")
nodes = {}
for fullDocId_bytes, blob in cur:
    if not blob: continue
    try:
        data = msgpack.unpackb(blob, raw=False)
        if data.get("type") in ["album", "space_album"]:
            name = data.get("name") or data.get("payload", {}).get("name")
            if name:
                nodes[fullDocId_bytes.decode("utf-8")] = {
                    "id": fullDocId_bytes.decode("utf-8"),
                    "name": name.strip(),
                    "parent_id": data.get("parent", {}).get("id"),
                    "is_folder": (data.get("subtype") == "collection_set")
                }
    except Exception: pass
conn.close()

children = defaultdict(list)
for n in nodes.values():
    if n["parent_id"] and n["parent_id"] in nodes:
        children[n["parent_id"]].append(n["id"])

for n in nodes.values():
    if any(k in n["name"] for k in ["Meilleures", "Pays"]):
        print(f"\n{n['name']} (is_folder={n['is_folder']}):")
        for cid in children[n["id"]]:
            c = nodes[cid]
            print(f"  -> {c['name']} (folder={c['is_folder']})")
