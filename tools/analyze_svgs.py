#!/usr/bin/env python3
"""Analyze all SVG artworks for structural anomalies."""
import re, os, glob

artworks_dir = os.path.join(os.path.dirname(__file__), "..", "One Hue", "Artworks")
results = []

for f in sorted(glob.glob(os.path.join(artworks_dir, "*.svg"))):
    name = os.path.basename(f).replace(".svg", "")
    content = open(f).read()
    size = os.path.getsize(f)

    # Count paths
    paths = len(re.findall(r"<path ", content))

    # Extract defined CSS classes from style block
    style_match = re.search(r"<style>(.*?)</style>", content, re.DOTALL)
    style_text = style_match.group(1) if style_match else ""
    defined_classes = sorted(set(re.findall(r"\.(cls-\d+)", style_text)))

    # Extract used classes (in path elements)
    used_classes = sorted(set(re.findall(r'class="(cls-\d+)"', content)))

    # Count colors defined in style
    colors = re.findall(r"fill:\s*#([0-9a-fA-F]{6})", style_text)
    num_colors = len(set(colors))

    # Check gaps in class numbering
    cls_nums = sorted(set(int(re.search(r"\d+", c).group()) for c in defined_classes))
    has_cls1 = 1 in cls_nums
    max_cls = max(cls_nums) if cls_nums else 0
    gaps = [i for i in range(1, max_cls + 1) if i not in cls_nums]

    # Defined but unused classes
    defined_set = set(defined_classes)
    used_set = set(used_classes)
    unused_defined = defined_set - used_set
    used_undefined = used_set - defined_set

    # Lines
    lines = content.count("\n") + 1
    lines_per_path = round(lines / paths, 1) if paths > 0 else 0

    results.append({
        "name": name,
        "size_kb": round(size / 1024),
        "paths": paths,
        "colors": num_colors,
        "max_cls": max_cls,
        "num_defined": len(defined_classes),
        "num_used": len(used_classes),
        "gaps": len(gaps),
        "gap_list": gaps[:8],
        "has_cls1": has_cls1,
        "lines_per_path": lines_per_path,
        "unused_defined": sorted(unused_defined)[:5],
        "used_undefined": sorted(used_undefined)[:5],
    })

# Print header
hdr = "{:<30} {:>6} {:>6} {:>5} {:>5} {:>5} {:>5} {:>5}  {}".format(
    "Name", "SizeK", "Paths", "Clrs", "Defnd", "Used", "Gaps", "L/P", "Issues"
)
print(hdr)
print("-" * 120)

for r in sorted(results, key=lambda x: x["paths"], reverse=True):
    issues = []
    if r["paths"] > 800:
        issues.append("HIGH_PATHS(>{})".format(r["paths"]))
    if r["gaps"] > 2:
        issues.append("GAPS({})={}".format(r["gaps"], r["gap_list"]))
    if not r["has_cls1"] and r["max_cls"] > 0:
        issues.append("NO_CLS1")
    if r["lines_per_path"] > 5:
        issues.append("MULTILINE({})".format(r["lines_per_path"]))
    if r["colors"] > 24:
        issues.append("MANY_COLORS({})".format(r["colors"]))
    if r["colors"] < 4 and r["colors"] > 0:
        issues.append("FEW_COLORS({})".format(r["colors"]))
    if r["size_kb"] > 400:
        issues.append("LARGE({}K)".format(r["size_kb"]))
    if r["unused_defined"]:
        issues.append("UNUSED_CLS={}".format(r["unused_defined"]))
    if r["used_undefined"]:
        issues.append("UNDEF_CLS={}".format(r["used_undefined"]))

    issue_str = ", ".join(issues) if issues else "OK"
    flag = "***" if issues else "   "
    line = "{} {:<27} {:>5}K {:>6} {:>5} {:>5} {:>5} {:>5} {:>5}  {}".format(
        flag, r["name"], r["size_kb"], r["paths"], r["colors"],
        r["num_defined"], r["num_used"], r["gaps"], r["lines_per_path"], issue_str
    )
    print(line)

# Summary
flagged = [r for r in results if any([
    r["paths"] > 800, r["gaps"] > 2, not r["has_cls1"] and r["max_cls"] > 0,
    r["lines_per_path"] > 5, r["colors"] > 24, r["size_kb"] > 400,
    r["unused_defined"], r["used_undefined"]
])]
print("\n{} of {} SVGs flagged with issues".format(len(flagged), len(results)))
