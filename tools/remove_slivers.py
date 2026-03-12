#!/usr/bin/env python3
"""
Remove tiny sliver/artifact elements and edge bands from SVG artwork files.

Parses each SVG, computes bounding boxes for all shape elements
(path, rect, circle, ellipse, polygon), and removes:
  1. Slivers — elements whose min dimension falls below a threshold
  2. Edge bands — thin strips hugging the top/bottom of the viewBox
     (a common artifact from Adobe Illustrator Image Trace)

Usage:
    python3 tools/remove_slivers.py [--threshold 8] [--dry-run]
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


def is_sliver(bbox, threshold, aspect_threshold):
    """
    Determine if an element is a sliver/artifact.

    A sliver is an element where:
    - min(width, height) < threshold (tiny in at least one dimension), OR
    - area is very small (< threshold^2 / 4), OR
    - aspect ratio is extreme (> aspect_threshold) AND one dimension is small
    """
    if bbox is None:
        return True  # can't compute bbox = likely degenerate

    x, y, w, h = bbox
    min_dim = min(w, h)
    max_dim = max(w, h)
    area = w * h

    # Truly tiny: min dimension below threshold
    if min_dim < threshold:
        return True

    # Very small area even if somewhat square
    if area < (threshold * threshold) / 2:
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


def process_svg(filepath, threshold, aspect_threshold, dry_run):
    """Process a single SVG file, removing sliver and edge band elements."""
    tree = ET.parse(filepath)
    root = tree.getroot()
    vb_width, vb_height = parse_viewbox(root)

    removed = []
    kept = 0

    # Find all shape elements at any depth
    parents_map = {child: parent for parent in root.iter() for child in parent}

    all_shapes = []
    for elem in list(root.iter()):
        if elem.tag in SHAPE_TAGS:
            all_shapes.append(elem)

    for elem in all_shapes:
        bbox = get_bbox(elem, elem.tag)
        reason = None

        if is_sliver(bbox, threshold, aspect_threshold):
            reason = "sliver"
        elif is_horizontal_band(bbox, vb_width):
            reason = "band"

        if reason:
            parent = parents_map.get(elem)
            if parent is not None:
                local_tag = elem.tag.replace(f"{{{SVG_NS}}}", "")
                cls = elem.get("class", "")
                if bbox:
                    x, y, w, h = bbox
                    removed.append(f"  {local_tag} class={cls} bbox=({w:.1f}x{h:.1f}) [{reason}]")
                else:
                    removed.append(f"  {local_tag} class={cls} bbox=None [{reason}]")
                if not dry_run:
                    parent.remove(elem)
        else:
            kept += 1

    if not dry_run and removed:
        # Write back, preserving XML declaration
        tree.write(filepath, encoding="UTF-8", xml_declaration=True)

    return kept, removed


def main():
    parser = argparse.ArgumentParser(description="Remove tiny sliver elements from SVG artworks")
    parser.add_argument("--threshold", type=float, default=8.0,
                        help="Minimum dimension in SVG units (default: 8)")
    parser.add_argument("--aspect-threshold", type=float, default=20.0,
                        help="Aspect ratio threshold for sliver detection (default: 20)")
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

    mode = "DRY RUN" if args.dry_run else "REMOVING"
    print(f"\n{mode} slivers with threshold={args.threshold} SVG units\n")

    total_removed = 0
    total_kept = 0

    for filepath in svg_files:
        name = os.path.basename(filepath)
        kept, removed = process_svg(filepath, args.threshold, args.aspect_threshold, args.dry_run)
        total_kept += kept
        total_removed += len(removed)

        if removed:
            print(f"{name}: {kept} kept, {len(removed)} removed")
            for desc in removed:
                print(desc)
        else:
            print(f"{name}: {kept} elements, all clean")

    print(f"\nTotal: {total_kept} kept, {total_removed} removed across {len(svg_files)} files")


if __name__ == "__main__":
    main()
