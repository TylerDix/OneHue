#!/usr/bin/env python3
"""
Frame raw simulator screenshots for App Store submission.
Adds dark gradient background, marketing headline, rounded corners + shadow.

Usage:
    python3 tools/frame_screenshots.py

Output dimensions:
    iPhone 6.7": 1320 x 2868 px
    iPhone 6.1": 1206 x 2622 px
    iPad 13":    2048 x 2732 px
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# ── Paths ──────────────────────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(BASE_DIR, "screenshots", "raw")
OUT_DIR = os.path.join(BASE_DIR, "screenshots", "framed")

# ── Fonts ──────────────────────────────────────────────────────────────────
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"

# ── Colors ─────────────────────────────────────────────────────────────────
BG_TOP = (15, 15, 30)        # Deep navy
BG_BOTTOM = (8, 10, 22)      # Darker navy
TEXT_COLOR = (255, 255, 255)  # White headline
SUBTITLE_COLOR = (160, 165, 190)  # Soft gray-blue subtitle

# ── Layout (iPhone 6.7" = 1320 x 2868) ────────────────────────────────────
CANVAS_W = 1320
CANVAS_H = 2868

TOP_PADDING = 460        # Generous space for headline + subtitle
SIDE_PADDING = 80        # Left/right margin around screenshot
BOTTOM_PADDING = 80      # Bottom margin
CORNER_RADIUS = 44       # iOS-style corner rounding
SHADOW_OFFSET = 12
SHADOW_BLUR = 35

# Crop status bar from raw screenshot to remove green battery icon
STATUS_BAR_CROP = 0      # Set >0 to crop pixels from top of raw screenshot

# ── Screenshot Definitions ─────────────────────────────────────────────────
# (raw_filename, headline, subtitle)
SCREENSHOTS = [
    ("shot_01_today.png",           "A New Artwork\nEvery Day",          "366 hand-drawn illustrations"),
    ("shot_02_coloring.png",        "Pick a Color.\nTap to Fill.",       "One hue at a time"),
    ("shot_03_progress.png",        "Watch It\nCome Alive",              "Relax and focus"),
    ("shot_04_completion.png",      "Complete.\nEnjoy the Sarcasm.",     "No timers. No scores. Just sarcasm."),
    ("shot_05_gallery.png",         "Bold Art.\nZero Clutter.",          "No ads. No accounts. No nonsense."),
    ("shot_06_gallery_scroll.png",  "366 Puzzles.\nOne a Day.",          "Every day a new challenge"),
]

# iPad screenshots — 10 framed screenshots for App Store
IPAD_RAW_DIR = os.path.expanduser("~/Desktop/promo/ipad_raw_10")
IPAD_SCREENSHOTS = [
    ("ipad_01_gallery_hero.png",        "A New Artwork\nEvery Day",          "366 hand-drawn illustrations"),
    ("ipad_02_penguins_early.png",      "Pick a Color.\nTap to Fill.",       "One hue at a time"),
    ("ipad_03_owl_mid.png",             "Watch It\nCome Alive",              "Relax and focus"),
    ("ipad_04_sleddogs_mid.png",        "Bold Art.\nZero Clutter.",          "No ads. No accounts. No nonsense."),
    ("ipad_05_flamingo_mid.png",        "One Color\nat a Time",              "Tap. Fill. Repeat."),
    ("ipad_06_stag_near.png",           "Every Detail\nCounts",              "Paint by numbers, reimagined"),
    ("ipad_07_sleddogs_complete.png",   "Complete.\nEnjoy the Sarcasm.",     "No timers. No scores. Just sarcasm."),
    ("ipad_08_flamingo_complete.png",   "Done.\nNow What?",                  "Take a moment. You earned this."),
    ("ipad_09_flamingo_near.png",       "Almost\nThere",                     "Just a few more taps"),
    ("ipad_10_gallery_scroll.png",      "366 Puzzles.\nOne a Day.",          "Every day a new challenge"),
]

# iPad layout (App Store 13" = 2048 x 2732)
IPAD_CANVAS_W = 2048
IPAD_CANVAS_H = 2732
IPAD_TOP_PADDING = 440
IPAD_SIDE_PADDING = 100
IPAD_BOTTOM_PADDING = 80
IPAD_CORNER_RADIUS = 36
IPAD_FONT_HEADLINE = 108
IPAD_FONT_SUBTITLE = 44


def make_gradient(w, h, top_color, bottom_color):
    """Create a vertical gradient image using numpy-like approach for speed."""
    img = Image.new("RGB", (w, h))
    pixels = img.load()
    for y in range(h):
        ratio = y / h
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * ratio)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * ratio)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * ratio)
        for x in range(w):
            pixels[x, y] = (r, g, b)
    return img


def round_corners(img, radius):
    """Apply rounded corners to an image."""
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), img.size], radius=radius, fill=255)
    result = img.copy()
    result.putalpha(mask)
    return result


def add_shadow(canvas, screenshot_with_alpha, x, y):
    """Add a drop shadow behind the screenshot."""
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_layer = Image.new("RGBA", screenshot_with_alpha.size, (0, 0, 0, 50))
    shadow_layer.putalpha(screenshot_with_alpha.getchannel("A"))
    shadow.paste(shadow_layer, (x + SHADOW_OFFSET, y + SHADOW_OFFSET))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=SHADOW_BLUR))
    canvas_rgba = canvas.convert("RGBA")
    canvas_rgba = Image.alpha_composite(canvas_rgba, shadow)
    return canvas_rgba


def frame_screenshot(raw_path, headline, subtitle, output_path,
                     canvas_w=CANVAS_W, canvas_h=CANVAS_H,
                     top_padding=TOP_PADDING, side_padding=SIDE_PADDING,
                     bottom_padding=BOTTOM_PADDING, corner_radius=CORNER_RADIUS,
                     headline_size=88, subtitle_size=38):
    """Frame a single screenshot with gradient background and text."""
    # Load raw screenshot
    raw = Image.open(raw_path).convert("RGB")

    # Optionally crop status bar
    if STATUS_BAR_CROP > 0:
        raw = raw.crop((0, STATUS_BAR_CROP, raw.width, raw.height))

    raw_w, raw_h = raw.size

    # Calculate screenshot size — scale down to leave room for text
    avail_w = canvas_w - 2 * side_padding
    avail_h = canvas_h - top_padding - bottom_padding

    scale = min(avail_w / raw_w, avail_h / raw_h)
    new_w = int(raw_w * scale)
    new_h = int(raw_h * scale)
    raw_resized = raw.resize((new_w, new_h), Image.LANCZOS)

    # Round corners
    raw_rounded = round_corners(raw_resized, corner_radius)

    # Create gradient background
    canvas = make_gradient(canvas_w, canvas_h, BG_TOP, BG_BOTTOM)

    # Position screenshot: centered horizontally, pinned to bottom area
    shot_x = (canvas_w - new_w) // 2
    shot_y = canvas_h - bottom_padding - new_h

    # Add shadow + paste screenshot
    canvas_rgba = add_shadow(canvas, raw_rounded, shot_x, shot_y)
    canvas_rgba.paste(raw_rounded, (shot_x, shot_y), raw_rounded)

    # ── Draw text ──────────────────────────────────────────────────────────
    draw = ImageDraw.Draw(canvas_rgba)

    font_headline = ImageFont.truetype(FONT_BOLD, headline_size)
    font_subtitle = ImageFont.truetype(FONT_REGULAR, subtitle_size)

    # Get text dimensions
    hl_bbox = draw.multiline_textbbox((0, 0), headline, font=font_headline, align="center", spacing=10)
    hl_h = hl_bbox[3] - hl_bbox[1]

    sub_bbox = draw.textbbox((0, 0), subtitle, font=font_subtitle)
    sub_h = sub_bbox[3] - sub_bbox[1]

    gap = 20  # gap between headline and subtitle
    total_text_h = hl_h + gap + sub_h

    # Center text vertically in the top padding area
    text_area_top = 40
    text_area_bottom = shot_y - 30
    text_center_y = text_area_top + (text_area_bottom - text_area_top - total_text_h) // 2

    # Draw headline (white, bold, large)
    draw.multiline_text(
        (canvas_w // 2, text_center_y),
        headline,
        font=font_headline,
        fill=TEXT_COLOR,
        anchor="ma",
        align="center",
        spacing=10,
    )

    # Draw subtitle (gray, smaller)
    draw.text(
        (canvas_w // 2, text_center_y + hl_h + gap),
        subtitle,
        font=font_subtitle,
        fill=SUBTITLE_COLOR,
        anchor="ma",
    )

    # Save
    canvas_rgb = canvas_rgba.convert("RGB")
    canvas_rgb.save(output_path, "PNG", optimize=True)
    print(f"  -> {os.path.basename(output_path)}")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    print(f"Raw dir:    {RAW_DIR}")
    print(f"Output dir: {OUT_DIR}")
    print()

    framed_count = 0
    for i, (filename, headline, subtitle) in enumerate(SCREENSHOTS, 1):
        raw_path = os.path.join(RAW_DIR, filename)
        out_name = f"iphone67_{i:02d}.png"
        out_path = os.path.join(OUT_DIR, out_name)

        if os.path.exists(raw_path):
            print(f"[{i}] {filename}")
            frame_screenshot(raw_path, headline, subtitle, out_path)
            framed_count += 1
        else:
            print(f"[{i}] SKIP {filename} (not found)")

    # Generate 6.1" versions (scaled from 6.7")
    if framed_count > 0:
        print(f"\nScaling {framed_count} screenshots to 6.1\" (1206x2622)...")
        for fname in sorted(os.listdir(OUT_DIR)):
            if fname.startswith("iphone67_"):
                src = os.path.join(OUT_DIR, fname)
                dst = os.path.join(OUT_DIR, fname.replace("iphone67_", "iphone61_"))
                img = Image.open(src)
                img.resize((1206, 2622), Image.LANCZOS).save(dst, "PNG", optimize=True)
                print(f"  -> {os.path.basename(dst)}")

    # ── iPad 13" (2048 x 2732) ────────────────────────────────────────────
    ipad_out_dir = os.path.expanduser("~/Desktop/promo/ipad_screenshots_framed")
    os.makedirs(ipad_out_dir, exist_ok=True)
    print(f"\n{'='*60}")
    print(f"iPad 13\" screenshots (2048 x 2732)")
    print(f"Output: {ipad_out_dir}")
    print(f"{'='*60}\n")

    ipad_count = 0
    for i, (filename, headline, subtitle) in enumerate(IPAD_SCREENSHOTS, 1):
        raw_path = os.path.join(IPAD_RAW_DIR, filename)
        out_name = f"ipad13_{i:02d}.png"
        out_path = os.path.join(ipad_out_dir, out_name)

        if os.path.exists(raw_path):
            print(f"[{i}] {filename}")
            frame_screenshot(
                raw_path, headline, subtitle, out_path,
                canvas_w=IPAD_CANVAS_W, canvas_h=IPAD_CANVAS_H,
                top_padding=IPAD_TOP_PADDING, side_padding=IPAD_SIDE_PADDING,
                bottom_padding=IPAD_BOTTOM_PADDING, corner_radius=IPAD_CORNER_RADIUS,
                headline_size=IPAD_FONT_HEADLINE, subtitle_size=IPAD_FONT_SUBTITLE,
            )
            ipad_count += 1
        else:
            print(f"[{i}] SKIP {filename} (not found)")

    total = framed_count + ipad_count
    print(f"\nDone! {total} screenshots framed in: {OUT_DIR}")


if __name__ == "__main__":
    main()
