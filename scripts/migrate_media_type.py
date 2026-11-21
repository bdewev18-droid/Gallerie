import sqlite3

conn = sqlite3.connect(r'd:\LRforIA\data\photos.db')
cur = conn.cursor()

# 1. Add media_type column if not exists
columns = [c[1] for c in cur.execute('PRAGMA table_info(photos)').fetchall()]
if 'media_type' not in columns:
    cur.execute("ALTER TABLE photos ADD COLUMN media_type TEXT DEFAULT 'photo'")
    print("Added media_type column")

# 2. Update media_type for video extensions
cur.execute("""
    UPDATE photos 
    SET media_type = 'video' 
    WHERE lower(filename) LIKE '%.mp4' 
       OR lower(filename) LIKE '%.mov' 
       OR lower(filename) LIKE '%.avi' 
       OR lower(filename) LIKE '%.m4v'
       OR lower(filename) LIKE '%.mkv'
""")
conn.commit()

# 3. Create index on media_type
cur.execute("CREATE INDEX IF NOT EXISTS idx_photos_media_type ON photos(media_type)")
cur.execute("CREATE INDEX IF NOT EXISTS idx_photos_media_year ON photos(media_type, year)")
conn.commit()

# 4. Check counts
cur.execute("SELECT media_type, count(*) FROM photos GROUP BY media_type")
print("Media types count:", cur.fetchall())

# 5. Check video years
cur.execute("SELECT year, count(*) FROM photos WHERE media_type = 'video' GROUP BY year ORDER BY year DESC")
print("Video years:", cur.fetchall())

conn.close()
