#!/usr/bin/env python3
"""
Standardize all SVG artworks: remove dark artifacts, normalize format, clean CSS.

Steps for each SVG:
  1. Remove tiny near-black artifact paths (luminance < threshold, small bbox area)
  2. Reassign near-black paths below a second threshold to the nearest non-black color
  3. Normalize to UTF-8, consistent width/height attrs, remove Illustrator comments
  4. Rename st* classes to cls-* with sequential numbering (no gaps)
  5. Remove orphaned CSS class definitions
  6. Clean up blank lines in style block

Usage:
    python3 tools/standardize_svgs.py [--dry-run] [--file X.svg]
"""

import argparse
import glob
import math
import os
import re
from xml.etree import ElementTree as ET

ARTWORKS_DIR = os.path.join(os.path.dirname(__file__), "..", "One Hue", "Artworks")
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

# --- Color helpers ---

def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = h[0]*2 + h[1]*2 + h[2]*2
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def luminance(hex_color):
    r, g, b = hex_to_rgb(hex_color)
    return 0.299 * r + 0.587 * g + 0.114 * b


def color_distance(hex1, hex2):
    r1, g1, b1 = hex_to_rgb(hex1)
    r2, g2, b2 = hex_to_rgb(hex2)
    rmean = (r1 + r2) / 2
    dr, dg, db = r1 - r2, g1 - g2, b1 - b2
    return ((2 + rmean/256)*dr*dr + 4*dg*dg + (2 + (255-rmean)/256)*db*db) ** 0.5


# --- Bbox helpers (simplified, no svgpathtools dependency) ---

def estimate_path_bbox(d_attr):
    """Estimate bounding box from path d-attribute using coordinate extraction."""
    if not d_attr or not d_attr.strip():
        return None
    # Extract all numbers from the path data
    nums = re.findall(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?', d_attr)
    if len(nums) < 4:
        return None
    floats = [float(n) for n in nums]
    # Treat pairs as (x, y) coordinates (rough estimate)
    xs = floats[0::2]
    ys = floats[1::2]
    if not xs or not ys:
        return None
    xmin, xmax = min(xs), max(xs)
    ymin, ymax = min(ys), max(ys)
    w = xmax - xmin
    h = ymax - ymin
    return (xmin, ymin, w, h)


def bbox_area(bbox):
    if bbox is None:
        return 0
    return bbox[2] * bbox[3]


def bbox_max_dim(bbox):
    if bbox is None:
        return 0
    return max(bbox[2], bbox[3])


# --- Core processing ---

DARK_LUM_THRESHOLD = 30       # Luminance below this = "near-black"
SMALL_ARTIFACT_AREA = 5000    # Area below this + near-black = remove
SMALL_ARTIFACT_DIM = 80       # Max dim below this + near-black = remove


def process_svg(filepath, dry_run=False):
    """Process a single SVG file."""
    name = os.path.basename(filepath)
    content = open(filepath, 'r', encoding='utf-8', errors='replace').read()
    stats = {"name": name, "dark_removed": 0, "css_cleaned": 0, "renamed": 0, "format_fixes": 0}

    # Parse
    try:
        tree = ET.parse(filepath)
    except ET.ParseError:
        # Try fixing encoding
        content = content.replace('encoding="iso-8859-1"', 'encoding="UTF-8"')
        import io
        tree = ET.parse(io.StringIO(content))

    root = tree.getroot()

    # --- Step 1: Extract style and color map ---
    style_elem = None
    style_text = ""
    for elem in root.iter():
        tag = elem.tag.replace(f"{{{SVG_NS}}}", "")
        if tag == "style" and elem.text:
            style_elem = elem
            style_text = elem.text
            break

    if not style_text:
        stats["skipped"] = "no style block"
        return stats

    # Parse colors: handle both cls-N and stN formats
    color_map = {}  # class_name -> hex_color
    for m in re.finditer(r'\.(cls-\d+|st\d+)\s*\{[^}]*fill:\s*(#[0-9a-fA-F]{3,6})', style_text):
        cls_name = m.group(1)
        hex_color = m.group(2)
        if len(hex_color) == 4:  # #abc -> #aabbcc
            hex_color = '#' + hex_color[1]*2 + hex_color[2]*2 + hex_color[3]*2
        color_map[cls_name] = hex_color.upper()

    if not color_map:
        stats["skipped"] = "no colors found"
        return stats

    # Identify near-black classes
    dark_classes = {c for c, h in color_map.items() if luminance(h) < DARK_LUM_THRESHOLD}
    light_classes = {c for c in color_map if c not in dark_classes}

    # --- Step 2: Remove tiny near-black artifact paths ---
    parents_map = {child: parent for parent in root.iter() for child in parent}
    to_remove = []

    for elem in list(root.iter()):
        tag = elem.tag.replace(f"{{{SVG_NS}}}", "")
        if tag != "path":
            continue

        cls = elem.get("class", "")
        if cls not in dark_classes:
            continue

        d = elem.get("d", "")
        bbox = estimate_path_bbox(d)
        area = bbox_area(bbox)
        max_dim = bbox_max_dim(bbox)

        # Remove if: near-black AND (small area OR small max dimension OR short path data)
        if area < SMALL_ARTIFACT_AREA or max_dim < SMALL_ARTIFACT_DIM or len(d) < 200:
            to_remove.append(elem)

    for elem in to_remove:
        parent = parents_map.get(elem)
        if parent is not None and not dry_run:
            parent.remove(elem)
    stats["dark_removed"] = len(to_remove)

    # --- Step 3: Rename classes to sequential cls-1, cls-2, ... ---
    # Collect all classes still in use after removal
    used_classes = set()
    for elem in root.iter():
        cls = elem.get("class", "")
        if cls and cls in color_map:
            used_classes.add(cls)

    # Sort by luminance (darkest first) for consistent ordering
    used_sorted = sorted(used_classes, key=lambda c: luminance(color_map[c]))

    # Build rename mapping
    rename_map = {}
    needs_rename = False
    for i, old_name in enumerate(used_sorted, 1):
        new_name = f"cls-{i}"
        rename_map[old_name] = new_name
        if old_name != new_name:
            needs_rename = True

    if needs_rename:
        stats["renamed"] = sum(1 for k, v in rename_map.items() if k != v)
        if not dry_run:
            # Rename on elements
            for elem in root.iter():
                cls = elem.get("class", "")
                if cls in rename_map:
                    elem.set("class", rename_map[cls])

            # Rebuild style block
            new_style_lines = ["\n"]
            for old_name in used_sorted:
                new_name = rename_map[old_name]
                hex_color = color_map[old_name]
                new_style_lines.append(f"      .{new_name} {{\n        fill: {hex_color.lower()};\n      }}\n\n")
            style_elem.text = "".join(new_style_lines) + "    "
    else:
        # Still clean up orphaned classes and gaps
        orphaned = set(color_map.keys()) - used_classes
        if orphaned and not dry_run:
            # Rebuild style with only used classes
            new_style_lines = ["\n"]
            for old_name in used_sorted:
                hex_color = color_map[old_name]
                new_style_lines.append(f"      .{old_name} {{\n        fill: {hex_color.lower()};\n      }}\n\n")
            style_elem.text = "".join(new_style_lines) + "    "
        stats["css_cleaned"] = len(orphaned)

    # --- Step 4: Normalize SVG root attributes ---
    format_fixes = []

    # Ensure width/height without px suffix
    if root.get("width") != "1200" or root.get("height") != "1800":
        if not dry_run:
            root.set("width", "1200")
            root.set("height", "1800")
        format_fixes.append("dims")

    # Remove Illustrator cruft
    for attr in ["style", "xml:space", "x", "y", "version"]:
        full_attr = attr
        if root.get(full_attr) is not None:
            if not dry_run:
                del root.attrib[full_attr]
            format_fixes.append(f"rm-{attr}")

    for attr in [f"{{{SVG_NS}}}xlink", "{http://www.w3.org/1999/xlink}"]:
        pass  # namespace attrs handled by ET

    # Set standard attributes
    if root.get("id") != "Layer_1":
        if not dry_run:
            root.set("id", "Layer_1")
            root.set("data-name", "Layer 1")

    # Remove XML comments (Illustrator generator comment)
    # ET doesn't preserve comments, so they'll be stripped on write

    stats["format_fixes"] = len(format_fixes)

    # --- Step 5: Write ---
    if not dry_run and (stats["dark_removed"] > 0 or stats["renamed"] > 0 or
                         stats["css_cleaned"] > 0 or stats["format_fixes"] > 0):
        tree.write(filepath, encoding="UTF-8", xml_declaration=True)

    return stats


def main():
    parser = argparse.ArgumentParser(description="Standardize SVG artworks")
    parser.add_argument("--dry-run", action="store_true",
                        help="Report what would change without modifying files")
    parser.add_argument("--file", type=str, default=None,
                        help="Process a single file instead of all artworks")
    args = parser.parse_args()

    artworks_dir = os.path.abspath(ARTWORKS_DIR)
    if args.file:
        svg_files = [args.file]
    else:
        svg_files = sorted(glob.glob(os.path.join(artworks_dir, "*.svg")))

    if not svg_files:
        print(f"No SVG files found in {artworks_dir}")
        return

    mode = "DRY RUN" if args.dry_run else "PROCESSING"
    print(f"\n{mode} — dark_lum<{DARK_LUM_THRESHOLD}, artifact_area<{SMALL_ARTIFACT_AREA}, artifact_dim<{SMALL_ARTIFACT_DIM}\n")

    hdr = "{:<30} {:>8} {:>8} {:>8} {:>8}  {}".format(
        "File", "DarkRm", "CSSClean", "Renamed", "FmtFix", "Notes")
    print(hdr)
    print("-" * 100)

    totals = {"dark_removed": 0, "css_cleaned": 0, "renamed": 0, "format_fixes": 0}
    changed = 0

    for filepath in svg_files:
        stats = process_svg(filepath, args.dry_run)

        if stats.get("skipped"):
            continue

        any_change = (stats["dark_removed"] + stats["css_cleaned"] +
                     stats["renamed"] + stats["format_fixes"]) > 0
        if any_change:
            changed += 1
            for k in totals:
                totals[k] += stats[k]
            print("{:<30} {:>8} {:>8} {:>8} {:>8}".format(
                stats["name"], stats["dark_removed"], stats["css_cleaned"],
                stats["renamed"], stats["format_fixes"]))

    print("-" * 100)
    print("{:<30} {:>8} {:>8} {:>8} {:>8}".format(
        f"TOTAL ({changed}/{len(svg_files)} changed)",
        totals["dark_removed"], totals["css_cleaned"],
        totals["renamed"], totals["format_fixes"]))


if __name__ == "__main__":
    main()
