#!/usr/bin/env python3
"""Generate review.html with artwork metadata embedded."""
import json, re, os, glob

artworks_dir = os.path.join(os.path.dirname(__file__), "..", "One Hue", "Artworks")
results = []

for f in sorted(glob.glob(os.path.join(artworks_dir, "*.svg"))):
    name = os.path.basename(f).replace(".svg", "")
    content = open(f).read()
    size = os.path.getsize(f)
    paths = len(re.findall(r"<path ", content))

    # Detect format
    style_match = re.search(r"<style[^>]*>(.*?)</style>", content, re.DOTALL)
    style_text = style_match.group(1) if style_match else ""

    has_cls = bool(re.search(r"\.cls-\d+", style_text))
    has_st = bool(re.search(r"\.st\d+", style_text))
    fmt = "cls" if has_cls else ("st" if has_st else "unknown")

    # Count colors from either format
    colors_hex = re.findall(r"fill:\s*#([0-9a-fA-F]{3,6})", style_text)
    num_colors = len(set(colors_hex))

    # Check for class gaps (cls format)
    if has_cls:
        cls_nums = sorted(set(int(m) for m in re.findall(r"\.cls-(\d+)", style_text)))
        max_cls = max(cls_nums) if cls_nums else 0
        gaps = [i for i in range(1, max_cls + 1) if i not in cls_nums]
    elif has_st:
        st_nums = sorted(set(int(m) for m in re.findall(r"\.st(\d+)", style_text)))
        max_cls = max(st_nums) if st_nums else 0
        gaps = [i for i in range(0, max_cls + 1) if i not in st_nums]
    else:
        gaps = []

    issues = []
    if paths > 800:
        issues.append("HIGH_PATHS")
    if len(gaps) > 2:
        issues.append("CLASS_GAPS({})".format(len(gaps)))
    if size > 400 * 1024:
        issues.append("LARGE")
    if num_colors > 20:
        issues.append("MANY_COLORS({})".format(num_colors))
    if num_colors < 4 and num_colors > 0:
        issues.append("FEW_COLORS({})".format(num_colors))

    results.append({
        "name": name,
        "paths": paths,
        "colors": num_colors,
        "sizeK": round(size / 1024),
        "format": fmt,
        "gaps": len(gaps),
        "flagged": bool(issues),
        "issues": ", ".join(issues) if issues else "",
    })

# Sort: flagged first, then by path count descending
results.sort(key=lambda x: (-x["flagged"], -x["paths"]))

# Generate HTML
template_path = os.path.join(os.path.dirname(__file__), "review.html")
html = open(template_path).read()
html = html.replace("ARTWORK_DATA_PLACEHOLDER", json.dumps(results, indent=2))
open(template_path, "w").write(html)
print("Generated review.html with {} artworks ({} flagged)".format(
    len(results), sum(1 for r in results if r["flagged"])
))
