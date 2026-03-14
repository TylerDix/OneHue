#!/usr/bin/env python3
"""
Fix older SVGs: merge colors to 10, remove white+dark artifacts, standardize format.

Only targets the 66 "older" SVGs that pre-date the newer batch. The newer SVGs
(added in commits c661f49 and 0165d54) are left untouched — they're already clean.

Steps for each older SVG:
  1. Remove tiny near-black artifact paths (lum < 25, small bbox)
  2. Remove tiny near-white artifact paths (lum > 240, small bbox)
  3. If >10 colors remain, agglomerative-merge closest pairs down to 10
  4. Rename all classes to sequential cls-1..cls-N sorted by luminance
  5. Normalize SVG root attributes (width/height, remove Illustrator cruft)

Usage:
    python3 tools/fix_old_svgs.py [--dry-run] [--file X.svg]
"""

import argparse
import glob
import os
import re
from xml.etree import ElementTree as ET

ARTWORKS_DIR = os.path.join(os.path.dirname(__file__), "..", "One Hue", "Artworks")
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

TARGET_COLORS = 10

# The 66 older SVGs (pre-date the newer batches)
OLD_SVGS = set("""airBalloon balloonFestival baloon bench canyon cathedral desert
driedFlowerBouquet elephantSavanna fishingBoats flamingoLagoon floodedDockTwilight
forestPuddleLeaves heronGoldenHour heronMoonlitLake highway home hummingbirdGarden
japanese jellyfishDeepSea koi_pond lantern lantern2 lighthouse logCabinSmoke
mangroveHeron mapleSeeds mistyFjordDawn moon mossyWaterfall mountain nightTrainStars
northerlights openPitMine orcaBreaching ospreyDive owlSunsetBranch papayaTree
paperLanternShop pitcherPlantsBog polarBearIce riceTerraces ropeBridgeJungle
rowboatShallows saltFlatSolitude seaAnemoneRock seaStack seaStackReflection seaTurtleReef
sealOnRock shorebirdsFlats snowyVillage starFish steamingCraterPool stormPetrelSea
tabbyCatWindowsill temple termiteMound toucanTropical turtles volcanoCraterLake
whaleTailOcean wheatFieldGoldenHour windowsillBottles wolfSnow wrenCactusSunset""".split())

# --- Color helpers ---

def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = h[0]*2 + h[1]*2 + h[2]*2
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def rgb_to_hex(r, g, b):
    return "#{:02x}{:02x}{:02x}".format(int(r), int(g), int(b))


def luminance(hex_color):
    r, g, b = hex_to_rgb(hex_color)
    return 0.299 * r + 0.587 * g + 0.114 * b


def redmean_distance(hex1, hex2):
    """Perceptual color distance using redmean formula."""
    r1, g1, b1 = hex_to_rgb(hex1)
    r2, g2, b2 = hex_to_rgb(hex2)
    rmean = (r1 + r2) / 2.0
    dr, dg, db = r1 - r2, g1 - g2, b1 - b2
    return ((2 + rmean/256)*dr*dr + 4*dg*dg + (2 + (255-rmean)/256)*db*db) ** 0.5


def weighted_avg_color(hex1, count1, hex2, count2):
    """Weighted average of two colors by their path counts."""
    r1, g1, b1 = hex_to_rgb(hex1)
    r2, g2, b2 = hex_to_rgb(hex2)
    total = count1 + count2
    if total == 0:
        total = 1
    r = (r1 * count1 + r2 * count2) / total
    g = (g1 * count1 + g2 * count2) / total
    b = (b1 * count1 + b2 * count2) / total
    return rgb_to_hex(r, g, b)


# --- Bbox helpers ---

def estimate_path_bbox(d_attr):
    """Estimate bounding box from path d-attribute using coordinate extraction."""
    if not d_attr or not d_attr.strip():
        return None
    nums = re.findall(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?', d_attr)
    if len(nums) < 4:
        return None
    floats = [float(n) for n in nums]
    xs = floats[0::2]
    ys = floats[1::2]
    if not xs or not ys:
        return None
    xmin, xmax = min(xs), max(xs)
    ymin, ymax = min(ys), max(ys)
    return (xmin, ymin, xmax - xmin, ymax - ymin)


def bbox_area(bbox):
    return bbox[2] * bbox[3] if bbox else 0


def bbox_max_dim(bbox):
    return max(bbox[2], bbox[3]) if bbox else 0


# --- Artifact detection ---

DARK_LUM = 25          # Near-black threshold
WHITE_LUM = 240        # Near-white threshold
SMALL_AREA = 5000      # Artifact area threshold
SMALL_DIM = 80         # Artifact max-dimension threshold
SHORT_PATH = 200       # Short path d-attr length threshold


def is_small_artifact(d_attr):
    """Check if a path element is small enough to be an artifact."""
    bbox = estimate_path_bbox(d_attr)
    area = bbox_area(bbox)
    max_dim = bbox_max_dim(bbox)
    return area < SMALL_AREA or max_dim < SMALL_DIM or len(d_attr) < SHORT_PATH


# --- Core processing ---

def process_svg(filepath, dry_run=False):
    """Process a single older SVG file."""
    name = os.path.basename(filepath)
    basename = name.replace(".svg", "")

    # Skip if not an old SVG
    if basename not in OLD_SVGS:
        return None

    stats = {
        "name": name,
        "dark_removed": 0,
        "white_removed": 0,
        "colors_merged": 0,
        "orig_colors": 0,
        "final_colors": 0,
        "renamed": 0,
        "format_fixes": 0,
    }

    # Parse
    try:
        tree = ET.parse(filepath)
    except ET.ParseError:
        content = open(filepath, 'r', encoding='utf-8', errors='replace').read()
        content = content.replace('encoding="iso-8859-1"', 'encoding="UTF-8"')
        import io
        tree = ET.parse(io.StringIO(content))

    root = tree.getroot()

    # --- Extract style and color map ---
    style_elem = None
    style_text = ""
    for elem in root.iter():
        tag = elem.tag.replace("{%s}" % SVG_NS, "")
        if tag == "style" and elem.text:
            style_elem = elem
            style_text = elem.text
            break

    if not style_text:
        return None

    # Parse colors: handle both cls-N and stN formats
    color_map = {}
    for m in re.finditer(r'\.(cls-\d+|st\d+)\s*\{[^}]*fill:\s*(#[0-9a-fA-F]{3,6})', style_text):
        cls_name = m.group(1)
        hex_color = m.group(2)
        if len(hex_color) == 4:
            hex_color = '#' + hex_color[1]*2 + hex_color[2]*2 + hex_color[3]*2
        color_map[cls_name] = hex_color.lower()

    if not color_map:
        return None

    stats["orig_colors"] = len(color_map)

    # Build parent map for element removal
    parents_map = {child: parent for parent in root.iter() for child in parent}

    # --- Step 1: Remove tiny near-black artifact paths ---
    dark_classes = {c for c, h in color_map.items() if luminance(h) < DARK_LUM}
    dark_removed = []

    for elem in list(root.iter()):
        tag = elem.tag.replace("{%s}" % SVG_NS, "")
        if tag != "path":
            continue
        cls = elem.get("class", "")
        if cls not in dark_classes:
            continue
        d = elem.get("d", "")
        if is_small_artifact(d):
            dark_removed.append(elem)

    for elem in dark_removed:
        parent = parents_map.get(elem)
        if parent is not None and not dry_run:
            parent.remove(elem)
    stats["dark_removed"] = len(dark_removed)

    # --- Step 2: Remove tiny near-white artifact paths ---
    white_classes = {c for c, h in color_map.items() if luminance(h) > WHITE_LUM}
    white_removed = []

    for elem in list(root.iter()):
        tag = elem.tag.replace("{%s}" % SVG_NS, "")
        if tag != "path":
            continue
        cls = elem.get("class", "")
        if cls not in white_classes:
            continue
        d = elem.get("d", "")
        if is_small_artifact(d):
            white_removed.append(elem)

    for elem in white_removed:
        parent = parents_map.get(elem)
        if parent is not None and not dry_run:
            parent.remove(elem)
    stats["white_removed"] = len(white_removed)

    # --- Step 3: Collect remaining classes and their path counts ---
    class_counts = {}
    for elem in root.iter():
        cls = elem.get("class", "")
        if cls and cls in color_map:
            class_counts[cls] = class_counts.get(cls, 0) + 1

    # Remove unused classes from color_map
    active_colors = {c: color_map[c] for c in class_counts}

    # --- Step 4: Agglomerative merge to TARGET_COLORS if needed ---
    if len(active_colors) > TARGET_COLORS:
        # Build cluster list: each cluster = (hex_color, total_paths, [member_classes])
        clusters = []
        for cls, hexc in active_colors.items():
            clusters.append({
                "color": hexc,
                "count": class_counts[cls],
                "members": [cls],
            })

        while len(clusters) > TARGET_COLORS:
            # Find closest pair by perceptual distance
            best_dist = float("inf")
            best_i, best_j = 0, 1
            for i in range(len(clusters)):
                for j in range(i + 1, len(clusters)):
                    d = redmean_distance(clusters[i]["color"], clusters[j]["color"])
                    if d < best_dist:
                        best_dist = d
                        best_i, best_j = i, j

            # Merge j into i (weighted average color)
            ci, cj = clusters[best_i], clusters[best_j]
            merged_color = weighted_avg_color(
                ci["color"], ci["count"], cj["color"], cj["count"]
            )
            ci["color"] = merged_color
            ci["count"] += cj["count"]
            ci["members"].extend(cj["members"])
            clusters.pop(best_j)

        stats["colors_merged"] = stats["orig_colors"] - TARGET_COLORS

        # Apply: build rename map (all member classes -> representative class)
        # and update color_map with merged colors
        merge_rename = {}
        new_color_map = {}
        for cluster in clusters:
            representative = cluster["members"][0]
            new_color_map[representative] = cluster["color"]
            for member in cluster["members"]:
                merge_rename[member] = representative

        # Update elements
        if not dry_run:
            for elem in root.iter():
                cls = elem.get("class", "")
                if cls in merge_rename:
                    elem.set("class", merge_rename[cls])

        # Update active colors for renaming step
        active_colors = new_color_map
        # Recount
        class_counts = {}
        for elem in root.iter():
            cls = elem.get("class", "")
            if cls and cls in active_colors:
                class_counts[cls] = class_counts.get(cls, 0) + 1
    else:
        # No merge needed, but use active_colors
        pass

    # --- Step 5: Rename to sequential cls-1..cls-N sorted by luminance ---
    used_sorted = sorted(active_colors.keys(), key=lambda c: luminance(active_colors[c]))
    rename_map = {}
    for i, old_name in enumerate(used_sorted, 1):
        rename_map[old_name] = "cls-{}".format(i)

    stats["renamed"] = sum(1 for k, v in rename_map.items() if k != v)
    stats["final_colors"] = len(used_sorted)

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
            hex_color = active_colors[old_name]
            new_style_lines.append(
                "      .{} {{\n        fill: {};\n      }}\n\n".format(new_name, hex_color)
            )
        if style_elem is not None:
            style_elem.text = "".join(new_style_lines) + "    "

    # --- Step 6: Normalize SVG root attributes ---
    format_fixes = []

    if root.get("width") != "1200" or root.get("height") != "1800":
        if not dry_run:
            root.set("width", "1200")
            root.set("height", "1800")
        format_fixes.append("dims")

    for attr in ["style", "xml:space", "x", "y", "version"]:
        if root.get(attr) is not None:
            if not dry_run:
                del root.attrib[attr]
            format_fixes.append("rm-{}".format(attr))

    if root.get("id") != "Layer_1":
        if not dry_run:
            root.set("id", "Layer_1")
            root.set("data-name", "Layer 1")
        format_fixes.append("id")

    stats["format_fixes"] = len(format_fixes)

    # --- Write ---
    if not dry_run:
        any_change = (stats["dark_removed"] + stats["white_removed"] +
                      stats["colors_merged"] + stats["renamed"] + stats["format_fixes"]) > 0
        if any_change:
            tree.write(filepath, encoding="UTF-8", xml_declaration=True)

    return stats


def main():
    parser = argparse.ArgumentParser(description="Fix older SVG artworks")
    parser.add_argument("--dry-run", action="store_true",
                        help="Report what would change without modifying files")
    parser.add_argument("--file", type=str, default=None,
                        help="Process a single file instead of all")
    args = parser.parse_args()

    artworks_dir = os.path.abspath(ARTWORKS_DIR)
    if args.file:
        svg_files = [os.path.join(artworks_dir, args.file)]
    else:
        svg_files = sorted(glob.glob(os.path.join(artworks_dir, "*.svg")))

    mode = "DRY RUN" if args.dry_run else "PROCESSING"
    print("\n{} — target={}colors, dark_lum<{}, white_lum>{}\n".format(
        mode, TARGET_COLORS, DARK_LUM, WHITE_LUM))

    hdr = "{:<30} {:>5} {:>6} {:>6} {:>8} {:>7} {:>7} {:>6}".format(
        "File", "Orig", "DkRm", "WtRm", "Merged", "Final", "Rename", "FmtFx")
    print(hdr)
    print("-" * 100)

    totals = {"dark_removed": 0, "white_removed": 0, "colors_merged": 0, "renamed": 0, "format_fixes": 0}
    changed = 0

    for filepath in svg_files:
        stats = process_svg(filepath, args.dry_run)
        if stats is None:
            continue

        any_change = (stats["dark_removed"] + stats["white_removed"] +
                      stats["colors_merged"] + stats["renamed"] + stats["format_fixes"]) > 0
        if any_change:
            changed += 1
        for k in totals:
            totals[k] += stats.get(k, 0)

        print("{:<30} {:>5} {:>6} {:>6} {:>8} {:>7} {:>7} {:>6}".format(
            stats["name"],
            stats["orig_colors"],
            stats["dark_removed"],
            stats["white_removed"],
            stats["colors_merged"],
            stats["final_colors"],
            stats["renamed"],
            stats["format_fixes"]))

    print("-" * 100)
    print("{:<30} {:>5} {:>6} {:>6} {:>8} {:>7} {:>7} {:>6}".format(
        "TOTAL ({}/{} changed)".format(changed, len([f for f in svg_files if os.path.basename(f).replace('.svg','') in OLD_SVGS])),
        "",
        totals["dark_removed"],
        totals["white_removed"],
        totals["colors_merged"],
        "",
        totals["renamed"],
        totals["format_fixes"]))


if __name__ == "__main__":
    main()
