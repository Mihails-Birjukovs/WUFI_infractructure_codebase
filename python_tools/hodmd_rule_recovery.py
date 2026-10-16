#!/usr/bin/env python3
"""Forensic constraints and candidate mode-selection rules for REF/HEMP HODMD.

All recovered facts are inferred from the *archived outputs*; this module
does NOT claim to reconstruct the lost original HODMD source implementation.

Two distinct archives must remain separate:
  hodmd_target_stability.csv       — 112 aggregated 39/40-fit records
  paperstyle_hodmd_24h_crosscheck.csv — 480 fits from another algorithm

Optionally accept a locally generated *full-spectrum* mode catalog,
containing one row per eigenmode per rank/delay/record. Never publish raw
time-series, private eigenvectors, or per-fit catalog without authorization.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd

DELAY_ORDERS = (12, 24, 36, 48, 72)
TRUNCATION_RANKS = (4, 6, 8, 10, 12, 16, 20, 24)
TARGET_PERIODS = {
    "12h": 12., "24h": 24., "48h": 48., "72h": 72.,
    "weekly": 168., "2week": 336., "monthly": 720.,
}
SUMMARY_KEYS = ("system", "window", "source", "target")
FIT_KEYS = ("system", "window", "source", "delay_h", "rank")
EXPECTED_SUMMARY_SYSTEMS = frozenset(("HEMP19", "HEMP27", "REF118", "HEMP_PRIMARY"))
EXPECTED_PAPER_SYSTEMS = frozenset(("HEMP19", "HEMP27", "REF118", "HEMP42", "HEMP18"))
MAX_CANDIDATE_RANKS = 40


def admissible_configs(n_channels: int, strict_embedding: bool = True
                       ) -> list[tuple[int, int]]:
    """Candidate rule: rank < (#channels × delay), NOT a recovered fact.

    Excludes (12,24) for 2-channel state, but retains it for 6 channels,
    exactly matching the *number* of archived fits. Another numerical
    failure could also explain the difference, so this is only a hypothesis.
    """
    if not isinstance(n_channels, int) or n_channels < 1:
        raise ValueError("n_channels must be a positive integer")
    return [
        (d, r) for d in DELAY_ORDERS for r in TRUNCATION_RANKS
        if (r < n_channels*d if strict_embedding else r <= n_channels*d)
    ]


def _unique(frame: pd.DataFrame, keys, context):
    if frame.duplicated(list(keys)).any():
        raise ValueError(f"{context} has duplicated selectors")


def archived_stability_constraints(archive: pd.DataFrame) -> dict:
    """Check exact saved arithmetic; infer only a MINIMUM candidate halfwidth.

    Quantile bounds constrain possible period windows but do not identify
    the threshold, because the tails and individual accepted modes are lost.
    """
    required = set(SUMMARY_KEYS) | {
        "target_h", "nfits_total", "nfits_found", "stability_fraction",
        "period_q10_h", "period_median_h", "period_q90_h",
    }
    missing = required - set(archive.columns)
    if missing:
        raise ValueError(f"Stability archive columns missing: {sorted(missing)}")
    _unique(archive, SUMMARY_KEYS, "Stability archive")
    if len(archive) != 112 or set(archive["system"]) != EXPECTED_SUMMARY_SYSTEMS \
       or set(archive["target"]) != set(TARGET_PERIODS):
        raise ValueError("Unexpected historical 112-row HODMD summary inventory")
    for target, period in TARGET_PERIODS.items():
        current = archive.loc[archive["target"] == target, "target_h"].astype(float)
        if not np.allclose(current, period, atol=0, rtol=0):
            raise ValueError(f"Target period mismatch: {target}")
    total = pd.to_numeric(archive["nfits_total"]).to_numpy(int)
    selected = pd.to_numeric(archive["nfits_found"]).to_numpy(int)
    frac = pd.to_numeric(archive["stability_fraction"]).to_numpy(float)
    if not (np.all(total > 0) and np.all((selected >= 0) & (selected <= total))):
        raise ValueError("Impossible archive fit counts")
    if not np.allclose(frac, selected/total, atol=1e-12, rtol=0):
        raise ValueError("Archived stability fraction inconsistent with counts")
    expected_denominator = np.array(
        [40 if x == "HEMP_PRIMARY" else 39 for x in archive["system"]])
    if not np.array_equal(total, expected_denominator):
        raise ValueError("Denominators differ from archived 39/40 pattern")
    period = pd.to_numeric(archive["target_h"]).to_numpy(float)
    quantiles = np.column_stack([
        pd.to_numeric(archive[key]).to_numpy(float)
        for key in ("period_q10_h", "period_median_h", "period_q90_h")])
    if (not np.isfinite(quantiles).all() or
            not np.all(quantiles[:, 0] <= quantiles[:, 1]) or
            not np.all(quantiles[:, 1] <= quantiles[:, 2])):
        raise ValueError("Invalid archive period quantiles")
    deviations = np.abs(quantiles[:, (0,2)]/period[:, None]-1)
    strict_lower_bound = float(np.max(deviations))
    outside_25 = np.any(deviations > .25, axis=1)
    outside_30 = np.any(deviations > .30, axis=1)
    return {
        "archive_rows": len(archive),
        "group_count": int(archive.groupby(list(SUMMARY_KEYS[:3])).ngroups),
        "target_count": len(TARGET_PERIODS),
        "stability_fractions_arithmetically_consistent": True,
        "two_channel_configurations_if_rank_strict": len(admissible_configs(2)),
        "six_channel_configurations_if_rank_strict": len(admissible_configs(6)),
        "excluded_two_channel_grid_pairs_if_strict": [
            [d, r] for d in DELAY_ORDERS for r in TRUNCATION_RANKS
            if (d, r) not in admissible_configs(2)],
        "rank_rule_status": "plausible hypothesis, not original code",
        "minimum_symmetric_relative_period_halfwidth_from_q10_q90":
            strict_lower_bound,
        "quantile_rows_incompatible_with_25pct_window":
            int(outside_25.sum()),
        "quantile_rows_incompatible_with_30pct_window":
            int(outside_30.sum()),
        "window_inference_caution": (
            "A >28% halfwindow is necessary if accepted modes obey a hard "
            "symmetric interval; quantiles are insufficient to determine "
            "the actual threshold or behavior of the distribution tails."
        ),
    }


def paperstyle_coverage(archive: pd.DataFrame) -> dict:
    """Audit separate per-fit 480-row reference; do not merge with 112 rows."""
    required = set(FIT_KEYS) | {
        "period24_h", "eig_abs", "growth_per_h", "load_T", "load_pv"
    }
    if missing := required-set(archive.columns):
        raise ValueError(f"Paper-style archive columns missing: {sorted(missing)}")
    _unique(archive, FIT_KEYS, "Paper-style archive")
    expected_delays = {24, 36, 48, 72}
    expected_ranks = {6, 8, 10, 12, 16, 20}
    if len(archive) != 480 or set(archive["system"]) != EXPECTED_PAPER_SYSTEMS or \
       set(pd.to_numeric(archive["delay_h"])) != expected_delays or \
       set(pd.to_numeric(archive["rank"])) != expected_ranks:
        raise ValueError("Unexpected archived 480-fit paper-style inventory")
    groups = archive.groupby(["system","window","source"]).size()
    if not (len(groups) == 20 and (groups == 24).all()):
        raise ValueError("Paper-style group configuration counts are inconsistent")
    growth = pd.to_numeric(archive["growth_per_h"], errors="coerce")
    modulus = pd.to_numeric(archive["eig_abs"], errors="raise")
    mask = growth.notna()
    growth_log_maxerr = float(np.max(np.abs(
        growth.loc[mask].to_numpy() - np.log(modulus.loc[mask].to_numpy())
    ))) if mask.any() else None
    coverage = {
        name: {
            "rows": int(len(group)),
            "growth_rows": int(group["growth_per_h"].notna().sum()),
            "loading_rows": int(group[["load_T", "load_pv"]].notna().all(axis=1).sum()),
        }
        for name, group in archive.groupby("system")
    }
    return {
        "fits": len(archive), "group_count": len(groups),
        "growth_is_log_eigenvalue_modulus_to_max_absolute_error":
            growth_log_maxerr,
        "coverage": coverage,
        "distinct_archive_from_stability_summary": True,
    }


def summarize_candidate_spectra(modes: pd.DataFrame, *, target: float,
        relative_halfwidth: float = .30, selection: str = "nearest_period",
        max_abs_growth: float | None = None,
        min_amplitude: float | None = None) -> pd.DataFrame:
    """Select AT MOST ONE candidate mode per fit, without archive fitting.

    CSV contract: FIT_KEYS, mode_id, period_h, growth_per_h, amplitude.
    Do not assume amplitude normalization identical to historic implementation.
    Returned rows are available for a separate *held-out* archive comparison.
    """
    needed = set(FIT_KEYS) | {"mode_id","period_h","growth_per_h","amplitude"}
    if missing := needed - set(modes.columns):
        raise ValueError(f"Mode catalog missing: {sorted(missing)}")
    if selection not in ("nearest_period","max_amplitude"):
        raise ValueError("Unknown mode selection policy")
    if target <= 0 or not 0 < relative_halfwidth < 1:
        raise ValueError("Invalid target period or acceptance window")
    x = modes.copy()
    for key in ("period_h","growth_per_h","amplitude"):
        x[key] = pd.to_numeric(x[key], errors="coerce")
    valid = x["period_h"].between(
        target*(1-relative_halfwidth), target*(1+relative_halfwidth)
    ) & np.isfinite(x["amplitude"]) & x["amplitude"].ge(0) & \
        np.isfinite(x["growth_per_h"])
    if max_abs_growth is not None:
        if max_abs_growth <= 0:
            raise ValueError("Growth cutoff must be positive")
        valid &= x["growth_per_h"].abs() <= max_abs_growth
    if min_amplitude is not None:
        if min_amplitude < 0:
            raise ValueError("Amplitude cutoff must be nonnegative")
        valid &= x["amplitude"] >= min_amplitude
    x = x.loc[valid].copy()
    x["period_abs_relative_error"] = (x["period_h"]/target-1).abs()
    order = (["period_abs_relative_error","amplitude"]
             if selection == "nearest_period" else
             ["amplitude","period_abs_relative_error"])
    asc = [True,False] if selection == "nearest_period" else [False,True]
    ranked = x.sort_values(order + ["mode_id"], ascending=asc + [True])
    return ranked.drop_duplicates(list(FIT_KEYS)).reset_index(drop=True)


def stability_counts(selected: pd.DataFrame, valid_fits: pd.DataFrame,
                     target_name: str) -> pd.DataFrame:
    """Count accepted per-fit modes; denominators based on *given* valid fits."""
    needed = set(FIT_KEYS)
    for f in (selected, valid_fits):
        if not needed.issubset(f.columns):
            raise ValueError("Missing fit selectors")
    unique = valid_fits[list(FIT_KEYS)].drop_duplicates()
    if len(unique) != len(valid_fits):
        raise ValueError("Repeated rows in valid-fits catalog")
    x = selected.merge(unique, on=list(FIT_KEYS), validate="one_to_one")
    if len(x) != len(selected):
        raise ValueError("Selected mode absent from valid-fits catalog")
    groups = ["system","window","source"]
    totals = unique.groupby(groups).size().rename("nfits_total")
    counts = x.groupby(groups).size().rename("nfits_found")
    out = pd.concat([totals,counts],axis=1).fillna(0).reset_index()
    out["nfits_found"] = out["nfits_found"].astype(int)
    out["stability_fraction"] = out["nfits_found"] / out["nfits_total"]
    out["target"] = target_name
    return out


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("stability_summary",type=Path)
    p.add_argument("paperstyle_crosscheck",type=Path)
    p.add_argument("--output-json",type=Path)
    p.add_argument("--candidate-modes",type=Path,help="PRIVATE per-mode CSV")
    p.add_argument("--target",choices=list(TARGET_PERIODS))
    p.add_argument("--relative-halfwidth",type=float,default=.30)
    p.add_argument("--selection",choices=("nearest_period","max_amplitude"),
                   default="nearest_period")
    p.add_argument("--max-abs-growth",type=float)
    p.add_argument("--min-amplitude",type=float)
    args = p.parse_args()
    stable = pd.read_csv(args.stability_summary)
    paper = pd.read_csv(args.paperstyle_crosscheck)
    report = {
        "stability_constraints": archived_stability_constraints(stable),
        "paperstyle_coverage": paperstyle_coverage(paper),
    }
    if args.candidate_modes is not None:
        if not args.target:
            p.error("--target required with --candidate-modes")
        modes = pd.read_csv(args.candidate_modes)
        candidates = summarize_candidate_spectra(
            modes, target=TARGET_PERIODS[args.target],
            relative_halfwidth=args.relative_halfwidth,
            selection=args.selection,
            max_abs_growth=args.max_abs_growth,
            min_amplitude=args.min_amplitude,
        )
        valid = modes[list(FIT_KEYS)].drop_duplicates()
        counts = stability_counts(candidates, valid, args.target)
        historic = stable.loc[stable.target == args.target]
        comparison = counts.merge(
            historic[[*SUMMARY_KEYS,"nfits_total","nfits_found"]],
            on=list(SUMMARY_KEYS), suffixes=("_candidate","_archived"),
            validate="one_to_one")
        report["candidate_rule"] = {
            "relative_halfwidth":args.relative_halfwidth,
            "selection":args.selection,
            "max_abs_growth":args.max_abs_growth,
            "min_amplitude":args.min_amplitude,
            "compared_groups":int(len(comparison)),
            "count_mae":float(np.mean(np.abs(
                comparison["nfits_found_candidate"]-
                comparison["nfits_found_archived"]))) if len(comparison) else None,
            "reason": (
                "Archive fits and spectrum extraction must be independently "
                "validated before interpreting differences as recovered rules."
            ),
        }
    text = json.dumps(report,indent=2)
    if args.output_json:
        args.output_json.parent.mkdir(parents=True,exist_ok=True)
        args.output_json.write_text(text,encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
