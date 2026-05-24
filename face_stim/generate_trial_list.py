"""
Generate trial list CSV for the emotion face-matching task.

Block layout per run (4 blocks, 9 trials each):
  Block 1 — female faces
  Block 2 — shapes
  Block 3 — male faces
  Block 4 — shapes

Which emotion depends on the run:
  Run 1 → negative face blocks  (RADIATE: AC, AO, FC, FO;  CFD: A, F)
  Run 2 → happy face blocks     (RADIATE: HC, HE, HO;      CFD: HC, HO)

Trials are drawn from BOTH the RADIATE and Chicago Face Database (CFD) pools.
Each trial's three images (top, bottom-left, bottom-right) all come from the
same database using the same expression code, so visual consistency is
maintained within every trial.

Shape blocks: same matching logic with generated shapes.

Outputs: trial_list.csv.
After running this script, run copy_stimuli.py to copy images into the
repo and produce trial_list_local.csv with portable relative paths.
"""

import csv
import random
from pathlib import Path
from typing import NamedTuple

SEED = 42
random.seed(SEED)

SCRIPT_DIR = Path(__file__).parent

RADIATE_ROOT = Path(
    r"C:\Users\draga\Documents\data\emotional_faces\RADIATE\RADIATE_BMP"
    r"\RADIATE_BMP\RADIATE_450_COLOR_BMP"
)
CFD_ROOT = Path(
    r"C:\Users\draga\Documents\data\emotional_faces\Chicago"
    r"\CFD Version 3.0\Images\CFD"
)
SHAPES_DIR = SCRIPT_DIR / "shapes_output"

N_DAYS             = 30
N_RUNS             = 2
N_BLOCKS_PER_RUN   = 8   # 4 face + 4 shape, interleaved
N_TRIALS_PER_BLOCK = 5

FEMALE_BLOCK_NUMBERS = {1, 5}   # odd face blocks → female
MALE_BLOCK_NUMBERS   = {3, 7}   # odd face blocks → male
SHAPE_BLOCK_NUMBERS  = {2, 4, 6, 8}

NEG_RUN = 1
HAP_RUN = 2

RADIATE_NEG_EXPRS = ("AC", "AO", "FC", "FO")
RADIATE_HAP_EXPRS = ("HC", "HE", "HO")
CFD_NEG_EXPRS     = ("A",  "F")
CFD_HAP_EXPRS     = ("HC", "HO")


# ---------------------------------------------------------------------------
# Pool: one (database, expression, sex) slice of identity → image-path pairs
# ---------------------------------------------------------------------------

class Pool(NamedTuple):
    db:   str   # 'radiate' or 'cfd'
    expr: str   # expression code
    base: Path  # root for computing relative paths
    ids:  dict  # {identity_key: Path}


# ---------------------------------------------------------------------------
# Image collection — per-expression, not requiring cross-expression presence
# ---------------------------------------------------------------------------

def _identity_key_radiate(path: Path, expr: str) -> str:
    """Strip _<expr> from stem → unique key per person."""
    relative = path.relative_to(RADIATE_ROOT)
    stem     = path.stem
    tag      = f"_{expr}"
    if not stem.endswith(tag):
        raise ValueError(f"Expected tag '{tag}' in: {path.name}")
    return str(relative.parent / stem[: -len(tag)])


def collect_radiate_pool(expr: str) -> dict:
    """Return {identity_key: Path} for every RADIATE identity with this expression."""
    result = {}
    for f in sorted(RADIATE_ROOT.rglob(f"*_{expr}.bmp")):
        key = _identity_key_radiate(f, expr)
        result[key] = f
    return result


def collect_cfd_pool(expr: str) -> dict:
    """Return {identity_key: Path} for every CFD identity with this expression."""
    result  = {}
    suffix  = f"-{expr}.jpg"
    for ident_dir in CFD_ROOT.iterdir():
        if not ident_dir.is_dir():
            continue
        for f in ident_dir.iterdir():
            if f.name.endswith(suffix):
                result[ident_dir.name] = f
                break   # at most one image per expression per identity
    return result


def _radiate_sex(key: str) -> str:
    """Return 'F' or 'M' from a RADIATE identity key like 'RADIATE_COLOR_1/AF01/AF01'."""
    return Path(key).name[1]


def _cfd_sex(key: str) -> str:
    """Return 'F' or 'M' from a CFD identity key like 'AF-200' or 'BM-001'."""
    return key[1] if len(key) >= 2 else ""


def filter_sex(pool_dict: dict, db: str, sex: str) -> dict:
    fn = _radiate_sex if db == "radiate" else _cfd_sex
    return {k: v for k, v in pool_dict.items() if fn(k) == sex}


# ---------------------------------------------------------------------------
# Trial-building helpers
# ---------------------------------------------------------------------------

def balanced_sides(n: int) -> list:
    half = n // 2
    pool = ["left"] * half + ["right"] * (n - half)
    random.shuffle(pool)
    return pool


def make_derangement(items: list) -> list:
    """Shuffled copy where no element keeps its original position."""
    while True:
        shuffled = random.sample(items, len(items))
        if all(a != b for a, b in zip(items, shuffled)):
            return shuffled


def rel(path: Path, base: Path) -> str:
    return path.relative_to(base).as_posix()


def make_left_right(top_path, wrong_path, side, base):
    top_rel   = rel(top_path,   base)
    wrong_rel = rel(wrong_path, base)
    if side == "left":
        return top_rel, wrong_rel, "left"
    else:
        return wrong_rel, top_rel, "right"


def build_expression_trials(paths: list, base: Path) -> list:
    """
    One trial per path. Correct match = same image as top.
    Distractor = different identity, same expression (derangement).
    """
    n = len(paths)
    if n == 1:
        # Can't derange 1 item; caller must ensure >=2 identities are sampled.
        raise ValueError("Need at least 2 paths to build a trial.")
    distractors = make_derangement(paths)
    sides       = balanced_sides(n)
    return [
        make_left_right(top, wrong, side, base)
        for top, wrong, side in zip(paths, distractors, sides)
    ]


MAX_USES = 2    # each target face image may appear in at most this many days
MIN_GAP  = 15   # days that must separate two appearances of the same image


class UsageTracker:
    """Track which days each target face image has been used."""

    def __init__(self):
        self._uses: dict[str, list[int]] = {}   # rel_path -> [day, ...]

    def available(self, rel_path: str, day: int) -> bool:
        uses = self._uses.get(rel_path, [])
        if len(uses) >= MAX_USES:
            return False
        if uses and (day - max(uses)) < MIN_GAP:
            return False
        return True

    def record(self, rel_path: str, day: int) -> None:
        self._uses.setdefault(rel_path, []).append(day)

    def stats(self) -> dict:
        from collections import Counter
        c = Counter(len(v) for v in self._uses.values())
        return dict(sorted(c.items()))


def filter_available_pool(pool: Pool, tracker: UsageTracker, day: int) -> Pool:
    """Return a copy of pool containing only images available on this day."""
    avail = {k: v for k, v in pool.ids.items()
             if tracker.available(rel(v, pool.base), day)}
    return Pool(pool.db, pool.expr, pool.base, avail)


def _distribute(total: int, n_buckets: int) -> list:
    """Spread total as evenly as possible across n_buckets buckets."""
    base  = total // n_buckets
    extra = total % n_buckets
    return [base + (1 if i < extra else 0) for i in range(n_buckets)]


def build_block(pools: list, n_trials: int) -> list:
    """
    Build exactly n_trials face trials from a list of Pool objects.
    Returns list of (bottom_left, bottom_right, correct_match, base_path_str).

    Trials are distributed evenly across pools; pools with fewer than 2
    identities are skipped. After building, the list is shuffled and trimmed.
    """
    valid = [p for p in pools if len(p.ids) >= 2]
    if not valid:
        raise ValueError("No expression pools have >=2 identities.")

    counts = _distribute(n_trials, len(valid))
    random.shuffle(counts)

    all_trials = []

    for pool, n in zip(valid, counts):
        if n == 0:
            continue
        bps = str(pool.base).rstrip("/\\") + "\\"
        # Sample max(n, 2) keys so derangement is always possible.
        n_sample = min(max(n, 2), len(pool.ids))
        keys     = random.sample(sorted(pool.ids), n_sample)
        paths    = [pool.ids[k] for k in keys]
        trials   = build_expression_trials(paths, pool.base)
        for bl, br, match in trials[:n]:
            all_trials.append((bl, br, match, bps))

    random.shuffle(all_trials)
    return all_trials[:n_trials]


# ---------------------------------------------------------------------------
# Shape block builder
# ---------------------------------------------------------------------------

def _shape_category(path: Path) -> str:
    parts = path.stem.split("_")
    return "_".join(parts[:-1])


def _collect_shapes() -> list:
    shapes = sorted(SHAPES_DIR.glob("*.png"))
    if not shapes:
        raise FileNotFoundError(f"No PNG shapes found in {SHAPES_DIR}")
    return shapes


def build_shape_trials(shapes: list, n_trials: int,
                       used_as_correct: set = None,
                       used_as_foil: set = None) -> list:
    """
    Generate n_trials shape trials with within-day uniqueness.

    Each shape image appears at most once as the correct target per day, and at
    most once as the foil per day.  A shape MAY appear in both roles on the same
    day (once correct, once foil).  Pass the same used_as_correct / used_as_foil
    sets across all build_shape_trials calls for a given day so the constraint is
    shared across runs.

    Foil is always from a different category than the target.
    """
    if used_as_correct is None:
        used_as_correct = set()
    if used_as_foil is None:
        used_as_foil = set()

    sides     = balanced_sides(n_trials)
    trials    = []
    prev_pair = None

    for side in sides:
        top = wrong = pair = None

        for candidate_top in random.sample(shapes, len(shapes)):
            if candidate_top.name in used_as_correct:
                continue
            top_cat = _shape_category(candidate_top)

            # Prefer foils not yet used as foil today and from a different category.
            wrong_pool = [s for s in shapes
                          if _shape_category(s) != top_cat
                          and s.name not in used_as_foil]
            if not wrong_pool:
                # Relax foil-uniqueness constraint, keep category constraint.
                wrong_pool = [s for s in shapes if _shape_category(s) != top_cat]
            if not wrong_pool:
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
            avail = [s for s in shapes if s.name not in used_as_correct] or shapes
            top   = random.choice(avail)
            wrong = random.choice([s for s in shapes if s != top])
            pair  = (top.name, wrong.name)

        used_as_correct.add(top.name)
        used_as_foil.add(wrong.name)

        bl, br, match = make_left_right(top, wrong, side, SHAPES_DIR)
        trials.append((bl, br, match))
        prev_pair = pair

    return trials


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    print("Collecting face image pools …")

    # RADIATE per-expression pools (all identities that have the expression)
    rad_neg = {e: collect_radiate_pool(e) for e in RADIATE_NEG_EXPRS}
    rad_hap = {e: collect_radiate_pool(e) for e in RADIATE_HAP_EXPRS}

    # CFD per-expression pools
    cfd_neg = {e: collect_cfd_pool(e) for e in CFD_NEG_EXPRS}
    cfd_hap = {e: collect_cfd_pool(e) for e in CFD_HAP_EXPRS}

    print("  RADIATE neg pools (per expression):")
    for e, d in rad_neg.items():
        nf = sum(1 for k in d if _radiate_sex(k) == "F")
        nm = sum(1 for k in d if _radiate_sex(k) == "M")
        print(f"    {e}: {len(d)} total  ({nf}F / {nm}M)")

    print("  RADIATE hap pools:")
    for e, d in rad_hap.items():
        nf = sum(1 for k in d if _radiate_sex(k) == "F")
        nm = sum(1 for k in d if _radiate_sex(k) == "M")
        print(f"    {e}: {len(d)} total  ({nf}F / {nm}M)")

    print("  CFD neg pools:")
    for e, d in cfd_neg.items():
        nf = sum(1 for k in d if _cfd_sex(k) == "F")
        nm = sum(1 for k in d if _cfd_sex(k) == "M")
        print(f"    {e}: {len(d)} total  ({nf}F / {nm}M)")

    print("  CFD hap pools:")
    for e, d in cfd_hap.items():
        nf = sum(1 for k in d if _cfd_sex(k) == "F")
        nm = sum(1 for k in d if _cfd_sex(k) == "M")
        print(f"    {e}: {len(d)} total  ({nf}F / {nm}M)")

    shapes = _collect_shapes()
    print(f"  Shapes: {len(shapes)} images across "
          f"{len({_shape_category(s) for s in shapes})} categories")

    # ------------------------------------------------------------------
    # Build trial rows
    # ------------------------------------------------------------------
    rows: list[dict] = []
    SHAPE_TRIALS_PER_RUN = len(SHAPE_BLOCK_NUMBERS) * N_TRIALS_PER_BLOCK  # 18

    # One tracker per (sex, emotion) block type — constraints are independent
    # across block types because each block draws from a different image pool.
    trackers = {
        ("F", "neg"): UsageTracker(),
        ("M", "neg"): UsageTracker(),
        ("F", "hap"): UsageTracker(),
        ("M", "hap"): UsageTracker(),
    }

    for day in range(1, N_DAYS + 1):
        shape_correct_today: set = set()
        shape_foil_today: set = set()
        shape_pools = {
            NEG_RUN: build_shape_trials(shapes, SHAPE_TRIALS_PER_RUN,
                                        shape_correct_today, shape_foil_today),
            HAP_RUN: build_shape_trials(shapes, SHAPE_TRIALS_PER_RUN,
                                        shape_correct_today, shape_foil_today),
        }
        shape_idx = {NEG_RUN: 0, HAP_RUN: 0}

        for run in range(1, N_RUNS + 1):
            is_neg    = (run == NEG_RUN)
            emo_label = "neg" if is_neg else "hap"

            for block in range(1, N_BLOCKS_PER_RUN + 1):
                is_face   = block not in SHAPE_BLOCK_NUMBERS
                is_female = block in FEMALE_BLOCK_NUMBERS
                sex       = "F" if is_female else "M"

                if is_face:
                    tracker = trackers[(sex, emo_label)]

                    # Full expression pools for this block type
                    if is_neg:
                        raw_pools = [
                            Pool("radiate", e, RADIATE_ROOT,
                                 filter_sex(rad_neg[e], "radiate", sex))
                            for e in RADIATE_NEG_EXPRS
                        ] + [
                            Pool("cfd", e, CFD_ROOT,
                                 filter_sex(cfd_neg[e], "cfd", sex))
                            for e in CFD_NEG_EXPRS
                        ]
                    else:
                        raw_pools = [
                            Pool("radiate", e, RADIATE_ROOT,
                                 filter_sex(rad_hap[e], "radiate", sex))
                            for e in RADIATE_HAP_EXPRS
                        ] + [
                            Pool("cfd", e, CFD_ROOT,
                                 filter_sex(cfd_hap[e], "cfd", sex))
                            for e in CFD_HAP_EXPRS
                        ]

                    # Keep only images available under the usage constraint
                    avail_pools = [filter_available_pool(p, tracker, day)
                                   for p in raw_pools]

                    n_avail = sum(len(p.ids) for p in avail_pools)
                    if n_avail < N_TRIALS_PER_BLOCK:
                        raise RuntimeError(
                            f"Day {day}, {sex}_{emo_label}: only {n_avail} "
                            f"available images, need {N_TRIALS_PER_BLOCK}. "
                            f"Increase pool size or relax constraints."
                        )

                    block_trials = build_block(avail_pools, N_TRIALS_PER_BLOCK)

                    # Record target usage so future days respect the constraints
                    for bl, br, match, _ in block_trials:
                        top_rel = bl if match == "left" else br
                        tracker.record(top_rel, day)

                    sex_label  = "fem" if is_female else "mal"
                    block_type = f"{sex_label}_{emo_label}"

                    for trial_n, (bl, br, match, base_path) in enumerate(block_trials, 1):
                        top = bl if match == "left" else br
                        rows.append({
                            "day":                  day,
                            "run":                  run,
                            "block":                block,
                            "trial":                trial_n,
                            "block_type":           block_type,
                            "base_path":            base_path,
                            "top_correct":          top,
                            "bottom_left":          bl,
                            "bottom_right":         br,
                            "bottom_correct_match": match,
                        })

                else:   # shape block
                    for trial_n in range(1, N_TRIALS_PER_BLOCK + 1):
                        idx = shape_idx[run]
                        bl, br, match = shape_pools[run][idx]
                        shape_idx[run] += 1
                        top = bl if match == "left" else br
                        rows.append({
                            "day":                  day,
                            "run":                  run,
                            "block":                block,
                            "trial":                trial_n,
                            "block_type":           "shape",
                            "base_path":            str(SHAPES_DIR) + "\\",
                            "top_correct":          top,
                            "bottom_left":          bl,
                            "bottom_right":         br,
                            "bottom_correct_match": match,
                        })

        # ---- Per-day sanity check ----
        # Each block type has 2 blocks per run × N_TRIALS_PER_BLOCK trials.
        face_trials_per_type = len(FEMALE_BLOCK_NUMBERS) * N_TRIALS_PER_BLOCK
        day_rows = [r for r in rows if r["day"] == day]
        for bt in ("fem_neg", "mal_neg", "fem_hap", "mal_hap"):
            bt_rows = [r for r in day_rows if r["block_type"] == bt]
            assert len(bt_rows) == face_trials_per_type, (
                f"Day {day}: expected {face_trials_per_type} {bt} trials, "
                f"got {len(bt_rows)}"
            )
            targets = [r["top_correct"] for r in bt_rows]
            assert len(targets) == len(set(targets)), (
                f"Day {day}: duplicate target in {bt} block"
            )

    # ------------------------------------------------------------------
    # Write CSV
    # ------------------------------------------------------------------
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
    print(f"\nWrote {total} rows → {out_path}")
    print(f"  {N_DAYS} days × {N_RUNS} runs × {N_BLOCKS_PER_RUN} blocks × "
          f"{N_TRIALS_PER_BLOCK} trials = "
          f"{N_DAYS * N_RUNS * N_BLOCKS_PER_RUN * N_TRIALS_PER_BLOCK}")
    print(f"\nUsage constraint: max {MAX_USES} appearances, min {MIN_GAP}-day gap")
    print("  Face appearances per image (by block type):")
    for key, tr in trackers.items():
        sex, emo = key
        label = ("fem" if sex == "F" else "mal") + "_" + emo
        print(f"    {label}: {tr.stats()}")
    print("\nNext step: run copy_stimuli.py to copy new images and regenerate "
          "trial_list_local.csv.")


if __name__ == "__main__":
    main()
