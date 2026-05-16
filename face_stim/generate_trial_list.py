"""
Generate trial list CSV for the emotion face-matching task.

Block layout per run (4 blocks, 9 trials each):
  Block 1 — face
  Block 2 — shape
  Block 3 — face
  Block 4 — shape

Which face type depends on the run:
  Run 1 → negative face blocks  (angry + fearful: AC, AO, FC, FO)
  Run 2 → happy face blocks     (HC, HE, HO)

Negative face blocks (run 1 only, 2 blocks × 9 trials = 18 trials):
  - 4 expressions; 18 is not divisible by 4, so the split is uneven:
    AC: 5 trials, AO: 5 trials, FC: 4 trials, FO: 4 trials.
  - Expressions are mixed within each block.
  - Distractors are always a different-identity image of the same expression.

Happy face blocks (run 2 only, 2 blocks × 9 trials = 18 trials):
  - 3 expressions, 6 identities each (6 × 3 = 18, evenly divisible).
  - Each block gets 3 HC + 3 HE + 3 HO (mixed within block).

Shape blocks (both runs, 2 × 2 blocks × 9 trials = 36 trials):
  - Same matching logic with generated shapes; anti-repetition for
    consecutive target/foil pairs.

Outputs: trial_list.csv.
After running this script, run copy_stimuli.py to copy images into the
repo and produce trial_list_local.csv with portable relative paths.
"""

import csv
import random
from pathlib import Path

SEED = 42
random.seed(SEED)

SCRIPT_DIR = Path(__file__).parent

RADIATE_ROOT = Path(
    r"C:\Users\draga\Documents\data\emotional_faces\RADIATE\RADIATE_BMP"
    r"\RADIATE_BMP\RADIATE_450_COLOR_BMP"
)
SHAPES_DIR = SCRIPT_DIR / "shapes_output"

N_DAYS             = 1
N_RUNS             = 2
N_BLOCKS_PER_RUN   = 4   # 2 face + 2 shape
N_TRIALS_PER_BLOCK = 9

FACE_BLOCK_NUMBERS  = {1, 3}   # same positions in every run
SHAPE_BLOCK_NUMBERS = {2, 4}

NEG_RUN = 1   # run whose face blocks are negative (angry / fearful)
HAP_RUN = 2   # run whose face blocks are happy

# Expression filename suffixes (no leading underscore)
NEG_EXPRESSIONS = ("AC", "AO", "FC", "FO")   # angry closed/open, fear closed/open
HAP_EXPRESSIONS = ("HC", "HE", "HO")         # happy closed, expressive, open

# Per-day trial counts
NEG_TRIALS_PER_DAY   = len(FACE_BLOCK_NUMBERS) * N_TRIALS_PER_BLOCK   # 18 (run 1)
HAP_TRIALS_PER_DAY   = len(FACE_BLOCK_NUMBERS) * N_TRIALS_PER_BLOCK   # 18 (run 2)
SHAPE_TRIALS_PER_DAY = N_RUNS * len(SHAPE_BLOCK_NUMBERS) * N_TRIALS_PER_BLOCK  # 36

# Neg expression trial counts — 18 / 4 = 4 remainder 2, so first two get +1
_base       = NEG_TRIALS_PER_DAY // len(NEG_EXPRESSIONS)    # 4
_remainder  = NEG_TRIALS_PER_DAY %  len(NEG_EXPRESSIONS)    # 2
NEG_EXPR_COUNTS = tuple(
    _base + (1 if i < _remainder else 0)
    for i in range(len(NEG_EXPRESSIONS))
)  # → (5, 5, 4, 4) for (AC, AO, FC, FO)

assert sum(NEG_EXPR_COUNTS) == NEG_TRIALS_PER_DAY

# Happy: evenly divisible → 6 identities per expression
assert HAP_TRIALS_PER_DAY % len(HAP_EXPRESSIONS) == 0
HAP_IDENTITIES_PER_EXPR = HAP_TRIALS_PER_DAY // len(HAP_EXPRESSIONS)   # 6


# ---------------------------------------------------------------------------
# Data collection
# ---------------------------------------------------------------------------

def identity_key_for(path: Path, expr_suffix: str) -> str:
    """Strip _{expr_suffix} from the file stem to get a per-person identity key."""
    relative = path.relative_to(RADIATE_ROOT)
    stem = path.stem
    tag = f"_{expr_suffix}"
    if not stem.endswith(tag):
        raise ValueError(f"Expected tag '{tag}' in filename: {path.name}")
    return str(relative.parent / stem[: -len(tag)])


def collect_identities(expression_suffixes: tuple[str, ...]) -> dict[str, dict[str, Path]]:
    """
    Scan RADIATE_ROOT for files matching each expression suffix and return
    only the identities that have an image for every suffix.

    Returns: {identity_key: {suffix: Path}}
    """
    by_expr: dict[str, dict[str, Path]] = {}
    for suffix in expression_suffixes:
        files = sorted(RADIATE_ROOT.rglob(f"*_{suffix}.bmp"))
        if not files:
            raise FileNotFoundError(
                f"No *_{suffix}.bmp files found under {RADIATE_ROOT}"
            )
        by_expr[suffix] = {identity_key_for(p, suffix): p for p in files}

    common_keys = sorted(
        set.intersection(*(set(d.keys()) for d in by_expr.values()))
    )
    return {k: {expr: by_expr[expr][k] for expr in expression_suffixes}
            for k in common_keys}


def collect_shapes() -> list[Path]:
    shapes = sorted(SHAPES_DIR.glob("*.png"))
    if not shapes:
        raise FileNotFoundError(f"No PNG shapes found in {SHAPES_DIR}")
    return shapes


# ---------------------------------------------------------------------------
# Trial-building helpers
# ---------------------------------------------------------------------------

def balanced_sides(n: int) -> list[str]:
    """Shuffled list of n sides: n//2 'left' and ceil(n/2) 'right'."""
    half = n // 2
    pool = ["left"] * half + ["right"] * (n - half)
    random.shuffle(pool)
    return pool


def rel(path: Path, base: Path) -> str:
    return path.relative_to(base).as_posix()  # forward slashes on all platforms


def make_left_right(
    top_path: Path, wrong_path: Path, side: str, base: Path
) -> tuple[str, str, str]:
    """Return (bottom_left, bottom_right, correct_side) with paths relative to base."""
    top_rel   = rel(top_path,   base)
    wrong_rel = rel(wrong_path, base)
    if side == "left":
        return top_rel, wrong_rel, "left"
    else:
        return wrong_rel, top_rel, "right"


def make_derangement(items: list[Path]) -> list[Path]:
    """Shuffled copy where no element stays in its original position."""
    while True:
        shuffled = random.sample(items, len(items))
        if all(a != b for a, b in zip(items, shuffled)):
            return shuffled


def build_expression_trials(correct_paths: list[Path]) -> list[tuple[str, str, str]]:
    """
    One trial per path. Distractor = different-identity file of the same
    expression, chosen via a derangement of the same pool.
    """
    distractors = make_derangement(correct_paths)
    sides       = balanced_sides(len(correct_paths))
    return [
        make_left_right(top, wrong, side, RADIATE_ROOT)
        for top, wrong, side in zip(correct_paths, distractors, sides)
    ]


# ---------------------------------------------------------------------------
# Face trial builders
# ---------------------------------------------------------------------------

def build_neg_face_trials(
    identities: dict[str, dict[str, Path]],
) -> list[tuple[str, str, str]]:
    """
    Build 18 negative face trials for the 2 neg blocks in run 1.

    Expression counts (uneven because 18 % 4 != 0):
      AC: 5  AO: 5  FC: 4  FO: 4  → total 18

    Identities are sampled independently per expression, so the same
    person may appear in multiple expression trials (consistent with the
    original design where each identity contributed both AC and FO).

    Trials are mixed across expressions within each block.
    """
    # Shuffle which expressions get the extra trial so no expression is
    # structurally privileged across participants / runs.
    expr_count_pairs = list(zip(NEG_EXPRESSIONS, NEG_EXPR_COUNTS))
    random.shuffle(expr_count_pairs)

    all_trials: list[tuple[str, str, str]] = []
    for expr, n in expr_count_pairs:
        if len(identities) < n:
            raise ValueError(
                f"Need at least {n} identities with expression {expr}, "
                f"found {len(identities)}."
            )
        selected = random.sample(sorted(identities.keys()), n)
        paths    = [identities[k][expr] for k in selected]
        all_trials.extend(build_expression_trials(paths))

    # Shuffle all 18, then split into 2 blocks of 9
    random.shuffle(all_trials)
    return all_trials   # caller slices into blocks of N_TRIALS_PER_BLOCK


def build_hap_face_trials(
    identities: dict[str, dict[str, Path]],
) -> list[tuple[str, str, str]]:
    """
    Build 18 happy face trials for the 2 hap blocks in run 2.

    6 identities × 3 expressions (HC, HE, HO) = 18 trials.
    Each block gets 3 HC + 3 HE + 3 HO (expressions mixed within block).
    """
    n = HAP_IDENTITIES_PER_EXPR   # 6
    if len(identities) < n:
        raise ValueError(
            f"Need at least {n} identities with all hap expressions "
            f"{HAP_EXPRESSIONS}, found {len(identities)}."
        )

    expr_trials: dict[str, list[tuple[str, str, str]]] = {}
    for expr in HAP_EXPRESSIONS:
        selected          = random.sample(sorted(identities.keys()), n)
        paths             = [identities[k][expr] for k in selected]
        trials            = build_expression_trials(paths)  # 6 trials
        random.shuffle(trials)   # randomise which identities land in block 1 vs block 2
        expr_trials[expr] = trials

    # Interleave into 2 blocks: 3 per expression per block
    per_block = n // len(FACE_BLOCK_NUMBERS)   # 6 / 2 = 3
    all_trials: list[tuple[str, str, str]] = []
    for b in range(len(FACE_BLOCK_NUMBERS)):   # 2 blocks
        block_trials: list[tuple[str, str, str]] = []
        for expr in HAP_EXPRESSIONS:
            start = b * per_block
            block_trials.extend(expr_trials[expr][start : start + per_block])
        random.shuffle(block_trials)
        all_trials.extend(block_trials)

    return all_trials


def build_shape_trials(shapes: list[Path], n_trials: int) -> list[tuple[str, str, str]]:
    """Generate n_trials shape trials, avoiding consecutive repeated target/foil pairs."""
    sides     = balanced_sides(n_trials)
    trials    = []
    prev_pair = None

    for side in sides:
        top = wrong = pair = None

        for candidate_top in random.sample(shapes, len(shapes)):
            wrong_pool = [s for s in shapes if s != candidate_top]
            random.shuffle(wrong_pool)
            for candidate_wrong in wrong_pool:
                candidate_pair = (candidate_top.name, candidate_wrong.name)
                if candidate_pair != prev_pair:
                    top, wrong, pair = candidate_top, candidate_wrong, candidate_pair
                    break
            if top is not None:
                break

        if top is None:   # fallback (practically unreachable)
            top   = random.choice(shapes)
            wrong = random.choice([s for s in shapes if s != top])
            pair  = (top.name, wrong.name)

        trials.append(make_left_right(top, wrong, side, SHAPES_DIR))
        prev_pair = pair

    return trials


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    print("Collecting face images...")

    neg_identities = collect_identities(NEG_EXPRESSIONS)
    print(f"  Identities with all neg expressions {NEG_EXPRESSIONS}: {len(neg_identities)}")
    print(f"  Neg expression trial counts (AC AO FC FO): {NEG_EXPR_COUNTS}")

    hap_identities = collect_identities(HAP_EXPRESSIONS)
    print(f"  Identities with all hap expressions {HAP_EXPRESSIONS}: {len(hap_identities)}")

    shapes = collect_shapes()
    print(f"  Shapes: {len(shapes)} images")

    rows: list[dict] = []
    neg_idx_total = hap_idx_total = shape_idx_total = 0

    for day in range(1, N_DAYS + 1):

        neg_trials   = build_neg_face_trials(neg_identities)
        hap_trials   = build_hap_face_trials(hap_identities)
        shape_trials = build_shape_trials(shapes, SHAPE_TRIALS_PER_DAY)

        neg_idx = hap_idx = shape_idx = 0

        for run in range(1, N_RUNS + 1):
            for block in range(1, N_BLOCKS_PER_RUN + 1):

                is_face  = block in FACE_BLOCK_NUMBERS

                for trial in range(1, N_TRIALS_PER_BLOCK + 1):

                    if is_face and run == NEG_RUN:
                        bl, br, match = neg_trials[neg_idx]
                        top        = bl if match == "left" else br
                        base_path  = str(RADIATE_ROOT) + "\\"
                        block_type = "neg_face"
                        neg_idx       += 1
                        neg_idx_total += 1

                    elif is_face and run == HAP_RUN:
                        bl, br, match = hap_trials[hap_idx]
                        top        = bl if match == "left" else br
                        base_path  = str(RADIATE_ROOT) + "\\"
                        block_type = "hap_face"
                        hap_idx       += 1
                        hap_idx_total += 1

                    else:  # shape block
                        bl, br, match = shape_trials[shape_idx]
                        top        = bl if match == "left" else br
                        base_path  = str(SHAPES_DIR) + "\\"
                        block_type = "shape"
                        shape_idx       += 1
                        shape_idx_total += 1

                    rows.append({
                        "day":                  day,
                        "run":                  run,
                        "block":                block,
                        "trial":                trial,
                        "block_type":           block_type,
                        "base_path":            base_path,
                        "top_correct":          top,
                        "bottom_left":          bl,
                        "bottom_right":         br,
                        "bottom_correct_match": match,
                    })

        # ---- Per-day assertions ----
        day_rows  = [r for r in rows if r["day"] == day]
        neg_rows  = [r for r in day_rows if r["block_type"] == "neg_face"]
        hap_rows  = [r for r in day_rows if r["block_type"] == "hap_face"]

        neg_targets = [r["top_correct"] for r in neg_rows]
        hap_targets = [r["top_correct"] for r in hap_rows]

        assert neg_idx  == NEG_TRIALS_PER_DAY,   f"Day {day}: expected {NEG_TRIALS_PER_DAY} neg trials, got {neg_idx}"
        assert hap_idx  == HAP_TRIALS_PER_DAY,   f"Day {day}: expected {HAP_TRIALS_PER_DAY} hap trials, got {hap_idx}"
        assert shape_idx == SHAPE_TRIALS_PER_DAY, f"Day {day}: expected {SHAPE_TRIALS_PER_DAY} shape trials, got {shape_idx}"

        assert len(neg_targets) == len(set(neg_targets)), \
            f"Day {day}: duplicate neg face target — each identity-expression pair must appear at most once"
        assert len(hap_targets) == len(set(hap_targets)), \
            f"Day {day}: duplicate hap face target — each identity-expression pair must appear at most once"

    # ---- Write CSV ----
    out_path   = SCRIPT_DIR / "trial_list.csv"
    fieldnames = [
        "day", "run", "block", "trial",
        "block_type",
        "base_path", "top_correct", "bottom_left", "bottom_right",
        "bottom_correct_match",
    ]
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    total = neg_idx_total + hap_idx_total + shape_idx_total
    print(f"\nWrote {total} rows to: {out_path}")
    print(f"  Neg face trials : {neg_idx_total}  (run {NEG_RUN})")
    print(f"  Hap face trials : {hap_idx_total}  (run {HAP_RUN})")
    print(f"  Shape trials    : {shape_idx_total} (both runs)")

    assert neg_idx_total   == N_DAYS * NEG_TRIALS_PER_DAY
    assert hap_idx_total   == N_DAYS * HAP_TRIALS_PER_DAY
    assert shape_idx_total == N_DAYS * SHAPE_TRIALS_PER_DAY

    left_count  = sum(1 for r in rows if r["bottom_correct_match"] == "left")
    right_count = total - left_count
    print(f"  Left matches    : {left_count}  |  Right matches: {right_count}")
    print("\nNext step: run copy_stimuli.py to copy new images and regenerate trial_list_local.csv.")


if __name__ == "__main__":
    main()
