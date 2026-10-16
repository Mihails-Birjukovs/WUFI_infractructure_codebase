#!/usr/bin/env python3
"""Independent paper-style HODMD sensitivity scan against saved cross-check CSV.

Uses analytic-signal preprocessing (Hilbert transform), delay embedding,
forward/backward reduced DMD operators and their arithmetic mean. It is a
NEW implementation of the documented method *class*, not the lost original
Phase-4 code. Mode selection is explicitly nearest positive 24-hour period.
This choice does NOT reproduce the archived stability-scoring logic.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.linalg import svd
from scipy.signal import hilbert

from python_tools.replay_phase4_multiscale import (
    WINDOWS, SENSORS, buck_saturation_pa, centered_hourly_medians, model_series,
)
from python_tools.wxf_subset import raw_sensor_samples

SCAN_DELAYS = (24, 36, 48, 72)
SCAN_RANKS = (6, 8, 10, 12, 16, 20)
DEFAULT_EDGE_TRIM_H = 24


def analytic_delay_operators(
    normalized_snapshots: np.ndarray, delay: int, rank: int,
    trim_h: int = DEFAULT_EDGE_TRIM_H,
) -> tuple[np.ndarray, np.ndarray]:
    """Reduced forward/backward operators, projected onto separate SVD bases.

    Both snapshot channels are assumed uniformly sampled and previously
    centered/scaled. Edge trimming occurs *before* the Hilbert transform.
    """
    x = np.asarray(normalized_snapshots, dtype=float)
    if x.ndim != 2 or not np.isfinite(x).all():
        raise ValueError("Expected complete finite [features, times] snapshots")
    if not isinstance(trim_h, int) or trim_h < 0 or \
       not isinstance(delay, int) or delay < 2 or \
       not isinstance(rank, int) or rank < 1:
        raise ValueError("Invalid HODMD parameters")
    if x.shape[1] - 2*trim_h < max(3*delay, 5*rank):
        raise ValueError("Too few samples after HODMD edge trim")
    if trim_h:
        x = x[:, trim_h:-trim_h]
    a = hilbert(x, axis=1)
    embedding = np.concatenate(
        [a[:, j:a.shape[1]-delay+j+1] for j in range(delay)], axis=0,
    )
    forward, next_step = embedding[:, :-1], embedding[:, 1:]
    u, singular, vh = svd(forward, full_matrices=False)
    ub, sb, vhb = svd(next_step, full_matrices=False)
    max_rank = min(len(singular), len(sb))
    if rank > max_rank or singular[rank-1] <= 0 or sb[rank-1] <= 0:
        raise ValueError("Rank exceeds usable embedding dimension")
    f = (u[:, :rank].conj().T @ next_step @ vh[:rank].conj().T) / \
        singular[:rank, None]
    b = (ub[:, :rank].conj().T @ forward @ vhb[:rank].conj().T) / \
        sb[:rank, None]
    return f, b


def nearest_daily_mode(
    normalized_snapshots: np.ndarray, delay: int, rank: int,
    trim_h: int = DEFAULT_EDGE_TRIM_H, target_period_h: float = 24.,
) -> dict:
    """Find closest positive-frequency mode to 24 h (NOT archival acceptance)."""
    if target_period_h <= 0:
        raise ValueError("Target oscillation period must be positive")
    f, b = analytic_delay_operators(normalized_snapshots, delay, rank, trim_h)
    # This is the paper-style *averaging alternative*; its eigenvalues
    # are not identical to the matrix geometric-mean fbDMD variant.
    eigenvalues = np.linalg.eigvals((f + np.linalg.pinv(b)) / 2)
    choices = [
        (abs(2*np.pi/np.angle(e)-target_period_h),
         float(2*np.pi/np.angle(e)), float(abs(e)), e)
        for e in eigenvalues if np.angle(e) > 0
    ]
    if not choices:
        raise ValueError("No positive-frequency modes")
    _, period, magnitude, eigenvalue = min(choices, key=lambda z: z[0])
    return {
        "period24_h": period,
        "eig_abs": magnitude,
        "growth_per_h": float(np.log(magnitude)),
        "mode_selection": "nearest positive-frequency period to 24h",
        "algorithm": "analytic Hilbert + forward/backward reduced-operator mean",
    }


def replay(manifest: dict, trim_h: int = DEFAULT_EDGE_TRIM_H) -> pd.DataFrame:
    """Generate the 480 24-hour candidate fits for authorized private WXFs."""
    if set(manifest) != set(SENSORS):
        raise ValueError("Manifest must contain the five archived sensors")
    results = []
    for system in SENSORS:
        spec = manifest[system]
        s = raw_sensor_samples(spec["sensor_wxf"])
        tm = model_series(spec["model_temperature_wxf"])
        hm = model_series(spec["model_humidity_wxf"])
        if not tm.index.equals(hm.index):
            raise ValueError("WUFI model grids disagree")
        measured = centered_hourly_medians(s, tm.index)
        obs_state = pd.DataFrame({
            "T": measured["T"],
            "pv": buck_saturation_pa(measured["T"]) * measured["RH"] / 100,
        })
        mod_state = pd.DataFrame({
            "T": tm, "pv": buck_saturation_pa(tm) * hm / 100,
        })
        for window, start, end in WINDOWS:
            grid = pd.date_range(start, end, freq="h")
            exp = obs_state.reindex(grid).to_numpy(float).T
            wufi = mod_state.reindex(grid).to_numpy(float).T
            if not np.isfinite(exp).all() or not np.isfinite(wufi).all():
                raise ValueError(f"{system} {window} contains missing state")
            scale = exp.std(axis=1)
            if not np.all(scale > 0):
                raise ValueError("Experimental state variance must be positive")
            for source, state in (("exp", exp), ("wufi", wufi)):
                normalized = (state-state.mean(axis=1, keepdims=True))/scale[:, None]
                for delay in SCAN_DELAYS:
                    for rank in SCAN_RANKS:
                        mode = nearest_daily_mode(normalized, delay, rank, trim_h)
                        results.append({
                            "system": system, "window": window, "source": source,
                            "delay_h": delay, "rank": rank,
                            "period24_h": mode["period24_h"],
                            "eig_abs": mode["eig_abs"],
                            "growth_per_h": mode["growth_per_h"],
                        })
    frame = pd.DataFrame(results)
    if len(frame) != 480:
        raise ValueError("Unexpected reference cross-check fit inventory")
    return frame


def compare_paperstyle(reproduced: pd.DataFrame, archived: pd.DataFrame) -> dict:
    """Report discrepancies; DO NOT make equivalence/acceptance claims."""
    keys = ["system", "window", "source", "delay_h", "rank"]
    joint = reproduced.merge(archived, on=keys, suffixes=("_new", "_archive"),
                             validate="one_to_one")
    if len(joint) != len(reproduced) or len(joint) != len(archived):
        raise ValueError("Paper-style comparison inventory mismatched")
    differences = np.abs(
        joint["period24_h_new"].to_numpy() -
        joint["period24_h_archive"].to_numpy())
    mod_errors = np.abs(joint["eig_abs_new"]-joint["eig_abs_archive"]).to_numpy()
    return {
        "rows": len(joint),
        "median_abs_period_error_h": float(np.median(differences)),
        "p90_abs_period_error_h": float(np.percentile(differences, 90)),
        "period_count_within_0_1_h": int(np.count_nonzero(differences < 0.1)),
        "period_count_within_1_h": int(np.count_nonzero(differences < 1)),
        "median_abs_eigenvalue_modulus_error": float(np.median(mod_errors)),
        "historical_equivalence": False,
        "reason": "Original forward/backward implementation, edge/mode acceptance, and rank stability scoring are not recovered",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("private_manifest_json", type=Path)
    parser.add_argument("archived_paperstyle_csv", type=Path)
    parser.add_argument("--trim-hours", type=int, default=DEFAULT_EDGE_TRIM_H)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    inputs = json.loads(args.private_manifest_json.read_text(encoding="utf-8"))
    generated = replay(inputs, args.trim_hours)
    report = compare_paperstyle(generated, pd.read_csv(args.archived_paperstyle_csv))
    report["edge_trim_hours"] = args.trim_hours
    args.output_dir.mkdir(parents=True, exist_ok=True)
    generated.to_csv(args.output_dir/"hodmd_independent_private_scan.csv", index=False)
    (args.output_dir/"hodmd_method_comparison.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
