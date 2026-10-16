#!/usr/bin/env python3
"""Reproduce three archived Phase-4 DMDc datasets from authorized local WXF.

Private data are read locally, never bundled. The recovered six-point ridge
grid and chronological 70/30 fit reproduce archive *results*, not the
missing historical code. No hyperparameter is selected against archived
gain/memory tables: only the trailing 30% forecast MSE determines ridge.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from python_tools.dmdc_phase4 import (
    joint_ridge, impulse, impulse_metrics, spectral_memory,
)
from python_tools.meteo_raw_wxf import meteo_samples, centered_hourly_meteo
from python_tools.replay_phase4_multiscale import (
    WINDOWS, SENSORS, buck_saturation_pa, centered_hourly_medians, model_series,
)
from python_tools.wxf_subset import raw_sensor_samples

RIDGE_GRID = (1e-3, 1e-2, 1e-1, 1., 10., 100.)
DELAYS = (6, 12, 24, 48)
INPUT_NAMES = (
    "temp_out", "outdoor_pv_Pa", "solar_radiation",
    "wind_speed", "temp_in", "indoor_pv_Pa",
)
FORCING_SETS = {
    "outpv_only": ("outdoor_pv_Pa",),
    "outpv_T": ("temp_out", "outdoor_pv_Pa"),
    "outpv_T_solar": ("temp_out", "outdoor_pv_Pa", "solar_radiation"),
    "moisture_indoor": ("outdoor_pv_Pa", "indoor_pv_Pa"),
    "full": INPUT_NAMES,
}


def forcing_columns(meteo: pd.DataFrame) -> pd.DataFrame:
    """Use raw meteorological centered medians and the historical Buck pv."""
    for name in ("temp_out", "humidity_out", "temp_in", "humidity_in",
                 "solar_radiation", "wind_speed"):
        if name not in meteo.columns:
            raise ValueError(f"Required forcing column absent: {name}")
    return pd.DataFrame({
        "temp_out": meteo["temp_out"],
        "outdoor_pv_Pa": buck_saturation_pa(meteo["temp_out"]) *
                         meteo["humidity_out"] / 100.,
        "solar_radiation": meteo["solar_radiation"],
        "wind_speed": meteo["wind_speed"],
        "temp_in": meteo["temp_in"],
        "indoor_pv_Pa": buck_saturation_pa(meteo["temp_in"]) *
                        meteo["humidity_in"] / 100.,
    }, index=meteo.index)


def normalize_states(experiment: np.ndarray, model: np.ndarray
                     ) -> tuple[np.ndarray, np.ndarray]:
    """Center separately; divide both by experimental population SD."""
    experiment = np.asarray(experiment, dtype=float)
    model = np.asarray(model, dtype=float)
    if experiment.ndim != 2 or experiment.shape != model.shape or \
       not np.isfinite(experiment).all() or not np.isfinite(model).all():
        raise ValueError("Need two finite, equally shaped state matrices")
    sigma = np.std(experiment, axis=0)
    if (sigma <= 0).any():
        raise ValueError("Zero-variance experimental state")
    return (experiment - experiment.mean(axis=0)) / sigma, \
           (model - model.mean(axis=0)) / sigma


def normalize_forcing(values: np.ndarray) -> np.ndarray:
    values = np.asarray(values, dtype=float)
    if values.ndim != 2 or not np.isfinite(values).all():
        raise ValueError("Forcing must be complete finite [time, channels]")
    sigma = np.std(values, axis=0)
    if (sigma <= 0).any():
        raise ValueError("Forcing contains a constant channel")
    return (values - values.mean(axis=0)) / sigma


def summarize_impulses(
    system: str, window: str, delay: int, source: str,
    a: np.ndarray, b: np.ndarray, names: tuple[str, ...],
) -> list[dict]:
    """One row for each forcing/output pair, using one-based response time."""
    if b.shape[1] != len(names):
        raise ValueError("B channel count does not match declared names")
    suffix = system[4:] if system.startswith("HEMP") else system[3:]
    outputs = (f"T{suffix}", f"pv{suffix}")
    rows = []
    for index, name in enumerate(names):
        response = impulse(a, b, delay, source=index, horizon=72)
        for output_idx, output in enumerate(outputs):
            signal = response[:, output_idx]
            summary = impulse_metrics(response, output=output_idx)
            rows.append({
                "system": system, "window": window, "source": source,
                "delay_h": delay, "output": output, "input": name,
                "peak_abs_gain_std": summary["peak_abs_gain_std"],
                "peak_lag_h": int(summary["peak_lag_h"]),
                "integrated_abs_gain_72h": summary["integrated_abs_gain"],
                "signed_sum_72h": float(np.sum(signal)),
                **{f"gain_{hour}h": float(signal[hour - 1])
                   for hour in (1, 6, 24, 48, 72)},
            })
    return rows


def replay(manifest: dict, meteo_wxf: Path
           ) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Return (90 forcing-ratio, 40 memory, 960 impulse) result tables."""
    if set(manifest) != set(SENSORS):
        raise ValueError("Manifest must select the exact five Phase-4 sensors")
    raw_meteo = meteo_samples(meteo_wxf)
    ratios, memory, impulses = [], [], []
    for system in SENSORS:
        spec = manifest[system]
        observed = raw_sensor_samples(spec["sensor_wxf"])
        t = model_series(spec["model_temperature_wxf"])
        rh = model_series(spec["model_humidity_wxf"])
        if not t.index.equals(rh.index):
            raise ValueError(f"{system}: model UTC grids do not agree")
        sensor_hourly = centered_hourly_medians(observed, t.index)
        state_s = pd.DataFrame({
            "T": sensor_hourly["T"],
            "pv": buck_saturation_pa(sensor_hourly["T"]) *
                  sensor_hourly["RH"] / 100.,
        })
        state_m = pd.DataFrame({
            "T": t, "pv": buck_saturation_pa(t) * rh / 100.,
        })
        for window, start, end in WINDOWS:
            grid = pd.date_range(start, end, freq="h")
            exp = state_s.reindex(grid).to_numpy(float)
            model = state_m.reindex(grid).to_numpy(float)
            exp, model = normalize_states(exp, model)
            meteorology = centered_hourly_meteo(raw_meteo, grid)
            forcing_all = forcing_columns(meteorology)
            for forcing_set, names in FORCING_SETS.items():
                u = normalize_forcing(forcing_all[list(names)].to_numpy(float))
                for delay in DELAYS:
                    if delay == 6 and forcing_set != "full":
                        continue
                    chosen = joint_ridge(exp, model, u, p=delay,
                                         grid=RIDGE_GRID, train_fraction=.7)
                    ae, be = chosen["experiment"]
                    aw, bw = chosen["model"]
                    if forcing_set == "full":
                        impulses.extend(summarize_impulses(
                            system, window, delay, "exp", ae, be, names))
                        impulses.extend(summarize_impulses(
                            system, window, delay, "wufi", aw, bw, names))
                        em = spectral_memory(ae, delay)
                        wm = spectral_memory(aw, delay)
                        memory.append({
                            "system": system, "window": window,
                            "delay_h": delay, "selected_ridge": chosen["ridge"],
                            "spectral_radius_exp": em["spectral_radius"],
                            "spectral_radius_wufi": wm["spectral_radius"],
                            "dominant_decay_time_h_exp": em["dominant_decay_time_h"],
                            "dominant_decay_time_h_wufi": wm["dominant_decay_time_h"],
                            "tau_wufi_over_exp":
                                wm["dominant_decay_time_h"] /
                                em["dominant_decay_time_h"],
                        })
                    if delay in (12, 24, 48) and system in \
                            ("HEMP27", "HEMP19", "REF118"):
                        channel = names.index("outdoor_pv_Pa")
                        exp_response = impulse(ae, be, delay, source=channel)
                        model_response = impulse(aw, bw, delay, source=channel)
                        eg = impulse_metrics(exp_response, output=1)
                        mg = impulse_metrics(model_response, output=1)
                        ratios.append({
                            "system": system, "window": window,
                            "delay_h": delay, "input_set": forcing_set,
                            "selected_ridge": chosen["ridge"],
                            "peak_abs_gain_exp": eg["peak_abs_gain_std"],
                            "peak_abs_gain_wufi": mg["peak_abs_gain_std"],
                            "int_abs_72h_exp": eg["integrated_abs_gain"],
                            "int_abs_72h_wufi": mg["integrated_abs_gain"],
                            "peak_lag_h_exp": int(eg["peak_lag_h"]),
                            "peak_lag_h_wufi": int(mg["peak_lag_h"]),
                            "peak_gain_exp_over_wufi":
                                eg["peak_abs_gain_std"] / mg["peak_abs_gain_std"],
                            "int_gain_exp_over_wufi":
                                eg["integrated_abs_gain"] /
                                mg["integrated_abs_gain"],
                        })
    results = tuple(map(pd.DataFrame, (ratios, memory, impulses)))
    if tuple(len(x) for x in results) != (90, 40, 960):
        raise ValueError("Unexpected archive replay inventory")
    return results


def compare(reference: pd.DataFrame, reproduced: pd.DataFrame, keys: tuple[str, ...],
            columns: tuple[str, ...]) -> dict:
    """Return independent per-column drift metrics without hardcoded tolerance."""
    merged = reproduced.merge(reference, on=list(keys),
                              suffixes=("_new", "_archive"), validate="one_to_one")
    if len(merged) != len(reproduced) or len(merged) != len(reference):
        raise ValueError("Replay and archive have different key inventories")
    maxima = {}
    for name in columns:
        a = merged[f"{name}_new"].to_numpy(float)
        b = merged[f"{name}_archive"].to_numpy(float)
        if not np.isfinite(a).all() or not np.isfinite(b).all():
            raise ValueError(f"Invalid nonfinite archive values in {name}")
        maxima[name] = float(np.max(np.abs(a - b)))
    return {"rows": len(merged), "max_absolute_difference": maxima}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("private_manifest", type=Path)
    p.add_argument("private_meteorology_wxf", type=Path)
    p.add_argument("archived_gain_ratios_csv", type=Path)
    p.add_argument("archived_memory_csv", type=Path)
    p.add_argument("archived_impulses_csv", type=Path)
    p.add_argument("--output-dir", type=Path, required=True)
    args = p.parse_args()
    private = json.loads(args.private_manifest.read_text(encoding="utf-8"))
    tables = replay(private, args.private_meteorology_wxf)
    tables_archive = [
        pd.read_csv(args.archived_gain_ratios_csv),
        pd.read_csv(args.archived_memory_csv),
        pd.read_csv(args.archived_impulses_csv),
    ]
    keys = [
        ("system", "window", "delay_h", "input_set"),
        ("system", "window", "delay_h"),
        ("system", "window", "source", "delay_h", "output", "input"),
    ]
    columns = [
        ("peak_abs_gain_exp", "peak_abs_gain_wufi", "int_abs_72h_exp",
         "int_abs_72h_wufi", "peak_lag_h_exp", "peak_lag_h_wufi",
         "peak_gain_exp_over_wufi", "int_gain_exp_over_wufi"),
        ("spectral_radius_exp", "spectral_radius_wufi",
         "dominant_decay_time_h_exp", "dominant_decay_time_h_wufi",
         "tau_wufi_over_exp"),
        ("peak_abs_gain_std", "peak_lag_h", "integrated_abs_gain_72h",
         "signed_sum_72h", "gain_1h", "gain_6h", "gain_24h", "gain_48h",
         "gain_72h"),
    ]
    names = ("inputset_ratios", "state_memory", "impulse_responses")
    report = {
        key: compare(previous, now, indices, fields)
        for key, previous, now, indices, fields in zip(
            names, tables_archive, tables, keys, columns)
    }
    report["ridge_grid"] = list(RIDGE_GRID)
    report["policy"] = (
        "chronological 70/30, joint unweighted experimental/WUFI "
        "validation MSE; retain training coefficients"
    )
    report["provenance"] = (
        "Numerically inferred from original REF/HEMP results; "
        "the historical source script has not been recovered."
    )
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name, table in zip(names, tables):
        table.to_csv(args.output_dir / f"{name}_private_replay.csv", index=False)
    (args.output_dir / "dmdc_numerical_parity.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
