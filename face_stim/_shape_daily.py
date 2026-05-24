"""Count unique shape images used per day."""
import csv
from collections import defaultdict
from pathlib import Path

CSV = Path(__file__).parent / "trial_list.csv"

day_shapes = defaultdict(set)

with open(CSV, newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        if row["block_type"] != "shape":
            continue
        day = int(row["day"])
        for col in ("top_correct", "bottom_left", "bottom_right"):
            day_shapes[day].add(row[col])

counts = [len(v) for v in day_shapes.values()]
print(f"Unique shape images per day: min={min(counts)} max={max(counts)} mean={sum(counts)/len(counts):.1f}")
print(f"(First 5 days: {[len(day_shapes[d]) for d in range(1,6)]})")
print(f"\nWith 75 shapes total and ~{round(sum(counts)/len(counts))} unique/day:")
avg = sum(counts)/len(counts)
print(f"  Days before forced repeat: {75 / avg:.1f}")
