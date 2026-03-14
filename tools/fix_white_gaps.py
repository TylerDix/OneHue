#!/usr/bin/env python3
"""
Fix white gap artifacts in SVGs by adding matching strokes to CSS classes.

Image Trace produces paths that don't perfectly tile — tiny sub-pixel gaps
between adjacent paths expose the white SVG background as visible bands/spots.

Fix: add `stroke: <color>; stroke-width: 1;` to every CSS class, where the
stroke color matches the fill. This makes each path slightly overlap its
neighbors, closing the gaps. The iOS app ignores CSS stroke properties
(its SVGParser only reads fill), so this is non-destructive.

For pure-white classes (#ffffff or near-white with luminance > 245), the
stroke is omitted to avoid making white regions bleed outward.

Usage:
    python3 tools/fix_white_gaps.py [--dry-run] [--file X.svg] [--all]
"""

import argparse
import glob
import os
import re
from xml.etree import ElementTree as ET

ARTWORKS_DIR = os.path.join(os.path.dirname(__file__), "..", "One Hue", "Artworks")
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

# Default: only fix the flagged SVGs
FLAGGED = {
    "baloon", "bench", "desert", "dragonflyCattail", "hammockPalms",
    "heronGoldenHour", "japanesePagoda", "lighthouse", "mistyFjordDawn",
    "moon", "seaAnemoneRock", "sealOnRock", "tabbyCatWindowsill",
    "toucanTropical", "windmillLavender",
}


def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = h[0]*2 + h[1]*2 + h[2]*2
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def luminance(hex_color):
    r, g, b = hex_to_rgb(hex_color)
    return 0.299 * r + 0.587 * g + 0.114 * b


def process_svg(filepath, dry_run=False):
    name = os.path.basename(filepath).replace(".svg", "")

    try:
        tree = ET.parse(filepath)
    except ET.ParseError:
        content = open(filepath, 'r', encoding='utf-8', errors='replace').read()
        content = content.replace('encoding="iso-8859-1"', 'encoding="UTF-8"')
        import io
        tree = ET.parse(io.StringIO(content))

    root = tree.getroot()

    # Find style element
    style_elem = None
    style_text = ""
    for elem in root.iter():
        tag = elem.tag.replace("{%s}" % SVG_NS, "")
        if tag == "style" and elem.text:
            style_elem = elem
            style_text = elem.text
            break

    if not style_text or style_elem is None:
        return None

    # Parse CSS classes and their fill colors (works whether strokes present or not)
    color_map = {}
    for m in re.finditer(r'\.(cls-\d+|st\d+)\s*\{[^}]*?fill:\s*(#[0-9a-fA-F]{3,6})', style_text, re.DOTALL):
        cls_name = m.group(1)
        hex_color = m.group(2)
        if len(hex_color) == 4:
            hex_color = '#' + hex_color[1]*2 + hex_color[2]*2 + hex_color[3]*2
        color_map[cls_name] = hex_color.lower()

    if not color_map:
        return None

    # Rebuild style block with strokes added
    # Sort classes by their name for consistent output
    used_classes = set()
    for elem in root.iter():
        cls = elem.get("class", "")
        if cls and cls in color_map:
            used_classes.add(cls)

    # Sort by luminance (darkest first) for readability
    used_sorted = sorted(used_classes, key=lambda c: luminance(color_map[c]))

    classes_fixed = 0
    new_style_lines = ["\n"]
    for cls in used_sorted:
        hex_color = color_map[cls]
        lum = luminance(hex_color)

        # Apply stroke to ALL colors including near-white.
        # Near-white strokes are harmless (match white background) and help
        # close gaps on the near-white side of adjacent paths.
        new_style_lines.append(
            "      .{} {{\n        fill: {};\n        stroke: {};\n        stroke-width: 3;\n      }}\n\n".format(cls, hex_color, hex_color)
        )
        classes_fixed += 1

    if not dry_run and classes_fixed > 0:
        style_elem.text = "".join(new_style_lines) + "    "
        tree.write(filepath, encoding="UTF-8", xml_declaration=True)

    return {"name": name, "classes_fixed": classes_fixed, "total_classes": len(used_sorted)}


def main():
    parser = argparse.ArgumentParser(description="Fix white gap artifacts in SVGs")
    parser.add_argument("--dry-run", action="store_true",
                        help="Report what would change without modifying files")
    parser.add_argument("--file", type=str, default=None,
                        help="Process a single file instead of flagged set")
    parser.add_argument("--all", action="store_true",
                        help="Process ALL SVGs, not just flagged ones")
    args = parser.parse_args()

    artworks_dir = os.path.abspath(ARTWORKS_DIR)

    if args.file:
        svg_files = [os.path.join(artworks_dir, args.file)]
    elif args.all:
        svg_files = sorted(glob.glob(os.path.join(artworks_dir, "*.svg")))
    else:
        svg_files = sorted([
            os.path.join(artworks_dir, name + ".svg")
            for name in FLAGGED
            if os.path.exists(os.path.join(artworks_dir, name + ".svg"))
        ])

    mode = "DRY RUN" if args.dry_run else "FIXING"
    print("\n{} — adding matching strokes to CSS classes\n".format(mode))
    print("{:<30} {:>10} {:>10}".format("File", "Fixed", "Total"))
    print("-" * 55)

    fixed_count = 0
    for filepath in svg_files:
        result = process_svg(filepath, args.dry_run)
        if result is None:
            continue
        if result.get("already_fixed"):
            print("{:<30} {:>10}".format(result["name"], "already"))
            continue
        if result["classes_fixed"] > 0:
            fixed_count += 1
        print("{:<30} {:>10} {:>10}".format(
            result["name"], result["classes_fixed"], result["total_classes"]))

    print("-" * 55)
    print("Fixed {}/{} files".format(fixed_count, len(svg_files)))


if __name__ == "__main__":
    main()
