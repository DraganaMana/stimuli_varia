"""
Generate trial list CSV for the emotion face-matching task.

Block layout per run (4 blocks, 9 trials each):
  Block 1 — female face
  Block 2 — shape
  Block 3 — male face
  Block 4 — shape

Which emotion depends on the run:
  Run 1 → negative face blocks  (angry + fearful: AC, AO, FC, FO)
  Run 2 → happy face blocks     (HC, HE, HO)

Negative face blocks (9 trials, 4 expressions):
  Expression distribution per block: (3, 2, 2, 2) — which expression
  gets the extra trial is randomised each time.

Happy face blocks (9 trials, 3 expressions):
  3 HC + 3 HE + 3 HO, mixed within block.

Shape blocks: same matching logic with generated shapes.

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

FEMALE_BLOCK = 1   # block position for female faces in every run
MALE_BLOCK   = 3   # block position for male faces in every run
SHAPE_BLOCK_NUMBERS = {2, 4}

NEG_RUN = 1
HAP_RUN = 2

NEG_EXPRESSIONS = ("AC", "AO", "FC", "FO")
HAP_EXPRESSIONS = ("HC", "HE", "HO")

# Neg expression counts for 9 trials: 9 = 3 + 2 + 2 + 2
_base      = N_TRIALS_PER_BLOCK // len(NEG_EXPRESSIONS)   # 2
_remainder = N_TRIALS_PER_BLOCK %  len(NEG_EXPRESSIONS)   # 1
NEG_EXPR_COUNTS = tuple(
    _base + (1 if i < _remainder else 0)
    for i in range(len(NEG_EXPRESSIONS))
)  # → (3, 2, 2, 2)

assert sum(NEG_EXPR_COUNTS) == N_TRIALS_PER_BLOCK

# Happy: 9 / 3 = 3 identities per expression
assert N_TRIALS_PER_BLOCK % len(HAP_EXPRESSIONS) == 0
HAP_IDENTITIES_PER_EXPR = N_TRIALS_PER_BLOCK // len(HAP_EXPRESSIONS)   # 3


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


def sex_of_identity(key: str) -> str:
    """Return 'F' or 'M' from an identity key like 'RADIATE_COLOR_6/HF03/HF03'."""
    return Path(key).name[1]


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


def filter_by_sex(
    identities: dict[str, dict[str, Path]], sex: str
) -> dict[str, dict[str, Path]]:
    """Return only the identities whose code has the given sex ('F' or 'M')."""
    return {k: v for k, v in identities.items() if sex_of_identity(k) == sex}


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
    return path.relative_to(base).as_posix()


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
# Face block builders (one block = 9 trials, one sex)
# ---------------------------------------------------------------------------

def build_neg_block(identities: dict[str, dict[str, Path]]) -> list[tuple[str, str, str]]:
    """
    Build 9 negative face trials for one sex block.
    Expression distribution (3, 2, 2, 2) — which expression gets 3 is randomised.
    """
    expr_count_pairs = list(zip(NEG_EXPRESSIONS, NEG_EXPR_COUNTS))
    random.shuffle(expr_count_pairs)

    trials: list[tuple[str, str, str]] = []
    for expr, n in expr_count_pairs:
        if len(identities) < n:
            raise ValueError(
                f"Need at least {n} identities with expression {expr}, "
                f"found {len(identities)}."
            )
        selected = random.sample(sorted(identities.keys()), n)
        paths    = [identities[k][expr] for k in selected]
        trials.extend(build_expression_trials(paths))

    random.shuffle(trials)
    return trials


def build_hap_block(identities: dict[str, dict[str, Path]]) -> list[tuple[str, str, str]]:
    """
    Build 9 happy face trials for one sex block: 3 HC + 3 HE + 3 HO, mixed.
    """
    n = HAP_IDENTITIES_PER_EXPR   # 3
    if len(identities) < n:
        raise ValueError(
            f"Need at least {n} identities with all hap expressions "
            f"{HAP_EXPRESSIONS}, found {len(identities)}."
        )

    trials: list[tuple[str, str, str]] = []
    for expr in HAP_EXPRESSIONS:
        selected = random.sample(sorted(identities.keys()), n)
        paths    = [identities[k][expr] for k in selected]
        trials.extend(build_expression_trials(paths))

    random.shuffle(trials)
    return trials


def shape_category(path: Path) -> str:
    """Extract category from filename stem, e.g. 'rect_wide' from 'rect_wide_small.png'."""
    parts = path.stem.split("_")
    return "_".join(parts[:-1])   # drop the trailing size word


def build_shape_trials(shapes: list[Path], n_trials: int) -> list[tuple[str, str, str]]:
    """
    Generate n_trials shape trials.
    Foil is always from a different shape category than the target (cross-category
    constraint), so target and distractor are never confused by size alone.
    Also avoids repeating the same (target, foil) pair in consecutive trials.
    """
    sides     = balanced_sides(n_trials)
    trials    = []
    prev_pair = None

    for side in sides:
        top = wrong = pair = None

        for candidate_top in random.sample(shapes, len(shapes)):
            top_cat    = shape_category(candidate_top)
            wrong_pool = [s for s in shapes if shape_category(s) != top_cat]
            if not wrong_pool:   # fallback: any different shape (unreachable with ≥2 categories)
                wrong_pool = [s for s in shapes if s != candidate_top]
            random.shuffle(wrong_pool)
            for candidate_wrong in wrong_pool:
                candidate_pair = (candidate_top.name, candidate_wrong.name)
                if candidate_pair != prev_pair:
                    top, wrong, pair = candidate_top, candidate_wrong, candidate_pair
                    break
            if top is not None:
                break

        if top is None:
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

    neg_all = collect_identities(NEG_EXPRESSIONS)
    neg_fem = filter_by_sex(neg_all, 'F')
    neg_mal = filter_by_sex(neg_all, 'M')
    print(f"  Neg female identities (all {NEG_EXPRESSIONS}): {len(neg_fem)}")
    print(f"  Neg male   identities (all {NEG_EXPRESSIONS}): {len(neg_mal)}")

    hap_all = collect_identities(HAP_EXPRESSIONS)
    hap_fem = filter_by_sex(hap_all, 'F')
    hap_mal = filter_by_sex(hap_all, 'M')
    print(f"  Hap female identities (all {HAP_EXPRESSIONS}): {len(hap_fem)}")
    print(f"  Hap male   identities (all {HAP_EXPRESSIONS}): {len(hap_mal)}")

    shapes = collect_shapes()
    print(f"  Shapes: {len(shapes)} images")

    rows: list[dict] = []
    SHAPE_TRIALS_PER_RUN = len(SHAPE_BLOCK_NUMBERS) * N_TRIALS_PER_BLOCK  # 18

    for day in range(1, N_DAYS + 1):

        shape_trials_run1 = build_shape_trials(shapes, SHAPE_TRIALS_PER_RUN)
        shape_trials_run2 = build_shape_trials(shapes, SHAPE_TRIALS_PER_RUN)
        shape_pools = {NEG_RUN: shape_trials_run1, HAP_RUN: shape_trials_run2}
        shape_idx   = {NEG_RUN: 0, HAP_RUN: 0}

        # Pre-build one block of trials per sex per run
        face_blocks = {
            NEG_RUN: {
                FEMALE_BLOCK: build_neg_block(neg_fem),
                MALE_BLOCK:   build_neg_block(neg_mal),
            },
            HAP_RUN: {
                FEMALE_BLOCK: build_hap_block(hap_fem),
                MALE_BLOCK:   build_hap_block(hap_mal),
            },
        }
        face_idx = {
            NEG_RUN: {FEMALE_BLOCK: 0, MALE_BLOCK: 0},
            HAP_RUN: {FEMALE_BLOCK: 0, MALE_BLOCK: 0},
        }

        for run in range(1, N_RUNS + 1):
            for block in range(1, N_BLOCKS_PER_RUN + 1):

                is_face = block in {FEMALE_BLOCK, MALE_BLOCK}

                for trial in range(1, N_TRIALS_PER_BLOCK + 1):

                    if is_face:
                        idx = face_idx[run][block]
                        bl, br, match = face_blocks[run][block][idx]
                        top        = bl if match == "left" else br
                        base_path  = str(RADIATE_ROOT) + "\\"
                        sex_label  = "fem" if block == FEMALE_BLOCK else "mal"
                        emo_label  = "neg" if run == NEG_RUN else "hap"
                        block_type = f"{sex_label}_{emo_label}"
                        face_idx[run][block] += 1

                    else:
                        idx = shape_idx[run]
                        bl, br, match = shape_pools[run][idx]
                        top        = bl if match == "left" else br
                        base_path  = str(SHAPES_DIR) + "\\"
                        block_type = "shape"
                        shape_idx[run] += 1

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
        day_rows = [r for r in rows if r["day"] == day]
        for bt in ("fem_neg", "mal_neg", "fem_hap", "mal_hap"):
            bt_rows = [r for r in day_rows if r["block_type"] == bt]
            assert len(bt_rows) == N_TRIALS_PER_BLOCK, \
                f"Day {day}: expected {N_TRIALS_PER_BLOCK} {bt} trials, got {len(bt_rows)}"
            targets = [r["top_correct"] for r in bt_rows]
            assert len(targets) == len(set(targets)), \
                f"Day {day}: duplicate target in {bt} block"

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

    total = len(rows)
    print(f"\nWrote {total} rows to: {out_path}")
    print(f"  Block layout per run:")
    print(f"    Block {FEMALE_BLOCK} — female faces  (fem_neg / fem_hap)")
    print(f"    Block 2       — shapes")
    print(f"    Block {MALE_BLOCK} — male faces    (mal_neg / mal_hap)")
    print(f"    Block 4       — shapes")
    print(f"  Run {NEG_RUN}: negative expressions {NEG_EXPRESSIONS}")
    print(f"  Run {HAP_RUN}: happy expressions    {HAP_EXPRESSIONS}")
    print("\nNext step: run copy_stimuli.py to copy new images and regenerate trial_list_local.csv.")


if __name__ == "__main__":
    main()
