#!/usr/bin/env python3
"""Compare two-channel REF/HEMP original HODMD archive with PRIVATE mode spectra.

This is a forensic comparison, not proof of original algorithm identity.
The multiplicative factor-1.3 period gate is a *candidate inferred from
held archive*, and not confirmed as the original rule. Input files stay local.

Requires mode catalog from hodmd_mode_catalog.py (full real delay-DMD)
and its separate fit-status inventory. Never publish private catalogs.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from python_tools.hodmd_rule_recovery import TARGET_PERIODS

FIT_KEYS = ("system", "window", "source", "delay_h", "rank")
GROUP_KEYS = ("system", "window", "source")
ARCHIVE_KEYS = (*GROUP_KEYS, "target")
WINDOW_LENGTHS = {"W1": 1388, "W2": 1393}
TWO_CHANNEL_SYSTEMS = frozenset(("HEMP19", "HEMP27", "REF118"))


def _candidate_modes(modes: pd.DataFrame, target_period_h: float,
                     period_factor: float = 1.3,
                     rule: str = "multiplicative") -> pd.DataFrame:
    """At most one nearest-log-period eigenmode per valid delay/rank fit."""
    if period_factor <= 1:
        raise ValueError("Period factor must exceed 1")
    if rule not in ("multiplicative", "additive_25pct"):
        raise ValueError("Invalid candidate period rule")
    if rule == "multiplicative":
        low, high = target_period_h/period_factor, target_period_h*period_factor
    else:
        low, high = target_period_h*.75, target_period_h*1.25
    x = modes.loc[modes["period_h"].between(low,high)].copy()
    x["log_period_error"] = np.abs(np.log(x["period_h"]/target_period_h))
    return (x.sort_values(
        ["log_period_error", "amplitude", "mode_id"],
        ascending=[True,False,True])
        .drop_duplicates(list(FIT_KEYS)).reset_index(drop=True))


def reproduce(modes: pd.DataFrame, fit_status: pd.DataFrame,
              archive: pd.DataFrame, *,
              rule: str = "multiplicative", factor: float = 1.3
              ) -> pd.DataFrame:
    """Return one independent comparison record for 84 two-channel groups.

    Sample-SD scaling is applied to the *mode amplitudes and loadings*,
    leaving eigenvalues and growth unchanged. It was inferred by comparing
    original archived amplitude ratios with population-SD mode outputs.
    """
    fields = set(FIT_KEYS) | {"mode_id", "period_h", "growth_per_h", "amplitude",
                              "loading_0", "loading_1"}
    if not fields.issubset(modes):
        raise ValueError(f"Missing full-mode columns: {sorted(fields-set(modes))}")
    if not (set(FIT_KEYS)|{"fit_status"}).issubset(fit_status):
        raise ValueError("Fit-status inventory missing expected fields")
    required = set(ARCHIVE_KEYS) | {
        "target_h", "nfits_total", "nfits_found", "period_median_h",
        "period_q10_h", "period_q90_h", "growth_median_per_h",
        "amp_median", "loading_0_median", "loading_1_median"}
    if not required.issubset(archive):
        raise ValueError(f"Archived summary fields missing: {sorted(required-set(archive))}")
    if modes.duplicated([*FIT_KEYS,"mode_id"]).any():
        raise ValueError("Mode catalog duplicates a fit/mode selector")
    if fit_status.duplicated(list(FIT_KEYS)).any():
        raise ValueError("Fit-status inventory duplicates fit selectors")
    if archive.duplicated(list(ARCHIVE_KEYS)).any():
        raise ValueError("Archive duplicate comparison groups")
    source = archive.loc[archive["system"].isin(TWO_CHANNEL_SYSTEMS)].copy()
    if len(source) != 84 or set(source.target) != set(TARGET_PERIODS):
        raise ValueError("Expected exactly 84 archived two-channel target groups")
    valid = fit_status.loc[fit_status.fit_status.eq("valid_fit")]
    counts = valid.groupby(list(GROUP_KEYS)).size().to_dict()
    if len(counts) != 12 or not all(value==39 for value in counts.values()):
        raise ValueError("Expected 39 valid fits in each two-channel group")
    if not modes.set_index(list(FIT_KEYS)).index.isin(
            valid.set_index(list(FIT_KEYS)).index).all():
        raise ValueError("Candidate mode catalog contains nonvalid fits")
    result=[]
    for _,row in source.iterrows():
        p=float(row.target_h)
        subset = modes.loc[
            (modes.system==row.system)&(modes.window==row.window)&
            (modes.source==row.source)]
        selected=_candidate_modes(subset,p,factor,rule)
        n=int(len(selected))
        window_n=WINDOW_LENGTHS[row.window]
        # Historical amplitude SD convention is inferred to be ddof=1.
        norm_factor=np.sqrt((window_n-1)/window_n)
        med = lambda name: float(selected[name].median()) if n else float("nan")
        q = lambda prob: float(selected["period_h"].quantile(prob)) if n else float("nan")
        result.append({
            **{key:row[key] for key in ARCHIVE_KEYS},
            "archived_nfits_found":int(row.nfits_found),
            "replayed_nfits_found":n,
            "count_error":n-int(row.nfits_found),
            "archived_period_median_h":float(row.period_median_h),
            "replayed_period_median_h":med("period_h"),
            "archived_period_q10_h":float(row.period_q10_h),
            "replayed_period_q10_h":q(.1),
            "archived_period_q90_h":float(row.period_q90_h),
            "replayed_period_q90_h":q(.9),
            "archived_growth_median_per_h":float(row.growth_median_per_h),
            "replayed_growth_median_per_h":med("growth_per_h"),
            "archived_amp_median":float(row.amp_median),
            "replayed_amp_median":med("amplitude")*norm_factor,
            "archived_loading_0_median":float(row.loading_0_median),
            "replayed_loading_0_median":med("loading_0")*norm_factor,
            "archived_loading_1_median":float(row.loading_1_median),
            "replayed_loading_1_median":med("loading_1")*norm_factor,
        })
    return pd.DataFrame(result)


def score(comparisons: pd.DataFrame, *, period_atol_h: float = 1e-7,
          spectral_atol: float = 1e-8) -> dict:
    n=len(comparisons)
    result={"rows":n,"exact_fit_count_rows":int((comparisons.count_error==0).sum()),
            "accepted_fit_count_mae":float(comparisons.count_error.abs().mean()),
            "accepted_fit_count_max_abs_error":int(comparisons.count_error.abs().max())}
    checks=(
        ("period_median_h",period_atol_h),
        ("period_q10_h",period_atol_h),
        ("period_q90_h",period_atol_h),
        ("growth_median_per_h",spectral_atol),
        ("amp_median",spectral_atol),
        ("loading_0_median",spectral_atol),
        ("loading_1_median",spectral_atol),
    )
    for name,tol in checks:
        diff=(comparisons["replayed_"+name]-comparisons["archived_"+name]).abs()
        result["matches_"+name] = int((diff<tol).sum())
        result["median_abs_difference_"+name] = float(diff.median())
    result["by_target_exact_counts"]={
        str(target):int((rows.count_error==0).sum())
        for target,rows in comparisons.groupby("target")
    }
    result["historical_equivalence"] = False
    result["notes"] = (
        "Candidate mode gate inferred retrospectively from the same archive. "
        "Reproducing selected spectral statistics is strong operator evidence, "
        "but selection policy and six-channel primary state remain unresolved.")
    return result


def main() -> None:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("private_modes",type=Path)
    p.add_argument("private_fit_status",type=Path)
    p.add_argument("archived_stability",type=Path)
    p.add_argument("--output-dir",type=Path,required=True)
    args=p.parse_args()
    modes=pd.read_csv(args.private_modes)
    fits=pd.read_csv(args.private_fit_status)
    archive=pd.read_csv(args.archived_stability)
    tables={
        "multiplicative_factor_1_3":reproduce(modes,fits,archive),
        "additive_25pct_baseline":reproduce(
            modes,fits,archive,rule="additive_25pct"),
    }
    args.output_dir.mkdir(parents=True,exist_ok=True)
    report={}
    for name,table in tables.items():
        table.to_csv(args.output_dir/(name+"_PRIVATE.csv"),index=False)
        report[name]=score(table)
    (args.output_dir/"hodmd_rule_replay_summary_PRIVATE.json").write_text(
        json.dumps(report,indent=2),encoding="utf-8")
    print(json.dumps(report,indent=2))


if __name__=="__main__":
    main()
