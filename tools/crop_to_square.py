#!/usr/bin/env python3
"""
Crop all non-square SVGs in Artworks/ to 1200x1200 by center-cropping the viewBox.

This adjusts the viewBox and enable-background style attribute only — no path data is
modified. Content outside the new viewBox is still in the file but won't be rendered.

Backs up originals to Artworks_backup_pretrim/ before modifying.
"""

import os
import re
import shutil
import sys

ARTWORKS_DIR = os.path.join(os.path.dirname(__file__), "..", "One Hue", "Artworks")
BACKUP_DIR = os.path.join(os.path.dirname(__file__), "..", "One Hue", "Artworks_backup_pretrim")
TARGET_SIZE = 1200.0

# Regex to match viewBox="x y w h"
VIEWBOX_RE = re.compile(r'viewBox="([^"]+)"')
# Regex to match enable-background:new x y w h;
ENABLE_BG_RE = re.compile(r'enable-background:\s*new\s+([^;"]+)')


def parse_viewbox(vb_str):
    """Parse '0 0 1200 1543' into (x, y, w, h) floats."""
    parts = vb_str.strip().split()
    if len(parts) != 4:
        return None
    return tuple(float(p) for p in parts)


def format_viewbox(x, y, w, h):
    """Format viewBox values, using ints where possible."""
    def fmt(v):
        return str(int(v)) if v == int(v) else f"{v:.2f}".rstrip('0').rstrip('.')
    return f"{fmt(x)} {fmt(y)} {fmt(w)} {fmt(h)}"


def crop_svg(filepath):
    """Crop a single SVG to square. Returns (old_vb, new_vb) or None if already square."""
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()

    m = VIEWBOX_RE.search(content)
    if not m:
        print(f"  WARNING: no viewBox found in {os.path.basename(filepath)}")
        return None

    vb = parse_viewbox(m.group(1))
    if not vb:
        print(f"  WARNING: unparseable viewBox in {os.path.basename(filepath)}: {m.group(1)}")
        return None

    x, y, w, h = vb

    # Already square?
    if abs(w - TARGET_SIZE) < 0.1 and abs(h - TARGET_SIZE) < 0.1:
        return None

    if abs(w - TARGET_SIZE) > 0.1:
        print(f"  WARNING: width != 1200 in {os.path.basename(filepath)}: {w}")
        return None

    # Center crop vertically
    extra = h - TARGET_SIZE
    new_y = y + extra / 2.0
    new_vb = format_viewbox(x, new_y, TARGET_SIZE, TARGET_SIZE)
    old_vb = m.group(1)

    # Replace viewBox
    content = content.replace(f'viewBox="{old_vb}"', f'viewBox="{new_vb}"')

    # Replace enable-background:new ... to match
    def replace_enable_bg(match):
        return f"enable-background:new {new_vb}"
    content = ENABLE_BG_RE.sub(replace_enable_bg, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    return (old_vb, new_vb)


def main():
    artworks_dir = os.path.abspath(ARTWORKS_DIR)
    backup_dir = os.path.abspath(BACKUP_DIR)

    if not os.path.isdir(artworks_dir):
        print(f"ERROR: Artworks directory not found: {artworks_dir}")
        sys.exit(1)

    svgs = sorted(f for f in os.listdir(artworks_dir) if f.endswith('.svg'))
    print(f"Found {len(svgs)} SVGs in {artworks_dir}")

    # Backup
    if not os.path.exists(backup_dir):
        print(f"Backing up to {backup_dir} ...")
        shutil.copytree(artworks_dir, backup_dir)
        print(f"Backup complete ({len(svgs)} files)")
    else:
        print(f"Backup already exists at {backup_dir}, skipping backup")

    cropped = 0
    skipped = 0
    errors = 0

    for svg_name in svgs:
        filepath = os.path.join(artworks_dir, svg_name)
        result = crop_svg(filepath)
        if result is None:
            skipped += 1
        else:
            old_vb, new_vb = result
            print(f"  {svg_name}: {old_vb} -> {new_vb}")
            cropped += 1

    print(f"\nDone! Cropped: {cropped}, Already square: {skipped}, Errors: {errors}")


if __name__ == "__main__":
    main()
