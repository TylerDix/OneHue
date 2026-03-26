#!/usr/bin/env python3
"""
Clean up GPT.svg:
  1. Merge 14 color classes → 10 by combining the 4 most similar pairs
  2. Remap fill colors to a distinct palette
"""
import re
import os

SVG_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "One Hue", "Artworks", "GPT.svg")

# Original 14 colors from Image Trace
# cls-1:  #e1f6f8  (ice blue, 137 el)
# cls-2:  #e1ac75  (light tan, 292 el)        ← merge into cls-12
# cls-3:  #b87968  (dusty rose, 142 el)
# cls-4:  #e76727  (orange, 221 el)
# cls-5:  #834329  (dark brown, 305 el)
# cls-6:  #7acbf3  (light blue, 98 el)        ← merge into cls-14
# cls-7:  #2f6a3e  (dark green, 350 el)       ← merge into cls-13
# cls-8:  #93b335  (olive green, 315 el)
# cls-9:  #d3d531  (yellow-green, 336 el)
# cls-10: #32271b  (very dark brown, 488 el)
# cls-11: #14140f  (near-black, 156 el)       ← merge into cls-10
# cls-12: #f6d699  (light gold, 232 el)
# cls-13: #598a36  (medium green, 360 el)
# cls-14: #39a2bf  (teal blue, 91 el)

MERGES = {
    "cls-11": "cls-10",  # near-black → very dark brown
    "cls-7":  "cls-13",  # dark green → medium green
    "cls-6":  "cls-14",  # light blue → teal blue
    "cls-2":  "cls-12",  # light tan → light gold
}

# After merge: 10 remaining classes → palette
NEW_PALETTE = {
    "cls-10": "#1A1A2E",  # 1: Deep Charcoal
    "cls-5":  "#4A2C17",  # 2: Espresso
    "cls-3":  "#B85C4A",  # 3: Clay Rose
    "cls-4":  "#E05A20",  # 4: Vermillion
    "cls-12": "#E8B44C",  # 5: Honey Gold
    "cls-9":  "#C4CC28",  # 6: Chartreuse
    "cls-8":  "#7EA830",  # 7: Moss Green
    "cls-13": "#3A7A40",  # 8: Forest Green
    "cls-14": "#2E8EAE",  # 9: Ocean Blue
    "cls-1":  "#D8F0F2",  # 10: Frost
}

RENUMBER = {}
for i, old_cls in enumerate(NEW_PALETTE.keys(), start=1):
    RENUMBER[old_cls] = f"cls-{i}"


def main():
    with open(SVG_PATH, "r") as f:
        svg = f.read()

    # --- Step 1: Merge classes ---
    for old, new in MERGES.items():
        svg = svg.replace(f'class="{old}"', f'class="{new}"')

    # --- Step 2: Replace <style> block ---
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

    print("GPT.svg cleaned up:")
    print(f"  Merged {len(MERGES)} class pairs → 10 groups")
    print(f"  Remapped palette to 10 distinct colors:")
    for old_cls, new_name in RENUMBER.items():
        print(f"    {new_name}: {NEW_PALETTE[old_cls]}")

    path_count = svg.count("<path")
    print(f"  Total <path> elements: {path_count}")
    print(f"  File size: {len(svg):,} bytes")


if __name__ == "__main__":
    main()
