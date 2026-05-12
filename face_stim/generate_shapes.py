"""
Generate shape stimuli for the Hariri face-matching task control condition.

Outputs 8 PNG files (RGBA, transparent background) at 240x200 px:
    4 circles  (small / medium / large / xlarge)
    4 ovals    (wide-small / wide-large / tall-small / tall-large)

Usage:
    python generate_shapes.py [--output PATH]

Default output: ./shapes_output/
Place the generated files in:  basepath/imagesv3/newstim/
"""

import argparse
import os
from pathlib import Path
from PIL import Image, ImageDraw

SCRIPT_DIR = Path(__file__).parent

IMG_W = 240
IMG_H = 200
FILL_COLOR = (80, 80, 80, 255)   # dark gray, fully opaque

SHAPES = [
    # (filename_stem,   ellipse_w, ellipse_h)
    ("circle_small",         60,   60),
    ("circle_medium",        90,   90),
    ("circle_large",        120,  120),
    ("circle_xlarge",       150,  150),
    ("oval_wide_small",     130,   65),
    ("oval_wide_large",     170,   85),
    ("oval_tall_small",      65,  110),
    ("oval_tall_large",      85,  150),
]


def generate(output_dir: str) -> None:
    os.makedirs(output_dir, exist_ok=True)

    for name, w, h in SHAPES:
        img = Image.new("RGBA", (IMG_W, IMG_H), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        x0 = (IMG_W - w) // 2
        y0 = (IMG_H - h) // 2
        draw.ellipse([x0, y0, x0 + w, y0 + h], fill=FILL_COLOR)

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
