#!/usr/bin/env python3
"""
Merge near-duplicate CSS color classes in SVG files.

For each SVG, computes perceptual color distances, clusters similar colors,
and merges them by rewriting CSS classes on elements and in the style block.
"""

import re
import sys
import os
from xml.etree import ElementTree as ET

SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def color_distance(hex1, hex2):
    """Weighted Euclidean distance with redmean correction (good perceptual approx)."""
    r1, g1, b1 = hex_to_rgb(hex1)
    r2, g2, b2 = hex_to_rgb(hex2)
    rmean = (r1 + r2) / 2
    dr = r1 - r2
    dg = g1 - g2
    db = b1 - b2
    return ((2 + rmean / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rmean) / 256) * db * db) ** 0.5


def parse_style_colors(style_text):
    """Extract class→hex mapping from CSS style block."""
    return dict(re.findall(r"\.(cls-\d+)\s*\{\s*fill:\s*(#[0-9a-fA-F]{6})", style_text))


def cluster_colors(colors_dict, target_count):
    """
    Agglomerative clustering: merge closest color pairs until we reach target_count.
    Returns a mapping: original_class → surviving_class.
    """
    # Start with each class as its own cluster
    clusters = {cls: [cls] for cls in colors_dict}
    hex_map = dict(colors_dict)  # cls → hex

    while len(clusters) > target_count:
        # Find the two closest clusters
        best_dist = float("inf")
        best_pair = None

        keys = list(clusters.keys())
        for i in range(len(keys)):
            for j in range(i + 1, len(keys)):
                d = color_distance(hex_map[keys[i]], hex_map[keys[j]])
                if d < best_dist:
                    best_dist = d
                    best_pair = (keys[i], keys[j])

        if best_pair is None:
            break

        a, b = best_pair
        # Merge b into a (keep a's color — it's arbitrary, pick the one with more elements)
        clusters[a].extend(clusters[b])
        del clusters[b]

    # Build mapping: every original class → its cluster representative
    mapping = {}
    for representative, members in clusters.items():
        for cls in members:
            mapping[cls] = representative

    return mapping


def count_elements_per_class(root):
    """Count how many shape elements use each CSS class."""
    counts = {}
    for elem in root.iter():
        cls = elem.get("class", "")
        if cls:
            counts[cls] = counts.get(cls, 0) + 1
    return counts


def apply_merge(filepath, target_count, dry_run=False):
    """Merge colors in an SVG file down to target_count."""
    tree = ET.parse(filepath)
    root = tree.getroot()

    # Find style block
    style_elem = None
    style_text = ""
    for elem in root.iter():
        tag = elem.tag.replace(f"{{{SVG_NS}}}", "")
        if tag == "style" and elem.text:
            style_elem = elem
            style_text = elem.text
            break

    if not style_text:
        print(f"  No style block found, skipping")
        return

    colors = parse_style_colors(style_text)
    if len(colors) <= target_count:
        print(f"  Already at {len(colors)} colors, skipping")
        return

    # Count elements per class to prefer keeping the more-used class
    elem_counts = count_elements_per_class(root)

    # Cluster
    mapping = cluster_colors(colors, target_count)

    # For each cluster, pick the representative as the class with most elements
    clusters = {}
    for cls, rep in mapping.items():
        if rep not in clusters:
            clusters[rep] = []
        clusters[rep].append(cls)

    # Re-pick representatives by element count
    final_mapping = {}
    for rep, members in clusters.items():
        best = max(members, key=lambda c: elem_counts.get(c, 0))
        for cls in members:
            final_mapping[cls] = best

    # Report merges
    merges = [(cls, target) for cls, target in final_mapping.items() if cls != target]
    merges.sort(key=lambda m: m[0])

    if not merges:
        print(f"  No merges needed")
        return

    print(f"  Merging {len(colors)} → {len(colors) - len(merges)} colors:")
    for cls, target in merges:
        count = elem_counts.get(cls, 0)
        print(f"    {cls} ({colors[cls]}, {count} elem) → {target} ({colors[target]})")

    if dry_run:
        return

    # 1. Update class attributes on all elements
    for elem in root.iter():
        cls = elem.get("class", "")
        if cls in final_mapping and final_mapping[cls] != cls:
            elem.set("class", final_mapping[cls])

    # 2. Remove merged classes from the style block
    merged_away = {cls for cls, target in final_mapping.items() if cls != target}
    new_style_lines = []
    for line in style_text.split("\n"):
        # Check if this line starts a rule for a merged-away class
        match = re.match(r"\s*\.(cls-\d+)\s*\{", line)
        if match and match.group(1) in merged_away:
            continue
        # Also skip standalone fill lines for removed classes
        if any(f".{cls}" in line for cls in merged_away):
            continue
        new_style_lines.append(line)

    # Rebuild style — handle multi-line CSS rules
    cleaned = re.sub(
        r"\.(cls-\d+)\s*\{[^}]*\}",
        lambda m: "" if m.group(1) in merged_away else m.group(0),
        style_text,
    )
    style_elem.text = cleaned

    tree.write(filepath, encoding="UTF-8", xml_declaration=True)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", type=int, default=10, help="Target number of colors")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("files", nargs="+", help="SVG files to process")
    args = parser.parse_args()

    for filepath in args.files:
        name = os.path.basename(filepath)
        print(f"\n{name}:")
        apply_merge(filepath, args.target, args.dry_run)


if __name__ == "__main__":
    main()
