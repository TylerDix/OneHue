#!/usr/bin/env python3
"""
Auto-rename Firefly downloads to catalog IDs and move into drop folder.

Workflow:
  1. Drop Firefly-named PNGs (with original names like
     "Firefly_Gemini Flash_a colony of emperor penguins...png") into ANY folder.
  2. Run this script with that folder as input.
  3. Script fuzzy-matches each filename's prompt fragment against the manifest,
     renames to <catalog_id>.png, and moves into the drop folder.
  4. Unmatched files are listed for manual handling.

Usage:
    python3 tools/firefly_rename.py <input_dir>
    python3 tools/firefly_rename.py ~/Downloads/firefly_batch

By default targets:
    ~/Desktop/One Hue - Drop PNGs Here/

The manifest maps distinctive prompt keywords to catalog IDs.
Add entries as new artworks get prompts. The cider barn entry shows the format.
"""

import os
import re
import shutil
import sys
from pathlib import Path

DROP_FOLDER = Path.home() / "Desktop" / "One Hue - Drop PNGs Here"

# Manifest: prompt-fragment keywords (lowercase, in order of distinctiveness) → catalog ID.
# Match score = sum of substring hits. First-keyword hit weighted 3x, rest 1x.
# Add new entries when new prompts are fired.
MANIFEST = {
    # Priority 1-stars (locked-formula gens this session)
    "venice":               ["gondola", "venetian", "striped pole", "ochre"],
    "mardiGrasMasks":       ["mardi gras", "ornate", "purple background", "fan shapes"],
    "snowyVillageDogWalk":  ["bundled figure", "snowy village", "small dog", "lane at night"],
    "celloEmptyStage":      ["cello", "wooden stage", "empty velvet"],

    # Tier 1 olds - earlier session
    "robinStoneWall":       ["robin perched", "moss-covered stone wall"],
    "magnoliaBlossoms":     ["magnolia blossom", "pink-tipped petals"],
    "tadpolePond":          ["tadpole", "still pond", "lily pads"],
    "kayakLakeshore":       ["kayaker", "glassy lake", "dawn"],
    "kingfisherDive":       ["kingfisher", "mid-dive", "river stones"],
    "firefliesTwilight":    ["fireflies", "glowing", "twilight forest"],
    "hummingbirdGarden":    ["ruby-throated hummingbird", "trumpet flower"],
    "mossyWaterfall":       ["mossy boulders", "fern fronds", "waterfall"],
    "ciderPressBarn":       ["cider barn", "wooden cider press", "apple", "rafters"],
    "redSquirrelPinecone":  ["red squirrel", "pinecone", "pine bough"],

    # Tier 1 olds - queued in BATCH file (for tomorrow)
    "orcaBreaching":        ["orca", "breaching", "ocean spray"],
    "ospryDivingWaves":     ["osprey", "diving", "wave"],
    "ospreyDive":           ["osprey", "talons", "fish below"],
    "autumnParkBench":      ["park bench", "maple tree", "fallen leaves"],
    "tidalHarborBoats":     ["fishing boats", "wet sand", "low tide"],
    "cardinalHolly":        ["cardinal perched", "holly branch"],
    "ferrySunset":          ["ferry crossing", "sunset", "wake"],
    "christmasMarketNight": ["christmas market", "stalls", "string lights"],
    "gingerbreadHouseSnow": ["gingerbread house", "icing", "candy-cane fence"],
    "snowmanTwilight":      ["snowman", "twilight", "red scarf"],

    # Validation gens (custom subjects, no slot yet)
    "northernLightsCabin":  ["log cabin", "aurora", "deer", "pine trees"],
    "_foxgloves":           ["foxgloves", "weathered wooden fence", "butterflies"],
    "_henChicks":           ["mother hen", "chicks", "barn door"],
}


def normalize_filename_for_matching(filename: str) -> str:
    """Strip Firefly prefixes and lowercase for keyword matching."""
    # Strip extension
    name = os.path.splitext(filename)[0]
    # Strip common prefixes
    for prefix in ["Firefly_Gemini Flash_", "Firefly_GeminiFlash_", "Firefly_gpt-image_", "Firefly_"]:
        if name.startswith(prefix):
            name = name[len(prefix):]
            break
    # Lowercase, normalize whitespace
    return re.sub(r'\s+', ' ', name.lower())


def best_match(filename: str) -> tuple:
    """Return (catalog_id, score) or (None, 0) if nothing matches well."""
    normalized = normalize_filename_for_matching(filename)
    best_id = None
    best_score = 0
    for catalog_id, keywords in MANIFEST.items():
        score = 0
        for i, kw in enumerate(keywords):
            if kw.lower() in normalized:
                # First keyword (most distinctive) weighted 3x
                score += 3 if i == 0 else 1
        if score > best_score:
            best_score = score
            best_id = catalog_id
    # Require at least the first keyword (score >= 3) to claim a match
    if best_score >= 3:
        return best_id, best_score
    return None, best_score


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <input_dir>")
        print(f"Drops renamed files into: {DROP_FOLDER}")
        sys.exit(1)

    input_dir = Path(sys.argv[1]).expanduser()
    if not input_dir.is_dir():
        print(f"ERROR: {input_dir} is not a directory")
        sys.exit(1)

    DROP_FOLDER.mkdir(exist_ok=True)

    matched = []
    unmatched = []
    conflicts = []

    image_files = sorted([
        f for f in input_dir.iterdir()
        if f.is_file() and f.suffix.lower() in {".png", ".jpg", ".jpeg"}
    ])

    if not image_files:
        print(f"No image files found in {input_dir}")
        return

    print(f"Found {len(image_files)} image file(s) in {input_dir}\n")

    for f in image_files:
        catalog_id, score = best_match(f.name)
        if catalog_id is None:
            unmatched.append(f)
            continue

        target = DROP_FOLDER / f"{catalog_id}{f.suffix.lower()}"
        if target.exists():
            conflicts.append((f, target, catalog_id))
            continue

        matched.append((f, target, catalog_id, score))

    # Report
    print(f"=== Matched ({len(matched)}) ===")
    for src, dst, cat_id, score in matched:
        print(f"  {src.name[:70]:70s}  →  {cat_id}  (score: {score})")

    if conflicts:
        print(f"\n=== Conflicts (target already exists — skipped) ({len(conflicts)}) ===")
        for src, dst, cat_id in conflicts:
            print(f"  {src.name[:60]:60s}  →  {cat_id}  (target {dst.name} exists)")
        print("  Resolve by deleting the existing target file or renaming manually.")

    if unmatched:
        print(f"\n=== Unmatched ({len(unmatched)}) — rename manually ===")
        for f in unmatched:
            print(f"  {f.name}")

    if not matched:
        print("\nNothing to do.")
        return

    # Confirm
    print(f"\nMove {len(matched)} file(s) into {DROP_FOLDER}? [y/N] ", end="")
    response = input().strip().lower()
    if response != "y":
        print("Cancelled.")
        return

    for src, dst, cat_id, _ in matched:
        shutil.move(str(src), str(dst))
        print(f"  moved: {dst.name}")

    print(f"\n✓ Done. {len(matched)} file(s) renamed and moved.")
    if conflicts or unmatched:
        print(f"  ({len(conflicts)} conflicts + {len(unmatched)} unmatched left in {input_dir})")


if __name__ == "__main__":
    main()
