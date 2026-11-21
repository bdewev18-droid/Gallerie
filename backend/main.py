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

app = FastAPI(title="Medias Familly")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

FRONTEND_DIR = Path(r"d:\LRforIA\frontend")
GDRIVE_DEFAULT_URL = "https://drive.google.com/drive/folders/1w_szSK4yKM_j0Trk8lT5Zcpcxae_0_iO"

# 1. API: Thematic Tree (Folders and Albums)
@app.get("/api/thematics")
def get_thematics(media_type: Optional[str] = "photo"):
    with get_connection() as conn:
        cur = conn.cursor()
        
        # When media_type is photo, completely exclude Videos from the thematics tree
        if media_type == "photo":
            cur.execute("""
            SELECT id, name, parent_id, is_folder, direct_count, total_count 
            FROM albums 
            WHERE lower(name) != 'videos' 
              AND id != 'bb3d36f6161042d4a2ba6a500c4fe504'
              AND (parent_id IS NULL OR parent_id != 'bb3d36f6161042d4a2ba6a500c4fe504')
            ORDER BY is_folder DESC, name ASC;
            """)
        else:
            cur.execute("""
            SELECT id, name, parent_id, is_folder, direct_count, total_count 
            FROM albums 
            ORDER BY is_folder DESC, name ASC;
            """)
        nodes = [dict(r) for r in cur.fetchall()]
        
        cur.execute("SELECT COUNT(*) FROM photos WHERE media_type = 'photo';")
        total_photos = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM photos WHERE media_type = 'video';")
        total_videos = cur.fetchone()[0]

    return {
        "title": "Medias Familly",
        "total_photos": total_photos,
        "total_videos": total_videos,
        "nodes": nodes,
        "gdrive_url": GDRIVE_DEFAULT_URL
    }

# 2. API: Years and sub-dates
@app.get("/api/years")
def get_years(media_type: Optional[str] = "photo"):
    where = "WHERE media_type = ?" if media_type and media_type != "all" else ""
    params = [media_type] if media_type and media_type != "all" else []
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute(f"""
        SELECT year, COUNT(*) as count 
        FROM photos 
        {where}
        GROUP BY year 
        ORDER BY CASE WHEN year = 'unknown_date' THEN '9999' ELSE year END DESC;
        """, params)
        years = [{"year": r["year"], "count": r["count"]} for r in cur.fetchall()]
    return {"years": years}

@app.get("/api/video_years")
def get_video_years():
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
        SELECT year, COUNT(*) as count 
        FROM photos 
        WHERE media_type = 'video'
        GROUP BY year 
        ORDER BY CASE WHEN year = 'unknown_date' THEN '9999' ELSE year END DESC;
        """)
        years = [{"year": r["year"], "count": r["count"]} for r in cur.fetchall()]
        cur.execute("SELECT COUNT(*) FROM photos WHERE media_type = 'video';")
        total = cur.fetchone()[0]
    return {"total": total, "years": years}

@app.get("/api/dates")
def get_dates_for_year(year: str, media_type: Optional[str] = "photo"):
    where_extra = "AND media_type = ?" if media_type and media_type != "all" else ""
    params = [year, media_type] if where_extra else [year]
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute(f"""
        SELECT date_folder, COUNT(*) as count 
        FROM photos 
        WHERE year = ? AND date_folder != '' {where_extra}
        GROUP BY date_folder 
        ORDER BY date_folder DESC;
        """, params)
        dates = [{"date_folder": r["date_folder"], "count": r["count"]} for r in cur.fetchall()]
    return {"year": year, "dates": dates}

# 3. API: Photos Grid with Filtering & Search
@app.get("/api/photos")
def list_photos(
    media_type: Optional[str] = Query("photo"),
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

        if media_type and media_type != "all":
            where_clauses.append("p.media_type = ?")
            params.append(media_type)

        if q and q.strip():
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
               p.width, p.height, p.capture_date, p.gdrive_file_id, p.gdrive_url, p.media_type
        FROM photos p
        {where_sql}
        ORDER BY CASE WHEN p.capture_date IS NOT NULL THEN p.capture_date ELSE p.rel_path END DESC
        LIMIT ? OFFSET ?
        """
        cur.execute(query, params + [limit, offset])
        rows = cur.fetchall()

        items = []
        for r in rows:
            drive_id = r["gdrive_file_id"]
            direct_view_url = f"https://drive.google.com/file/d/{drive_id}/view" if drive_id else GDRIVE_DEFAULT_URL
            drive_thumb = f"https://drive.google.com/thumbnail?id={drive_id}&sz=w400" if drive_id else None

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
                "drive_id": drive_id,
                "media_type": r["media_type"],
                "media_url": f"/api/media/{r['id']}",
                "thumbnail_url": f"/api/thumbnail/{r['id']}",
                "drive_thumbnail_url": drive_thumb,
                "gdrive_url": direct_view_url
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

# 4. API: Thumbnail (Local WebP Smart Preview)
@app.get("/api/thumbnail/{photo_id}")
def get_thumbnail(photo_id: int):
    thumb_path = THUMBNAILS_DIR / f"{photo_id}.webp"
    if thumb_path.exists() and thumb_path.stat().st_size > 0:
        return FileResponse(
            thumb_path, 
            media_type="image/webp",
            headers={"Cache-Control": "public, max-age=31536000, immutable"}
        )

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

    placeholder = FRONTEND_DIR / "placeholder.svg"
    if placeholder.exists():
        return FileResponse(placeholder, media_type="image/svg+xml")
    return Response(status_code=404)

# 4b. API: Direct Media Stream (Local Video/Photo full file)
@app.get("/api/media/{photo_id}")
def get_media_file(photo_id: int):
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT rel_path, media_type FROM photos WHERE id = ?", (photo_id,))
        row = cur.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Media not found")

    file_path = PHOTOS_DIR / row["rel_path"]
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File on disk not found")

    ext = file_path.suffix.lower()
    media_types = {
        ".mp4": "video/mp4",
        ".mov": "video/quicktime",
        ".avi": "video/x-msvideo",
        ".m4v": "video/mp4",
        ".mkv": "video/x-matroska",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png"
    }
    content_type = media_types.get(ext, "application/octet-stream")
    return FileResponse(file_path, media_type=content_type)

# 5. API: Single Photo Details
@app.get("/api/photos/{photo_id}")
def get_photo_detail(photo_id: int):
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT * FROM photos WHERE id = ?", (photo_id,))
        p = cur.fetchone()
        if not p:
            raise HTTPException(status_code=404, detail="Photo not found")

        cur.execute("""
        SELECT a.id, a.name, a.is_folder 
        FROM albums a 
        JOIN photo_albums pa ON a.id = pa.album_id 
        WHERE pa.photo_id = ?
        ORDER BY a.is_folder DESC, a.name ASC;
        """, (photo_id,))
        albums = [{"id": r["id"], "name": r["name"], "is_folder": bool(r["is_folder"])} for r in cur.fetchall()]

    drive_id = p["gdrive_file_id"]
    direct_view_url = f"https://drive.google.com/file/d/{drive_id}/view" if drive_id else GDRIVE_DEFAULT_URL
    drive_thumb_large = f"https://drive.google.com/thumbnail?id={drive_id}&sz=w1200" if drive_id else None

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
        "drive_id": drive_id,
        "albums": albums,
        "thumbnail_url": f"/api/thumbnail/{p['id']}",
        "large_preview_url": drive_thumb_large,
        "gdrive_url": direct_view_url
    }

app.mount("/static", StaticFiles(directory=str(FRONTEND_DIR)), name="static")

@app.get("/")
def serve_index():
    index_file = FRONTEND_DIR / "index.html"
    return FileResponse(index_file)
