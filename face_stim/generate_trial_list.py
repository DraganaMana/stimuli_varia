"""
Generate trial list CSV for the emotion face-matching task.

Structure:
  - 1 day, 2 runs
  - 8 blocks per run: face / shape / face / shape ... (odd blocks = face, even = shape)
  - 9 trials per block
    - Face trials: 36 identities per day, each contributing exactly one angry (AC)
        and one fearful (FO) correct-answer trial
  - Shape trials: same matching logic with the 8 generated shapes

Outputs: trial_list.csv in the same directory as this script.
"""
#%%
import csv
import random
from pathlib import Path

#%%

SEED = 42
random.seed(SEED)

SCRIPT_DIR = Path(__file__).parent

RADIATE_ROOT = Path(
    r"C:\Users\draga\Documents\data\emotional_faces\RADIATE\RADIATE_BMP"
    r"\RADIATE_BMP\RADIATE_450_COLOR_BMP"
)
SHAPES_DIR = SCRIPT_DIR / "shapes_output"

N_DAYS = 1
N_RUNS = 2
N_BLOCKS_PER_RUN = 8          # 4 face + 4 shape, interleaved
N_TRIALS_PER_BLOCK = 9

# Block indices (1-based) that are face blocks; even = shape
FACE_BLOCK_INDICES = {1, 3, 5, 7}
SHAPE_BLOCK_INDICES = {2, 4, 6, 8}

FACE_TRIALS_PER_DAY = N_RUNS * len(FACE_BLOCK_INDICES) * N_TRIALS_PER_BLOCK  # 72
FACE_IDENTITIES_PER_DAY = FACE_TRIALS_PER_DAY // 2  # 36 identities x 2 expressions
SHAPE_TRIALS_PER_DAY = N_RUNS * len(SHAPE_BLOCK_INDICES) * N_TRIALS_PER_BLOCK  # 72

if FACE_TRIALS_PER_DAY % 2 != 0:
    raise ValueError("FACE_TRIALS_PER_DAY must be even so each identity can contribute AC and FO once.")


def collect_faces(expression_suffix: str) -> list[Path]:
    """Return all face image paths with the given suffix (e.g. '_AC.bmp')."""
    files = sorted(RADIATE_ROOT.rglob(f"*{expression_suffix}"))
    if not files:
        raise FileNotFoundError(
            f"No files matching *{expression_suffix} under {RADIATE_ROOT}"
        )
    return files


def identity_key(path: Path, expression_suffixes: tuple[str, ...] = ("_AC", "_FO")) -> str:
    """Return an identity key shared by AC and FO files for the same person."""
    relative = path.relative_to(RADIATE_ROOT)
    stem = path.stem
    for suffix in expression_suffixes:
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    else:
        raise ValueError(f"Could not parse expression suffix from filename: {path.name}")

    return str(relative.parent / stem)


def collect_face_pairs() -> list[tuple[Path, Path]]:
    """Collect identities that have both AC and FO images available."""
    ac_files = collect_faces("_AC.bmp")
    fo_files = collect_faces("_FO.bmp")

    ac_by_identity = {identity_key(path): path for path in ac_files}
    fo_by_identity = {identity_key(path): path for path in fo_files}
    paired_keys = sorted(set(ac_by_identity) & set(fo_by_identity))

    if len(paired_keys) < FACE_IDENTITIES_PER_DAY:
        raise ValueError(
            f"Need at least {FACE_IDENTITIES_PER_DAY} identities with both AC and FO images, "
            f"but found {len(paired_keys)}."
        )

    return [(ac_by_identity[key], fo_by_identity[key]) for key in paired_keys]


def collect_shapes() -> list[Path]:
    shapes = sorted(SHAPES_DIR.glob("*.png"))
    if not shapes:
        raise FileNotFoundError(f"No PNG shapes found in {SHAPES_DIR}")
    return shapes


def balanced_sides(n: int) -> list[str]:
    """Return a shuffled list of n sides with exactly n//2 'left' and ceil(n/2) 'right'."""
    half = n // 2
    pool = ["left"] * half + ["right"] * (n - half)
    random.shuffle(pool)
    return pool


def rel(path: Path, base: Path) -> str:
    return str(path.relative_to(base))


def make_left_right(top_path: Path, wrong_path: Path, side: str, base: Path) -> tuple[str, str, str]:
    """Return (bottom_left, bottom_right, bottom_correct_match) as paths relative to base."""
    top_rel = rel(top_path, base)
    wrong_rel = rel(wrong_path, base)
    if side == "left":
        return top_rel, wrong_rel, "left"
    else:
        return wrong_rel, top_rel, "right"


def make_derangement(items: list[Path]) -> list[Path]:
    """Return a shuffled copy where no item remains in its original position."""
    while True:
        shuffled = random.sample(items, len(items))
        if all(original != swapped for original, swapped in zip(items, shuffled)):
            return shuffled


def build_expression_trials(correct_paths: list[Path]) -> list[tuple[str, str, str]]:
    """Create one trial per correct path with a different-identity distractor of the same expression."""
    distractors = make_derangement(correct_paths)
    sides = balanced_sides(len(correct_paths))
    return [
        make_left_right(top_path, wrong_path, side, RADIATE_ROOT)
        for top_path, wrong_path, side in zip(correct_paths, distractors, sides)
    ]


def build_face_trials(face_pairs: list[tuple[Path, Path]]) -> list[tuple[str, str, str]]:
    """Build face trials so each selected identity contributes AC once and FO once as the correct answer."""
    selected_pairs = random.sample(face_pairs, FACE_IDENTITIES_PER_DAY)
    random.shuffle(selected_pairs)

    ac_paths = [ac_path for ac_path, _ in selected_pairs]
    fo_paths = [fo_path for _, fo_path in selected_pairs]

    ac_trials = build_expression_trials(ac_paths)
    fo_trials = build_expression_trials(fo_paths)

    trials = []
    face_blocks_per_day = N_RUNS * len(FACE_BLOCK_INDICES)
    expression_blocks = face_blocks_per_day // 2

    ac_blocks = [
        ac_trials[i * N_TRIALS_PER_BLOCK:(i + 1) * N_TRIALS_PER_BLOCK]
        for i in range(expression_blocks)
    ]
    fo_blocks = [
        fo_trials[i * N_TRIALS_PER_BLOCK:(i + 1) * N_TRIALS_PER_BLOCK]
        for i in range(expression_blocks)
    ]

    for ac_block, fo_block in zip(ac_blocks, fo_blocks):
        trials.extend(random.sample(ac_block, len(ac_block)))
        trials.extend(random.sample(fo_block, len(fo_block)))

    return trials


def build_shape_trials(shapes: list[Path], n_trials: int):
    """Generate n_trials shape trials, reusing shapes as needed."""
    sides = balanced_sides(n_trials)
    trials = []
    for side in sides:
        top = random.choice(shapes)
        wrong = random.choice([s for s in shapes if s != top])
        trials.append(make_left_right(top, wrong, side, SHAPES_DIR))
    return trials


def main():
    print("Collecting face images...")
    face_pairs = collect_face_pairs()
    print(f"  Paired identities with AC and FO: {len(face_pairs)}")

    shapes = collect_shapes()
    print(f"  Shapes: {len(shapes)} images")

    # Assemble CSV rows
    rows = []
    face_idx_total = 0
    shape_idx_total = 0

    for day in range(1, N_DAYS + 1):
        face_trials = build_face_trials(face_pairs)
        shape_trials = build_shape_trials(shapes, SHAPE_TRIALS_PER_DAY)
        face_idx = 0
        shape_idx = 0

        for run in range(1, N_RUNS + 1):
            for block in range(1, N_BLOCKS_PER_RUN + 1):
                is_face_block = block in FACE_BLOCK_INDICES
                for trial in range(1, N_TRIALS_PER_BLOCK + 1):
                    if is_face_block:
                        bl, br, match = face_trials[face_idx]
                        top = bl if match == "left" else br
                        base_path = str(RADIATE_ROOT) + "\\"
                        face_idx += 1
                        face_idx_total += 1
                    else:
                        bl, br, match = shape_trials[shape_idx]
                        top = bl if match == "left" else br
                        base_path = str(SHAPES_DIR) + "\\"
                        shape_idx += 1
                        shape_idx_total += 1

                    rows.append({
                        "day": day,
                        "run": run,
                        "block": block,
                        "trial": trial,
                        "base_path": base_path,
                        "top_correct": top,
                        "bottom_left": bl,
                        "bottom_right": br,
                        "bottom_correct_match": match,
                    })

        day_face_rows = [
            row for row in rows
            if row["day"] == day and row["base_path"].startswith(str(RADIATE_ROOT))
        ]
        day_face_targets = [row["top_correct"] for row in day_face_rows]
        day_face_identities = {
            identity_key(RADIATE_ROOT / relative_path)
            for relative_path in day_face_targets
        }

        assert face_idx == FACE_TRIALS_PER_DAY, f"Expected {FACE_TRIALS_PER_DAY} face trials on day {day}"
        assert shape_idx == SHAPE_TRIALS_PER_DAY, f"Expected {SHAPE_TRIALS_PER_DAY} shape trials on day {day}"
        assert len(day_face_targets) == len(set(day_face_targets)), "Each face expression must appear once as a correct answer per day"
        assert len(day_face_identities) == FACE_IDENTITIES_PER_DAY, f"Expected {FACE_IDENTITIES_PER_DAY} face identities on day {day}"

    out_path = SCRIPT_DIR / "trial_list.csv"
    fieldnames = [
        "day", "run", "block", "trial",
        "base_path", "top_correct", "bottom_left", "bottom_right", "bottom_correct_match",
    ]
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nWrote {len(rows)} rows to: {out_path}")
    print(f"  Face trials: {face_idx_total}  |  Shape trials: {shape_idx_total}")

    # Sanity checks
    assert face_idx_total == N_DAYS * FACE_TRIALS_PER_DAY, f"Expected {N_DAYS * FACE_TRIALS_PER_DAY} face trials"
    assert shape_idx_total == N_DAYS * SHAPE_TRIALS_PER_DAY, f"Expected {N_DAYS * SHAPE_TRIALS_PER_DAY} shape trials"
    left_count = sum(1 for r in rows if r["bottom_correct_match"] == "left")
    right_count = len(rows) - left_count
    print(f"  Left matches: {left_count}  |  Right matches: {right_count}")
    print("Done.")


if __name__ == "__main__":
    main()
