# _archive_for_review

Files moved here are NOT in the build (Xcode 16's synchronized folder
group is anchored at `One Hue/` — anything outside that path doesn't
get bundled). Each entry below explains why it landed here. Once you've
confirmed nothing is missed, delete this folder.

## Stale duplicates of canonical files in `One Hue/`

These existed at repo root with the same name as files inside `One Hue/`
but with older content. The bundled (and therefore real) copy is the one
inside `One Hue/`.

| Archived | Canonical |
| --- | --- |
| `App + Root/AppRootView.swift` | `One Hue/App + Root/AppRootView.swift` (differs) |
| `App + Root/OneHueApp.swift` | `One Hue/App + Root/OneHueApp.swift` (identical) |
| `Assets.xcassets/` | `One Hue/Assets.xcassets/` |
| `Canvas Engine/CanvasView.swift` | `One Hue/Canvas Engine/CanvasView.swift` (differs) |
| `Today Experience/TodayView.swift` | `One Hue/Today Experience/TodayView.swift` (differs) |
| `Today Experience/CompletionOverlayView.swift` | `One Hue/Today Experience/CompletionOverlayView.swift` (differs) |
| `PaletteView.swift` | `One Hue/PaletteView.swift` (differs) |

Note: `One Hue/Today Experience/` also contains `GalleryView.swift`,
`HomeView.swift`, and `RadialRevealView.swift` — none of which are in
the archived copy. Confirms the archived copy is older.

## Probably-orphaned

| File | Notes |
| --- | --- |
| `Networking/OneHueAPI.swift` | Not referenced anywhere in `One Hue/`. No canonical copy. Delete unless you remember a reason. |
| `daily_2026-03-05.json` | Looks like a debug snapshot from March. Not loaded by any code path. |

## macOS Finder duplicates

`tools/*` had four "Filename 2.py" siblings that were byte-identical
to their bases — Finder copy-paste artifacts.

- `tools/fix_golden_firefly 2.py` (== `fix_golden_firefly.py`)
- `tools/fix_gpt 2.py` (== `fix_gpt.py`)
- `tools/fix_koi_pond 2.py` (== `fix_koi_pond.py`)
- `tools/fix_moon 2.py` (== `fix_moon.py`)

## Recovery

If anything here turns out to be needed: `git log --diff-filter=R --
"_archive_for_review/<path>"` shows the rename, and a normal `git mv`
back into place restores it (history is preserved).
