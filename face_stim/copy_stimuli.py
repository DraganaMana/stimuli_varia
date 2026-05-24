"""
copy_stimuli.py — bundle face images into the repo for standalone use.

Reads trial_list.csv (which references external RADIATE and CFD image files),
copies every unique face image into stimuli_images/faces/ preserving each
database's subfolder structure, then writes trial_list_local.csv with paths
relative to this script's directory so the repo is portable across machines.

Database layouts after copying:
  stimuli_images/faces/RADIATE_COLOR_X/IDENTITY/file.bmp   (RADIATE)
  stimuli_images/faces/CFD/IDENTITY_DIR/file.jpg            (CFD)

Shape images are already generated locally by generate_shapes.py and
tracked in shapes_output/ — no copying needed for those.

Usage:
    python copy_stimuli.py

After running this once (requires access to RADIATE and CFD data),
point the task script to trial_list_local.csv via opts.csv_path.
"""

import csv
import shutil
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
SRC_CSV    = SCRIPT_DIR / "trial_list.csv"
DST_CSV    = SCRIPT_DIR / "trial_list_local.csv"
IMG_DIR    = SCRIPT_DIR / "stimuli_images" / "faces"

# Relative base_path values written into trial_list_local.csv.
# These are resolved against script_dir by the MATLAB task.
FACES_BASE  = "stimuli_images/faces"
SHAPES_BASE = "shapes_output"

PATH_COLS = ["top_correct", "bottom_left", "bottom_right"]

# Substrings used to identify which database a face row belongs to.
RADIATE_TAG = "RADIATE"
CFD_TAG     = "CFD"

# Destination subdirectory prefix under IMG_DIR for CFD images.
CFD_SUBDIR  = "CFD"


def row_db(row: dict) -> str:
    """Return 'radiate', 'cfd', or 'shape' for a trial row."""
    bp = row["base_path"]
    if RADIATE_TAG in bp:
        return "radiate"
    if CFD_TAG in bp:
        return "cfd"
    return "shape"


def main():
    if not SRC_CSV.exists():
        raise FileNotFoundError(
            f"trial_list.csv not found at {SRC_CSV}\n"
            "Run generate_trial_list.py first."
        )

    IMG_DIR.mkdir(parents=True, exist_ok=True)

    with open(SRC_CSV, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    fieldnames = list(rows[0].keys())

    # Determine database roots from the first matching row in the CSV.
    def _first_base(tag):
        for r in rows:
            if tag in r["base_path"]:
                return Path(r["base_path"].rstrip("\\/"))
        return None

    radiate_root = _first_base(RADIATE_TAG)
    cfd_root     = _first_base(CFD_TAG)

    if radiate_root:
        print(f"Source RADIATE root : {radiate_root}")
    if cfd_root:
        print(f"Source CFD root     : {cfd_root}")
    print(f"Destination         : {IMG_DIR}\n")

    # Collect unique (source_path, dest_path) pairs to copy.
    copy_pairs: list[tuple[Path, Path]] = []

    for row in rows:
        db = row_db(row)
        if db == "shape":
            continue

        bp = Path(row["base_path"].rstrip("\\/"))

        for col in PATH_COLS:
            rel_path = Path(row[col].replace("\\", "/"))
            src      = bp / rel_path

            if db == "radiate":
                # Preserve RADIATE_COLOR_X/IDENTITY/ hierarchy.
                dst = IMG_DIR / rel_path
            else:
                # Place CFD images under stimuli_images/faces/CFD/IDENTITY/
                dst = IMG_DIR / CFD_SUBDIR / rel_path

            copy_pairs.append((src, dst))

    # Deduplicate while keeping order.
    seen       = set()
    unique_pairs = []
    for pair in copy_pairs:
        key = str(pair[0])
        if key not in seen:
            seen.add(key)
            unique_pairs.append(pair)

    print(f"Unique face images referenced: {len(unique_pairs)}")

    copied = skipped = missing = 0
    for src, dst in unique_pairs:
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not src.exists():
            print(f"  [MISSING] {src}")
            missing += 1
            continue
        if dst.exists():
            skipped += 1
        else:
            shutil.copy2(src, dst)
            copied += 1

    print(f"  Copied          : {copied}")
    print(f"  Already present : {skipped}")
    if missing:
        print(f"  Missing on disk : {missing}  <-- check source data paths")
    print()

    # Write trial_list_local.csv with relative base_path values.
    out_rows = []
    for row in rows:
        new_row = dict(row)
        db = row_db(row)
        if db == "shape":
            new_row["base_path"] = SHAPES_BASE
        else:
            new_row["base_path"] = FACES_BASE
            if db == "cfd":
                # Prefix relative image paths with CFD/ to match the
                # stimuli_images/faces/CFD/ destination hierarchy.
                for col in PATH_COLS:
                    rel = new_row[col].replace("\\", "/")
                    new_row[col] = CFD_SUBDIR + "/" + rel
        out_rows.append(new_row)

    with open(DST_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(out_rows)

    print(f"Written : {DST_CSV}")

    # Summary
    radiate_rows = [r for r in rows if row_db(r) == "radiate"]
    cfd_rows     = [r for r in rows if row_db(r) == "cfd"]
    shape_rows   = [r for r in rows if row_db(r) == "shape"]
    print(f"\nTrial counts in trial_list_local.csv:")
    print(f"  RADIATE face trials : {len(radiate_rows)}")
    print(f"  CFD face trials     : {len(cfd_rows)}")
    print(f"  Shape trials        : {len(shape_rows)}")
    print("Done.")


if __name__ == "__main__":
    main()
