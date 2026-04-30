#!/bin/bash
# Pre-flight check before running BatchColorByNumber.jsx in Illustrator.
# Catches the most common gotcha: an existing SVG with the same ID makes the
# script silently skip the PNG.
#
# Usage: ./tools/preflight_check.sh
# Run from project root.

set -e

DROP="$HOME/Desktop/One Hue - Drop PNGs Here"
ARTWORKS="One Hue/Artworks"

if [ ! -d "$DROP" ]; then
  echo "ERROR: drop folder not found at $DROP"
  exit 1
fi

echo "=== Drop folder: $DROP ==="
PNGS=$(find "$DROP" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | sort)

if [ -z "$PNGS" ]; then
  echo "  (empty — nothing to process)"
  exit 0
fi

echo ""
echo "=== Pending images and conflicts ==="
echo ""

CONFLICTS=0
TOTAL=0
while IFS= read -r png; do
  TOTAL=$((TOTAL + 1))
  basename=$(basename "$png")
  id="${basename%.*}"
  svg_path="$ARTWORKS/$id.svg"
  if [ -f "$svg_path" ]; then
    age=$(stat -f "%Sm" -t "%Y-%m-%d" "$svg_path")
    echo "  ⚠ $basename — '$id.svg' EXISTS in project ($age)"
    echo "    The script will SKIP this image. Either:"
    echo "      (a) rm \"$svg_path\"   ← if you want to overwrite"
    echo "      (b) rename PNG to a different ID before running"
    CONFLICTS=$((CONFLICTS + 1))
  else
    echo "  ✓ $basename — clean ($id.svg does not exist yet)"
  fi
done <<< "$PNGS"

echo ""
echo "=== Summary ==="
echo "  $TOTAL image(s) ready to process"
echo "  $CONFLICTS conflict(s) — script will skip these unless resolved"

if [ "$CONFLICTS" -gt 0 ]; then
  exit 1
fi
exit 0
