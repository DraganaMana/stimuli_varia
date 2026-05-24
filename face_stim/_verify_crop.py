import csv
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
LOCAL_CSV  = SCRIPT_DIR / "trial_list_local.csv"

with open(LOCAL_CSV, newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f))

cfd_rows = [r for r in rows if r["top_correct"].startswith("CFD/")]
print(f"CFD rows in CSV : {len(cfd_rows)}")
print("Sample paths:")
for r in cfd_rows[:3]:
    p = SCRIPT_DIR / r["base_path"] / r["top_correct"]
    print(f"  {r['top_correct']}  exists={p.exists()}")

non_cropped = [r for r in cfd_rows if not r["top_correct"].endswith("_cropped.jpg")]
print(f"Non-cropped CFD paths remaining: {len(non_cropped)}")
