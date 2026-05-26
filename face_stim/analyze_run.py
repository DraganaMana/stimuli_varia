"""
analyze_run.py  —  Summarise one EmotMatch run from its output CSVs.

Usage:
    conda run -n mne1.8 python analyze_run.py <output_folder>
    conda run -n mne1.8 python analyze_run.py        # defaults to the pilot folder

Writes <output_folder>/summary.md with run-level statistics.
"""

import sys
import re
import math
from pathlib import Path

import pandas as pd
import numpy as np

SCRIPT_DIR    = Path(__file__).parent
DEFAULT_FOLDER = SCRIPT_DIR / "data" / "laptop_pilot_analysis_052426"

STIM_DURATION = 4.0   # nominal display duration (s)
CUE_DURATION  = 3.0   # nominal block cue duration (s)


# ---------------------------------------------------------------------------

def find_csvs(folder: Path):
    behavioral = sorted(folder.glob("*_behavioral.csv"))
    frames     = sorted(folder.glob("*_frames.csv"))
    if not behavioral:
        raise FileNotFoundError(f"No *_behavioral.csv found in {folder}")
    if not frames:
        raise FileNotFoundError(f"No *_frames.csv found in {folder}")
    if len(behavioral) > 1:
        print(f"Warning: multiple behavioral CSVs; using {behavioral[-1].name}")
    return behavioral[-1], frames[-1]


def fmt_mmss(t):
    m = int(t) // 60
    s = t - 60 * m
    return f"{m}:{s:05.2f}"


def fmt_pct(x):
    return f"{x:.1%}" if not (math.isnan(x) if isinstance(x, float) else False) else "—"


def fmt_f(x, decimals=3):
    return f"{x:.{decimals}f}" if not (math.isnan(x) if isinstance(x, float) else False) else "—"


# ---------------------------------------------------------------------------

def main():
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_FOLDER
    if not folder.exists():
        sys.exit(f"Folder not found: {folder}")

    beh_file, frm_file = find_csvs(folder)
    beh = pd.read_csv(beh_file)
    frm = pd.read_csv(frm_file)

    # --- metadata
    day        = beh["day"].iloc[0]
    run        = beh["run"].iloc[0]
    trigger_ts = beh["trigger_timestamp"].iloc[0]
    accuracy   = beh["accuracy"].iloc[0]
    n_trials   = len(beh)
    n_blocks   = beh["block_number"].nunique()

    date_match = re.search(r"(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})", beh_file.name)
    run_date = f"{date_match.group(1)} {date_match.group(2).replace('-', ':')}" if date_match else "unknown"

    t0 = trigger_ts

    # --- run timing
    last_row      = beh.iloc[-1]
    run_end_est   = last_row["stimonset"] + STIM_DURATION + last_row["isi_seconds"]
    run_dur_beh   = run_end_est - t0
    run_dur_frame = frm["timestamp"].iloc[-1] - t0   # last recorded flip

    # --- block-level stats
    block_rows = []
    for bl_num, bl_df in beh.groupby("block_number"):
        bl_onset  = bl_df["block_onset"].iloc[0] - t0
        bl_type   = bl_df["block_type"].iloc[0]
        is_face   = bool(bl_df["is_face_block"].iloc[0])
        last_end  = bl_df["stimonset"].iloc[-1] + STIM_DURATION + bl_df["isi_seconds"].iloc[-1]
        bl_dur    = last_end - bl_df["block_onset"].iloc[0]

        rm        = bl_df["respsec"] > 0
        n_resp    = int(rm.sum())
        acc_bl    = bl_df.loc[rm, "responsecorr"].mean() if n_resp > 0 else float("nan")
        rt_mean   = bl_df.loc[rm, "respsec"].mean()      if n_resp > 0 else float("nan")
        rt_sd     = bl_df.loc[rm, "respsec"].std()       if n_resp > 0 else float("nan")

        block_rows.append(dict(
            block=bl_num, type=bl_type, face_block=is_face,
            onset_s=bl_onset, duration_s=bl_dur, n_trials=len(bl_df),
            n_resp=n_resp, accuracy=acc_bl, rt_mean=rt_mean, rt_sd=rt_sd,
        ))
    bl_stats = pd.DataFrame(block_rows)

    # --- overall response stats
    resp_mask    = beh["respsec"] > 0
    n_resp_total = int(resp_mask.sum())
    n_no_resp    = int((~resp_mask).sum())

    rt_all   = beh.loc[resp_mask, "respsec"]
    rt_face  = beh.loc[resp_mask & (beh["is_face_block"] == 1), "respsec"]
    rt_shape = beh.loc[resp_mask & (beh["is_face_block"] == 0), "respsec"]
    acc_face  = beh.loc[resp_mask & (beh["is_face_block"] == 1), "responsecorr"].mean()
    acc_shape = beh.loc[resp_mask & (beh["is_face_block"] == 0), "responsecorr"].mean()

    # --- per block_type stats
    bt_rows = []
    for bt, grp in beh.groupby("block_type"):
        rm = grp["respsec"] > 0
        bt_rows.append(dict(
            block_type=bt, n_trials=len(grp), n_resp=int(rm.sum()),
            accuracy=grp.loc[rm, "responsecorr"].mean() if rm.any() else float("nan"),
            rt_mean=grp.loc[rm, "respsec"].mean()  if rm.any() else float("nan"),
            rt_sd  =grp.loc[rm, "respsec"].std()   if rm.any() else float("nan"),
            rt_min =grp.loc[rm, "respsec"].min()   if rm.any() else float("nan"),
            rt_max =grp.loc[rm, "respsec"].max()   if rm.any() else float("nan"),
        ))
    bt_stats = pd.DataFrame(bt_rows)

    # --- timing: inter-stimulus gaps within blocks
    beh2 = beh.copy()
    beh2["prev_stimonset"] = beh2["stimonset"].shift(1)
    beh2["prev_isi"]       = beh2["isi_seconds"].shift(1)
    within = beh2[beh2["trial_in_block"] > 1].copy()
    within["actual_gap"]   = within["stimonset"] - within["prev_stimonset"]
    within["expected_gap"] = STIM_DURATION + within["prev_isi"]
    within["error_ms"]     = (within["actual_gap"] - within["expected_gap"]) * 1000

    # --- IFI estimate from frame log (exclude large gaps at block transitions)
    flip_gaps = frm[frm["frame_type"] != 0]["timestamp"].diff().dropna()
    ifi_est   = flip_gaps.median()                   # single-flip median including gaps
    ifi_clean = flip_gaps[flip_gaps < 0.05]          # only sub-50ms intervals
    ifi_ms    = ifi_clean.median() * 1000
    ifi_sd_ms = ifi_clean.std()    * 1000

    # --- actual stimulus display durations from frame log
    stim_frm = frm[frm["frame_type"] == 1].copy()
    stim_frm["gap"] = stim_frm["timestamp"].diff()
    # new stim period when gap > 3 × IFI
    stim_frm["period"] = (stim_frm["gap"] > ifi_est * 3).cumsum()
    stim_durs = stim_frm.groupby("period")["timestamp"].agg(
        lambda x: x.iloc[-1] - x.iloc[0] + ifi_est
    )

    # --- no-response trial list
    no_resp = beh.loc[~resp_mask, ["trial_index", "block_number", "trial_in_block", "block_type"]]

    # -----------------------------------------------------------------------
    # Build markdown
    # -----------------------------------------------------------------------
    L = []   # lines

    L += [f"# EmotMatch Run Summary — Day {day}, Run {run}", ""]
    L += [f"**Date:** {run_date}  ",
          f"**Source:** `{beh_file.name}`  ",
          f"**Trials:** {n_trials}  ({n_blocks} blocks × {n_trials // n_blocks} trials/block)", ""]

    # -- Run duration
    L += ["## Run Duration", ""]
    first_stim_rel = beh["stimonset"].iloc[0] - t0
    last_stim_rel  = beh["stimonset"].iloc[-1] - t0
    L += ["| | |",
          "|---|---|",
          f"| Trigger (t = 0) | {run_date} |",
          f"| First stimulus onset | +{first_stim_rel:.2f} s |",
          f"| Last stimulus onset  | +{last_stim_rel:.2f} s |",
          f"| Estimated end (last stim + display + ITI) | {run_dur_beh:.2f} s  ({fmt_mmss(run_dur_beh)}) |",
          f"| Last frame in log | {run_dur_frame:.2f} s  ({fmt_mmss(run_dur_frame)}) |",
          ""]

    # Detect baseline wait from first stimulus onset: onset = equil + cue
    equil_secs   = max(0, round(beh["stimonset"].iloc[0] - t0 - CUE_DURATION))
    expected_base = CUE_DURATION * n_blocks + STIM_DURATION * n_trials + 20 * 4 + 10 * 4
    expected_total = expected_base + equil_secs
    equil_note = f" + {equil_secs}s baseline wait" if equil_secs > 0 else " (no baseline wait)"
    L += [f"> **Expected{equil_note}:** "
          f"{n_blocks}×{CUE_DURATION:.0f}s cue + {n_trials}×{STIM_DURATION:.0f}s stim "
          f"+ 4 face blocks×20s ITI + 4 shape blocks×10s ITI{equil_note} = **{expected_total:.0f} s "
          f"({fmt_mmss(expected_total)})**", ""]

    # -- Block summary
    L += ["## Block Summary", ""]
    L += ["| Block | Type | Onset (s) | Duration (s) | Trials | Resp | Accuracy | Mean RT (s) | RT SD |"]
    L += ["|---|---|---|---|---|---|---|---|---|"]
    for _, r in bl_stats.iterrows():
        L.append(
            f"| {int(r['block'])} | {r['type']} | {r['onset_s']:.2f} | {r['duration_s']:.2f} "
            f"| {int(r['n_trials'])} | {int(r['n_resp'])}/{int(r['n_trials'])} "
            f"| {fmt_pct(r['accuracy'])} | {fmt_f(r['rt_mean'])} | {fmt_f(r['rt_sd'])} |"
        )
    L += [""]
    L += ["> **Expected durations:** "
          "face blocks = 3 (cue) + 20 (stim) + 20 (ITI mean) = **43 s**;  "
          "shape blocks = 3 + 20 + 10 = **33 s**", ""]

    # -- Accuracy and RT by block type
    L += ["## Accuracy and RT by Block Type", ""]
    L += ["| Type | Trials | Resp | Accuracy | Mean RT | RT SD | Min RT | Max RT |"]
    L += ["|---|---|---|---|---|---|---|---|"]
    for _, r in bt_stats.iterrows():
        L.append(
            f"| {r['block_type']} | {int(r['n_trials'])} | {int(r['n_resp'])} "
            f"| {fmt_pct(r['accuracy'])} | {fmt_f(r['rt_mean'])} s "
            f"| {fmt_f(r['rt_sd'])} s | {fmt_f(r['rt_min'])} s | {fmt_f(r['rt_max'])} s |"
        )
    L += [""]
    L += [f"**Overall accuracy:** {fmt_pct(accuracy)}  ",
          f"**Face accuracy:** {fmt_pct(acc_face)}  ",
          f"**Shape accuracy:** {fmt_pct(acc_shape)}  ",
          f"**No-response trials:** {n_no_resp} / {n_trials}  ", ""]

    # -- RT distribution
    L += ["## RT Distribution (responded trials only)", ""]
    for label, series in [("All trials", rt_all), ("Face blocks", rt_face), ("Shape blocks", rt_shape)]:
        if len(series) > 0:
            L.append(
                f"**{label}** (n={len(series)}): "
                f"mean={series.mean():.3f} s, median={series.median():.3f} s, "
                f"SD={series.std():.3f} s, range [{series.min():.3f} – {series.max():.3f}] s  "
            )
    L += [""]

    # -- Timing checks
    L += ["## Timing Checks", ""]

    L += ["### Inter-stimulus gaps (within-block)", ""]
    L += ["Gap = time from stimulus N onset to stimulus N+1 onset (within the same block).  ",
          "Expected = 4.0 s display + ITI of trial N.", ""]
    L += [f"| | |",
          f"|---|---|",
          f"| Gaps checked | {len(within)} |",
          f"| Mean error   | {within['error_ms'].mean():.2f} ms |",
          f"| Median error | {within['error_ms'].median():.2f} ms |",
          f"| SD of errors | {within['error_ms'].std():.2f} ms |",
          f"| Max absolute error | {within['error_ms'].abs().max():.2f} ms |",
          ""]

    L += ["### Frame flip interval (IFI)", ""]
    L += [f"| | |",
          f"|---|---|",
          f"| Median IFI (sub-50ms flips only) | {ifi_ms:.3f} ms |",
          f"| SD | {ifi_sd_ms:.3f} ms |",
          f"| Expected at 60 Hz | 16.667 ms |",
          f"| Expected at 144 Hz | 6.944 ms |",
          ""]

    L += ["### Actual stimulus display durations", ""]
    L += [f"| | |",
          f"|---|---|",
          f"| Stimulus periods detected | {len(stim_durs)} (expected {n_trials}) |",
          f"| Mean duration | {stim_durs.mean():.4f} s |",
          f"| SD | {stim_durs.std():.4f} s |",
          f"| Min / Max | {stim_durs.min():.4f} s / {stim_durs.max():.4f} s |",
          f"| Nominal | {STIM_DURATION:.1f} s |",
          ""]

    # -- No-response trials
    L += ["## No-Response Trials", ""]
    if n_no_resp == 0:
        L += ["All trials received a response.", ""]
    else:
        L += [f"{n_no_resp} trial(s) had no response recorded.", ""]
        L += ["| trial_index | block | trial_in_block | block_type |"]
        L += ["|---|---|---|---|"]
        for _, r in no_resp.iterrows():
            L.append(f"| {int(r['trial_index'])} | {int(r['block_number'])} "
                     f"| {int(r['trial_in_block'])} | {r['block_type']} |")
        L += [""]

    L += ["---",
          f"*Generated by `analyze_run.py` · source: `{beh_file.name}`*"]

    md_path = folder / "summary.md"
    md_path.write_text("\n".join(L), encoding="utf-8")
    print(f"Summary written: {md_path}")


if __name__ == "__main__":
    main()
