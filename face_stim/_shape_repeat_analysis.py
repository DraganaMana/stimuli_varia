"""Quick shape repeat analysis on trial_list.csv."""
import csv
from collections import defaultdict
from pathlib import Path

CSV = Path(__file__).parent / "trial_list.csv"

shape_days = defaultdict(set)

with open(CSV, newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        if row["block_type"] != "shape":
            continue
        day = int(row["day"])
        for col in ("top_correct", "bottom_left", "bottom_right"):
            shape_days[row[col]].add(day)

appearances = sorted(len(v) for v in shape_days.values())
print(f"Total unique shape images : {len(shape_days)}")
print(f"Appearances per image     : min={min(appearances)} max={max(appearances)} mean={sum(appearances)/len(appearances):.1f}")

# Distribution
from collections import Counter
dist = Counter(appearances)
for k in sorted(dist):
    print(f"  {k:2d} days : {dist[k]} images")

# For images appearing >1 day, show gap stats
gaps = []
for days in shape_days.values():
    sorted_days = sorted(days)
    for i in range(1, len(sorted_days)):
        gaps.append(sorted_days[i] - sorted_days[i-1])

if gaps:
    print(f"\nGap between repeat appearances: min={min(gaps)} max={max(gaps)} mean={sum(gaps)/len(gaps):.1f}")

print("\nCategory breakdown:")
cat_days = defaultdict(lambda: defaultdict(set))
for path_str, days in shape_days.items():
    stem = Path(path_str).stem
    cat = "_".join(stem.split("_")[:-1])
    for d in days:
        cat_days[cat][path_str].add(d)

for cat in sorted(cat_days):
    imgs = cat_days[cat]
    all_app = [len(v) for v in imgs.values()]
    print(f"  {cat:<30s}  {len(imgs)} imgs, appearances: {min(all_app)}-{max(all_app)}")
