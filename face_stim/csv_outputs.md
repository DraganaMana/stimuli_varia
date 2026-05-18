# CSV Output Documentation — Emotion Face-Matching Task

## File naming

Two files are written per run:

```
EmotMatch_day{D}_run{R}_{YYYY-MM-DD_HH-MM-SS}_behavioral.csv   ← use this for analysis
EmotMatch_day{D}_run{R}_{YYYY-MM-DD_HH-MM-SS}_frames.csv       ← timing verification only
```

The timestamp is wall-clock time when the task finished.

---

## `_behavioral.csv` — 36 rows, one per trial

This is the file you open for all behavioral and fMRI analyses. Every column is filled for every row — no NaN columns, no filtering required.

### Columns

| Column | Type | Description |
|--------|------|-------------|
| `day` | int | Session day (1 or 2) |
| `run` | int | Run within day (1 or 2) |
| `block` | int | Block number within run (1–4) |
| `trial` | int | Trial number within block (1–9) |
| `block_type` | str | `neg_face` (fearful/angry), `hap_face` (happy), or `shape` |
| `base_path` | str | Relative base directory for image files |
| `top_correct` | str | Filename of the top image (the target to match) |
| `bottom_left` | str | Filename of the left choice image |
| `bottom_right` | str | Filename of the right choice image |
| `bottom_correct_match` | str | Which bottom image is correct: `left` or `right` |
| `trial_index` | int | Sequential trial counter across the full run (1–36) |
| `block_number` | int | Block number (same as `block`; kept for convenience) |
| `trial_in_block` | int | Trial position within block (1–9) |
| `is_face_block` | int | `1` = face block, `0` = shape block |
| `block_onset` | float | Absolute timestamp (Unix epoch s) of this block's cue screen. Same value for all 9 trials in a block. |
| `stimonset` | float | Absolute timestamp when the stimulus appeared on screen (first flip of the 4 s display window) |
| `respsec` | float | Reaction time in seconds from `stimonset`. **`0` means no response was recorded** within the 4 s window — not RT = 0 ms. Use `respsec > 0` to select valid responses. |
| `responsecorr` | float | `1` = correct, `0` = incorrect, `NaN` = no response |
| `key_code` | float | PTB key code of the button pressed. MRI (Current Designs 932): `11` = left/index finger, `12` = right/middle finger. Laptop: depends on `opts.responseKeys`. `NaN` if no response. |
| `keypress_timestamp` | float | Absolute timestamp of the button press. Computed as `stimonset + respsec`. `NaN` if no response. |
| `isi_seconds` | float | ITI duration for this trial: jittered 2/4/6 s (face blocks) or fixed 2 s (shape blocks) |
| `trigger_timestamp` | float | **Absolute timestamp of task start.** In MRI mode: time of the scanner trigger pulse (within one frame, ~8–16 ms). In laptop mode: time of the first flip after the experimenter pressed start. This is `t = 0` for the run. Same value repeated on every row. |
| `accuracy` | float | Mean accuracy across all trials in this run (proportion correct, 0–1). Same value repeated on every row. |
| `screenX` | int | Screen width in pixels (e.g. 1920) |
| `screenY` | int | Screen height in pixels (e.g. 1200) |
| `source_csv_path` | str | Full path to the trial-list CSV used to generate this run |

---

## `_frames.csv` — one row per screen flip (~12 700 rows)

Save this file if you need sub-trial timing verification (e.g. checking display latency or frame drops). You rarely need it for standard analyses.

### Columns

| Column | Type | Description |
|--------|------|-------------|
| `day` | int | Session day |
| `run` | int | Run within day |
| `frame_index` | int | Sequential flip counter across the run (starts at 1) |
| `timestamp` | float | Absolute timestamp of this flip (PTB `Screen('Flip')` return value, Unix epoch s) |
| `frame_type` | int | What was shown: `0` = first flip (pre-task blank), `-1` = block cue screen, `1` = stimulus (3 images), `2` = ITI fixation cross |
| `screenX` | int | Screen width in pixels |
| `screenY` | int | Screen height in pixels |

---

## Scanner timing and synchronisation

### How to align stimulus timing with the BOLD signal

All timestamps are **absolute Unix epoch seconds** from PTB `GetSecs`. To get timing relative to the scanner, subtract `trigger_timestamp`. Because `trigger_timestamp` is on every trial row, this is a single operation:

```python
import pandas as pd

df = pd.read_csv('EmotMatch_day1_run1_*_behavioral.csv')

df['stimonset_rel']  = df['stimonset']         - df['trigger_timestamp']
df['block_onset_rel'] = df['block_onset']       - df['trigger_timestamp']
df['keypress_rel']   = df['keypress_timestamp'] - df['trigger_timestamp']  # NaN if no response
```

This gives stimulus onsets in seconds from the first TR — the standard input for fMRI GLMs in SPM, FSL, or nilearn.

### What `trigger_timestamp` captures

**MRI mode** (`outside_of_mri_test = 0`): the script waits for the `+` trigger pulse via KbQueue, then immediately flips the first block cue. `trigger_timestamp` is the timestamp of that flip — within one frame (~8–16 ms) of the actual scanner trigger.

**Laptop/test mode** (`outside_of_mri_test = 1`): the script starts on a keypress. `trigger_timestamp` is still the first flip timestamp but has no scanner meaning.

### Do we need to save individual TR triggers?

**No, not for standard analyses.** The current single task-start timestamp is the established approach for fMRI paradigm scripts and is sufficient to:
- Align behavioral timing to the BOLD signal
- Build design matrices for GLMs
- Compute trial-level HRF regressors

TR-by-TR trigger logging would only be needed to verify TR regularity or detect dropped volumes — tasks normally handled by the scanner software.

---

## Common analysis recipes

### Stimulus onset times for a face-vs-shape GLM

```python
df['onset_s'] = df['stimonset'] - df['trigger_timestamp']

face_onsets  = df.loc[df.is_face_block == 1, 'onset_s']
shape_onsets = df.loc[df.is_face_block == 0, 'onset_s']
```

### Reaction time (valid responses only)

```python
valid = df[df.respsec > 0].copy()
rt = valid['respsec']
```

### Accuracy by condition

```python
df[df.respsec > 0].groupby('block_type')['responsecorr'].mean()
```

### Block onset times

```python
blocks = df.groupby('block_number').first()[['block_onset', 'block_type']].copy()
blocks['onset_s'] = blocks['block_onset'] - df['trigger_timestamp'].iloc[0]
```

---

## Known issues and notes

| Issue | Detail |
|-------|--------|
| `respsec == 0` means no response | Not RT = 0 ms. Filter with `respsec > 0` for RT analyses. |
| `responsecorr == NaN` when `respsec == 0` | Distinguishes "absent response" from "wrong response" (0). Exclude NaN rows or treat as incorrect depending on convention. |
| `key_code` is device-dependent | Values 11/12 are specific to the Current Designs 932 MRI button box. Laptop testing produces different codes based on `opts.responseKeys`. |
| `accuracy` is run-level mean | It is the same value on every row. It counts trials with no response as incorrect (denominator = all 36 trials). |
