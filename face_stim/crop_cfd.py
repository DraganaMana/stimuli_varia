"""
crop_cfd.py — center-crop CFD images to square and update trial_list_local.csv.

CFD images are 2444×1718 (landscape, ratio ~1.42).
RADIATE images are 450×450 (square).
This script center-crops every CFD JPG in stimuli_images/faces/CFD/ to a
square (width = height), saves the result alongside the original as
<stem>_cropped.jpg, then rewrites trial_list_local.csv to reference the
cropped versions.

Run after copy_stimuli.py:
    conda run -n mne1.8 python crop_cfd.py
"""

import csv
from pathlib import Path
from PIL import Image

SCRIPT_DIR = Path(__file__).parent
CFD_LOCAL  = SCRIPT_DIR / "stimuli_images" / "faces" / "CFD"
LOCAL_CSV  = SCRIPT_DIR / "trial_list_local.csv"
PATH_COLS  = ["top_correct", "bottom_left", "bottom_right"]
JPEG_QUALITY = 95


def center_crop_square(img: Image.Image) -> Image.Image:
    w, h = img.size
    s    = min(w, h)
    left = (w - s) // 2
    top  = (h - s) // 2
    return img.crop((left, top, left + s, top + s))


def main():
    if not CFD_LOCAL.exists():
        raise FileNotFoundError(
            f"CFD local folder not found: {CFD_LOCAL}\n"
            "Run copy_stimuli.py first."
        )
    if not LOCAL_CSV.exists():
        raise FileNotFoundError(
            f"trial_list_local.csv not found.\n"
            "Run copy_stimuli.py first."
        )

    originals = [
        f for f in CFD_LOCAL.rglob("*.jpg")
        if not f.stem.endswith("_cropped")
    ]
    print(f"CFD originals found : {len(originals)}")

    cropped_count = skipped = 0
    sizes_seen = set()

    for src in sorted(originals):
        dst = src.parent / (src.stem + "_cropped.jpg")
        if dst.exists():
            skipped += 1
            continue
        img = Image.open(src)
        sizes_seen.add(img.size)
        img_sq = center_crop_square(img)
        img_sq.save(dst, "JPEG", quality=JPEG_QUALITY)
        cropped_count += 1

    print(f"  Cropped            : {cropped_count}")
    print(f"  Already present    : {skipped}")
    if sizes_seen:
        print(f"  Source sizes seen  : {sorted(sizes_seen)}")

    # Update trial_list_local.csv — replace CFD .jpg paths with _cropped.jpg
    with open(LOCAL_CSV, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    fieldnames = list(rows[0].keys())

    updated = 0
    for row in rows:
        # CFD rows have relative paths starting with "CFD/"; RADIATE start with "RADIATE_"
        if not row.get("top_correct", "").startswith("CFD/"):
            continue
        for col in PATH_COLS:
            val = row[col]
            if val.endswith(".jpg") and not val.endswith("_cropped.jpg"):
                row[col] = val[:-4] + "_cropped.jpg"
                updated += 1

    with open(LOCAL_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nUpdated {updated} path entries in {LOCAL_CSV.name}")
    print("Done.")


if __name__ == "__main__":
    main()
