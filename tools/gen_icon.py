#!/usr/bin/env python3
"""Generate a mosaic-style app icon for One Hue."""

from PIL import Image, ImageDraw, ImageFilter
import random
import math

SIZE = 1024
OUT_DIR = "One Hue/Assets.xcassets/AppIcon.appiconset"

# Warm amber palette
HUE_BASE = (232, 168, 72)


def make_icon():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # 6x6 grid — reads well at small sizes
    cols, rows = 6, 6
    margin = 155
    gap = 10
    grid_w = SIZE - margin * 2
    grid_h = SIZE - margin * 2
    cell_w = (grid_w - gap * (cols - 1)) / cols
    cell_h = (grid_h - gap * (rows - 1)) / rows
    corner = cell_w * 0.2

    ox = margin
    oy = margin

    random.seed(7)

    # Hand-crafted pattern: organic cluster flowing from center-right
    # 1 = filled, 0 = empty
    pattern = [
        [0, 0, 0, 1, 1, 1],
        [0, 0, 1, 1, 1, 1],
        [0, 1, 1, 1, 1, 0],
        [1, 1, 1, 1, 0, 0],
        [1, 1, 1, 0, 0, 0],
        [1, 1, 0, 0, 0, 0],
    ]

    # Draw glow layer behind filled cells
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    for r in range(rows):
        for c in range(cols):
            if pattern[r][c]:
                x = ox + c * (cell_w + gap)
                y = oy + r * (cell_h + gap)
                pad = 12
                glow_draw.rounded_rectangle(
                    [x - pad, y - pad, x + cell_w + pad, y + cell_h + pad],
                    radius=corner + pad,
                    fill=(HUE_BASE[0], HUE_BASE[1], HUE_BASE[2], 25)
                )

    glow = glow.filter(ImageFilter.GaussianBlur(radius=20))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # Draw cells
    for r in range(rows):
        for c in range(cols):
            x = ox + c * (cell_w + gap)
            y = oy + r * (cell_h + gap)

            if pattern[r][c]:
                # Subtle brightness variation for depth
                brightness = 0.82 + random.uniform(0, 0.18)
                color = tuple(int(v * brightness) for v in HUE_BASE)
                draw.rounded_rectangle(
                    [x, y, x + cell_w, y + cell_h],
                    radius=corner,
                    fill=color
                )
            else:
                # Very subtle dark cell
                draw.rounded_rectangle(
                    [x, y, x + cell_w, y + cell_h],
                    radius=corner,
                    fill=(22, 22, 22, 255)
                )

    return img.convert("RGB")


def make_tinted_icon():
    """Grayscale for iOS tinted mode."""
    img = make_icon()
    return img.convert("L").convert("RGB")


if __name__ == "__main__":
    icon = make_icon()
    icon.save(f"{OUT_DIR}/icon_light.png")
    print(f"Saved icon_light.png")

    icon.save(f"{OUT_DIR}/icon_dark.png")
    print(f"Saved icon_dark.png")

    tinted = make_tinted_icon()
    tinted.save(f"{OUT_DIR}/icon_tinted.png")
    print(f"Saved icon_tinted.png")
