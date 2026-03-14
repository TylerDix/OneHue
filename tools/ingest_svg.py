#!/usr/bin/env python3
"""
ingest_svg.py — One Hue SVG ingestion pipeline

Clips white border bars from Firefly → Illustrator Image Trace SVGs
by adjusting the viewBox to show only non-white content.

No coordinate translation needed — just moves the viewBox window.
Also removes white border-band <path> elements to keep files clean.

Usage
-----
    python3 tools/ingest_svg.py                         # all Artworks
    python3 tools/ingest_svg.py "One Hue/Artworks/x.svg"  # one file
    python3 tools/ingest_svg.py --dry-run               # preview only
"""

import argparse
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

ARTWORKS_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "One Hue", "Artworks",
)

TARGET_W = 1200
NEAR_WHITE_THRESHOLD = 250
CLIP_INTO = 3.0  # clip 3px into content to guarantee no white edge gaps

# ── Helpers ───────────────────────────────────────────────────────

_TOKEN_RE = re.compile(
    r"[MmLlHhVvCcSsQqTtAaZz]|[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?"
)


def _is_near_white(hex6: str) -> bool:
    r, g, b = int(hex6[0:2], 16), int(hex6[2:4], 16), int(hex6[4:6], 16)
    return r >= NEAR_WHITE_THRESHOLD and g >= NEAR_WHITE_THRESHOLD and b >= NEAR_WHITE_THRESHOLD


def _white_classes(style_text: str) -> set[str]:
    classes: set[str] = set()
    for m in re.finditer(r"\.(st\d+)\{fill:#([0-9A-Fa-f]{6})", style_text):
        if _is_near_white(m.group(2).upper()):
            classes.add(m.group(1))
    return classes


def _path_y_bounds(d: str) -> tuple[float, float]:
    min_y, max_y = float("inf"), float("-inf")
    tokens = _TOKEN_RE.findall(d)
    cmd = None
    coords: list[float] = []
    x = y = 0.0
    i = 0

    def _up(val: float):
        nonlocal min_y, max_y
        if val < min_y: min_y = val
        if val > max_y: max_y = val

    while i < len(tokens):
        t = tokens[i]
        if t.isalpha():
            cmd, coords = t, []
            i += 1
            continue
        coords.append(float(t))
        i += 1

        if cmd == "M" and len(coords) >= 2:
            x, y = coords[-2], coords[-1]; _up(y)
            if len(coords) == 2: cmd = "L"
        elif cmd == "m" and len(coords) >= 2:
            x += coords[-2]; y += coords[-1]; _up(y)
            if len(coords) == 2: cmd = "l"
        elif cmd == "L" and len(coords) >= 2:
            x, y = coords[-2], coords[-1]; _up(y); coords = []
        elif cmd == "l" and len(coords) >= 2:
            x += coords[-2]; y += coords[-1]; _up(y); coords = []
        elif cmd == "V" and len(coords) >= 1:
            y = coords[-1]; _up(y); coords = []
        elif cmd == "v" and len(coords) >= 1:
            y += coords[-1]; _up(y); coords = []
        elif cmd in ("H", "h") and len(coords) >= 1:
            if cmd == "H": x = coords[-1]
            else: x += coords[-1]
            coords = []
        elif cmd == "C" and len(coords) >= 6:
            for j in (1, 3, 5): _up(coords[j])
            x, y = coords[4], coords[5]; coords = []
        elif cmd == "c" and len(coords) >= 6:
            for j in (1, 3, 5): _up(y + coords[j])
            x += coords[4]; y += coords[5]; coords = []
        elif cmd == "S" and len(coords) >= 4:
            _up(coords[1]); _up(coords[3])
            x, y = coords[2], coords[3]; coords = []
        elif cmd == "s" and len(coords) >= 4:
            _up(y + coords[1]); _up(y + coords[3])
            x += coords[2]; y += coords[3]; coords = []
        elif cmd == "Q" and len(coords) >= 4:
            _up(coords[1]); _up(coords[3])
            x, y = coords[2], coords[3]; coords = []
        elif cmd == "q" and len(coords) >= 4:
            _up(y + coords[1]); _up(y + coords[3])
            x += coords[2]; y += coords[3]; coords = []
        elif cmd in ("Z", "z"):
            coords = []

    return min_y, max_y


def _element_y_bounds(el: ET.Element) -> tuple[float, float]:
    tag = el.tag.split("}")[-1] if "}" in el.tag else el.tag
    if tag == "path" and "d" in el.attrib:
        return _path_y_bounds(el.attrib["d"])
    if tag == "polygon" and "points" in el.attrib:
        nums = re.findall(r"[-+]?\d*\.?\d+", el.attrib["points"])
        ys = [float(nums[j]) for j in range(1, len(nums), 2)]
        return (min(ys), max(ys)) if ys else (float("inf"), float("-inf"))
    if tag == "circle":
        cy, r = float(el.attrib.get("cy", 0)), float(el.attrib.get("r", 0))
        return (cy - r, cy + r)
    if tag == "ellipse":
        cy, ry = float(el.attrib.get("cy", 0)), float(el.attrib.get("ry", 0))
        return (cy - ry, cy + ry)
    if tag == "rect":
        ry, rh = float(el.attrib.get("y", 0)), float(el.attrib.get("height", 0))
        return (ry, ry + rh)
    return (float("inf"), float("-inf"))


# ── Content-bounds detection ──────────────────────────────────────


def _content_y_bounds(root: ET.Element, whites: set[str]) -> tuple[float, float]:
    """Return (min_y, max_y) of all non-white elements."""
    cmin, cmax = float("inf"), float("-inf")
    for el in root.iter():
        if el.attrib.get("class", "") in whites:
            continue
        el_min, el_max = _element_y_bounds(el)
        if el_min == float("inf"):
            continue
        if el_min < cmin: cmin = el_min
        if el_max > cmax: cmax = el_max
    return cmin, cmax


# ── Border path removal ──────────────────────────────────────────


def _element_y_bounds_from_line(line: str) -> tuple[float, float]:
    """Extract Y bounds from a single SVG element line (path or polygon)."""
    d_m = re.search(r'd="([^"]+)"', line)
    if d_m:
        return _path_y_bounds(d_m.group(1))
    pts_m = re.search(r'points="([^"]+)"', line)
    if pts_m:
        nums = re.findall(r"[-+]?\d*\.?\d+", pts_m.group(1))
        ys = [float(nums[j]) for j in range(1, len(nums), 2)]
        return (min(ys), max(ys)) if ys else (float("inf"), float("-inf"))
    return (float("inf"), float("-inf"))


def _remove_border_paths(content: str, whites: set[str],
                         view_top: float, view_bottom: float) -> str:
    """Remove white element lines (path, polygon, etc.) mostly outside the view."""
    lines = content.split("\n")
    kept: list[str] = []
    for line in lines:
        cls_m = re.search(r'class="(st\d+)"', line)
        if cls_m and cls_m.group(1) in whites:
            el_min, el_max = _element_y_bounds_from_line(line)
            if el_min != float("inf"):
                total = max(el_max - el_min, 1)
                inside = max(0, min(el_max, view_bottom) - max(el_min, view_top))
                if inside / total < 0.1:
                    continue
        kept.append(line)
    return "\n".join(kept)


# ── Main ingestion ────────────────────────────────────────────────


def ingest(path: str, *, dry_run: bool = False) -> dict:
    name = os.path.basename(path)
    with open(path) as f:
        content = f.read()

    vb_match = re.search(
        r'viewBox="([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)"', content
    )
    if not vb_match:
        return {"file": name, "status": "skipped", "reason": "no viewBox"}

    vb_x, vb_y = float(vb_match.group(1)), float(vb_match.group(2))
    vb_w, vb_h = float(vb_match.group(3)), float(vb_match.group(4))

    # Only process raw Firefly exports (1200×1800 canvas)
    if vb_h < 1750:
        return {"file": name, "status": "unchanged"}

    tree = ET.parse(path)
    root = tree.getroot()

    # Find white classes
    style_text = ""
    for el in root.iter():
        if el.tag.endswith("style"):
            style_text = el.text or ""
            break
    whites = _white_classes(style_text)
    if not whites:
        return {"file": name, "status": "unchanged"}

    # Find content bounds (non-white elements)
    cmin, cmax = _content_y_bounds(root, whites)
    if cmin == float("inf"):
        return {"file": name, "status": "unchanged"}

    # New viewBox: clip slightly into content to hide any edge artifacts
    new_y = cmin + CLIP_INTO
    new_h = (cmax - cmin) - 2 * CLIP_INTO

    # Remove white border-band paths
    new_content = _remove_border_paths(content, whites, new_y, new_y + new_h)

    # Update viewBox (offset approach — no coordinate translation)
    old_vb = vb_match.group(0)
    new_vb = f'viewBox="0 {new_y:.1f} {TARGET_W} {new_h:.1f}"'
    new_content = new_content.replace(old_vb, new_vb)

    old_bg = f"enable-background:new {vb_match.group(1)} {vb_match.group(2)} {vb_match.group(3)} {vb_match.group(4)}"
    new_bg = f"enable-background:new 0 {new_y:.1f} {TARGET_W} {new_h:.1f}"
    new_content = new_content.replace(old_bg, new_bg)

    if not dry_run:
        with open(path, "w") as f:
            f.write(new_content)

    return {
        "file": name,
        "status": "updated",
        "old_viewBox": f"{vb_x} {vb_y} {vb_w} {vb_h}",
        "new_viewBox": f"0 {new_y:.1f} {TARGET_W} {new_h:.1f}",
    }


def main():
    parser = argparse.ArgumentParser(description="Ingest One Hue SVG artworks")
    parser.add_argument("files", nargs="*", help="SVG files (default: all in Artworks/)")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    paths = args.files or sorted(glob.glob(os.path.join(ARTWORKS_DIR, "*.svg")))
    if not paths:
        print("No SVG files found.", file=sys.stderr)
        sys.exit(1)

    updated = unchanged = skipped = 0
    for p in paths:
        r = ingest(p, dry_run=args.dry_run)
        if r["status"] == "updated":
            updated += 1
            print(f"  ✓ {r['file']}: {r['old_viewBox']} → {r['new_viewBox']}")
        elif r["status"] == "unchanged":
            unchanged += 1
        else:
            skipped += 1
            print(f"  ✗ {r['file']}: {r.get('reason', '?')}")

    tag = "[DRY RUN] " if args.dry_run else ""
    print(f"\n{tag}{updated} updated, {unchanged} unchanged, {skipped} skipped  ({len(paths)} total)")


if __name__ == "__main__":
    main()
