#!/usr/bin/env python3
"""
Clean up KoiPond.svg:
  1. Merge 12 color classes → 10 by combining the 2 most similar pairs
  2. Remap fill colors to a distinct koi pond palette
"""
import re
import os

SVG_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "One Hue", "Artworks", "KoiPond.svg")

# Original 12 colors from Image Trace
# cls-1:  #758413  (olive green, 37 el)
# cls-2:  #ccb813  (bright yellow-gold, 44 el)
# cls-3:  #031017  (near-black blue, 40 el)
# cls-4:  #e8c786  (light peach/gold, 12 el)   ← merge into cls-8
# cls-5:  #324d2d  (dark green, 35 el)
# cls-6:  #5a7e7a  (teal/sage, 64 el)
# cls-7:  #fce6a9  (light cream, 19 el)
# cls-8:  #e8b159  (golden amber, 23 el)
# cls-9:  #041721  (near-black blue, 39 el)    ← merge into cls-3
# cls-10: #988352  (brownish gold, 31 el)
# cls-11: #f94806  (bright orange-red, 12 el)
# cls-12: #2c575f  (dark teal, 67 el)

MERGES = {
    "cls-9": "cls-3",   # near-black pair
    "cls-4": "cls-8",   # golden amber pair
}

# After merge: 10 remaining classes → koi pond palette
# Ordered dark to light
NEW_PALETTE = {
    "cls-3":  "#0A1628",  # 1: Deep Indigo (dark water/shadows)
    "cls-12": "#1A4B6E",  # 2: Deep Water Blue
    "cls-5":  "#2D6B3F",  # 3: Lily Pad Green
    "cls-6":  "#3A8F8F",  # 4: Pond Teal (water surface)
    "cls-1":  "#6B8F3A",  # 5: Bamboo Green (foliage)
    "cls-10": "#8C7B5A",  # 6: Warm Stone (rocks/earth)
    "cls-2":  "#D4A832",  # 7: Sunlit Gold (reflections)
    "cls-8":  "#E8A860",  # 8: Peach Blossom (warm light)
    "cls-7":  "#F5E6C8",  # 9: Moonlight (highlights)
    "cls-11": "#E85420",  # 10: Koi Orange (fish accent)
}

RENUMBER = {}
for i, old_cls in enumerate(NEW_PALETTE.keys(), start=1):
    RENUMBER[old_cls] = f"cls-{i}"


def main():
    with open(SVG_PATH, "r") as f:
        svg = f.read()

    # --- Step 1: Merge classes in element attributes ---
    for old, new in MERGES.items():
        svg = svg.replace(f'class="{old}"', f'class="{new}"')

    # --- Step 2: Replace <style> block with new palette ---
    css_lines = []
    for old_cls, new_name in RENUMBER.items():
        hex_color = NEW_PALETTE[old_cls]
        css_lines.append(f"      .{new_name} {{\n        fill: {hex_color};\n      }}")
    new_css = "\n\n".join(css_lines)
    new_style_block = f"    <style>\n{new_css}\n    </style>"

    svg = re.sub(
        r"<style>.*?</style>",
        new_style_block,
        svg,
        flags=re.DOTALL,
    )

    # --- Step 3: Renumber class references ---
    for old_cls in RENUMBER:
        tmp = f"__tmp_{old_cls}__"
        svg = svg.replace(f'class="{old_cls}"', f'class="{tmp}"')

    for old_cls, new_name in RENUMBER.items():
        tmp = f"__tmp_{old_cls}__"
        svg = svg.replace(f'class="{tmp}"', f'class="{new_name}"')

    # --- Step 4: Clean up SVG root attributes ---
    svg = re.sub(r' id="Layer_1"', '', svg)
    svg = re.sub(r' data-name="Layer 1"', '', svg)

    with open(SVG_PATH, "w") as f:
        f.write(svg)

    print("KoiPond.svg cleaned up:")
    print(f"  Merged {len(MERGES)} class pairs → 10 groups")
    print(f"  Remapped palette to 10 distinct colors:")
    for old_cls, new_name in RENUMBER.items():
        print(f"    {new_name}: {NEW_PALETTE[old_cls]}")

    path_count = svg.count("<path")
    print(f"  Total <path> elements: {path_count}")
    print(f"  File size: {len(svg):,} bytes")


if __name__ == "__main__":
    main()
