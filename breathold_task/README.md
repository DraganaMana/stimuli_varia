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

## Running the task

1. Start CO2 recording on the CapStar-100 **before** launching the script.
2. Set the MRI scanning protocol duration a few seconds **longer** than the script to absorb PsychToolbox overhead.
3. Run `breathhold_cvr_clean.m` in MATLAB — the script will display a waiting screen until the scanner trigger (`+`) is received.
4. Stop CO2 recording several seconds **after** the script finishes to capture the delayed gas signal.
