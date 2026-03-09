#!/usr/bin/env python3
"""
Clean up moon.svg:
  1. Merge 12 color classes → 10 by combining the 2 most similar pairs
  2. Remap fill colors to a distinct moonlit palette
"""
import re
import os

SVG_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "One Hue", "Artworks", "moon.svg")

# Original 12 colors — mostly dark blues + 2 warm moon tones
# cls-1:  #2a3d55  (medium navy, 16 el)
# cls-2:  #23334a  (medium navy, 26 el)
# cls-3:  #161b27  (dark navy, 1 el)          ← merge into cls-4
# cls-4:  #0f121a  (near-black, 33 el)
# cls-5:  #192333  (dark navy, 10 el)
# cls-6:  #1d2b3f  (dark navy, 32 el)
# cls-7:  #182231  (dark navy, 10 el)         ← merge into cls-5
# cls-8:  #f7e3ba  (light cream, 10 el)
# cls-9:  #e9d0a0  (warm gold, 12 el)
# cls-10: #2c3f57  (lighter navy, 46 el)
# cls-11: #171f2e  (dark navy, 1 el)
# cls-12: #1a2639  (dark navy, 8 el)

MERGES = {
    "cls-7": "cls-5",   # nearly identical dark navies
    "cls-3": "cls-4",   # single-element dark into near-black
}

# Spread the dark blues apart more for gameplay distinction
NEW_PALETTE = {
    "cls-4":  "#080C18",  # 1: Abyss (near-black)
    "cls-11": "#1A1040",  # 2: Dark Plum
    "cls-5":  "#162848",  # 3: Deep Navy
    "cls-12": "#2B4A6E",  # 4: Prussian Blue
    "cls-6":  "#1E5050",  # 5: Teal Shadow
    "cls-2":  "#3A6090",  # 6: Ocean Blue
    "cls-1":  "#5A80A8",  # 7: Periwinkle
    "cls-10": "#7090B8",  # 8: Powder Blue
    "cls-9":  "#E8C060",  # 9: Amber Moon
    "cls-8":  "#FFF0D0",  # 10: Cream Light
}

RENUMBER = {}
for i, old_cls in enumerate(NEW_PALETTE.keys(), start=1):
    RENUMBER[old_cls] = f"cls-{i}"


def main():
    with open(SVG_PATH, "r") as f:
        svg = f.read()

    for old, new in MERGES.items():
        svg = svg.replace(f'class="{old}"', f'class="{new}"')

    css_lines = []
    for old_cls, new_name in RENUMBER.items():
        hex_color = NEW_PALETTE[old_cls]
        css_lines.append(f"      .{new_name} {{\n        fill: {hex_color};\n      }}")
    new_css = "\n\n".join(css_lines)
    new_style_block = f"    <style>\n{new_css}\n    </style>"

    svg = re.sub(r"<style>.*?</style>", new_style_block, svg, flags=re.DOTALL)

    for old_cls in RENUMBER:
        tmp = f"__tmp_{old_cls}__"
        svg = svg.replace(f'class="{old_cls}"', f'class="{tmp}"')
    for old_cls, new_name in RENUMBER.items():
        tmp = f"__tmp_{old_cls}__"
        svg = svg.replace(f'class="{tmp}"', f'class="{new_name}"')

    svg = re.sub(r' id="Layer_1"', '', svg)
    svg = re.sub(r' data-name="Layer 1"', '', svg)

    with open(SVG_PATH, "w") as f:
        f.write(svg)

    print("moon.svg cleaned up:")
    print(f"  Merged {len(MERGES)} class pairs → 10 groups")
    for old_cls, new_name in RENUMBER.items():
        print(f"    {new_name}: {NEW_PALETTE[old_cls]}")
    print(f"  Total <path> elements: {svg.count('<path')}")
    print(f"  File size: {len(svg):,} bytes")


if __name__ == "__main__":
    main()
