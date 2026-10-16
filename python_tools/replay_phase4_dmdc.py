#!/usr/bin/env python3
"""Reference replay of Phase-4 outdoor-vapour-pressure-only DMDc from private WXF.

The archived source script/ridge grid is unavailable; this is a *diagnostic
historical replay*, not guaranteed numerical equivalence. It uses a documented
common ridge selection on the first 70% of each continuous period, and
separately centered sensor/WUFI states on the experimental SD scale.
All private per-hour data stay local.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from python_tools.dmdc_phase4 import joint_ridge, impulse, impulse_metrics
from python_tools.meteo_raw_wxf import meteo_samples, centered_hourly_meteo
from python_tools.replay_phase4_multiscale import (
    buck_saturation_pa, centered_hourly_medians, model_series,
    WINDOWS,
)
from python_tools.wxf_subset import raw_sensor_samples

TARGETS = ("HEMP27", "HEMP19", "REF118")
LAGS = (12, 24, 48)
RIDGE_GRID = (0., 1e-8, 1e-6, 1e-4, 1e-2, 1., 100.)


def normalize_states(experiment: np.ndarray, model: np.ndarray
                     ) -> tuple[np.ndarray, np.ndarray]:
    """Each series is centered independently; common experimental SD scale."""
    experiment, model = np.asarray(experiment, float), np.asarray(model, float)
    if (experiment.shape != model.shape or experiment.ndim != 2 or
            not np.isfinite(experiment).all() or not np.isfinite(model).all()):
        raise ValueError("Expected finite, equally shaped experiment/WUFI arrays")
    sig = np.std(experiment, axis=0, ddof=0)
    if (sig <= 0).any():
        raise ValueError("Experimental state SD must be positive")
    return ((experiment-experiment.mean(axis=0))/sig,
            (model-model.mean(axis=0))/sig)


def normalized_forcing(pv_out: np.ndarray) -> np.ndarray:
    """Center and standardize exterior vapour pressure within each window."""
    values = np.asarray(pv_out, dtype=float)
    if values.ndim != 1 or not np.isfinite(values).all():
        raise ValueError("Outdoor vapour forcing must be a finite hourly vector")
    sd = np.std(values, ddof=0)
    if sd <= 0:
        raise ValueError("Outdoor vapour pressure must vary")
    return ((values - np.mean(values)) / sd)[:, None]


def replay_lowcollinearity(
    private_manifest: dict, meteorological_wxf: str | Path,
    archived_gain_csv: str | Path, ridge_grid: tuple[float, ...] = RIDGE_GRID,
) -> pd.DataFrame:
    """Compare independent source-raw Phase-4 refits with archived DMDc rows.

    Even exact agreement in a subset is not proof of identical original
    preprocessing/validation/ridge policy.
    """
    if set(private_manifest) != set(TARGETS):
        raise ValueError(f"Expected exactly {TARGETS} private sensor mappings")
    hist = pd.read_csv(archived_gain_csv)
    required = {"system", "window", "delay_h", "input_set",
                "peak_abs_gain_exp", "peak_abs_gain_wufi",
                "peak_lag_h_exp", "peak_lag_h_wufi",
                "peak_gain_exp_over_wufi"}
    if not required.issubset(hist.columns):
        raise ValueError("Archived gain table has missing columns")
    subset = hist[hist["input_set"] == "outpv_only"]
    if len(subset) != len(TARGETS) * len(WINDOWS) * len(LAGS):
        raise ValueError("Archive outpv_only row count unexpectedly changed")
    raw_weather = meteo_samples(meteorological_wxf)
    outputs = []
    for target in TARGETS:
        spec = private_manifest[target]
        s = raw_sensor_samples(spec["sensor_wxf"])
        t_model = model_series(spec["model_temperature_wxf"])
        rh_model = model_series(spec["model_humidity_wxf"])
        if not t_model.index.equals(rh_model.index):
            raise ValueError(f"{target}: model UTC grids disagree")
        obs = centered_hourly_medians(s, t_model.index)
        ref_pv = buck_saturation_pa(obs["T"]) * obs["RH"] / 100
        model_pv = buck_saturation_pa(t_model) * rh_model / 100
        for label, start, finish in WINDOWS:
            utc_hours = pd.date_range(start, finish, freq="h")
            exp_x = np.column_stack([obs["T"].reindex(utc_hours),
                                     ref_pv.reindex(utc_hours)])
            wufi_x = np.column_stack([t_model.reindex(utc_hours),
                                      model_pv.reindex(utc_hours)])
            exp_x, wufi_x = normalize_states(exp_x, wufi_x)
            weather = centered_hourly_meteo(raw_weather, utc_hours)
            outdoor_pv = buck_saturation_pa(weather["temp_out"]) * \
                weather["humidity_out"] / 100.
            forcing = normalized_forcing(outdoor_pv.to_numpy())
            for delay in LAGS:
                selection = joint_ridge(
                    exp_x, wufi_x, forcing, p=delay, grid=ridge_grid,
                    train_fraction=0.7)
                ae, be = selection["experiment"]
                am, bm = selection["model"]
                ex = impulse_metrics(impulse(ae, be, delay, horizon=72), output=1)
                mo = impulse_metrics(impulse(am, bm, delay, horizon=72), output=1)
                archive = subset.loc[
                    (subset["system"] == target) &
                    (subset["window"] == label) &
                    (subset["delay_h"] == delay)]
                if len(archive) != 1:
                    raise ValueError(f"Expected one archive row: {target}/{label}/{delay}")
                previous = archive.iloc[0]
                computed = ex["peak_abs_gain_std"]/mo["peak_abs_gain_std"]
                outputs.append({
                    "system": target, "window": label, "delay_h": delay,
                    "ridge_selected": selection["ridge"],
                    "estimated_peak_gain_ratio": computed,
                    "archive_peak_gain_ratio": float(previous["peak_gain_exp_over_wufi"]),
                    "peak_gain_ratio_difference": computed -
                        float(previous["peak_gain_exp_over_wufi"]),
                    "estimated_exp_lag_h": ex["peak_lag_h"],
                    "archived_exp_lag_h": float(previous["peak_lag_h_exp"]),
                    "estimated_wufi_lag_h": mo["peak_lag_h"],
                    "archived_wufi_lag_h": float(previous["peak_lag_h_wufi"]),
                    "estimated_gain_experiment": ex["peak_abs_gain_std"],
                    "estimated_gain_wufi": mo["peak_abs_gain_std"],
                })
    return pd.DataFrame(outputs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("private_manifest_json", type=Path)
    parser.add_argument("private_meteo_wxf", type=Path)
    parser.add_argument("archived_dmdc_gain_csv", type=Path)
    parser.add_argument("--output-csv", type=Path, required=True)
    args = parser.parse_args()
    inputs = json.loads(args.private_manifest_json.read_text(encoding="utf-8"))
    result = replay_lowcollinearity(
        inputs, args.private_meteo_wxf, args.archived_dmdc_gain_csv)
    args.output_csv.parent.mkdir(parents=True, exist_ok=True)
    result.to_csv(args.output_csv, index=False)
    print(result.to_string(index=False))
    print("RESEARCH REFERENCE ONLY: selected ridge grid/score is not proven "
          "historically identical; do not treat differences as regression failures.")


if __name__ == "__main__":
    main()
