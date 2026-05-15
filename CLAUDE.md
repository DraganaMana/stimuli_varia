# stimuli_varia — Claude context

## Python environment
Always run Python via: `conda run -n mne1.8 python <script>`
Bare `python` or `python3` in PowerShell resolves to a Windows Store stub (exit code 49).

## Repo overview
Collection of MRI-compatible stimulus paradigms. Each subfolder is a self-contained task.

| Folder | Task | Language |
|--------|------|----------|
| `face_stim/` | Emotion face-matching (match angry/fearful faces or shapes) | Python + MATLAB/PsychToolbox |
| `breathold_task/` | Breath-hold cerebrovascular reactivity (CVR) | MATLAB/PsychToolbox |
| `from_stim_laptop/` | Archived scripts from the MRI stimulus laptop (read-only reference) | MATLAB/PsychToolbox |

---

## face_stim/

### What it does
Participants match a top image (face or shape) to one of two bottom choices, pressing left/right. Alternating face/shape blocks, 2 runs per session.

### Key files
| File | Purpose |
|------|---------|
| `generate_shapes.py` | Generates PNG shape stimuli → `shapes_output/` |
| `generate_trial_list.py` | Builds `trial_list.csv` from RADIATE data + local shapes |
| `copy_stimuli.py` | Copies RADIATE face images → `stimuli_images/faces/`; writes `trial_list_local.csv` |
| `trial_list.csv` | Source trial list — `base_path` absolute (machine-specific, needs RADIATE data) |
| `trial_list_local.csv` | Portable trial list — `base_path` relative to `face_stim/` |
| `emot_face_stim_26.m` | PsychToolbox task script; accepts `opts.csv_path` to use either CSV |

### Standalone repo workflow (run once per machine)
1. `generate_shapes.py` → `shapes_output/` (or just use the tracked PNGs)
2. `generate_trial_list.py` (needs RADIATE) → `trial_list.csv`
3. `copy_stimuli.py` (needs RADIATE) → `stimuli_images/faces/` + `trial_list_local.csv`
4. Run task with `opts.csv_path = '.../face_stim/trial_list_local.csv'`

### RADIATE face images
- Original location: `C:\Users\draga\Documents\data\emotional_faces\RADIATE\RADIATE_BMP\RADIATE_BMP\RADIATE_450_COLOR_BMP\`
- Local copy (repo): `face_stim/stimuli_images/faces/RADIATE_COLOR_X/IDENTITY/*.bmp`
- 72 images: 36 identities × 2 expressions (AC = angry, FO = fearful)

### Task parameters
- 1 day, 2 runs; 8 blocks/run (face/shape interleaved); 9 trials/block
- Stimulus display: 4 s; ITIs: jittered 2/4/6 s (faces), fixed 2 s (shapes)
- MRI mode: trigger `5%`, Current Designs 932 button box; laptop mode: keypress to start

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
