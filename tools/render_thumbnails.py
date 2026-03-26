#!/usr/bin/env python3
"""Render all SVGs to 200x200 PNG thumbnails for AI identification."""

import os
import ctypes.util

# Monkey-patch find_library so cairocffi can find homebrew's cairo
_orig_find = ctypes.util.find_library
def _patched_find(name):
    if name in ('cairo', 'cairo-2'):
        return '/opt/homebrew/lib/libcairo.2.dylib'
    return _orig_find(name)
ctypes.util.find_library = _patched_find

import cairosvg
from PIL import Image
from io import BytesIO

ARTWORKS_DIR = os.path.join(os.path.dirname(__file__), "..", "One Hue", "Artworks")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "thumbnails")
SIZE = 200

def main():
    artworks_dir = os.path.abspath(ARTWORKS_DIR)
    output_dir = os.path.abspath(OUTPUT_DIR)
    os.makedirs(output_dir, exist_ok=True)

    svgs = sorted(f for f in os.listdir(artworks_dir) if f.endswith('.svg'))
    print(f"Rendering {len(svgs)} SVGs to {SIZE}x{SIZE} PNGs...")

    ok = 0
    errors = 0
    for svg_name in svgs:
        svg_path = os.path.join(artworks_dir, svg_name)
        png_name = svg_name.replace('.svg', '.png')
        png_path = os.path.join(output_dir, png_name)

        try:
            png_data = cairosvg.svg2png(
                url=svg_path,
                output_width=SIZE,
                output_height=SIZE,
            )
            # Ensure it's exactly SIZE x SIZE
            img = Image.open(BytesIO(png_data))
            if img.size != (SIZE, SIZE):
                img = img.resize((SIZE, SIZE), Image.LANCZOS)
            img.save(png_path)
            ok += 1
        except Exception as e:
            print(f"  ERROR: {svg_name}: {e}")
            errors += 1

    print(f"\nDone! Rendered: {ok}, Errors: {errors}")
    print(f"Thumbnails in: {output_dir}")

if __name__ == "__main__":
    main()
