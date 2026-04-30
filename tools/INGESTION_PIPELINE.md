# One Hue Ingestion Pipeline

Step-by-step. Run this for every new artwork going from a Firefly JPG to a working catalog entry.

---

## Folder map (the moving parts)

| Path | Role |
| --- | --- |
| `~/Desktop/BatchColorByNumber.jsx` | The Illustrator script |
| `~/Desktop/One Hue - Drop PNGs Here/` | **INPUT** — drop renamed PNGs here |
| `~/Desktop/One Hue - Drop PNGs Here/processed/` | Where the script moves PNGs after success |
| `~/Desktop/Illustrator originals/` | Where `.ai` files land (kept as masters) |
| `~/Documents/One Hue/One Hue/Artworks/` | **OUTPUT** — `.svg` lands here automatically (this is the project bundle folder) |
| `~/Documents/One Hue/tools/standardize_svgs.py` | Cleanup pass after the .svg lands |
| `~/Documents/One Hue/One Hue/Daily Artwork/DailyArtwork.swift` | Catalog file — manually add the entry |

---

## Step 1 — Generate (Firefly)
- Open `firefly.adobe.com/generate/image`
- Confirm: **Gemini 3.1**, Square 1:1, 1K, owl reference attached
- Paste the prompt for the artwork (priority queue is at `~/Desktop/promo/ff_regenerated/_priority_replacements.md`)
- Click **Generate** (20 credits, ~30s)
- Hover the result, click the download icon, click-through the Chrome download prompt
- **Rename** the file to the artwork ID, e.g. `celloEmptyStage.png` (the script picks files alphabetically — must match the catalog `id`)

## Step 2 — Drop the PNG
Move the renamed PNG into `~/Desktop/One Hue - Drop PNGs Here/`.

```
mv ~/Downloads/celloEmptyStage.png ~/Desktop/One\ Hue\ -\ Drop\ PNGs\ Here/
```

## Step 3 — First run of the .jsx (trace)
- In Illustrator: **File > Scripts > Other Script…** → pick `~/Desktop/BatchColorByNumber.jsx`
  - First time only: assign a keyboard shortcut so future runs are one keystroke
- The script will:
  - Open the next unprocessed PNG from the drop folder
  - Apply Image Trace with 8 colors, noise 100, paths 20, corners 25
- It pauses with the trace preview live — **adjust the Image Trace panel settings if needed**:
  - Sweet spot: **60–350 path elements** in the final SVG
  - 1-star outcomes (e.g. cobble at 1244 elements) come from too many small pieces
  - If the trace looks too noisy, raise the Noise threshold; too blocky, lower it

## Step 4 — Second run of the .jsx (expand + save)
- Run the script again (keyboard shortcut)
- This time it will:
  - Expand the live trace into vector paths
  - Save the `.ai` master to `~/Desktop/Illustrator originals/<id>.ai`
  - Save the **`.svg` straight into `~/Documents/One Hue/One Hue/Artworks/<id>.svg`** ← this is the auto-dump
  - Move the source PNG into `processed/`
  - Close the document
  - Load the next unprocessed PNG (so a batch of multiple artworks just keeps cycling)
- It also warns if the path count exceeds 500 (warn) or 900 (hard rejection)

## Step 5 — Standardize the SVG
Open Terminal, then:

```
cd ~/Documents/One\ Hue
python3 tools/standardize_svgs.py --file "One Hue/Artworks/celloEmptyStage.svg"
```

This pass:
- Renames Illustrator's `st0`, `st1`, … classes to `cls-0`, `cls-1`, …
- Cleans CSS, removes Illustrator comments, normalizes encoding
- Reassigns near-black tiny artifacts to nearest non-black color (the dark-removal step that previously caused black tears — verify the output if the Firefly source had heavy shadow areas)

Drop `--file …` to process the whole folder. Add `--dry-run` to preview without writing.

## Step 6 — Add the catalog entry
Open `One Hue/Daily Artwork/DailyArtwork.swift` and add a line in the catalog list:

```swift
Artwork(id: "celloEmptyStage", fileName: "celloEmptyStage", displayName: "After the Last Note", completionMessage: "<one-sentence fact + warmth + connection per voice memory>", month: 1, day: 7),
```

The `id` and `fileName` must match the SVG filename (without extension).

## Step 7 — Build + on-device test
- Build to a simulator first to catch parser/render errors
- Then run on personal device and color the entire piece — watch for:
  - Distinct fillable regions (not blob fields)
  - Color count ~16–20 (target) — too many = tedious, too few = boring
  - No black tears or rendering artifacts
  - Numbers render at appropriate cluster centers

## Step 8 — Commit
```
git add "One Hue/Artworks/celloEmptyStage.svg" "One Hue/Daily Artwork/DailyArtwork.swift"
git commit -m "Add celloEmptyStage artwork (1/7)"
```

---

## Quality targets (from `BatchColorByNumber.jsx` itself)
- 5-star pieces: moon (94 elements / 10 colors), mountain (93 / 10)
- 1-star: cobble at 1244 elements (too many small pieces)
- Sweet spot: 60–350 path elements, 8–10 visual color groups

## Known issues / gotchas
- **`BatchColorByNumber.jsx` skips any PNG whose SVG already exists in the project bundle.** When REPLACING an existing artwork, you MUST delete the old `<id>.svg` from `One Hue/Artworks/` BEFORE running the script — otherwise the script considers it "already processed" and silently does nothing (you'll get a "All N images have been processed!" dialog that looks successful but isn't). Back it up first if you want to revert.
- `standardize_svgs.py` dark-removal can cause black tears on heavy-shadow inputs — eyeball the result, revert if it ruins the artwork
- `BatchColorByNumber.jsx` runs once = trace, runs again = save+next. Don't expect a single run to finish a piece.
- File upload to Firefly's Style Kit is blocked through Chrome MCP — the reference image must be drag-dropped manually at session start
- Use **Gemini 3.1**, not Firefly Image 3 — Gemini holds the flat-vector style much better for One Hue
- Chrome MCP triggers a per-file download permission prompt. Click-through is normal, not a bug.
