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

from PIL import Image, ImageDraw

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

    return img


def draw_octavo_icon(size):
    """Draw the Octavo open book icon at the given pixel size."""
    import random
    rng = random.Random(42)  # Fixed seed for reproducibility

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background — matching Athenaeum burgundy
    bg_color = (85, 40, 50)
    radius = int(size * 0.18)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, fill=bg_color)

    edge_color = (65, 30, 38)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, outline=edge_color, width=max(1, size // 256))

    # Shadow under book
    shadow_color = (60, 25, 32)
    cx = size // 2
    shadow_top = int(size * 0.26)
    shadow_bottom = int(size * 0.76)
    shadow_offset = max(2, int(size * 0.015))
    draw.polygon([
        (int(size * 0.11) + shadow_offset, shadow_top - int(size * 0.02) + shadow_offset),
        (cx, shadow_top + int(size * 0.02) + shadow_offset),
        (size - int(size * 0.11) + shadow_offset, shadow_top - int(size * 0.02) + shadow_offset),
        (size - int(size * 0.11) + shadow_offset, shadow_bottom - int(size * 0.02) + shadow_offset),
        (cx, shadow_bottom + int(size * 0.02) + shadow_offset),
        (int(size * 0.11) + shadow_offset, shadow_bottom - int(size * 0.02) + shadow_offset),
    ], fill=shadow_color)

    # Book geometry — angled pages meeting at spine
    book_top = int(size * 0.22)
    book_bottom = int(size * 0.72)
    book_left = int(size * 0.12)
    book_right = size - int(size * 0.12)
    # Perspective angles — subtle: outer edges slightly higher than spine
    spine_top = book_top + int(size * 0.012)
    spine_bottom = book_bottom - int(size * 0.005)

    left_top_inner = spine_top
    left_top_outer = book_top - int(size * 0.008)
    left_bot_inner = spine_bottom
    left_bot_outer = book_bottom - int(size * 0.02)

    right_top_inner = spine_top
    right_top_outer = book_top - int(size * 0.008)
    right_bot_inner = spine_bottom
    right_bot_outer = book_bottom - int(size * 0.02)

    cover_color = (160, 50, 45)
    cover_dark = (130, 40, 35)
    page_color = (250, 245, 235)
    page_shadow = (235, 228, 215)
    spine_color = (90, 55, 38)

    # Left cover (visible only at outer edge, not extending to spine)
    cover_w = int(size * 0.025)
    cover_extent = int(size * 0.06)  # How far inward the cover peeks
    draw.polygon([
        (book_left - cover_w, left_top_outer + int(size * 0.005)),
        (book_left + cover_extent, left_top_outer + int(size * 0.015)),
        (book_left + cover_extent, left_bot_outer + int(size * 0.01)),
        (book_left - cover_w, left_bot_outer + int(size * 0.015)),
    ], fill=cover_color)

    # Right cover (visible only at outer edge)
    draw.polygon([
        (book_right - cover_extent, right_top_outer + int(size * 0.015)),
        (book_right + cover_w, right_top_outer + int(size * 0.005)),
        (book_right + cover_w, right_bot_outer + int(size * 0.015)),
        (book_right - cover_extent, right_bot_outer + int(size * 0.01)),
    ], fill=cover_color)

    # Page edges (stacked pages visible at outer edges only)
    edge_color_light = (240, 235, 225)
    edge_color_mid = (225, 218, 205)
    page_thickness = max(2, int(size * 0.012))
    # Left side — thin strip along outer edge beneath the page
    draw.polygon([
        (book_left - page_thickness, left_top_outer + int(size * 0.005)),
        (book_left, left_top_outer),
        (book_left, left_bot_outer),
        (book_left - page_thickness, left_bot_outer + int(size * 0.005)),
    ], fill=edge_color_mid)
    # Right side
    draw.polygon([
        (book_right, right_top_outer),
        (book_right + page_thickness, right_top_outer + int(size * 0.005)),
        (book_right + page_thickness, right_bot_outer + int(size * 0.005)),
        (book_right, right_bot_outer),
    ], fill=edge_color_mid)

    # Spine
    spine_w = max(2, int(size * 0.015))
    spine_x_l = cx - spine_w // 2
    spine_x_r = cx + spine_w // 2
    flat_top = min(left_top_outer, right_top_outer)  # Highest point

    # Left page — top edge is flat across, slopes only at bottom
    draw.polygon([
        (book_left, left_top_outer),
        (spine_x_l, flat_top),
        (spine_x_l, left_bot_inner),
        (book_left, left_bot_outer),
    ], fill=page_color)

    # Right page
    draw.polygon([
        (spine_x_r, flat_top),
        (book_right, right_top_outer),
        (book_right, right_bot_outer),
        (spine_x_r, right_bot_inner),
    ], fill=page_color)

    # Inner shadow near spine (left)
    shadow_w = int(size * 0.04)
    for s in range(shadow_w):
        alpha_frac = 1.0 - (s / shadow_w)
        r = int(page_color[0] - (page_color[0] - page_shadow[0]) * alpha_frac)
        g = int(page_color[1] - (page_color[1] - page_shadow[1]) * alpha_frac)
        b = int(page_color[2] - (page_color[2] - page_shadow[2]) * alpha_frac)
        x = spine_x_l - s
        frac = s / shadow_w
        y_bot = int(left_bot_inner + (left_bot_outer - left_bot_inner) * frac)
        draw.line([x, flat_top, x, y_bot], fill=(r, g, b))

    # Inner shadow near spine (right)
    for s in range(shadow_w):
        alpha_frac = 1.0 - (s / shadow_w)
        r = int(page_color[0] - (page_color[0] - page_shadow[0]) * alpha_frac)
        g = int(page_color[1] - (page_color[1] - page_shadow[1]) * alpha_frac)
        b = int(page_color[2] - (page_color[2] - page_shadow[2]) * alpha_frac)
        x = spine_x_r + s
        frac = s / shadow_w
        y_bot = int(right_bot_inner + (right_bot_outer - right_bot_inner) * frac)
        draw.line([x, flat_top, x, y_bot], fill=(r, g, b))

    # Spine groove
    draw.rectangle([spine_x_l, flat_top, spine_x_r, spine_bottom], fill=spine_color)
    hl_w = max(1, spine_w // 3)
    spine_hl = (120, 80, 55)
    draw.rectangle([spine_x_l, flat_top, spine_x_l + hl_w, spine_bottom], fill=spine_hl)

    # Text scribbles — varied lengths to simulate real text
    lw = max(1, size // 256)
    line_color = (195, 188, 178)
    line_dark = (175, 168, 158)
    num_lines = 9
    line_spacing = int(size * 0.038)

    # Line length patterns (fraction of available width) — simulate paragraphs
    left_lengths = [0.95, 0.88, 0.72, 0.95, 0.80, 0.60, 0.95, 0.90, 0.45]
    right_lengths = [0.90, 0.95, 0.85, 0.68, 0.95, 0.92, 0.75, 0.95, 0.55]

    for i in range(num_lines):
        # Interpolate Y positions along the angled page
        frac = (int(size * 0.06) + i * line_spacing) / (left_bot_outer - left_top_outer)
        if frac > 0.9:
            break

        # Left page
        y_left_at_outer = left_top_outer + frac * (left_bot_outer - left_top_outer)
        y_left_at_inner = left_top_inner + frac * (left_bot_inner - left_top_inner)
        margin_l = book_left + int(size * 0.04)
        margin_r_left = cx - int(size * 0.05)
        avail_w = margin_r_left - margin_l
        length_frac = left_lengths[i] if i < len(left_lengths) else 0.8
        # Slight y slope across the line for perspective
        y_l = int(y_left_at_outer) + int(size * 0.02)
        y_r = int(y_left_at_outer + (y_left_at_inner - y_left_at_outer) * length_frac) + int(size * 0.02)
        color = line_dark if i % 3 == 0 else line_color
        draw.line([margin_l, y_l, margin_l + int(avail_w * length_frac), y_r], fill=color, width=lw)

        # Right page
        y_right_at_inner = right_top_inner + frac * (right_bot_inner - right_top_inner)
        y_right_at_outer = right_top_outer + frac * (right_bot_outer - right_top_outer)
        margin_l_right = cx + int(size * 0.05)
        margin_r = book_right - int(size * 0.04)
        avail_w_r = margin_r - margin_l_right
        length_frac_r = right_lengths[i] if i < len(right_lengths) else 0.8
        y_l2 = int(y_right_at_inner) + int(size * 0.02)
        y_r2 = int(y_right_at_inner + (y_right_at_outer - y_right_at_inner) * length_frac_r) + int(size * 0.02)
        color = line_dark if (i + 1) % 3 == 0 else line_color
        draw.line([margin_l_right, y_l2, margin_l_right + int(avail_w_r * length_frac_r), y_r2], fill=color, width=lw)

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
