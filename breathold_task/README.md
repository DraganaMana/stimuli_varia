# Breath-Hold CVR Paradigm

This folder contains two versions of the breath-hold cerebrovascular reactivity (CVR) task script for MRI scanning.

| File | Description |
|------|-------------|
| `breathhold_steph_upd.m` | Original script (Baarbod Ashenagar), copied unmodified |
| `breathhold_cvr_clean.m` | Cleaned and commented version — use this one |

---

## What changed in the clean version

### 1. Header documentation block
A full description of the task is now at the top of the file, covering:
- the purpose of the paradigm and what CVR measures
- the exact block structure with durations for each phase
- participant coaching notes (notably: exhale through the **nose** after the hold, not the mouth, as CO2 is sampled via nasal cannula)
- hardware setup checklist (CapStar-100, Current Designs 932 button box, scanner trigger key, protocol timing advice)

### 2. Inline comments throughout
Every non-obvious line now has a comment explaining the *why*, not just the *what* — e.g. why `dt = 0.25`, what the `bh_case` flag tracks, why the countdown uses a ceiling (`floor + 1`) rather than a raw float.

### 3. Corrupted content removed
Line 60 of the original contained hundreds of stray `+` characters (likely an accidental keyboard event saved into the file). These are removed.

### 4. Dead code removed
Several blocks of commented-out code were removed to reduce noise:
- An old keyboard-detection loop that was never used
- An unused `rect` variable for a windowed screen open
- A leftover `deviceString` variable from a different lab setup

### 5. Breath-hold flag logic clarified
The original raised the `bh_case` flag inside the `switch` statement and silently reset it at the end of the `elseif` branch, making the control flow hard to follow. The clean version uses an explicit `if icondition == 5` check to raise the flag, with a comment explaining the raise/reset cycle.

### 6. Diagnostic figure improved
The condition timeline figure now has axis labels, a title, and named y-tick labels (e.g. "Hold breath", "Exhale nose") so it is actually readable as a sanity check before running.

---

## Task structure (unchanged)

```
Per block (60 s):
  Breathe normally       21 s   baseline
  Breathe out             3 s   |
  Breathe in              3 s   | x3 paced breathing cycles
  Breathe out             3 s   |
  Breathe in              3 s   |
  Breathe out             3 s   |
  Breathe in              3 s   |
  Prepare to hold         3 s   pre-hold cue
  Hold your breath       15 s   countdown timer shown on screen
  Exhale through nose     3 s   must be through nose for CO2 capture

Post-task (once):
  Breathe normally       39 s   recovery

Default: 8 blocks  ×  60 s  +  39 s  ≈  8.65 minutes total
```

---

## CSV output

One CSV file is written per run to `breathold_task/data/`:

```
BreathHold_YYYY-MM-DD_HH-MM-SS.csv
```

It is saved **immediately after the scanner trigger is received**, before any blocks run, so timing is preserved even if the script errors mid-run.

### Columns

| Column | Type | Description |
|--------|------|-------------|
| `trigger_timestamp` | float | PTB `GetSecs` timestamp of the `+` trigger pulse. This is **t = 0** for the run — subtract this from all derived onset times to align with the BOLD signal. In test mode (`outside_of_mri_test = 1`), it is `GetSecs` at the moment the script started (no scanner meaning). |
| `datetime` | str | Wall-clock time string (`YYYY-MM-DD_HH-MM-SS`) — use this to match the CSV against the CapStar-100 CO2 recording file. |
| `mode` | str | `mri` or `test` |
| `nblocks` | int | Number of task blocks (default 8) |
| `block_duration_s` | float | Duration of one block in seconds (default 60) |
| `total_duration_s` | float | Total task duration including post-task recovery (default 519 s = 8 × 60 + 39) |

### Deriving condition onsets from `trigger_timestamp`

The task timing is fully deterministic — no jitter, no random events. All condition onsets can be computed analytically:

```python
import pandas as pd

df = pd.read_csv('BreathHold_YYYY-MM-DD_HH-MM-SS.csv')
t0 = df['trigger_timestamp'].iloc[0]   # t = 0

# Onset of each phase within a block (seconds after block start):
#   Breathe normally:  0 s
#   Paced breathing:  21 s  (3 cycles × in/out × 3 s = 18 s)
#   Prepare:          39 s
#   Hold breath:      42 s
#   Exhale:           57 s

block_duration = 60   # seconds
n_blocks       = 8

hold_onsets = [(t0 + b * block_duration + 42) for b in range(n_blocks)]
```

### Aligning with the BOLD signal

Subtract `trigger_timestamp` from any derived onset to get seconds from the first TR:

```python
hold_onset_rel = (t0 + 0 * block_duration + 42) - t0   # = 42.0 s
```

If the scanner trigger fires at the **first dummy volume**, add `n_dummies × TR` to all onsets when building your GLM against the trimmed (kept) timeseries. Confirm with your MRI physicist whether the trigger is sent before or after dummy volumes.

---

## Running the task

1. Start CO2 recording on the CapStar-100 **before** launching the script.
2. Set the MRI scanning protocol duration a few seconds **longer** than the script to absorb PsychToolbox overhead.
3. Run `breathhold_cvr_clean.m` in MATLAB — the script will display a waiting screen until the scanner trigger (`+`) is received.
4. Stop CO2 recording several seconds **after** the script finishes to capture the delayed gas signal.
