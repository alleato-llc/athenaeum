#!/usr/bin/env python3
"""Generate macOS app icons for Athenaeum and Octavo.

Requires: pip install Pillow

Usage:
    python3 scripts/generate-icons.py              # Generate both icons
    python3 scripts/generate-icons.py athenaeum     # Generate Athenaeum only
    python3 scripts/generate-icons.py octavo        # Generate Octavo only
"""

import json
import math
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# macOS icon slots: (logical_size, scale) -> pixel_size
ICON_SLOTS = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def rounded_rectangle_mask(size, radius):
    """Create a rounded rectangle mask."""
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (size[0] - 1, size[1] - 1)], radius=radius, fill=255)
    return mask


def get_font(size):
    """Get a serif font at the given size, falling back to default."""
    font_paths = [
        "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
        "/System/Library/Fonts/Times.ttc",
        "/Library/Fonts/Georgia.ttf",
    ]
    for path in font_paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except (OSError, IOError):
                continue
    return ImageFont.load_default()


def draw_athenaeum_icon(size):
    """Draw the Athenaeum bookshelf icon at the given pixel size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background
    bg_color = (85, 40, 50)
    radius = int(size * 0.18)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, fill=bg_color)

    # Subtle darker edge for depth
    edge_color = (65, 30, 38)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, outline=edge_color, width=max(1, size // 256))

    # Shelf
    shelf_y = int(size * 0.72)
    shelf_h = max(2, int(size * 0.03))
    shelf_color = (139, 105, 71)
    shelf_dark = (110, 82, 55)
    margin = int(size * 0.1)
    draw.rectangle([margin, shelf_y, size - margin, shelf_y + shelf_h], fill=shelf_color)
    draw.rectangle([margin, shelf_y + shelf_h, size - margin, shelf_y + shelf_h + max(1, shelf_h // 2)], fill=shelf_dark)

    # Books
    book_colors = [
        (210, 60, 60),    # red
        (230, 170, 50),   # yellow
        (100, 160, 220),  # light blue
        (200, 80, 160),   # pink
        (80, 170, 80),    # green
        (200, 80, 160),   # magenta
        (230, 140, 50),   # orange
        (80, 190, 190),   # teal
        (200, 80, 80),    # red
        (160, 120, 190),  # purple
        (180, 150, 80),   # olive/tan
    ]

    book_area_left = margin + int(size * 0.02)
    book_area_right = size - margin - int(size * 0.02)
    book_area_width = book_area_right - book_area_left
    num_books = len(book_colors)
    book_width = book_area_width // num_books
    gap = max(1, book_width // 10)
    book_width -= gap

    base_top = int(size * 0.32)
    for i, color in enumerate(book_colors):
        x = book_area_left + i * (book_width + gap)
        # Vary book height
        height_variation = int(size * 0.04 * math.sin(i * 1.3))
        top = base_top + height_variation
        bottom = shelf_y

        # Book body
        draw.rectangle([x, top, x + book_width, bottom], fill=color)

        # Spine highlight
        highlight = tuple(min(255, c + 30) for c in color)
        spine_w = max(1, book_width // 6)
        draw.rectangle([x, top, x + spine_w, bottom], fill=highlight)

        # Horizontal lines on book (detail)
        if book_width > 4:
            line_color = tuple(min(255, c + 50) for c in color)
            mid_y = (top + bottom) // 2
            lw = max(1, size // 256)
            for dy in [-int(size * 0.02), int(size * 0.02)]:
                y = mid_y + dy
                draw.line([x + spine_w + 1, y, x + book_width - 1, y], fill=line_color, width=lw)

        # One book leaning (last book)
        if i == num_books - 1 and size >= 64:
            # Draw a slight lean effect by making the book narrower at top
            lean = max(1, int(size * 0.015))
            draw.polygon([
                (x + lean, top),
                (x + book_width, top + int(size * 0.03)),
                (x + book_width, bottom),
                (x, bottom),
            ], fill=color)

    # Letter "A" at top
    font_size = int(size * 0.1)
    font = get_font(font_size)
    letter_color = (200, 170, 175)
    bbox = draw.textbbox((0, 0), "A", font=font)
    text_w = bbox[2] - bbox[0]
    text_x = (size - text_w) // 2
    text_y = int(size * 0.12)
    draw.text((text_x, text_y), "A", fill=letter_color, font=font)

    return img


def draw_octavo_icon(size):
    """Draw the Octavo open book icon at the given pixel size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background
    bg_color = (140, 95, 70)
    radius = int(size * 0.18)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, fill=bg_color)

    edge_color = (115, 78, 55)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, outline=edge_color, width=max(1, size // 256))

    # Open book dimensions
    cx = size // 2
    book_top = int(size * 0.22)
    book_bottom = int(size * 0.72)
    book_left = int(size * 0.14)
    book_right = size - int(size * 0.14)
    page_color = (250, 245, 235)
    cover_color = (160, 50, 45)
    spine_color = (100, 65, 45)
    line_color = (190, 185, 175)

    # Left cover (visible edges)
    cover_inset = int(size * 0.02)
    draw.polygon([
        (book_left - cover_inset, book_top + cover_inset),
        (cx - int(size * 0.01), book_top),
        (cx - int(size * 0.01), book_bottom),
        (book_left - cover_inset, book_bottom - cover_inset),
    ], fill=cover_color)

    # Right cover
    draw.polygon([
        (cx + int(size * 0.01), book_top),
        (book_right + cover_inset, book_top + cover_inset),
        (book_right + cover_inset, book_bottom - cover_inset),
        (cx + int(size * 0.01), book_bottom),
    ], fill=cover_color)

    # Left page
    draw.polygon([
        (book_left, book_top + int(size * 0.01)),
        (cx - int(size * 0.005), book_top - int(size * 0.005)),
        (cx - int(size * 0.005), book_bottom + int(size * 0.005)),
        (book_left, book_bottom - int(size * 0.01)),
    ], fill=page_color)

    # Right page
    draw.polygon([
        (cx + int(size * 0.005), book_top - int(size * 0.005)),
        (book_right, book_top + int(size * 0.01)),
        (book_right, book_bottom - int(size * 0.01)),
        (cx + int(size * 0.005), book_bottom + int(size * 0.005)),
    ], fill=page_color)

    # Spine
    spine_w = max(2, int(size * 0.02))
    draw.rectangle([cx - spine_w // 2, book_top - int(size * 0.005),
                     cx + spine_w // 2, book_bottom + int(size * 0.005)], fill=spine_color)

    # Text lines on left page
    lw = max(1, size // 256)
    line_margin_l = book_left + int(size * 0.04)
    line_margin_r_left = cx - int(size * 0.04)
    line_margin_l_right = cx + int(size * 0.04)
    line_margin_r = book_right - int(size * 0.04)
    line_spacing = int(size * 0.045)
    num_lines = 7

    for i in range(num_lines):
        y = book_top + int(size * 0.06) + i * line_spacing
        if y > book_bottom - int(size * 0.04):
            break
        # Left page lines
        draw.line([line_margin_l, y, line_margin_r_left, y], fill=line_color, width=lw)
        # Right page lines
        draw.line([line_margin_l_right, y, line_margin_r, y], fill=line_color, width=lw)

    # Letter "O" at bottom
    font_size = int(size * 0.08)
    font = get_font(font_size)
    letter_color = (220, 210, 200)
    bbox = draw.textbbox((0, 0), "O", font=font)
    text_w = bbox[2] - bbox[0]
    text_x = (size - text_w) // 2
    text_y = int(size * 0.78)
    draw.text((text_x, text_y), "O", fill=letter_color, font=font)

    return img


def generate_contents_json():
    """Generate the Contents.json for a macOS app icon set."""
    images = []
    for logical_size, scale in ICON_SLOTS:
        images.append({
            "filename": f"icon_{logical_size}x{logical_size}@{scale}x.png",
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{logical_size}x{logical_size}",
        })
    return {"images": images, "info": {"author": "xcode", "version": 1}}


def generate_icon(name, draw_func, output_dir):
    """Generate all icon sizes for an app."""
    appiconset = output_dir / "Assets.xcassets" / "AppIcon.appiconset"
    appiconset.mkdir(parents=True, exist_ok=True)

    # Root Contents.json
    root_contents = output_dir / "Assets.xcassets" / "Contents.json"
    with open(root_contents, "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")

    # Icon Contents.json
    contents = appiconset / "Contents.json"
    with open(contents, "w") as f:
        json.dump(generate_contents_json(), f, indent=2)
        f.write("\n")

    # Generate PNGs
    for logical_size, scale in ICON_SLOTS:
        pixel_size = logical_size * scale
        filename = f"icon_{logical_size}x{logical_size}@{scale}x.png"
        img = draw_func(pixel_size)
        img.save(appiconset / filename, "PNG")
        print(f"  {filename} ({pixel_size}x{pixel_size}px)")


def main():
    targets = sys.argv[1:] if len(sys.argv) > 1 else ["athenaeum", "octavo"]

    for target in targets:
        target = target.lower()
        if target == "athenaeum":
            print("Generating Athenaeum icons (bookshelf)...")
            generate_icon("Athenaeum", draw_athenaeum_icon, PROJECT_ROOT / "Athenaeum")
        elif target == "octavo":
            print("Generating Octavo icons (open book)...")
            generate_icon("Octavo", draw_octavo_icon, PROJECT_ROOT / "Octavo")
        else:
            print(f"Unknown target: {target}. Use 'athenaeum' or 'octavo'.", file=sys.stderr)
            sys.exit(1)

    print("Done.")


if __name__ == "__main__":
    main()
