"""
Generate shape stimuli for the Hariri face-matching task control condition.

Outputs 20 PNG files (RGBA, transparent background) at 300x300 px:
    8 circles  — sizes spaced far enough to be clearly distinguishable
    6 wide ovals
    6 tall ovals

Each shape is rendered with a medium-gray fill and a thick very-dark-gray
outline so shape boundaries are crisp at all viewing distances.

Usage:
    python generate_shapes.py [--output PATH]

Default output: ./shapes_output/
"""

import argparse
import os
from pathlib import Path
from PIL import Image, ImageDraw

SCRIPT_DIR = Path(__file__).parent

IMG_W = 300
IMG_H = 300

FILL_COLOR    = (115, 115, 115, 255)   # medium gray, fully opaque
OUTLINE_COLOR = (30,  30,  30,  255)   # very dark gray, fully opaque
OUTLINE_WIDTH = 10                     # thick outline (px)

# (filename_stem, ellipse_w, ellipse_h)
# Sizes chosen so adjacent shapes differ by ≥ 22 px on the 300 px canvas
# (≥ 25 px when rendered at the ~1.1× display scale), making all pairs
# clearly visually distinguishable.
SHAPES = [
    # --- circles (8): diameter 40 → 236 px, step ≥ 22 px ---
    ("circle_xsmall",       40,   40),
    ("circle_small",        68,   68),
    ("circle_smallplus",    98,   98),
    ("circle_medium",      130,  130),
    ("circle_mediumplus",  160,  160),
    ("circle_large",       188,  188),
    ("circle_xlarge",      214,  214),
    ("circle_xxlarge",     236,  236),

    # --- wide ovals (6): width 110 → 278 px, aspect ratio ≈ 2:1 ---
    ("oval_wide_xsmall",   110,   54),
    ("oval_wide_small",    152,   74),
    ("oval_wide_medium",   194,   94),
    ("oval_wide_large",    228,  110),
    ("oval_wide_xlarge",   256,  122),
    ("oval_wide_xxlarge",  278,  132),

    # --- tall ovals (6): height 110 → 278 px, aspect ratio ≈ 2:1 ---
    ("oval_tall_xsmall",    54,  110),
    ("oval_tall_small",     74,  152),
    ("oval_tall_medium",    94,  194),
    ("oval_tall_large",    110,  228),
    ("oval_tall_xlarge",   122,  256),
    ("oval_tall_xxlarge",  132,  278),
]


def generate(output_dir: str) -> None:
    os.makedirs(output_dir, exist_ok=True)

    for name, w, h in SHAPES:
        img  = Image.new("RGBA", (IMG_W, IMG_H), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        x0 = (IMG_W - w) // 2
        y0 = (IMG_H - h) // 2
        draw.ellipse(
            [x0, y0, x0 + w, y0 + h],
            fill=FILL_COLOR,
            outline=OUTLINE_COLOR,
            width=OUTLINE_WIDTH,
        )

        path = os.path.join(output_dir, f"{name}.png")
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
