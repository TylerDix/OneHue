#!/usr/bin/env python3
"""
Clean up GoldenFirefly.svg:
  1. Merge 12 color classes → 10 by combining the 2 most similar pairs
  2. Remap fill colors to a more visually distinct palette
"""
import re
import sys

import os
SVG_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "One Hue", "Artworks", "GoldenFirefly.svg")

# Original 12 colors from Image Trace
# cls-1:  #5a5115  (olive)
# cls-2:  #3f3d13  (dark olive)
# cls-3:  #4b492d  (brown-olive)       ← merge into cls-2
# cls-4:  #f1c33e  (bright gold)
# cls-5:  #131f0e  (very dark green)   ← merge into cls-11
# cls-6:  #c09c44  (gold/brown)
# cls-7:  #26300f  (dark green)
# cls-8:  #786b22  (olive)
# cls-9:  #d19e05  (gold)
# cls-10: #ece19a  (light yellow)
# cls-11: #080f0a  (near-black)
# cls-12: #977e19  (dark gold)

# Step 1: Merge pairs (replace in class attributes)
MERGES = {
    "cls-5": "cls-11",   # very dark green → near-black
    "cls-3": "cls-2",    # brown-olive → dark olive
}

# Step 2: After merge, 10 remaining classes → remap to distinct palette
# Ordered darkest to lightest for the final numbering
NEW_PALETTE = {
    "cls-11": "#0F1A2E",  # 1: Midnight Navy (deep shadows)
    "cls-7":  "#1A472A",  # 2: Dark Forest Green
    "cls-2":  "#8C8578",  # 3: Warm Stone Gray (rocks/earth)
    "cls-1":  "#4A8C5C",  # 4: Medium Green (foliage)
    "cls-8":  "#8FBF6A",  # 5: Leaf Green (light foliage)
    "cls-12": "#D4652F",  # 6: Burnt Orange (firefly/warm accents)
    "cls-6":  "#4A90A4",  # 7: Teal Blue (water/sky)
    "cls-9":  "#B03A2E",  # 8: Deep Red (bold accent)
    "cls-4":  "#E8B84B",  # 9: Golden Yellow (warm light)
    "cls-10": "#E2DEBB",  # 10: Warm Sky Cream (highlights)
}

# Final renumbering: old class → new class name
RENUMBER = {}
for i, old_cls in enumerate(NEW_PALETTE.keys(), start=1):
    RENUMBER[old_cls] = f"cls-{i}"


def main():
    with open(SVG_PATH, "r") as f:
        svg = f.read()

    # --- Step 1: Merge classes in element attributes ---
    for old, new in MERGES.items():
        # Replace class="cls-X" attributes safely
        svg = svg.replace(f'class="{old}"', f'class="{new}"')

    # --- Step 2: Replace the entire <style> block with new palette ---
    # Build new CSS
    css_lines = []
    for old_cls, new_name in RENUMBER.items():
        hex_color = NEW_PALETTE[old_cls]
        css_lines.append(f"      .{new_name} {{\n        fill: {hex_color};\n      }}")
    new_css = "\n\n".join(css_lines)
    new_style_block = f"    <style>\n{new_css}\n    </style>"

    # Replace existing style block
    svg = re.sub(
        r"<style>.*?</style>",
        new_style_block,
        svg,
        flags=re.DOTALL,
    )

    # --- Step 3: Renumber class references in elements ---
    # Do this in reverse order of number to avoid cls-1 matching inside cls-10
    # First rename to temporary names, then to final names
    for old_cls in RENUMBER:
        tmp = f"__tmp_{old_cls}__"
        svg = svg.replace(f'class="{old_cls}"', f'class="{tmp}"')

    for old_cls, new_name in RENUMBER.items():
        tmp = f"__tmp_{old_cls}__"
        svg = svg.replace(f'class="{tmp}"', f'class="{new_name}"')

    # --- Step 4: Clean up SVG root attributes ---
    # Remove id and data-name from root <svg> (not needed by parser)
    svg = re.sub(r' id="Layer_1"', '', svg)
    svg = re.sub(r' data-name="Layer 1"', '', svg)

    with open(SVG_PATH, "w") as f:
        f.write(svg)

    # Print summary
    print("GoldenFirefly.svg cleaned up:")
    print(f"  Merged {len(MERGES)} class pairs → 10 groups")
    print(f"  Remapped palette to 10 distinct colors:")
    for old_cls, new_name in RENUMBER.items():
        print(f"    {new_name}: {NEW_PALETTE[old_cls]}")

    # Count elements
    path_count = svg.count("<path")
    print(f"  Total <path> elements: {path_count}")
    print(f"  File size: {len(svg):,} bytes")


if __name__ == "__main__":
    main()
