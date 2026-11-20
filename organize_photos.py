import os
import shutil
import hashlib
from pathlib import Path
from PIL import Image
from PIL.ExifTags import TAGS

def get_image_properties(path):
    stat = path.stat()
    size = stat.st_size
    dim = None
    shot_date = None
    try:
        with Image.open(path) as img:
            dim = img.size
            exif = img.getexif()
            if exif:
                # 36867 = DateTimeOriginal, 36868 = DateTimeDigitized, 306 = DateTime
                shot_date = exif.get(36867) or exif.get(36868) or exif.get(306)
    except Exception:
        pass
    return {
        'size': size,
        'dim': dim,
        'shot_date': shot_date
    }

def properties_match(p_src, p_dst):
    # Check weight (poids = file size)
    if p_src.stat().st_size != p_dst.stat().st_size:
        return False
    
    # Check dimensions & shot date if possible
    props_src = get_image_properties(p_src)
    props_dst = get_image_properties(p_dst)
    
    if props_src['dim'] is not None and props_dst['dim'] is not None:
        if props_src['dim'] != props_dst['dim']:
            return False
            
    if props_src['shot_date'] is not None and props_dst['shot_date'] is not None:
        if props_src['shot_date'] != props_dst['shot_date']:
            return False
            
    return True

def main():
    base = Path(r"D:\dowload chrome")
    target_base = base / "ALLPHOTOS"
    target_base.mkdir(parents=True, exist_ok=True)
    
    # Track created folders
    existing_dirs_before = set()
    if target_base.exists():
        for d in target_base.rglob('*'):
            if d.is_dir():
                existing_dirs_before.add(d)

    files_moved = 0
    files_overwritten = 0
    files_left = []
    
    # Process LightroomLibrary_1 to 41
    for i in range(1, 42):
        lib = base / f"LightroomLibrary_{i}"
        if not lib.exists():
            continue
        print(f"Processing {lib.name}...")
        
        # Collect all files first so directory iteration isn't affected by moves
        files_to_process = [p for p in lib.rglob('*') if p.is_file()]
        
        for src in files_to_process:
            rel = src.relative_to(lib)
            dst = target_base / rel
            
            # Ensure destination directory exists
            dst.parent.mkdir(parents=True, exist_ok=True)
            
            if not dst.exists():
                # Move to destination
                shutil.move(str(src), str(dst))
                files_moved += 1
            else:
                # File already exists at destination - compare properties
                if properties_match(src, dst):
                    # Overwrite
                    os.replace(str(src), str(dst))
                    files_overwritten += 1
                else:
                    # Keep in original folder
                    files_left.append({
                        'src': str(src),
                        'dst_existing': str(dst),
                        'src_size': src.stat().st_size,
                        'dst_size': dst.stat().st_size
                    })

    # Count all folders in ALLPHOTOS
    all_dirs_now = set(d for d in target_base.rglob('*') if d.is_dir())
    created_dirs_count = len(all_dirs_now - existing_dirs_before)
    
    print("\n" + "="*50)
    print("BILAN DU TRANSFERT")
    print("="*50)
    print(f"Dossiers créés dans ALLPHOTOS : {created_dirs_count}")
    print(f"Fichiers déplacés : {files_moved}")
    print(f"Fichiers écrasés (doublons identiques) : {files_overwritten}")
    print(f"Fichiers laissés dans le dossier d'origine : {len(files_left)}")
    print("="*50)
    
    if files_left:
        print("\nListe précise des fichiers laissés dans le dossier d'origine :")
        for item in files_left:
            print(f"- {item['src']} (taille: {item['src_size']} octets) vs destination existante {item['dst_existing']} (taille: {item['dst_size']} octets)")

    # Save report to a text file
    report_path = target_base / "rapport_transfert.txt"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("BILAN DU TRANSFERT\n")
        f.write("="*50 + "\n")
        f.write(f"Dossiers créés dans ALLPHOTOS : {created_dirs_count}\n")
        f.write(f"Fichiers déplacés : {files_moved}\n")
        f.write(f"Fichiers écrasés : {files_overwritten}\n")
        f.write(f"Fichiers laissés dans le dossier d'origine : {len(files_left)}\n\n")
        if files_left:
            f.write("Fichiers laissés dans l'origine :\n")
            for item in files_left:
                f.write(f"- {item['src']} ({item['src_size']} octets) non écrasé car différent de {item['dst_existing']} ({item['dst_size']} octets)\n")

if __name__ == "__main__":
    main()
