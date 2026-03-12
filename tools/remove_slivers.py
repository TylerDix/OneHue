#!/usr/bin/env python3
"""
Remove tiny sliver/artifact elements and edge bands from SVG artwork files.

Parses each SVG, computes bounding boxes for all shape elements
(path, rect, circle, ellipse, polygon), and removes:
  1. Slivers — elements whose min dimension falls below a threshold
  2. Small specks — elements whose area falls below an area threshold
  3. Edge bands — thin strips hugging the top/bottom of the viewBox
     (a common artifact from Adobe Illustrator Image Trace)

Usage:
    python3 tools/remove_slivers.py [--threshold 12] [--area-threshold 100]
                                    [--dry-run] [--file X.svg]
"""

import argparse
import glob
import os
import re
import math
from xml.etree import ElementTree as ET
from svgpathtools import parse_path

ARTWORKS_DIR = os.path.join(os.path.dirname(__file__), "..", "One Hue", "Artworks")
SVG_NS = "http://www.w3.org/2000/svg"

# Register SVG namespace to preserve it in output
ET.register_namespace("", SVG_NS)


def bbox_of_path(d_attr):
    """Compute bounding box of an SVG path using svgpathtools."""
    try:
        path = parse_path(d_attr)
        if len(path) == 0:
            return None
        xmin, xmax, ymin, ymax = path.bbox()
        return (xmin, ymin, xmax - xmin, ymax - ymin)  # x, y, w, h
    except Exception:
        return None


def bbox_of_rect(elem):
    """Compute bounding box of a <rect> element."""
    x = float(elem.get("x", 0))
    y = float(elem.get("y", 0))
    w = float(elem.get("width", 0))
    h = float(elem.get("height", 0))
    return (x, y, w, h)


def bbox_of_circle(elem):
    """Compute bounding box of a <circle> element."""
    cx = float(elem.get("cx", 0))
    cy = float(elem.get("cy", 0))
    r = float(elem.get("r", 0))
    return (cx - r, cy - r, 2 * r, 2 * r)


def bbox_of_ellipse(elem):
    """Compute bounding box of an <ellipse> element."""
    cx = float(elem.get("cx", 0))
    cy = float(elem.get("cy", 0))
    rx = float(elem.get("rx", 0))
    ry = float(elem.get("ry", 0))
    return (cx - rx, cy - ry, 2 * rx, 2 * ry)


def bbox_of_polygon(elem):
    """Compute bounding box of a <polygon> element."""
    points_str = elem.get("points", "")
    if not points_str.strip():
        return None
    coords = re.findall(r"[-+]?[0-9]*\.?[0-9]+", points_str)
    if len(coords) < 4:
        return None
    xs = [float(coords[i]) for i in range(0, len(coords), 2)]
    ys = [float(coords[i]) for i in range(1, len(coords), 2)]
    xmin, xmax = min(xs), max(xs)
    ymin, ymax = min(ys), max(ys)
    return (xmin, ymin, xmax - xmin, ymax - ymin)


def get_bbox(elem, tag):
    """Get bounding box for any supported SVG shape element."""
    local_tag = tag.replace(f"{{{SVG_NS}}}", "")
    if local_tag == "path":
        d = elem.get("d")
        if d:
            return bbox_of_path(d)
    elif local_tag == "rect":
        return bbox_of_rect(elem)
    elif local_tag == "circle":
        return bbox_of_circle(elem)
    elif local_tag == "ellipse":
        return bbox_of_ellipse(elem)
    elif local_tag == "polygon":
        return bbox_of_polygon(elem)
    return None


SHAPE_TAGS = {
    f"{{{SVG_NS}}}path", f"{{{SVG_NS}}}rect", f"{{{SVG_NS}}}circle",
    f"{{{SVG_NS}}}ellipse", f"{{{SVG_NS}}}polygon",
    "path", "rect", "circle", "ellipse", "polygon",
}


def is_sliver(bbox, threshold, area_threshold):
    """
    Determine if an element is a sliver/artifact.

    A sliver is an element where:
    - min(width, height) < threshold (tiny in at least one dimension), OR
    - area < area_threshold (small overall even if somewhat square)
    """
    if bbox is None:
        return True  # can't compute bbox = likely degenerate

    x, y, w, h = bbox
    min_dim = min(w, h)
    area = w * h

    # Truly tiny: min dimension below threshold
    if min_dim < threshold:
        return True

    # Very small area even if somewhat square
    if area < area_threshold:
        return True

    return False


def is_horizontal_band(bbox, vb_width, min_width_frac=0.30, max_height=25, min_aspect=10):
    """
    Determine if an element is a horizontal band artifact (interior or edge).

    Bands are thin horizontal strips spanning a significant portion of the
    viewport width with a high aspect ratio. Common Image Trace artifact.
    """
    if bbox is None:
        return False

    x, y, w, h = bbox
    if h <= 0:
        h = 0.001
    if w < vb_width * min_width_frac:
        return False
    if h > max_height:
        return False
    if w / h < min_aspect:
        return False
    return True


def parse_viewbox(root):
    """Extract viewBox dimensions from SVG root element."""
    vb_str = root.get("viewBox", "")
    if not vb_str:
        # Fallback: try width/height attributes
        w = float(root.get("width", "1200").replace("px", ""))
        h = float(root.get("height", "1800").replace("px", ""))
        return w, h
    parts = vb_str.split()
    if len(parts) == 4:
        return float(parts[2]), float(parts[3])
    return 1200.0, 1800.0


def process_svg(filepath, threshold, area_threshold, dry_run):
    """Process a single SVG file, removing sliver and edge band elements."""
    tree = ET.parse(filepath)
    root = tree.getroot()
    vb_width, vb_height = parse_viewbox(root)

    removed_slivers = 0
    removed_bands = 0
    removed_degenerate = 0
    kept = 0

    # Find all shape elements at any depth
    parents_map = {child: parent for parent in root.iter() for child in parent}

    all_shapes = []
    for elem in list(root.iter()):
        if elem.tag in SHAPE_TAGS:
            all_shapes.append(elem)

    total_before = len(all_shapes)

    for elem in all_shapes:
        bbox = get_bbox(elem, elem.tag)
        reason = None

        if bbox is None:
            reason = "degenerate"
        elif is_sliver(bbox, threshold, area_threshold):
            reason = "sliver"
        elif is_horizontal_band(bbox, vb_width):
            reason = "band"

        if reason:
            parent = parents_map.get(elem)
            if parent is not None and not dry_run:
                parent.remove(elem)
            if reason == "sliver":
                removed_slivers += 1
            elif reason == "band":
                removed_bands += 1
            else:
                removed_degenerate += 1
        else:
            kept += 1

    total_removed = removed_slivers + removed_bands + removed_degenerate

    if not dry_run and total_removed > 0:
        # Write back, preserving XML declaration
        tree.write(filepath, encoding="UTF-8", xml_declaration=True)

    return {
        "before": total_before,
        "after": kept,
        "slivers": removed_slivers,
        "bands": removed_bands,
        "degenerate": removed_degenerate,
        "total_removed": total_removed,
    }


def main():
    parser = argparse.ArgumentParser(description="Remove tiny sliver elements from SVG artworks")
    parser.add_argument("--threshold", type=float, default=12.0,
                        help="Min dimension in SVG units (default: 12)")
    parser.add_argument("--area-threshold", type=float, default=100.0,
                        help="Min area in SVG units² (default: 100)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Report what would be removed without modifying files")
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

    mode = "DRY RUN" if args.dry_run else "CLEANING"
    print(f"\n{mode} — threshold={args.threshold}, area={args.area_threshold}\n")

    # Column widths
    name_w = 30
    header = f"{'File':<{name_w}} {'Before':>7} {'After':>7} {'Slivers':>8} {'Bands':>6} {'Degen':>6}"
    print(header)
    print("─" * len(header))

    grand = {"before": 0, "after": 0, "slivers": 0, "bands": 0, "degenerate": 0, "total_removed": 0}

    for filepath in svg_files:
        name = os.path.basename(filepath)
        stats = process_svg(filepath, args.threshold, args.area_threshold, args.dry_run)

        for k in grand:
            grand[k] += stats[k]

        if stats["total_removed"] > 0:
            print(f"{name:<{name_w}} {stats['before']:>7} {stats['after']:>7} {stats['slivers']:>8} {stats['bands']:>6} {stats['degenerate']:>6}")

    print("─" * len(header))
    print(f"{'TOTAL (' + str(len(svg_files)) + ' files)':<{name_w}} {grand['before']:>7} {grand['after']:>7} {grand['slivers']:>8} {grand['bands']:>6} {grand['degenerate']:>6}")
    print(f"\n{grand['total_removed']} elements removed across {len(svg_files)} files")


if __name__ == "__main__":
    main()
