#!/usr/bin/env python3
"""Create contact sheets from thumbnails for AI vision identification.
Each sheet is an 8x6 grid with filename labels below each thumbnail."""

import os
from PIL import Image, ImageDraw, ImageFont

THUMB_DIR = os.path.join(os.path.dirname(__file__), "thumbnails")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "contact_sheets")
COLS, ROWS = 8, 6
THUMB_SIZE = 200
LABEL_HEIGHT = 24
CELL_W = THUMB_SIZE
CELL_H = THUMB_SIZE + LABEL_HEIGHT
MARGIN = 4
PER_SHEET = COLS * ROWS  # 48

def main():
    thumb_dir = os.path.abspath(THUMB_DIR)
    output_dir = os.path.abspath(OUTPUT_DIR)
    os.makedirs(output_dir, exist_ok=True)

    pngs = sorted(f for f in os.listdir(thumb_dir) if f.endswith('.png'))
    print(f"Found {len(pngs)} thumbnails, creating contact sheets ({COLS}x{ROWS} = {PER_SHEET} per sheet)...")

    sheet_num = 0
    for start in range(0, len(pngs), PER_SHEET):
        batch = pngs[start:start + PER_SHEET]
        sheet_w = COLS * (CELL_W + MARGIN) + MARGIN
        sheet_h = ROWS * (CELL_H + MARGIN) + MARGIN
        sheet = Image.new('RGB', (sheet_w, sheet_h), (30, 30, 30))
        draw = ImageDraw.Draw(sheet)

        try:
            font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 11)
        except:
            font = ImageFont.load_default()

        for idx, png_name in enumerate(batch):
            col = idx % COLS
            row = idx // COLS
            x = MARGIN + col * (CELL_W + MARGIN)
            y = MARGIN + row * (CELL_H + MARGIN)

            thumb = Image.open(os.path.join(thumb_dir, png_name))
            sheet.paste(thumb, (x, y))

            label = png_name.replace('.png', '')
            # Truncate long names
            if len(label) > 24:
                label = label[:22] + '..'
            draw.text((x + 2, y + THUMB_SIZE + 2), label, fill=(180, 180, 180), font=font)

        sheet_path = os.path.join(output_dir, f"sheet_{sheet_num:02d}.png")
        sheet.save(sheet_path)
        print(f"  Sheet {sheet_num}: {len(batch)} thumbnails -> {sheet_path}")
        sheet_num += 1

    print(f"\nDone! {sheet_num} contact sheets in: {output_dir}")

if __name__ == "__main__":
    main()
