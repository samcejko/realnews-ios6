#!/usr/bin/env python3
"""Generates the app icon and launch images for RealNews iOS 6 (run in CI, needs Pillow).

Usage: python3 tools/gen_assets.py Resources
"""
import os
import sys
import math

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "Resources"
os.makedirs(OUT, exist_ok=True)

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
    "/Library/Fonts/Arial Bold.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
]

_R = getattr(Image, "Resampling", Image)
LANCZOS, NEAREST = _R.LANCZOS, _R.NEAREST


def font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    try:
        return ImageFont.load_default(size)  # Pillow >= 10.1
    except TypeError:
        sys.exit("gen_assets: no TrueType font found (install fonts-dejavu-core)")


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(size, top, bottom):
    w, h = size
    col = Image.new("RGB", (1, h))
    col.putdata([lerp(top, bottom, y / max(1, h - 1)) for y in range(h)])
    return col.resize((w, h), NEAREST)


def text_size(draw, text, fnt):
    if hasattr(draw, "textbbox"):
        l, t, r, b = draw.textbbox((0, 0), text, font=fnt)
        return r - l, b - t, l, t
    w, h = draw.textsize(text, font=fnt)
    return w, h, 0, 0


_BASE_ICON = None


def base_icon():
    """The 1024 px master icon for RealNews (classic RSS orange with glossy sheen)."""
    global _BASE_ICON
    if _BASE_ICON is not None:
        return _BASE_ICON
    base = 1024
    # Classic rich RSS orange gradient
    img = vertical_gradient((base, base), (255, 140, 20), (215, 80, 0))

    # Skeuomorphic iOS 6 gloss: soft top diagonal highlight
    gloss = Image.new("RGBA", (base, base), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.rectangle((0, 0, base, int(base * 0.48)), fill=(255, 255, 255, 36))
    img = Image.alpha_composite(img.convert("RGBA"), gloss)

    # Draw the RSS symbol (dot and two concentric arcs)
    d = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)

    # Origin corner at bottom-left
    ox = int(base * 0.22)
    oy = int(base * 0.78)

    # Dot in bottom left
    dot_radius = int(base * 0.08)
    d.ellipse((ox - dot_radius, oy - dot_radius, ox + dot_radius, oy + dot_radius), fill=white)

    # Inner arc
    r1_in = int(base * 0.24)
    r1_out = int(base * 0.35)
    # Outer arc
    r2_in = int(base * 0.44)
    r2_out = int(base * 0.55)

    # High-res arc drawing
    scale = 2
    big_s = base * scale
    arc_mask = Image.new("L", (big_s, big_s), 0)
    ad = ImageDraw.Draw(arc_mask)
    box_ox = ox * scale
    box_oy = oy * scale

    # Arc 1
    ad.pieslice((box_ox - r1_out * scale, box_oy - r1_out * scale, box_ox + r1_out * scale, box_oy + r1_out * scale),
                start=270, end=360, fill=255)
    ad.pieslice((box_ox - r1_in * scale, box_oy - r1_in * scale, box_ox + r1_in * scale, box_oy + r1_in * scale),
                start=270, end=360, fill=0)

    # Arc 2
    ad.pieslice((box_ox - r2_out * scale, box_oy - r2_out * scale, box_ox + r2_out * scale, box_oy + r2_out * scale),
                start=270, end=360, fill=255)
    ad.pieslice((box_ox - r2_in * scale, box_oy - r2_in * scale, box_ox + r2_in * scale, box_oy + r2_in * scale),
                start=270, end=360, fill=0)

    scaled_mask = arc_mask.resize((base, base), LANCZOS)
    white_layer = Image.new("RGBA", (base, base), (255, 255, 255, 255))
    img.paste(white_layer, (0, 0), scaled_mask)

    _BASE_ICON = img.convert("RGB")
    return _BASE_ICON


def make_icon(size):
    return base_icon().resize((size, size), LANCZOS)


def rounded_mask(size, radius_ratio=0.1757):
    scale = 4
    big = size * scale
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=int(big * radius_ratio), fill=255)
    return mask.resize((size, size), LANCZOS)


def make_home_icon(size):
    icon = make_icon(size).convert("RGBA")
    icon.putalpha(rounded_mask(size))
    return icon


def make_launch(w, h):
    # iOS 6 textured light background
    img = vertical_gradient((w, h), (245, 245, 247), (225, 226, 230))
    d = ImageDraw.Draw(img)
    s = int(min(w, h) * 0.22)
    icon = make_icon(s)
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s - 1, s - 1), radius=int(s * 0.20), fill=255)
    cx, cy = w // 2, int(h * 0.40)
    img.paste(icon, (cx - s // 2, cy - s // 2), mask)

    fnt = font(int(min(w, h) * 0.065))
    tw, th, l, t = text_size(d, "RealNews", fnt)
    d.text((cx - tw // 2 - l, cy + s // 2 + int(s * 0.25) - t), "RealNews", font=fnt, fill=(50, 54, 66))

    subfnt = font(int(min(w, h) * 0.032))
    subtext = "RSS & Atom Reader"
    sw, sh, sl, st = text_size(d, subtext, subfnt)
    d.text((cx - sw // 2 - sl, cy + s // 2 + int(s * 0.25) + th + int(s * 0.1) - st), subtext, font=subfnt, fill=(110, 116, 130))
    return img


def main():
    print(f"Generating RealNews assets in {OUT}...")
    base_icon().save(os.path.join(OUT, "iTunesArtwork.png"), "PNG")

    sizes = [
        ("Icon.png", 57),
        ("Icon@2x.png", 114),
        ("Icon-72.png", 72),
        ("Icon-72@2x.png", 144),
        ("Icon-Small.png", 29),
        ("Icon-Small@2x.png", 58),
        ("Icon-Small-50.png", 50),
        ("Icon-Small-50@2x.png", 100),
        ("Icon-60@2x.png", 120),
        ("Icon-60@3x.png", 180),
        ("Icon-76.png", 76),
        ("Icon-76@2x.png", 152),
        ("Icon-83.5@2x.png", 167),
    ]
    for filename, sz in sizes:
        make_home_icon(sz).save(os.path.join(OUT, filename), "PNG")

    launches = [
        ("Default.png", 320, 480),
        ("Default@2x.png", 640, 960),
        ("Default-568h@2x.png", 640, 1136),
        ("Default-Portrait~ipad.png", 768, 1004),
        ("Default-Portrait@2x~ipad.png", 1536, 2008),
        ("Default-Landscape~ipad.png", 1024, 748),
        ("Default-Landscape@2x~ipad.png", 2048, 1496),
    ]
    for filename, w, h in launches:
        make_launch(w, h).save(os.path.join(OUT, filename), "PNG")

    print("Assets generated successfully.")


if __name__ == "__main__":
    main()
