"""Check all unique image sizes across both databases."""
from pathlib import Path
from PIL import Image
from collections import Counter

RADIATE_ROOT = Path(r"C:\Users\draga\Documents\data\emotional_faces\RADIATE\RADIATE_BMP\RADIATE_BMP\RADIATE_450_COLOR_BMP")
CFD_ROOT     = Path(r"C:\Users\draga\Documents\data\emotional_faces\Chicago\CFD Version 3.0\Images\CFD")

def all_sizes(files, label):
    sizes = Counter()
    for f in files:
        w, h = Image.open(f).size
        sizes[(w, h)] += 1
    print(f"\n{label} ({sum(sizes.values())} files):")
    for (w, h), count in sizes.most_common():
        print(f"  {w}×{h}  ratio={w/h:.3f}  — {count} files")

radiate_files = list(RADIATE_ROOT.rglob("*.bmp"))
cfd_files     = [f for d in CFD_ROOT.iterdir() if d.is_dir()
                 for f in d.iterdir() if f.suffix.lower() == ".jpg"]

all_sizes(radiate_files, "RADIATE BMP")
all_sizes(cfd_files,     "CFD JPG")
