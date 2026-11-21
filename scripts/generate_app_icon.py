import math
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

def create_app_icon(size=1024):
    # Create RGBA canvas
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Background: Smooth squircle / rounded rect with gradient
    radius = int(size * 0.22)
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)

    # Gradient fill
    for y in range(size):
        ratio = y / size
        # From #0F172A (15, 23, 42) to #0369A1 (3, 105, 161)
        r = int(15 * (1 - ratio) + 2 * ratio)
        g = int(23 * (1 - ratio) + 105 * ratio)
        b = int(42 * (1 - ratio) + 161 * ratio)
        bg_draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # Mask for squircle
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    margin = int(size * 0.04)
    mask_draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius,
        fill=255
    )

    img.paste(bg, (0, 0), mask)

    # Re-obtain draw handle
    draw = ImageDraw.Draw(img)

    # Subtle inner border / glow
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius,
        outline=(56, 189, 248, 80),
        width=int(size * 0.015)
    )

    # 2. Modern Photo/Video Gallery Icon
    # Center coordinates
    cx, cy = size / 2, size / 2

    # Draw stylized camera & gallery elements:
    # Outer elegant rounded frame (Photo polaroid/card aspect)
    fw = int(size * 0.54)
    fh = int(size * 0.54)
    fx1 = int(cx - fw / 2)
    fy1 = int(cy - fh / 2)
    fx2 = fx1 + fw
    fy2 = fy1 + fh
    fradius = int(size * 0.08)

    # Frame background (deep blue plate)
    draw.rounded_rectangle(
        [fx1, fy1, fx2, fy2],
        radius=fradius,
        fill=(15, 23, 42, 220),
        outline=(56, 189, 248, 200),
        width=int(size * 0.02)
    )

    # Mountains silhouette (Photo iconography)
    # Sun / warm circle (Amber/gold)
    sun_r = int(size * 0.07)
    sun_cx = int(cx + size * 0.12)
    sun_cy = int(cy - size * 0.08)
    draw.ellipse(
        [sun_cx - sun_r, sun_cy - sun_r, sun_cx + sun_r, sun_cy + sun_r],
        fill=(251, 191, 36, 240)
    )

    # Mountain peak 1 (Back mountain - darker cyan)
    m1 = [
        (int(cx - size * 0.22), int(fy2 - size * 0.02)),
        (int(cx - size * 0.04), int(cy - size * 0.06)),
        (int(cx + size * 0.16), int(fy2 - size * 0.02))
    ]
    draw.polygon(m1, fill=(2, 132, 199, 220))

    # Mountain peak 2 (Front mountain - bright vibrant sky cyan)
    m2 = [
        (int(cx - size * 0.10), int(fy2 - size * 0.02)),
        (int(cx + size * 0.07), int(cy - size * 0.13)),
        (int(cx + size * 0.22), int(fy2 - size * 0.02))
    ]
    draw.polygon(m2, fill=(56, 189, 248, 255))

    # Video Play triangle badge on lower right (indicates Medias: Photos + Videos!)
    pb_r = int(size * 0.12)
    pb_cx = int(fx2 - size * 0.02)
    pb_cy = int(fy2 - size * 0.02)
    draw.ellipse(
        [pb_cx - pb_r, pb_cy - pb_r, pb_cx + pb_r, pb_cy + pb_r],
        fill=(225, 29, 72, 240), # Vibrant rose/crimson
        outline=(255, 255, 255, 220),
        width=int(size * 0.015)
    )

    # White play triangle
    tri_len = pb_r * 0.55
    tri_pts = [
        (int(pb_cx - tri_len * 0.5), int(pb_cy - tri_len * 0.7)),
        (int(pb_cx - tri_len * 0.5), int(pb_cy + tri_len * 0.7)),
        (int(pb_cx + tri_len * 0.75), int(pb_cy))
    ]
    draw.polygon(tri_pts, fill=(255, 255, 255, 255))

    return img

def export_all_sizes():
    icon_1024 = create_app_icon(1024)

    # Save master high-res icon
    assets_dir = Path(r"d:\LRforIA\assets\icon")
    assets_dir.mkdir(parents=True, exist_ok=True)
    master_path = assets_dir / "app_icon.png"
    icon_1024.save(master_path, "PNG")
    print(f"Saved master icon: {master_path}")

    # Android mipmap icons
    android_res = Path(r"d:\LRforIA\android\app\src\main\res")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, s in android_sizes.items():
        out_dir = android_res / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        resized = icon_1024.resize((s, s), Image.Resampling.LANCZOS)
        out_file = out_dir / "ic_launcher.png"
        resized.save(out_file, "PNG")
        print(f"Saved Android {folder} ({s}x{s}): {out_file}")

    # Web icons
    web_dir = Path(r"d:\LRforIA\web")
    web_icons_dir = web_dir / "icons"
    web_icons_dir.mkdir(parents=True, exist_ok=True)

    icon_1024.resize((512, 512), Image.Resampling.LANCZOS).save(web_icons_dir / "Icon-512.png", "PNG")
    icon_1024.resize((512, 512), Image.Resampling.LANCZOS).save(web_icons_dir / "Icon-maskable-512.png", "PNG")
    icon_1024.resize((192, 192), Image.Resampling.LANCZOS).save(web_icons_dir / "Icon-192.png", "PNG")
    icon_1024.resize((192, 192), Image.Resampling.LANCZOS).save(web_icons_dir / "Icon-maskable-192.png", "PNG")
    icon_1024.resize((32, 32), Image.Resampling.LANCZOS).save(web_dir / "favicon.png", "PNG")
    print("Saved Web icons and favicon.")

if __name__ == "__main__":
    export_all_sizes()
