#!/usr/bin/env python3
"""
Analyze white/near-white artifacts in specific SVGs.

For each flagged SVG, reports:
  - All CSS color classes sorted by luminance
  - Near-white classes (luminance > threshold)
  - Path count per class
  - Estimated bbox size of each near-white path (to distinguish large valid
    regions from small artifact speckles/bands)

Usage:
    python3 tools/analyze_white_artifacts.py
"""

import os
import re
from xml.etree import ElementTree as ET

ARTWORKS_DIR = os.path.join(os.path.dirname(__file__), "..", "One Hue", "Artworks")
SVG_NS = "http://www.w3.org/2000/svg"

# SVGs the user flagged for white artifact analysis
FLAGGED = [
    "baloon", "bench", "desert", "dragonflyCattail", "hammockPalms",
    "heronGoldenHour", "japanesePagoda", "lighthouse", "mistyFjordDawn",
    "moon", "seaAnemoneRock", "sealOnRock", "tabbyCatWindowsill",
    "toucanTropical", "windmillLavender",
]

WHITE_LUM_THRESHOLD = 230  # luminance above this = "near-white"


def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = h[0]*2 + h[1]*2 + h[2]*2
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def luminance(hex_color):
    r, g, b = hex_to_rgb(hex_color)
    return 0.299 * r + 0.587 * g + 0.114 * b


def estimate_path_bbox(d_attr):
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


def analyze_svg(filepath):
    name = os.path.basename(filepath).replace(".svg", "")

    try:
        tree = ET.parse(filepath)
    except ET.ParseError:
        content = open(filepath, 'r', encoding='utf-8', errors='replace').read()
        content = content.replace('encoding="iso-8859-1"', 'encoding="UTF-8"')
        import io
        tree = ET.parse(io.StringIO(content))

    root = tree.getroot()

    # Extract style
    style_text = ""
    for elem in root.iter():
        tag = elem.tag.replace("{%s}" % SVG_NS, "")
        if tag == "style" and elem.text:
            style_text = elem.text
            break

    if not style_text:
        print(f"  {name}: NO STYLE BLOCK")
        return

    # Parse colors
    color_map = {}
    for m in re.finditer(r'\.(cls-\d+|st\d+)\s*\{[^}]*fill:\s*(#[0-9a-fA-F]{3,6})', style_text):
        cls_name = m.group(1)
        hex_color = m.group(2)
        if len(hex_color) == 4:
            hex_color = '#' + hex_color[1]*2 + hex_color[2]*2 + hex_color[3]*2
        color_map[cls_name] = hex_color.lower()

    # Count paths per class and collect near-white path details
    class_path_count = {}
    white_paths = []  # (class, hex, lum, bbox, d_length)

    for elem in root.iter():
        tag = elem.tag.replace("{%s}" % SVG_NS, "")
        if tag != "path":
            continue
        cls = elem.get("class", "")
        if cls in color_map:
            class_path_count[cls] = class_path_count.get(cls, 0) + 1
            lum = luminance(color_map[cls])
            if lum > WHITE_LUM_THRESHOLD:
                d = elem.get("d", "")
                bbox = estimate_path_bbox(d)
                white_paths.append({
                    "class": cls,
                    "hex": color_map[cls],
                    "lum": lum,
                    "bbox": bbox,
                    "area": bbox[2] * bbox[3] if bbox else 0,
                    "width": bbox[2] if bbox else 0,
                    "height": bbox[3] if bbox else 0,
                    "d_len": len(d),
                })

    # Print report
    print(f"\n{'='*80}")
    print(f"  {name}.svg  ({len(color_map)} colors, {sum(class_path_count.values())} paths)")
    print(f"{'='*80}")

    # All colors sorted by luminance
    print(f"\n  All colors (sorted by luminance):")
    for cls in sorted(color_map.keys(), key=lambda c: luminance(color_map[c])):
        lum = luminance(color_map[cls])
        count = class_path_count.get(cls, 0)
        marker = " <<<WHITE" if lum > WHITE_LUM_THRESHOLD else ""
        print(f"    {cls:>8}  {color_map[cls]}  lum={lum:6.1f}  paths={count:3d}{marker}")

    # White path details
    if white_paths:
        print(f"\n  Near-white paths (lum > {WHITE_LUM_THRESHOLD}): {len(white_paths)} total")
        # Sort by area
        for wp in sorted(white_paths, key=lambda x: x["area"]):
            print(f"    {wp['class']:>8} {wp['hex']} lum={wp['lum']:5.1f}  "
                  f"area={wp['area']:10.0f}  w={wp['width']:7.1f} h={wp['height']:7.1f}  "
                  f"d_len={wp['d_len']:5d}")

        # Summary stats
        areas = [wp["area"] for wp in white_paths]
        print(f"\n  White path area stats: min={min(areas):.0f} max={max(areas):.0f} "
              f"median={sorted(areas)[len(areas)//2]:.0f}")

        # Horizontal banding check: paths that span wide but are thin
        bands = [wp for wp in white_paths if wp["width"] > 200 and wp["height"] < 100]
        if bands:
            print(f"\n  POTENTIAL HORIZONTAL BANDS ({len(bands)} paths):")
            for wp in bands:
                print(f"    {wp['class']:>8} w={wp['width']:.0f} h={wp['height']:.0f} "
                      f"area={wp['area']:.0f}")

        # Small speckles check: paths with tiny area
        speckles = [wp for wp in white_paths if wp["area"] < 5000]
        if speckles:
            print(f"\n  POTENTIAL SPECKLES ({len(speckles)} paths, area < 5000):")
            for wp in speckles:
                print(f"    {wp['class']:>8} area={wp['area']:.0f} d_len={wp['d_len']}")
    else:
        print(f"\n  No near-white paths found (lum > {WHITE_LUM_THRESHOLD})")


def main():
    artworks_dir = os.path.abspath(ARTWORKS_DIR)

    for name in FLAGGED:
        filepath = os.path.join(artworks_dir, name + ".svg")
        if not os.path.exists(filepath):
            print(f"\n  {name}.svg: FILE NOT FOUND")
            continue
        analyze_svg(filepath)


if __name__ == "__main__":
    main()
