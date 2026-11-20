import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parent))

from fastapi import FastAPI, Query, HTTPException, Response
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import sqlite3
import math
from typing import Optional, List
from database import DB_PATH, get_connection
from thumbnails import make_thumbnail, THUMBNAILS_DIR, PHOTOS_DIR

app = FastAPI(title="Lightroom Gallery & Drive Explorer")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

FRONTEND_DIR = Path(r"d:\LRforIA\frontend")

# 1. API: Navigation Tree (Years & Albums)
@app.get("/api/navigation")
def get_navigation():
    with get_connection() as conn:
        cur = conn.cursor()
        
        # Years
        cur.execute("""
        SELECT year, COUNT(*) as count 
        FROM photos 
        GROUP BY year 
        ORDER BY CASE WHEN year = 'unknown_date' THEN '9999' ELSE year END DESC;
        """)
        years = [{"year": r["year"], "count": r["count"]} for r in cur.fetchall()]

        # Active Albums
        cur.execute("""
        SELECT id, name, parent_id, photo_count 
        FROM albums 
        WHERE photo_count > 0 
        ORDER BY photo_count DESC;
        """)
        albums = [{"id": r["id"], "name": r["name"], "parent_id": r["parent_id"], "count": r["photo_count"]} for r in cur.fetchall()]

        # Stats
        cur.execute("SELECT COUNT(*) FROM photos;")
        total_photos = cur.fetchone()[0]

    return {
        "total_photos": total_photos,
        "years": years,
        "albums": albums,
        "gdrive_folder_url": "https://drive.google.com/drive/folders/1w_szSK4yKM_j0Trk8lT5Zcpcxae_0_iO"
    }

# 2. API: Sub-folders / dates for a specific year
@app.get("/api/dates")
def get_dates_for_year(year: str):
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
        SELECT date_folder, COUNT(*) as count 
        FROM photos 
        WHERE year = ? AND date_folder != ''
        GROUP BY date_folder 
        ORDER BY date_folder DESC;
        """, (year,))
        dates = [{"date_folder": r["date_folder"], "count": r["count"]} for r in cur.fetchall()]
    return {"year": year, "dates": dates}

# 3. API: Photos Grid with Filtering & Search
@app.get("/api/photos")
def list_photos(
    year: Optional[str] = None,
    date_folder: Optional[str] = None,
    album_id: Optional[str] = None,
    q: Optional[str] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(60, ge=1, le=200)
):
    offset = (page - 1) * limit
    params = []
    where_clauses = []

    with get_connection() as conn:
        cur = conn.cursor()

        if q and q.strip():
            # Use Full-Text Search
            clean_q = re_clean_query(q.strip())
            if clean_q:
                where_clauses.append("p.id IN (SELECT photo_id FROM photos_fts WHERE photos_fts MATCH ?)")
                params.append(clean_q)

        if album_id:
            where_clauses.append("p.id IN (SELECT photo_id FROM photo_albums WHERE album_id = ?)")
            params.append(album_id)

        if year:
            where_clauses.append("p.year = ?")
            params.append(year)

        if date_folder:
            where_clauses.append("p.date_folder = ?")
            params.append(date_folder)

        where_sql = ("WHERE " + " AND ".join(where_clauses)) if where_clauses else ""

        # Count total
        cur.execute(f"SELECT COUNT(*) FROM photos p {where_sql}", params)
        total = cur.fetchone()[0]

        # Fetch page
        query = f"""
        SELECT p.id, p.filename, p.rel_path, p.year, p.date_folder, p.file_size,
               p.width, p.height, p.capture_date, p.camera_make, p.camera_model, p.gdrive_url
        FROM photos p
        {where_sql}
        ORDER BY CASE WHEN p.capture_date IS NOT NULL THEN p.capture_date ELSE p.rel_path END DESC
        LIMIT ? OFFSET ?
        """
        cur.execute(query, params + [limit, offset])
        rows = cur.fetchall()

        items = []
        for r in rows:
            items.append({
                "id": r["id"],
                "filename": r["filename"],
                "rel_path": r["rel_path"],
                "year": r["year"],
                "date_folder": r["date_folder"],
                "file_size": r["file_size"],
                "width": r["width"],
                "height": r["height"],
                "capture_date": r["capture_date"],
                "camera": f"{r['camera_make'] or ''} {r['camera_model'] or ''}".strip(),
                "thumbnail_url": f"/api/thumbnail/{r['id']}",
                "gdrive_url": r["gdrive_url"]
            })

    return {
        "items": items,
        "total": total,
        "page": page,
        "limit": limit,
        "pages": math.ceil(total / limit) if total > 0 else 1
    }

def re_clean_query(q: str) -> str:
    words = [w for w in q.split() if w.isalnum()]
    if not words:
        return ""
    return " ".join(f"{w}*" for w in words)

# 4. API: Smart Preview Thumbnail (Instant or On-demand)
@app.get("/api/thumbnail/{photo_id}")
def get_thumbnail(photo_id: int):
    thumb_path = THUMBNAILS_DIR / f"{photo_id}.webp"
    if thumb_path.exists() and thumb_path.stat().st_size > 0:
        return FileResponse(
            thumb_path, 
            media_type="image/webp",
            headers={"Cache-Control": "public, max-age=31536000, immutable"}
        )

    # Generate on the fly
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT rel_path FROM photos WHERE id = ?", (photo_id,))
        row = cur.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Photo not found")

    rel_path = row["rel_path"]
    ok = make_thumbnail(photo_id, rel_path)
    if ok and thumb_path.exists():
        return FileResponse(
            thumb_path, 
            media_type="image/webp",
            headers={"Cache-Control": "public, max-age=31536000, immutable"}
        )

    # Return placeholder if video or generation failed
    placeholder = FRONTEND_DIR / "placeholder.svg"
    if placeholder.exists():
        return FileResponse(placeholder, media_type="image/svg+xml")
    return Response(status_code=404)

# 5. API: Single Photo Details with its Albums
@app.get("/api/photos/{photo_id}")
def get_photo_detail(photo_id: int):
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM photos WHERE id = ?", (photo_id,))
        p = cur.fetchone()
        if not p:
            raise HTTPException(status_code=404, detail="Photo not found")

        # Get albums
        cur.execute("""
        SELECT a.id, a.name 
        FROM albums a 
        JOIN photo_albums pa ON a.id = pa.album_id 
        WHERE pa.photo_id = ?
        """, (photo_id,))
        albums = [{"id": r["id"], "name": r["name"]} for r in cur.fetchall()]

    return {
        "id": p["id"],
        "filename": p["filename"],
        "rel_path": p["rel_path"],
        "year": p["year"],
        "date_folder": p["date_folder"],
        "file_size": p["file_size"],
        "width": p["width"],
        "height": p["height"],
        "capture_date": p["capture_date"],
        "camera_make": p["camera_make"],
        "camera_model": p["camera_model"],
        "albums": albums,
        "thumbnail_url": f"/api/thumbnail/{p['id']}",
        "gdrive_url": p["gdrive_url"]
    }

# Mount static frontend
app.mount("/static", StaticFiles(directory=str(FRONTEND_DIR)), name="static")

@app.get("/")
def serve_index():
    index_file = FRONTEND_DIR / "index.html"
    return FileResponse(index_file)
