# One Hue — Device Test Checklist
*Updated 2026-04-29*

Print this. Each item has a clear pass/fail. Where I need your *judgment*, there's a callout box — those are the specific places I need your eye.

> **Debug menu:** Settings → tap "One Hue" tagline 5 times → "Jump to #" lets you go to any artwork by index (1–366).

---

## 1. Tip Jar Removed (paid model)

- [ ] Settings → About One Hue: **no "Support One Hue" section, no tip buttons.**
- [ ] Settings tagline at bottom reads: **"No ads. No tracking. Ever."**
- [ ] About paragraphs read: **"No ads. No accounts. No subscriptions. Just color, quiet, and the occasional dry remark."**
- [ ] App launches normally. No missing-symbol crash.

---

## 2. Darkness Lift (mom's complaint)

I changed two things: pure black backgrounds → soft near-black (`Color(white: 0.07)`), and unfilled-region brightness lifted from 15% → 35% saturation/35% brightness.

> **YOUR JUDGMENT:** Is it lighter enough now? Or do we need to go further? Or did I overshoot and lose the meditative dark feel?

- [ ] App chrome (header, palette area, gallery) feels softer than pure black
- [ ] Canvas — when a color IS selected, the **other unfilled regions** are visible, not just dark blobs
- [ ] Canvas — when **no color is selected**, you can see the artwork in dim form (preview state)
- [ ] **The reveal still feels rewarding** — filled regions still pop noticeably against unfilled

**My note:** dialing in dimming is iterative — tell me "more" or "less" and I'll adjust the multipliers in `computeMuted()` / `computeMutedOverview()`.

---

## 3. iPad — Zoom on Launch (THE BIG FIX)

- [ ] Cold-launch iPad in **portrait**: full artwork visible at zoom 1.0, no cropping
- [ ] Cold-launch iPad in **landscape**: full artwork visible, letterboxed if needed
- [ ] Pinch to zoom in still works
- [ ] Pinch to zoom out — bottoms at 1.0×
- [ ] Switch artworks via debug Jump To: whole artwork visible immediately

> **YOUR JUDGMENT:** Does aspect-fit feel right, or does the iPad now feel "too small" with letterboxing? Tradeoff: cropping vs letterboxing. Pick one.

---

## 4. iPad — Both Orientations

- [ ] Rotate iPad to landscape while painting → layout reflows cleanly
- [ ] Rotate back to portrait → clean transition
- [ ] **Gallery in iPad portrait:** 3–4 columns (was 2)
- [ ] **Gallery in iPad landscape:** 5–6 columns
- [ ] Settings sheet renders correctly in iPad landscape
- [ ] Completion overlay readable in iPad landscape

---

## 5. Voice Rewrite (40 messages — Phase 1)

I rewrote 40 completion messages in the new fact-driven warmth voice. Color these to completion and read the message:

| Jump # | Date | Artwork | Sample message preview |
|---|------|---------|------|
| 119 | 4/29 | heronCypress | "Great blue herons stand motionless for hours…" |
| 120 | 4/30 | coyoteSunset | "Coyotes have quietly expanded into every state…" |
| 122 | 5/1 | teaFarmerHills | "Tea is picked by hand because machines can't tell…" |
| 130 | 5/9 | weirdBird | "Birds don't know they're weird-looking…" |
| 134 | 5/13 | prairieDogTown | "Prairie dogs have a language…" |
| 142 | 5/21 | apiaryGoldenHour | "A single hive has 50,000 bees…" |
| 152 | 5/31 | firefliesTwilight | "Fireflies are disappearing…" |

> **YOUR JUDGMENT:** Read each message carefully. Mark each one:
> - ✅ Lands well — keep
> - ✏️ Needs editing — note what's off
> - ❌ Wrong direction — write what you want instead
>
> The voice is brand-new. I will not be offended. Tell me which ones don't work.

Notes:
```
[your handwritten notes per artwork]
```

---

## 6. Non-Square Artwork Samples

These have non-square viewboxes. With aspect-fit they should render fully visible (with letterboxing).

| Jump # | ID | Aspect |
|---|-----|--------|
| 162 | goldenSailboat | slightly tall (1200×1540) |
| 221 | humpbackWhale | slightly tall |
| 287 | birchTreesAutumn | very tall (1200×1789) |
| 298 | autumnParkBench | very tall |
| 336 | cardinalHolly | very tall |

For each:
- [ ] Loads with whole image visible
- [ ] Tapping a region fills it correctly
- [ ] Decision: ☐ acceptable as-is  ☐ must regenerate as square

> **YOUR JUDGMENT:** Are these acceptable to ship at launch, or should we burn FF credits regenerating them as squares? You have ~125 of these.

---

## 7. Mandala Removal (peacockMandala — April 4)

- [ ] Jump to **#95** to see the current mandala artwork
- [ ] Decide: regenerate in Firefly today (I'll provide the prompt) **OR** swap to a different completed artwork from your queue

**Firefly prompt suggestion** (if you want to replace with a peacock that isn't a mandala):
> *"A peacock standing in a sunlit garden, full feather display, layered editorial style. Borrowing the style and complexity only of attached image, but not substance or color. Limit colors to no more than 16. Flat, layered vector editorial illustration with no lines. Bold vivid saturated colors. No texture, no gradients. Evokes wonder."*

---

## 8. Core Gameplay Sanity

- [ ] Tap a color → hint regions highlight (lift, glow, etc.)
- [ ] Tap a region → fills correctly with selected color, plays sound
- [ ] Long-press a gallery card with progress → "Start Over" works
- [ ] Complete an artwork → reveal animation → completion overlay → countdown shows
- [ ] "← Today" header button while in another day → goes back to today
- [ ] Daily reminder toggle → permission prompt fires → toggle persists

---

## 9. Performance Spot-Check

- [ ] Cold launch < 2s to first interaction
- [ ] Gallery scroll smooth on iPad (where there are now more cells visible)
- [ ] Painting taps respond immediately
- [ ] Switch artworks 5 times rapidly — no slowdown

---

## What I Specifically Need From You

These are the things only your eye can answer. Anything you can mark here helps me prioritize fixes:

### Voice Direction
- [ ] **Phase 1 voice nails it** ←→ **Needs more iteration**
- Any messages from the 40-rewrite that feel **off-tone**? List IDs:
  ```
  ```
- Any subjects where you wish I'd taken a different angle?
  ```
  ```

### Darkness Calibration
- [ ] Just right ←→ Still too dark ←→ Now too light
- Where specifically? (canvas, gallery, settings, header):
  ```
  ```

### iPad
- [ ] aspect-fit feels right ←→ prefer cropped/zoomed feel
- Any controls that feel awkward in landscape?
  ```
  ```

### General Pain Points
- The **moment you don't know what to do**:
  ```
  ```
- The **thing that bugged you most** in the test:
  ```
  ```
- Something a first-time user would **definitely miss**:
  ```
  ```
- Something you wish was **clearer on the screen**:
  ```
  ```

### Things I Can Work on While You Test
While you run through this checklist, I can be doing (your call — say "go" on any):
- [ ] Phase 2 voice rewrites (rest of June onward) — ~30 more
- [ ] Investigate the ↗↙ button-blocks-numbers issue (sprint item)
- [ ] Investigate "show all numbers quicker after final color selected" (sprint item)
- [ ] Push code to GitHub
- [ ] Delete old Xcode archives
- [ ] Draft App Store description for paid model

---

**When done:** report back which sections passed and what failed. Section 5 (voice) and the "What I Need From You" block are the highest-value feedback.
