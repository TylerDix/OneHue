# One Hue — Quick Test (1 page)
*Updated 2026-04-29*

## What changed in this build

1. **Find/scope button shrunk + see-through.** Was blocking number labels in bottom-right. Now smaller (~33pt), 50% more transparent.
2. **Canvas fills the screen on iPhone.** Aspect-fill instead of aspect-fit. Edges of artwork crop slightly; panning still works to reach them. iPad keeps aspect-fit.
3. **Debug nav chip on the canvas.** Bottom-leading: `◀ #X ▶`. Tap the number to type any index. Tap arrows to step. (DEBUG only.)
4. **Settings → Jump to # actually navigates now.** Tapping Go closes the sheet and loads the artwork.

## Test (in order)

- [ ] **Canvas fill (iPhone).** Open today's artwork. Does the artwork fill the canvas (no black bars)? Does the wobble hint that you can pan?
- [ ] **Aspect-fill comfort.** Step through 5–10 artworks via the new chip. Pick one that's flagrantly cropped. Is it still readable as the subject? Or does the crop kill the image?
- [ ] **Find button.** Color something into a corner. Tap the scope button — does it find unfilled regions? Are number labels in that corner now legible?
- [ ] **Debug nav chip.** Tap arrows — moves prev/next? Tap `#X` — does the alert appear and accept a number? Does it jump correctly?
- [ ] **Jump from Settings.** 5-tap tagline → enter # → Go. Does the sheet close and the right artwork load?

## Where I want your eye

- **Crop tolerance:** which artworks (if any) get unacceptably cropped at default zoom on iPhone? Note their indices.
- **Is the wobble enough hint?** Does it read as "you can pan", or just feel like jitter?
- **Find-button visibility:** still findable? Or did I make it too quiet?

## Things still pending (post-test)

- Show all numbers quicker after final color (need a clearer description of what you're seeing)
- Phase 2 voice rewrites (~325 messages, post-launch)
- Mass artwork regen (workflow change pending)
