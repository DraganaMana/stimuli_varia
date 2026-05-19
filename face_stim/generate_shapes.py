"""
Generate shape stimuli for the Hariri face-matching task control condition.

Outputs 15 PNG files (RGBA, transparent background) at 300x300 px:
    3 circles          (small, large, xxlarge)
    3 squares          (small, large, xxlarge)
    3 wide rectangles  (small, large, xxlarge)
    3 tall rectangles  (small, large, xxlarge)
    3 equilateral triangles (small, large, xxlarge)

Three clearly-spaced sizes per category ensure within-category pairs are
distinguishable. Across-category pairs are immediately distinguishable by
shape — the trial list generator enforces cross-category foils so that
the target and distractor in each trial are always from different categories.

Each shape is rendered with a medium-gray fill and a thick dark-gray outline.

Usage:
    python generate_shapes.py [--output PATH]

Default output: ./shapes_output/
Note: existing .png files in the output directory are removed before
      regenerating so stale shapes from a previous run don't accumulate.
"""

import argparse
import math
import os
from pathlib import Path
from PIL import Image, ImageDraw

SCRIPT_DIR = Path(__file__).parent

IMG_W = 300
IMG_H = 300
CX    = IMG_W // 2
CY    = IMG_H // 2

FILL_COLOR    = (115, 115, 115, 255)
OUTLINE_COLOR = (30,  30,  30,  255)
OUTLINE_WIDTH = 10

# (filename_stem, shape_type, param_a, param_b)
# param_a / param_b meaning by type:
#   circle   → diameter (param_b ignored)
#   square   → side     (param_b ignored)
#   rect     → width, height
#   triangle → side     (param_b ignored)
SHAPES = [
    # --- circles: diameter small / large / xxlarge ---
    ("circle_small",        "circle",    70,   0),
    ("circle_large",        "circle",   140,   0),
    ("circle_xxlarge",      "circle",   210,   0),

    # --- squares: side small / large / xxlarge ---
    ("square_small",        "square",    70,   0),
    ("square_large",        "square",   140,   0),
    ("square_xxlarge",      "square",   210,   0),

    # --- wide rectangles: width × height, aspect ≈ 2.3:1 ---
    ("rect_wide_small",     "rect",     120,  52),
    ("rect_wide_large",     "rect",     190,  82),
    ("rect_wide_xxlarge",   "rect",     260, 112),

    # --- tall rectangles: width × height, aspect ≈ 1:2.3 ---
    ("rect_tall_small",     "rect",      52, 120),
    ("rect_tall_large",     "rect",      82, 190),
    ("rect_tall_xxlarge",   "rect",     112, 260),

    # --- equilateral triangles: side small / large / xxlarge ---
    ("triangle_small",      "triangle",  80,   0),
    ("triangle_large",      "triangle", 150,   0),
    ("triangle_xxlarge",    "triangle", 220,   0),
]


def draw_circle(draw: ImageDraw.ImageDraw, diameter: int) -> None:
    r = diameter // 2
    draw.ellipse(
        [CX - r, CY - r, CX + r, CY + r],
        fill=FILL_COLOR, outline=OUTLINE_COLOR, width=OUTLINE_WIDTH,
    )


def draw_square(draw: ImageDraw.ImageDraw, side: int) -> None:
    h = side // 2
    draw.rectangle(
        [CX - h, CY - h, CX + h, CY + h],
        fill=FILL_COLOR, outline=OUTLINE_COLOR, width=OUTLINE_WIDTH,
    )


def draw_rect(draw: ImageDraw.ImageDraw, w: int, h: int) -> None:
    hw, hh = w // 2, h // 2
    draw.rectangle(
        [CX - hw, CY - hh, CX + hw, CY + hh],
        fill=FILL_COLOR, outline=OUTLINE_COLOR, width=OUTLINE_WIDTH,
    )


def draw_triangle(draw: ImageDraw.ImageDraw, side: int) -> None:
    h = side * math.sqrt(3) / 2          # height of equilateral triangle
    top    = (CX,           CY - 2 * h / 3)
    bot_l  = (CX - side / 2, CY + h / 3)
    bot_r  = (CX + side / 2, CY + h / 3)
    draw.polygon(
        [top, bot_l, bot_r],
        fill=FILL_COLOR, outline=OUTLINE_COLOR, width=OUTLINE_WIDTH,
    )


def generate(output_dir: str) -> None:
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)

    # Remove stale PNGs from a previous run
    removed = list(out.glob("*.png"))
    for f in removed:
        f.unlink()
    if removed:
        print(f"Removed {len(removed)} old PNG(s) from {output_dir}")

    for name, shape_type, a, b in SHAPES:
        img  = Image.new("RGBA", (IMG_W, IMG_H), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        if shape_type == "circle":
            draw_circle(draw, a)
        elif shape_type == "square":
            draw_square(draw, a)
        elif shape_type == "rect":
            draw_rect(draw, a, b)
        elif shape_type == "triangle":
            draw_triangle(draw, a)
        else:
            raise ValueError(f"Unknown shape type: {shape_type}")

        path = out / f"{name}.png"
        img.save(path)
        print(f"Saved: {path}")

    print(f"\nDone — {len(SHAPES)} shapes written to: {output_dir}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate shape stimuli PNGs.")
    parser.add_argument(
        "--output",
        default=str(SCRIPT_DIR / "shapes_output"),
        help="Directory to write PNGs into (default: face_stim/shapes_output/)",
    )
    args = parser.parse_args()
    generate(args.output)