#!/usr/bin/env python3
"""
reduce_colors.py — Merge similar colors and absorb tiny slivers in SVG files.

Designed for the One Hue artwork pipeline. Processes SVGs that use CSS classes
in a <style> block (e.g. .cls-1 { fill: #241a4b; }) and paths that reference
them via class="cls-1".

Steps:
  1. Parse all CSS classes and their fill colors from the <style> block.
  2. Convert colors to CIELAB and merge perceptually similar colors (ΔE < threshold).
     The color with the most total path area wins.
  3. Absorb tiny paths (bounding box area < threshold) into their nearest spatial neighbor.
  4. Remove unused CSS classes and renumber sequentially (cls-1, cls-2, ...).

Usage:
  python3 reduce_colors.py <input.svg> [--delta-e 12] [--min-area 2000] [--inplace]
"""

from __future__ import annotations

import argparse
import math
import os
import re
import sys
import xml.etree.ElementTree as ET


# ---------------------------------------------------------------------------
# Color conversion: sRGB -> XYZ -> CIELAB
# Using standard illuminant D65 reference white.
# No external dependencies — pure math.
# ---------------------------------------------------------------------------

D65_X, D65_Y, D65_Z = 95.047, 100.000, 108.883


def hex_to_rgb(h: str) -> tuple[int, int, int]:
    """Parse '#rrggbb' to (r, g, b) in 0-255."""
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def rgb_to_lab(r: int, g: int, b: int) -> tuple[float, float, float]:
    """Convert sRGB (0-255) to CIELAB (L*, a*, b*)."""
    # Linearize sRGB
    def linearize(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    rl, gl, bl = linearize(r), linearize(g), linearize(b)

    # sRGB -> XYZ (D65)
    x = (rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375) * 100.0
    y = (rl * 0.2126729 + gl * 0.7151522 + bl * 0.0721750) * 100.0
    z = (rl * 0.0193339 + gl * 0.1191920 + bl * 0.9503041) * 100.0

    # XYZ -> Lab
    def f(t):
        return t ** (1.0 / 3.0) if t > 0.008856 else (7.787 * t) + (16.0 / 116.0)

    fx, fy, fz = f(x / D65_X), f(y / D65_Y), f(z / D65_Z)

    L = 116.0 * fy - 16.0
    a = 500.0 * (fx - fy)
    b_val = 200.0 * (fy - fz)
    return L, a, b_val


def delta_e(lab1: tuple, lab2: tuple) -> float:
    """CIE76 color difference (Euclidean distance in Lab space)."""
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(lab1, lab2)))


# ---------------------------------------------------------------------------
# SVG parsing helpers
# ---------------------------------------------------------------------------

# Regex for CSS class definitions: .cls-N { fill: #rrggbb; }
CSS_CLASS_RE = re.compile(
    r"\.(cls-\d+)\s*\{\s*fill:\s*(#[0-9a-fA-F]{6})\s*;\s*\}"
)

# Namespace handling for SVG
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)


def parse_style_block(svg_root: ET.Element) -> tuple[ET.Element | None, dict[str, str]]:
    """
    Find the <style> element and parse CSS class -> fill color mappings.
    Returns (style_element, {class_name: hex_color}).
    """
    style_el = svg_root.find(f".//{{{SVG_NS}}}style")
    if style_el is None:
        # Try without namespace (some SVGs omit it)
        style_el = svg_root.find(".//style")

    if style_el is None or not style_el.text:
        return None, {}

    classes = {}
    for match in CSS_CLASS_RE.finditer(style_el.text):
        cls_name, color = match.group(1), match.group(2).lower()
        classes[cls_name] = color

    return style_el, classes


def extract_path_coords(d: str) -> list[tuple[float, float]]:
    """
    Extract approximate coordinate pairs from an SVG path 'd' attribute.
    Grabs all numbers and pairs them up. This gives a rough bounding box —
    not geometrically exact, but good enough for neighbor detection.
    """
    # Find all numbers (including negative and decimal)
    nums = re.findall(r"-?\d+\.?\d*", d)
    coords = []
    i = 0
    while i + 1 < len(nums):
        try:
            x, y = float(nums[i]), float(nums[i + 1])
            # Sanity check: skip values that are clearly not coordinates
            # (e.g. arc flags). Keep values in a reasonable SVG range.
            if -5000 < x < 5000 and -5000 < y < 5000:
                coords.append((x, y))
        except ValueError:
            pass
        i += 2
    return coords


def bounding_box(coords: list[tuple[float, float]]) -> tuple[float, float, float, float] | None:
    """Return (min_x, min_y, max_x, max_y) or None if no coords."""
    if not coords:
        return None
    xs = [c[0] for c in coords]
    ys = [c[1] for c in coords]
    return min(xs), min(ys), max(xs), max(ys)


def bbox_area(bbox: tuple[float, float, float, float]) -> float:
    """Area of a bounding box."""
    return max(0, bbox[2] - bbox[0]) * max(0, bbox[3] - bbox[1])


def bbox_distance(a: tuple, b: tuple) -> float:
    """
    Minimum distance between two bounding boxes.
    Returns 0 if they overlap.
    """
    # Horizontal gap
    dx = max(0, a[0] - b[2], b[0] - a[2])
    # Vertical gap
    dy = max(0, a[1] - b[3], b[1] - a[3])
    return math.sqrt(dx * dx + dy * dy)


def bbox_overlap_length(a: tuple, b: tuple) -> float:
    """
    Approximate shared boundary length between two bounding boxes.
    Uses overlap of edges as a proxy for shared boundary.
    """
    # Horizontal overlap range
    x_overlap = max(0, min(a[2], b[2]) - max(a[0], b[0]))
    # Vertical overlap range
    y_overlap = max(0, min(a[3], b[3]) - max(a[1], b[1]))

    # If boxes overlap, shared boundary is the perimeter of intersection
    if x_overlap > 0 and y_overlap > 0:
        return 2 * (x_overlap + y_overlap)

    # If they are adjacent (one axis overlaps, other is near-zero gap)
    margin = 5.0  # SVG units tolerance for "adjacent"
    dx = max(0, a[0] - b[2], b[0] - a[2])
    dy = max(0, a[1] - b[3], b[1] - a[3])

    if dx <= margin and y_overlap > 0:
        return y_overlap
    if dy <= margin and x_overlap > 0:
        return x_overlap

    return 0.0


def centroid(bbox: tuple) -> tuple[float, float]:
    """Center point of a bounding box."""
    return ((bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2)


def centroid_distance(a: tuple, b: tuple) -> float:
    """Euclidean distance between bounding box centroids."""
    ca, cb = centroid(a), centroid(b)
    return math.sqrt((ca[0] - cb[0]) ** 2 + (ca[1] - cb[1]) ** 2)


# ---------------------------------------------------------------------------
# Path info extraction
# ---------------------------------------------------------------------------

def get_all_paths(svg_root: ET.Element) -> list[dict]:
    """
    Extract info about every path/polygon/rect with a class attribute.
    Returns list of dicts with keys: element, class_name, bbox, area.
    """
    paths = []

    for tag in ["path", "polygon", "rect", "circle", "ellipse"]:
        for el in svg_root.iter(f"{{{SVG_NS}}}{tag}"):
            cls = el.get("class", "").strip()
            if not cls:
                # Try without namespace
                continue

            d = el.get("d", "")
            # For polygons, use 'points' attribute
            if not d:
                points = el.get("points", "")
                if points:
                    d = points

            # For rects, synthesize coordinates
            if not d and tag == "rect":
                try:
                    rx = float(el.get("x", 0))
                    ry = float(el.get("y", 0))
                    rw = float(el.get("width", 0))
                    rh = float(el.get("height", 0))
                    d = f"{rx},{ry} {rx+rw},{ry} {rx+rw},{ry+rh} {rx},{ry+rh}"
                except (ValueError, TypeError):
                    continue

            coords = extract_path_coords(d)
            bb = bounding_box(coords)

            if bb is None:
                continue

            area = bbox_area(bb)
            paths.append({
                "element": el,
                "class_name": cls,
                "bbox": bb,
                "area": area,
            })

    # Also check without namespace prefix
    for tag in ["path", "polygon", "rect", "circle", "ellipse"]:
        for el in svg_root.iter(tag):
            cls = el.get("class", "").strip()
            if not cls:
                continue
            # Skip if already processed (has SVG namespace)
            if el in [p["element"] for p in paths]:
                continue

            d = el.get("d", "")
            if not d:
                points = el.get("points", "")
                if points:
                    d = points
            if not d and tag == "rect":
                try:
                    rx = float(el.get("x", 0))
                    ry = float(el.get("y", 0))
                    rw = float(el.get("width", 0))
                    rh = float(el.get("height", 0))
                    d = f"{rx},{ry} {rx+rw},{ry} {rx+rw},{ry+rh} {rx},{ry+rh}"
                except (ValueError, TypeError):
                    continue

            coords = extract_path_coords(d)
            bb = bounding_box(coords)
            if bb is None:
                continue

            paths.append({
                "element": el,
                "class_name": cls,
                "bbox": bb,
                "area": bbox_area(bb),
            })

    return paths


# ---------------------------------------------------------------------------
# Step 1: Merge similar colors
# ---------------------------------------------------------------------------

def merge_similar_colors(
    class_colors: dict[str, str],
    paths: list[dict],
    max_delta_e: float,
) -> dict[str, str]:
    """
    Merge colors within ΔE threshold. Returns a mapping of
    old_class -> new_class (the winner class that keeps its color).

    The winning color in each merge group is the one with the most
    total path area across all paths using that class.
    """
    # Compute total area per class
    area_per_class: dict[str, float] = {}
    for p in paths:
        cls = p["class_name"]
        area_per_class[cls] = area_per_class.get(cls, 0) + p["area"]

    # Convert all colors to Lab
    class_labs: dict[str, tuple] = {}
    for cls, color in class_colors.items():
        rgb = hex_to_rgb(color)
        class_labs[cls] = rgb_to_lab(*rgb)

    # Build merge groups using union-find
    parent: dict[str, str] = {cls: cls for cls in class_colors}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra == rb:
            return
        # Winner is the one with more total area
        if area_per_class.get(ra, 0) >= area_per_class.get(rb, 0):
            parent[rb] = ra
        else:
            parent[ra] = rb

    # Compare all pairs of classes
    class_list = sorted(class_colors.keys())
    for i in range(len(class_list)):
        for j in range(i + 1, len(class_list)):
            ci, cj = class_list[i], class_list[j]
            de = delta_e(class_labs[ci], class_labs[cj])
            if de < max_delta_e:
                union(ci, cj)

    # Build remap: every class -> its group's root
    remap = {}
    for cls in class_list:
        remap[cls] = find(cls)

    return remap


# ---------------------------------------------------------------------------
# Step 2: Absorb tiny slivers
# ---------------------------------------------------------------------------

def absorb_tiny_paths(
    paths: list[dict],
    min_area: float,
    class_remap: dict[str, str],
) -> dict[str, str]:
    """
    For paths below min_area, reassign their class to their nearest
    spatial neighbor's class. Modifies class_remap in place and returns it.

    Neighbor selection priority:
      1. Largest shared boundary (bbox overlap)
      2. Closest centroid distance
    """
    # Separate tiny and normal paths
    tiny_paths = [p for p in paths if p["area"] < min_area]
    normal_paths = [p for p in paths if p["area"] >= min_area]

    if not normal_paths:
        return class_remap

    absorbed_count = 0

    for tp in tiny_paths:
        best_neighbor = None
        best_overlap = -1.0
        best_dist = float("inf")

        tp_bbox = tp["bbox"]
        tp_cls = class_remap.get(tp["class_name"], tp["class_name"])

        # Search margin: look at paths within a reasonable distance
        for np in normal_paths:
            np_cls = class_remap.get(np["class_name"], np["class_name"])
            # Skip if same color — no need to absorb into same color
            if np_cls == tp_cls:
                continue

            dist = bbox_distance(tp_bbox, np["bbox"])
            # Only consider neighbors within 50 SVG units
            if dist > 50:
                continue

            overlap = bbox_overlap_length(tp_bbox, np["bbox"])

            # Prefer largest shared boundary, break ties by closest centroid
            if overlap > best_overlap or (
                overlap == best_overlap
                and centroid_distance(tp_bbox, np["bbox"]) < best_dist
            ):
                best_neighbor = np
                best_overlap = overlap
                best_dist = centroid_distance(tp_bbox, np["bbox"])

        # If no neighbor found within margin, expand search to any path
        if best_neighbor is None:
            for np in normal_paths:
                np_cls = class_remap.get(np["class_name"], np["class_name"])
                if np_cls == tp_cls:
                    continue
                cd = centroid_distance(tp_bbox, np["bbox"])
                if cd < best_dist:
                    best_dist = cd
                    best_neighbor = np

        if best_neighbor is not None:
            target_cls = class_remap.get(
                best_neighbor["class_name"], best_neighbor["class_name"]
            )
            # Update remap for this tiny path's original class
            # But only for this specific element — we'll handle per-element below
            tp["_absorbed_to"] = target_cls
            absorbed_count += 1

    return absorbed_count


# ---------------------------------------------------------------------------
# Step 3: Clean up — remove unused classes, renumber sequentially
# ---------------------------------------------------------------------------

def rebuild_style_block(
    used_classes: set[str],
    class_colors: dict[str, str],
) -> str:
    """Build a clean style block with only used classes, renumbered sequentially."""
    # Sort classes for deterministic output
    sorted_classes = sorted(used_classes, key=lambda c: int(re.search(r"\d+", c).group()))

    # Create new numbering
    remap = {}
    lines = []
    for i, old_cls in enumerate(sorted_classes, start=1):
        new_cls = f"cls-{i}"
        remap[old_cls] = new_cls
        color = class_colors[old_cls]
        lines.append(f"      .{new_cls} {{\n        fill: {color};\n      }}")

    style_text = "\n\n".join(lines)
    return style_text, remap


# ---------------------------------------------------------------------------
# Main processing pipeline
# ---------------------------------------------------------------------------

def process_svg(input_path: str, max_delta_e: float, min_area: float, inplace: bool):
    """Full pipeline: parse -> merge colors -> absorb slivers -> clean up -> write."""

    # Parse the SVG
    tree = ET.parse(input_path)
    root = tree.getroot()

    # Extract style block and class->color mappings
    style_el, class_colors = parse_style_block(root)
    if not class_colors:
        print("ERROR: No CSS classes with fill colors found in <style> block.")
        sys.exit(1)

    original_color_count = len(set(class_colors.values()))
    original_class_count = len(class_colors)

    print(f"Input: {os.path.basename(input_path)}")
    print(f"  Classes: {original_class_count}")
    print(f"  Unique colors: {original_color_count}")

    # Extract all paths with their bounding boxes
    paths = get_all_paths(root)
    print(f"  Paths/shapes: {len(paths)}")

    # --- Step 1: Merge similar colors ---
    class_remap = merge_similar_colors(class_colors, paths, max_delta_e)

    # Count merges
    merge_groups: dict[str, list[str]] = {}
    for old, new in class_remap.items():
        merge_groups.setdefault(new, []).append(old)

    merged_count = sum(1 for g in merge_groups.values() if len(g) > 1)
    classes_eliminated = sum(len(g) - 1 for g in merge_groups.values() if len(g) > 1)

    print(f"\n  Color merge (ΔE < {max_delta_e}):")
    print(f"    Groups merged: {merged_count}")
    print(f"    Classes eliminated: {classes_eliminated}")

    # Show merge details
    for root_cls, members in sorted(merge_groups.items()):
        if len(members) > 1:
            color_list = ", ".join(
                f"{m}={class_colors[m]}" for m in sorted(members)
            )
            print(f"    Merged: [{color_list}] -> {root_cls} ({class_colors[root_cls]})")

    # Apply color merges to path elements
    for p in paths:
        old_cls = p["class_name"]
        new_cls = class_remap.get(old_cls, old_cls)
        if new_cls != old_cls:
            p["element"].set("class", new_cls)
            p["class_name"] = new_cls

    # --- Step 2: Absorb tiny slivers ---
    absorbed_count = absorb_tiny_paths(paths, min_area, class_remap)

    print(f"\n  Sliver absorption (area < {min_area}):")
    print(f"    Paths absorbed: {absorbed_count}")

    # Apply sliver absorptions to elements
    for p in paths:
        if "_absorbed_to" in p:
            p["element"].set("class", p["_absorbed_to"])
            p["class_name"] = p["_absorbed_to"]

    # --- Step 3: Clean up ---
    # Determine which classes are actually used
    used_classes = set()
    for p in paths:
        used_classes.add(p["class_name"])

    # Also check for any elements we didn't find in get_all_paths
    # (fallback: scan all elements with class attributes)
    for el in root.iter():
        cls = el.get("class", "").strip()
        if cls and cls in class_colors:
            if cls not in class_remap:
                used_classes.add(cls)
            else:
                # This element might not have been updated by our path loop
                remapped = class_remap.get(cls, cls)
                if remapped != cls:
                    el.set("class", remapped)
                used_classes.add(remapped)

    # Build color map for used classes (using the root class's color)
    used_class_colors = {}
    for cls in used_classes:
        if cls in class_colors:
            used_class_colors[cls] = class_colors[cls]

    unused_removed = original_class_count - len(used_class_colors)

    # Renumber classes sequentially
    new_style_text, renumber_map = rebuild_style_block(used_class_colors, class_colors)

    # Apply renumbering to all elements
    for el in root.iter():
        cls = el.get("class", "").strip()
        if cls in renumber_map:
            el.set("class", renumber_map[cls])

    # Update the style block
    style_el.text = "\n" + new_style_text + "\n    "

    final_color_count = len(set(used_class_colors.values()))
    final_class_count = len(used_class_colors)

    print(f"\n  Cleanup:")
    print(f"    Unused classes removed: {unused_removed}")
    print(f"    Final classes: {final_class_count} (renumbered cls-1 .. cls-{final_class_count})")
    print(f"    Final unique colors: {final_color_count}")

    # --- Write output ---
    if inplace:
        output_path = input_path
    else:
        base, ext = os.path.splitext(input_path)
        output_path = f"{base}_reduced{ext}"

    # Write with XML declaration
    tree.write(output_path, encoding="unicode", xml_declaration=True)

    # ET doesn't preserve the original XML declaration exactly,
    # so we fix it up to match the expected format
    with open(output_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Ensure proper XML declaration
    content = re.sub(
        r"<\?xml[^?]*\?>",
        "<?xml version='1.0' encoding='UTF-8'?>",
        content,
    )

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"\n  Summary: {original_color_count} colors -> {final_color_count} colors")
    print(f"  Output: {output_path}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Merge similar colors and absorb tiny slivers in SVG files.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 reduce_colors.py artwork.svg
  python3 reduce_colors.py artwork.svg --delta-e 15 --min-area 3000
  python3 reduce_colors.py artwork.svg --inplace
        """,
    )
    parser.add_argument("input", help="Input SVG file path")
    parser.add_argument(
        "--delta-e",
        type=float,
        default=12.0,
        help="Max perceptual color distance (CIELAB ΔE) for merging (default: 12)",
    )
    parser.add_argument(
        "--min-area",
        type=float,
        default=2000.0,
        help="Min bounding-box area in sq SVG units; smaller paths get absorbed (default: 2000)",
    )
    parser.add_argument(
        "--inplace",
        action="store_true",
        help="Overwrite the input file instead of writing *_reduced.svg",
    )

    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f"ERROR: File not found: {args.input}")
        sys.exit(1)

    process_svg(args.input, args.delta_e, args.min_area, args.inplace)


if __name__ == "__main__":
    main()
