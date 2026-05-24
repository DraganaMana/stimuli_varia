"""Check within-day shape image repetition by role (correct vs foil)."""
import csv
from collections import defaultdict, Counter
from pathlib import Path

CSV = Path(__file__).parent / "trial_list.csv"

# Per day: how many times each shape is used as correct target vs foil
day_correct = defaultdict(lambda: defaultdict(int))  # [day][img] = count as correct
day_foil    = defaultdict(lambda: defaultdict(int))  # [day][img] = count as foil

with open(CSV, newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        if row["block_type"] != "shape":
            continue
        day   = int(row["day"])
        top   = row["top_correct"]
        match = row["bottom_correct_match"]
        bl    = row["bottom_left"]
        br    = row["bottom_right"]
        foil  = br if match == "left" else bl

        day_correct[day][top]  += 1
        day_foil[day][foil]    += 1

# Violations: any image used >1 time in the same role on the same day
correct_violations = sum(
    1 for d in day_correct.values() for c in d.values() if c > 1
)
foil_violations = sum(
    1 for d in day_foil.values() for c in d.values() if c > 1
)

print(f"=== Within-day shape uniqueness (by role) ===")
print(f"Correct-role violations  (same image correct >1×/day): {correct_violations}")
print(f"Foil-role violations     (same image foil >1×/day)   : {foil_violations}")

# Cross-role: shapes that appear both as correct and foil the same day (allowed)
both_roles = sum(
    1
    for day in day_correct
    for img in day_correct[day]
    if img in day_foil[day]
)
print(f"\nCross-role (correct + foil same day, allowed)        : {both_roles}")

# Per-day unique image counts
unique_per_day = [
    len(set(day_correct[d]) | set(day_foil[d]))
    for d in range(1, 31)
]
print(f"\nUnique shape images per day: "
      f"min={min(unique_per_day)} max={max(unique_per_day)} "
      f"mean={sum(unique_per_day)/len(unique_per_day):.1f}")
print(f"(Pool size: 75 shapes)")
