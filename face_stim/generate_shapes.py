"""
Generate shape stimuli for the Hariri face-matching task control condition.

Outputs PNG files (RGBA, transparent background) at 300x300 px.

Shape categories (3 sizes each: small / large / xxlarge):
  Existing:
    circles, squares, wide rectangles, tall rectangles, triangles (up)
  New:
    ovals wide, ovals tall, ovals tilted 45°, ovals tilted 315°,
    triangles down, kites, pentagons, trapezoids, parallelograms,
    rhombuses, heptagons, semicircles, stars (5-pointed)

Each shape is rendered with a medium-gray fill and a thick dark-gray outline.
Each orientation/variant is its own category (used as the foil constraint in
the trial-list generator: top and distractor are always from different categories).

Usage:
    python generate_shapes.py [--output PATH]

Default output: ./shapes_output/
Existing .png files in the output directory are removed before regenerating.
"""

import argparse
import math
from pathlib import Path
from PIL import Image, ImageDraw

SCRIPT_DIR = Path(__file__).parent

IMG_W = IMG_H = 300
CX = CY = IMG_W // 2

FILL    = (115, 115, 115, 255)
OUTLINE = (30,  30,  30,  255)
OW      = 10   # outline width

# ---------------------------------------------------------------------------
# Shape list — list of dicts with keys: name, type, and type-specific params.
# The "name" becomes the output filename stem.
# The last "_" segment of the stem is the size label (small/large/xxlarge),
# and everything before it is the category used by the trial-list generator.
# ---------------------------------------------------------------------------

SHAPES = [
    # --- circles: diameter ---
    dict(name="circle_small",        type="circle",      d=70),
    dict(name="circle_large",        type="circle",      d=140),
    dict(name="circle_xxlarge",      type="circle",      d=210),

    # --- squares: side ---
    dict(name="square_small",        type="square",      s=70),
    dict(name="square_large",        type="square",      s=140),
    dict(name="square_xxlarge",      type="square",      s=210),

    # --- wide rectangles: width × height (aspect ~2.3:1) ---
    dict(name="rect_wide_small",     type="rect",        w=120, h=52),
    dict(name="rect_wide_large",     type="rect",        w=190, h=82),
    dict(name="rect_wide_xxlarge",   type="rect",        w=260, h=112),

    # --- tall rectangles: width × height (aspect ~1:2.3) ---
    dict(name="rect_tall_small",     type="rect",        w=52,  h=120),
    dict(name="rect_tall_large",     type="rect",        w=82,  h=190),
    dict(name="rect_tall_xxlarge",   type="rect",        w=112, h=260),

    # --- equilateral triangles pointing up: side ---
    dict(name="triangle_small",      type="triangle_up", s=80),
    dict(name="triangle_large",      type="triangle_up", s=150),
    dict(name="triangle_xxlarge",    type="triangle_up", s=220),

    # --- equilateral triangles pointing down: side ---
    dict(name="triangle_down_small",    type="triangle_down", s=80),
    dict(name="triangle_down_large",    type="triangle_down", s=150),
    dict(name="triangle_down_xxlarge",  type="triangle_down", s=220),

    # --- ovals wide (horizontal, aspect ~2:1): semi-major a, semi-minor b ---
    dict(name="oval_wide_small",     type="oval",  a=75,  b=38,  angle=0),
    dict(name="oval_wide_large",     type="oval",  a=105, b=52,  angle=0),
    dict(name="oval_wide_xxlarge",   type="oval",  a=135, b=67,  angle=0),

    # --- ovals tall (vertical, aspect ~1:2): semi-minor a, semi-major b ---
    dict(name="oval_tall_small",     type="oval",  a=38,  b=75,  angle=0),
    dict(name="oval_tall_large",     type="oval",  a=52,  b=105, angle=0),
    dict(name="oval_tall_xxlarge",   type="oval",  a=67,  b=135, angle=0),

    # --- ovals tilted 45° (drawn as oval_wide then rotated) ---
    dict(name="oval_tilt45_small",   type="oval",  a=75,  b=38,  angle=45),
    dict(name="oval_tilt45_large",   type="oval",  a=105, b=52,  angle=45),
    dict(name="oval_tilt45_xxlarge", type="oval",  a=135, b=67,  angle=45),

    # --- ovals tilted 315° (−45°) ---
    dict(name="oval_tilt315_small",   type="oval", a=75,  b=38,  angle=315),
    dict(name="oval_tilt315_large",   type="oval", a=105, b=52,  angle=315),
    dict(name="oval_tilt315_xxlarge", type="oval", a=135, b=67,  angle=315),

    # --- kites: half-width hw, height above centre h_top, height below h_bot ---
    dict(name="kite_small",          type="kite",  hw=40, h_top=50, h_bot=90),
    dict(name="kite_large",          type="kite",  hw=55, h_top=70, h_bot=128),
    dict(name="kite_xxlarge",        type="kite",  hw=72, h_top=88, h_bot=162),

    # --- pentagons (regular 5-gon, vertex up): circumradius r ---
    dict(name="pentagon_small",      type="ngon",  n=5,  r=65),
    dict(name="pentagon_large",      type="ngon",  n=5,  r=100),
    dict(name="pentagon_xxlarge",    type="ngon",  n=5,  r=130),

    # --- trapezoids (isosceles, wider bottom): top_w, bot_w, h ---
    dict(name="trapezoid_small",     type="trapezoid", top_w=60,  bot_w=120, h=70),
    dict(name="trapezoid_large",     type="trapezoid", top_w=90,  bot_w=175, h=100),
    dict(name="trapezoid_xxlarge",   type="trapezoid", top_w=115, bot_w=225, h=130),

    # --- parallelograms: half-width hw, half-height hh, horizontal skew sk ---
    dict(name="parallelogram_small",    type="parallelogram", hw=55, hh=30, sk=25),
    dict(name="parallelogram_large",    type="parallelogram", hw=80, hh=42, sk=35),
    dict(name="parallelogram_xxlarge",  type="parallelogram", hw=105, hh=55, sk=45),

    # --- rhombuses (elongated diamond): half-width hw, half-height hh ---
    dict(name="rhombus_small",       type="rhombus", hw=40, hh=65),
    dict(name="rhombus_large",       type="rhombus", hw=57, hh=95),
    dict(name="rhombus_xxlarge",     type="rhombus", hw=75, hh=125),

    # --- heptagons (regular 7-gon): circumradius r ---
    dict(name="heptagon_small",      type="ngon",  n=7,  r=65),
    dict(name="heptagon_large",      type="ngon",  n=7,  r=100),
    dict(name="heptagon_xxlarge",    type="ngon",  n=7,  r=130),

    # --- semicircles (flat side at bottom): radius r ---
    dict(name="semicircle_small",    type="semicircle", r=70),
    dict(name="semicircle_large",    type="semicircle", r=100),
    dict(name="semicircle_xxlarge",  type="semicircle", r=130),

    # --- 5-pointed stars: outer radius, inner radius ---
    dict(name="star_small",          type="star",  outer=65,  inner=26),
    dict(name="star_large",          type="star",  outer=100, inner=40),
    dict(name="star_xxlarge",        type="star",  outer=130, inner=52),

    # --- right triangles (90° at bottom-left): leg s ---
    dict(name="right_triangle_small",   type="right_triangle", s=80),
    dict(name="right_triangle_large",   type="right_triangle", s=150),
    dict(name="right_triangle_xxlarge", type="right_triangle", s=195),

    # --- wide isosceles triangles (flat, obtuse apex): base width, height ---
    dict(name="triangle_wide_small",    type="triangle_wide", base=180, h=55),
    dict(name="triangle_wide_large",    type="triangle_wide", base=240, h=78),
    dict(name="triangle_wide_xxlarge",  type="triangle_wide", base=260, h=90),

    # --- arrows pointing right: total_len, head_len, shaft_half, head_half ---
    dict(name="arrow_right_small",   type="arrow_right", total_len=140, head_len=55, shaft_half=14, head_half=38),
    dict(name="arrow_right_large",   type="arrow_right", total_len=200, head_len=75, shaft_half=20, head_half=52),
    dict(name="arrow_right_xxlarge", type="arrow_right", total_len=250, head_len=95, shaft_half=26, head_half=66),

    # --- arrows pointing up: same proportions, rotated 90° ---
    dict(name="arrow_up_small",   type="arrow_up", total_len=140, head_len=55, shaft_half=14, head_half=38),
    dict(name="arrow_up_large",   type="arrow_up", total_len=200, head_len=75, shaft_half=20, head_half=52),
    dict(name="arrow_up_xxlarge", type="arrow_up", total_len=250, head_len=95, shaft_half=26, head_half=66),

    # --- plus / Greek cross: arm_half (half arm-width), arm_ext (arm length) ---
    dict(name="plus_small",    type="plus", ah=18, ae=50),
    dict(name="plus_large",    type="plus", ah=26, ae=70),
    dict(name="plus_xxlarge",  type="plus", ah=34, ae=90),

    # --- chevrons opening right (">" shape): size ---
    dict(name="chevron_right_small",   type="chevron_right", s=70),
    dict(name="chevron_right_large",   type="chevron_right", s=95),
    dict(name="chevron_right_xxlarge", type="chevron_right", s=120),

    # --- chevrons opening up ("^" shape): size ---
    dict(name="chevron_up_small",   type="chevron_up", s=70),
    dict(name="chevron_up_large",   type="chevron_up", s=95),
    dict(name="chevron_up_xxlarge", type="chevron_up", s=120),
]


# ---------------------------------------------------------------------------
# Drawing helpers — all operate on (draw, **params)
# ---------------------------------------------------------------------------

def draw_circle(draw, d, **_):
    r = d // 2
    draw.ellipse([CX-r, CY-r, CX+r, CY+r], fill=FILL, outline=OUTLINE, width=OW)


def draw_square(draw, s, **_):
    h = s // 2
    draw.rectangle([CX-h, CY-h, CX+h, CY+h], fill=FILL, outline=OUTLINE, width=OW)


def draw_rect(draw, w, h, **_):
    draw.rectangle([CX-w//2, CY-h//2, CX+w//2, CY+h//2],
                   fill=FILL, outline=OUTLINE, width=OW)


def draw_triangle_up(draw, s, **_):
    height = s * math.sqrt(3) / 2
    pts = [
        (CX,           CY - 2 * height / 3),
        (CX - s / 2,   CY + height / 3),
        (CX + s / 2,   CY + height / 3),
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_triangle_down(draw, s, **_):
    height = s * math.sqrt(3) / 2
    pts = [
        (CX,           CY + 2 * height / 3),
        (CX - s / 2,   CY - height / 3),
        (CX + s / 2,   CY - height / 3),
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_kite(draw, hw, h_top, h_bot, **_):
    pts = [
        (CX,        CY - h_top),   # top vertex
        (CX + hw,   CY),           # right vertex
        (CX,        CY + h_bot),   # bottom vertex
        (CX - hw,   CY),           # left vertex
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def _regular_polygon_pts(n, r, start_deg=90):
    pts = []
    for i in range(n):
        a = math.radians(start_deg + 360 * i / n)
        pts.append((CX + r * math.cos(a), CY - r * math.sin(a)))
    return pts


def draw_ngon(draw, n, r, **_):
    draw.polygon(_regular_polygon_pts(n, r), fill=FILL, outline=OUTLINE, width=OW)


def draw_trapezoid(draw, top_w, bot_w, h, **_):
    pts = [
        (CX - top_w // 2, CY - h // 2),
        (CX + top_w // 2, CY - h // 2),
        (CX + bot_w // 2, CY + h // 2),
        (CX - bot_w // 2, CY + h // 2),
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_parallelogram(draw, hw, hh, sk, **_):
    pts = [
        (CX - hw + sk, CY - hh),
        (CX + hw + sk, CY - hh),
        (CX + hw - sk, CY + hh),
        (CX - hw - sk, CY + hh),
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_rhombus(draw, hw, hh, **_):
    pts = [
        (CX,      CY - hh),   # top
        (CX + hw, CY),        # right
        (CX,      CY + hh),   # bottom
        (CX - hw, CY),        # left
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_semicircle(draw, r, **_):
    # Flat edge at the bottom; arc spans 180° → 360° (upper half of ellipse bbox).
    draw.pieslice([CX-r, CY-r, CX+r, CY+r], start=180, end=360,
                  fill=FILL, outline=OUTLINE, width=OW)
    # Explicitly draw the flat chord so the outline is closed cleanly.
    draw.line([(CX-r, CY), (CX+r, CY)], fill=OUTLINE, width=OW)


def draw_right_triangle(draw, s, **_):
    # Right angle at bottom-left; centroid centred on (CX, CY).
    ra_x = CX - s // 3
    ra_y = CY + s // 3
    pts = [
        (ra_x,     ra_y),       # right-angle corner (bottom-left)
        (ra_x + s, ra_y),       # bottom-right
        (ra_x,     ra_y - s),   # top-left
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_triangle_wide(draw, base, h, **_):
    # Wide, flat isosceles triangle with apex pointing up.
    pts = [
        (CX,            CY - 2 * h / 3),   # apex
        (CX - base / 2, CY + h / 3),       # bottom-left
        (CX + base / 2, CY + h / 3),       # bottom-right
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_arrow_right(draw, total_len, head_len, shaft_half, head_half, **_):
    x_left   = CX - total_len // 2
    x_notch  = CX + total_len // 2 - head_len
    x_tip    = CX + total_len // 2
    pts = [
        (x_left,  CY - shaft_half),
        (x_notch, CY - shaft_half),
        (x_notch, CY - head_half),
        (x_tip,   CY),
        (x_notch, CY + head_half),
        (x_notch, CY + shaft_half),
        (x_left,  CY + shaft_half),
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_arrow_up(draw, total_len, head_len, shaft_half, head_half, **_):
    y_bot   = CY + total_len // 2
    y_notch = CY - total_len // 2 + head_len
    y_tip   = CY - total_len // 2
    pts = [
        (CX - shaft_half, y_bot),
        (CX - shaft_half, y_notch),
        (CX - head_half,  y_notch),
        (CX,              y_tip),
        (CX + head_half,  y_notch),
        (CX + shaft_half, y_notch),
        (CX + shaft_half, y_bot),
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_plus(draw, ah, ae, **_):
    # 12-vertex Greek cross (arm half-width ah, arm extension ae from centre square).
    pts = [
        (CX - ah,      CY - ae - ah),
        (CX + ah,      CY - ae - ah),
        (CX + ah,      CY - ah),
        (CX + ae + ah, CY - ah),
        (CX + ae + ah, CY + ah),
        (CX + ah,      CY + ah),
        (CX + ah,      CY + ae + ah),
        (CX - ah,      CY + ae + ah),
        (CX - ah,      CY + ah),
        (CX - ae - ah, CY + ah),
        (CX - ae - ah, CY - ah),
        (CX - ah,      CY - ah),
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_chevron_right(draw, s, **_):
    # Solid ">" shape: outer triangle minus a triangular inner notch.
    thick = s * 0.4
    pts = [
        (CX - s,            CY - s),             # outer top-left
        (CX + s,            CY),                 # right tip
        (CX - s,            CY + s),             # outer bottom-left
        (CX - s + thick,    CY + s - thick),     # inner bottom notch
        (CX + s - thick * 1.5, CY),              # inner tip
        (CX - s + thick,    CY - s + thick),     # inner top notch
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_chevron_up(draw, s, **_):
    # Solid "^" shape: outer triangle minus a triangular inner notch.
    thick = s * 0.4
    pts = [
        (CX - s,            CY + s),             # outer bottom-left
        (CX,                CY - s),             # top tip
        (CX + s,            CY + s),             # outer bottom-right
        (CX + s - thick,    CY + s - thick),     # inner bottom-right notch
        (CX,                CY - s + thick * 1.5), # inner tip
        (CX - s + thick,    CY + s - thick),     # inner bottom-left notch
    ]
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


def draw_star(draw, outer, inner, **_):
    n = 5
    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(90 + 360 * i / (n * 2))
        pts.append((CX + r * math.cos(a), CY - r * math.sin(a)))
    draw.polygon(pts, fill=FILL, outline=OUTLINE, width=OW)


# ---------------------------------------------------------------------------
# Oval: drawn on an oversized canvas so rotation doesn't clip the outline.
# ---------------------------------------------------------------------------

def render_oval(a, b, angle):
    """Return a 300×300 RGBA image with an ellipse of semi-axes (a, b) rotated by angle°."""
    BIG = IMG_W * 2
    big = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    d   = ImageDraw.Draw(big)
    cx  = BIG // 2
    d.ellipse([cx-a, cx-b, cx+a, cx+b], fill=FILL, outline=OUTLINE, width=OW)
    if angle:
        big = big.rotate(angle, expand=False, resample=Image.BILINEAR)
    off = (BIG - IMG_W) // 2
    return big.crop((off, off, off + IMG_W, off + IMG_H))


# ---------------------------------------------------------------------------
# Dispatch table
# ---------------------------------------------------------------------------

DRAW_FNS = {
    "circle":          draw_circle,
    "square":          draw_square,
    "rect":            draw_rect,
    "triangle_up":     draw_triangle_up,
    "triangle_down":   draw_triangle_down,
    "right_triangle":  draw_right_triangle,
    "triangle_wide":   draw_triangle_wide,
    "kite":            draw_kite,
    "ngon":            draw_ngon,
    "trapezoid":       draw_trapezoid,
    "parallelogram":   draw_parallelogram,
    "rhombus":         draw_rhombus,
    "semicircle":      draw_semicircle,
    "star":            draw_star,
    "arrow_right":     draw_arrow_right,
    "arrow_up":        draw_arrow_up,
    "plus":            draw_plus,
    "chevron_right":   draw_chevron_right,
    "chevron_up":      draw_chevron_up,
}


# ---------------------------------------------------------------------------
# Main generator
# ---------------------------------------------------------------------------

def generate(output_dir: str) -> None:
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)

    removed = list(out.glob("*.png"))
    for f in removed:
        f.unlink()
    if removed:
        print(f"Removed {len(removed)} old PNG(s) from {output_dir}")

    for spec in SHAPES:
        stype = spec["type"]

        if stype == "oval":
            img = render_oval(spec["a"], spec["b"], spec["angle"])
        else:
            img  = Image.new("RGBA", (IMG_W, IMG_H), (0, 0, 0, 0))
            draw = ImageDraw.Draw(img)
            fn   = DRAW_FNS.get(stype)
            if fn is None:
                raise ValueError(f"Unknown shape type: {stype!r} (name={spec['name']!r})")
            fn(draw, **spec)

        path = out / f"{spec['name']}.png"
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
