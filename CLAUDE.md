# stimuli_varia — Claude context

## Python environment
Always run Python via: `conda run -n mne1.8 python <script>`
Bare `python` or `python3` in PowerShell resolves to a Windows Store stub (exit code 49).

## Repo overview
Collection of MRI-compatible stimulus paradigms. Each subfolder is a self-contained task.

| Folder | Task | Language |
|--------|------|----------|
| `face_stim/` | 30-day emotion face-matching (negative + happy faces or shapes, 2 databases) | Python + MATLAB/PsychToolbox |
| `breathold_task/` | Breath-hold cerebrovascular reactivity (CVR) | MATLAB/PsychToolbox |
| `from_stim_laptop/` | Archived scripts from the MRI stimulus laptop (read-only reference) | MATLAB/PsychToolbox |

---

## face_stim/

### What it does
30-day longitudinal paradigm. Participants match a top image (face or shape) to one of two bottom choices, pressing left/right. Alternating face/shape blocks, 2 runs per day. Run 1 = negative faces (angry/fearful), Run 2 = happy faces.

### Key files
| File | Purpose |
|------|---------|
| `generate_shapes.py` | Generates 75 PNG shape stimuli (25 categories × 3 sizes) → `shapes_output/` |
| `generate_trial_list.py` | Builds `trial_list.csv` from RADIATE + CFD data + local shapes; enforces face repetition constraints |
| `copy_stimuli.py` | Copies face images (RADIATE + CFD) → `stimuli_images/faces/`; writes `trial_list_local.csv` |
| `crop_cfd.py` | Center-crops CFD JPGs (2444×1718 → 1718×1718 square) → `*_cropped.jpg`; updates `trial_list_local.csv` |
| `trial_list.csv` | Source trial list — `base_path` absolute (machine-specific) |
| `trial_list_local.csv` | Portable trial list — `base_path` relative to `face_stim/` |
| `emot_face_stim_26.m` | PsychToolbox task script |
| `emot_face_stim_eyetracking.m` | Eye-tracking variant (EyeLink) |

### Standalone repo workflow (run once per machine)
1. `generate_shapes.py` → `shapes_output/` (or use tracked PNGs)
2. `generate_trial_list.py` (needs RADIATE + CFD) → `trial_list.csv`
3. `copy_stimuli.py` (needs RADIATE + CFD) → `stimuli_images/faces/` + `trial_list_local.csv`
4. `crop_cfd.py` → `stimuli_images/faces/CFD/**/*_cropped.jpg` + updates `trial_list_local.csv`
5. Run task with `opts.csv_path = '.../face_stim/trial_list_local.csv'`

### Face databases
- **RADIATE**: `C:\Users\draga\Documents\data\emotional_faces\RADIATE\RADIATE_BMP\RADIATE_BMP\RADIATE_450_COLOR_BMP\`
  - Expressions: AC, AO, FC, FO (neg); HC, HE, HO (hap)
  - Local copy: `face_stim/stimuli_images/faces/RADIATE_COLOR_X/IDENTITY/*.bmp`
- **CFD (Chicago Face Database)**: `C:\Users\draga\Documents\data\emotional_faces\Chicago\CFD Version 3.0\Images\CFD`
  - Expressions: A, F (neg); HC, HO (hap)
  - Original images: 2444×1718 px (landscape); center-cropped to 1718×1718 (square) by `crop_cfd.py`
  - Local copy: `face_stim/stimuli_images/faces/CFD/IDENTITY_DIR/*_cropped.jpg` (task uses cropped versions)
- 1250 face images + 533 cropped JPGs in `stimuli_images/faces/`

### Task parameters
- 30 days, 2 runs/day; 8 blocks/run (4 face + 4 shape, interleaved); 5 trials/block = 2400 total trials
- Face blocks: 1,3,5,7 (odd) — female at 1,5; male at 3,7; run 1 = neg, run 2 = hap
- Shape blocks: 2,4,6,8 (even)
- Stimulus display: 4 s; no fixation cross during stimulus (participants scan images freely); ITIs: jittered [2,2,4,6,6] s shuffled (faces), fixed 2 s (shapes); fixation cross shown during ITI only
- 10 s blank gray screen after trigger (pre-task baseline; runs in both laptop and MRI mode); dummy volumes reach steady state *before* the trigger fires, so this is a resting baseline for the GLM — not for steady state. Trigger `5%`/`+`, Current Designs 932 button box
- Face repetition constraint: max 2 appearances per image, min 15-day gap between appearances
- Shape constraint: each image at most once as correct target and once as foil per day

---

## breathold_task/

### What it does
Breath-hold CVR paradigm for measuring cerebrovascular reactivity via CO2 changes during MRI. Participants hold their breath for 15 s per block while CO2 is recorded continuously.

### Key files
| File | Purpose |
|------|---------|
| `breathhold_steph_upd.m` | Original script (Baarbod Ashenagar) — untouched reference copy |
| `breathhold_cvr_clean.m` | Cleaned version with full documentation — use this one |

### Block structure (per block, 60 s)
```
Breathe normally       21 s   baseline
Breathe out / in       × 3    paced breathing (3 s each = 18 s)
Prepare to hold         3 s
Hold your breath       15 s   countdown shown on screen
Exhale through nose     3 s   must be nose — CO2 sampled via nasal cannula
```
Post-task recovery: 39 s. Default: 8 blocks × 60 s + 39 s ≈ 8.65 min.

### Hardware
- CO2: CapStar-100 (start before script, stop several seconds after)
- MRI trigger: `+` key (Current Designs 932 button box)
- Set scanning protocol duration a few seconds longer than the script

---

## from_stim_laptop/

Archived scripts from the MRI stimulus laptop. Treat as read-only reference.

| File | Task |
|------|------|
| `psychtoolbox NIGHT/breathhold_steph_upd.m` | Original breath-hold CVR (superseded by `breathold_task/`) |
| `psychtoolbox NIGHT/breathhold_steph.m` | Earlier version of breath-hold (9 blocks) |
| `psychtoolbox NIGHT/avpvt_rest.m` | Auditory/visual psychomotor vigilance task (PVT) |
| `psychtoolbox NIGHT/audvisPVT_s25_eye.m` | PVT with eyetracking |
| `psychtoolbox NIGHT/FixationTask.m` | Fixation task |
| `from_pilot_folder/` | Pilot scripts (flicker + piloth variants) — exploratory, not finalised |
