"""
copy_stimuli.py — bundle face images into the repo for standalone use.

Reads trial_list.csv (which references external RADIATE image files),
copies every unique face image into stimuli_images/faces/ (preserving the
RADIATE subfolder structure), then writes trial_list_local.csv with paths
relative to this script's directory so the repo is portable across machines.

Shape images are already generated locally by generate_shapes.py and
tracked in shapes_output/ — no copying needed for those.

Usage:
    python copy_stimuli.py

After running this once (requires access to the original RADIATE data),
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


def is_face_row(row: dict) -> bool:
    return "RADIATE" in row["base_path"]


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

    # Determine the RADIATE root from the first face row in the CSV.
    face_rows = [r for r in rows if is_face_row(r)]
    if not face_rows:
        raise RuntimeError("No face (RADIATE) rows found in trial_list.csv.")

    radiate_root = Path(face_rows[0]["base_path"].rstrip("\\/"))

    print(f"Source RADIATE root : {radiate_root}")
    print(f"Destination         : {IMG_DIR}")
    print()

    # Collect every unique relative face image path across all three columns.
    unique_rel_paths = set()
    for row in face_rows:
        for col in PATH_COLS:
            unique_rel_paths.add(row[col])

    print(f"Unique face images referenced: {len(unique_rel_paths)}")

    # Copy images, preserving the RADIATE_COLOR_X/IDENTITY/ subfolder structure.
    copied  = 0
    skipped = 0
    missing = 0
    for rel_path in sorted(unique_rel_paths):
        # Normalise separators so Path handles Windows backslashes from the CSV.
        rel_path_norm = Path(rel_path.replace("\\", "/"))
        src = radiate_root / rel_path_norm
        dst = IMG_DIR / rel_path_norm
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
        print(f"  Missing on disk : {missing}  <-- check RADIATE path")
    print()

    # Write trial_list_local.csv with relative base_path values.
    out_rows = []
    for row in rows:
        new_row = dict(row)
        new_row["base_path"] = FACES_BASE if is_face_row(row) else SHAPES_BASE
        out_rows.append(new_row)

    with open(DST_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(out_rows)

    print(f"Written : {DST_CSV}")

    # Summary of directory structure created.
    subdirs = sorted({(IMG_DIR / Path(r.replace("\\", "/"))).parent for r in unique_rel_paths if not Path(r.replace("\\", "/")).parent == Path(".")})
    color_groups = sorted({p.parent.name for p in subdirs})
    print(f"\nDirectory structure under stimuli_images/faces/:")
    print(f"  Colour groups : {color_groups}")
    print(f"  Identity dirs : {len(subdirs)}")
    print("Done.")


if __name__ == "__main__":
    main()
