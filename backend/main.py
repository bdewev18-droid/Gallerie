import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parent))

from fastapi import FastAPI, Query, HTTPException, Response
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime, timedelta
import sqlite3
import math
import uuid
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

# Pydantic Models for Actions
class BatchTrashRequest(BaseModel):
    photo_ids: List[int]

class BatchMoveRequest(BaseModel):
    photo_ids: List[int]
    target_album_id: str
    remove_from_current: bool = False
    current_album_id: Optional[str] = None

class AlbumCreateRequest(BaseModel):
    name: str
    parent_id: Optional[str] = None
    is_folder: bool = False

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

# 3. API: Photos Grid with Filtering, Search & Trash
@app.get("/api/photos")
def list_photos(
    media_type: Optional[str] = Query("photo"),
    drive_only: bool = Query(True),
    in_trash: bool = Query(False),
    country: Optional[str] = None,
    city: Optional[str] = None,
    camera: Optional[str] = None,
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

        # Trash filtering
        if in_trash:
            where_clauses.append("p.deleted_at IS NOT NULL")
        else:
            where_clauses.append("p.deleted_at IS NULL")

        # Media type
        if media_type and media_type != "all":
            where_clauses.append("p.media_type = ?")
            params.append(media_type)

        # Drive only (Point 1: Se servir que de ce qui a dans drive)
        if drive_only:
            where_clauses.append("p.gdrive_file_id IS NOT NULL")

        # Metadata filters
        if country:
            where_clauses.append("p.country = ?")
            params.append(country)

        if city:
            where_clauses.append("p.city = ?")
            params.append(city)

        if camera:
            where_clauses.append("p.camera_model = ?")
            params.append(camera)

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

        # Fetch page with Homepage ordering: filter future/erroneous dates so 10/2026 Maroc is first!
        query = f"""
        SELECT p.id, p.filename, p.rel_path, p.year, p.date_folder, p.file_size,
               p.width, p.height, p.capture_date, p.gdrive_file_id, p.gdrive_url, p.media_type,
               p.camera_make, p.camera_model, p.country, p.city, p.focal_length, p.aperture, p.iso, p.exposure_time, p.deleted_at
        FROM photos p
        {where_sql}
        ORDER BY CASE 
            WHEN p.capture_date IS NOT NULL AND p.capture_date <= '2026-12-31T23:59:59' THEN p.capture_date 
            ELSE '1900-01-01' 
        END DESC, p.id DESC
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
                "is_in_drive": bool(drive_id),
                "media_type": r["media_type"],
                "camera_make": r["camera_make"],
                "camera_model": r["camera_model"],
                "country": r["country"],
                "city": r["city"],
                "focal_length": r["focal_length"],
                "aperture": r["aperture"],
                "iso": r["iso"],
                "exposure_time": r["exposure_time"],
                "deleted_at": r["deleted_at"],
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

# 6. API: Filter Aggregations for Sidebar/Drawer
@app.get("/api/filters")
def get_filters_data():
    with get_connection() as conn:
        cur = conn.cursor()
        
        # Countries
        cur.execute("""
        SELECT country, COUNT(*) as count 
        FROM photos 
        WHERE country IS NOT NULL AND country != '' AND deleted_at IS NULL
        GROUP BY country 
        ORDER BY count DESC 
        LIMIT 15;
        """)
        countries = [{"name": r["country"], "count": r["count"]} for r in cur.fetchall()]

        # Cameras
        cur.execute("""
        SELECT camera_model, COUNT(*) as count 
        FROM photos 
        WHERE camera_model IS NOT NULL AND camera_model != '' AND deleted_at IS NULL
        GROUP BY camera_model 
        ORDER BY count DESC 
        LIMIT 15;
        """)
        cameras = [{"name": r["camera_model"], "count": r["count"]} for r in cur.fetchall()]

        # Drive counts
        cur.execute("SELECT COUNT(*) FROM photos WHERE gdrive_file_id IS NOT NULL AND deleted_at IS NULL;")
        drive_synced = cur.fetchone()[0]

        cur.execute("SELECT COUNT(*) FROM photos WHERE gdrive_file_id IS NULL AND deleted_at IS NULL;")
        drive_pending = cur.fetchone()[0]

        # Trash count
        cur.execute("SELECT COUNT(*) FROM photos WHERE deleted_at IS NOT NULL;")
        trash_count = cur.fetchone()[0]

    return {
        "countries": countries,
        "cameras": cameras,
        "drive_synced": drive_synced,
        "drive_pending": drive_pending,
        "trash_count": trash_count
    }

# 7. API: Batch Actions & Trash System (30-day Retention)
@app.post("/api/photos/trash")
def move_to_trash(req: BatchTrashRequest):
    if not req.photo_ids:
        return {"status": "ok", "count": 0}
    now_iso = datetime.utcnow().isoformat()
    with get_connection() as conn:
        cur = conn.cursor()
        placeholders = ",".join("?" for _ in req.photo_ids)
        cur.execute(f"UPDATE photos SET deleted_at = ? WHERE id IN ({placeholders});", [now_iso] + req.photo_ids)
        conn.commit()
    return {"status": "ok", "count": len(req.photo_ids)}

@app.post("/api/photos/restore")
def restore_from_trash(req: BatchTrashRequest):
    if not req.photo_ids:
        return {"status": "ok", "count": 0}
    with get_connection() as conn:
        cur = conn.cursor()
        placeholders = ",".join("?" for _ in req.photo_ids)
        cur.execute(f"UPDATE photos SET deleted_at = NULL WHERE id IN ({placeholders});", req.photo_ids)
        conn.commit()
    return {"status": "ok", "count": len(req.photo_ids)}

@app.post("/api/photos/purge")
def purge_trash():
    cutoff = (datetime.utcnow() - timedelta(days=30)).isoformat()
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT id FROM photos WHERE deleted_at IS NOT NULL AND deleted_at < ?;", (cutoff,))
        expired = [r[0] for r in cur.fetchall()]
        if expired:
            pl = ",".join("?" for _ in expired)
            cur.execute(f"DELETE FROM photo_albums WHERE photo_id IN ({pl});", expired)
            cur.execute(f"DELETE FROM photos WHERE id IN ({pl});", expired)
            conn.commit()
    return {"status": "ok", "purged_count": len(expired)}

@app.post("/api/photos/move_album")
def move_photos_to_album(req: BatchMoveRequest):
    if not req.photo_ids or not req.target_album_id:
        return {"status": "error", "message": "Missing ids or target album"}
    with get_connection() as conn:
        cur = conn.cursor()
        if req.remove_from_current and req.current_album_id:
            pl = ",".join("?" for _ in req.photo_ids)
            cur.execute(f"DELETE FROM photo_albums WHERE album_id = ? AND photo_id IN ({pl});", [req.current_album_id] + req.photo_ids)
        
        insert_data = [(pid, req.target_album_id) for pid in req.photo_ids]
        cur.executemany("INSERT OR IGNORE INTO photo_albums (photo_id, album_id) VALUES (?, ?);", insert_data)
        conn.commit()
    return {"status": "ok", "count": len(req.photo_ids)}

@app.post("/api/albums")
def create_album(req: AlbumCreateRequest):
    alb_id = str(uuid.uuid4()).replace("-", "")
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
        INSERT INTO albums (id, name, parent_id, is_folder, direct_count, total_count)
        VALUES (?, ?, ?, ?, 0, 0);
        """, (alb_id, req.name.strip(), req.parent_id, 1 if req.is_folder else 0))
        conn.commit()
    return {"status": "ok", "id": alb_id, "name": req.name}

@app.delete("/api/albums/{album_id}")
def delete_album(album_id: str):
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("DELETE FROM photo_albums WHERE album_id = ?;", (album_id,))
        cur.execute("DELETE FROM albums WHERE id = ?;", (album_id,))
        conn.commit()
    return {"status": "ok", "deleted_album_id": album_id}

app.mount("/static", StaticFiles(directory=str(FRONTEND_DIR)), name="static")

@app.get("/")
def serve_index():
    index_file = FRONTEND_DIR / "index.html"
    return FileResponse(index_file)
