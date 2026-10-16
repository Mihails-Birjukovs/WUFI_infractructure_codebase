#!/usr/bin/env python3
"""Recompute archived REF/HEMP Phase-4 Butterworth metrics from private WXF data.

NO raw measurements, WUFI outputs or derived hourly series are published.
Requires an explicit local manifest of the five original sensor WXFs and
corresponding comparison-group T/RH WXF archives.

Unlike the Appendix-I centered-window demonstration, this reproduces the
archived *fourth-order Butterworth* method and original Buck vapour pressure.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.signal import butter, sosfiltfilt

from python_tools.wxf_subset import (
    association, centered_raw_median, list_args, load_wxf, raw_sensor_samples,
    utc_date_object,
)

ANALYSIS_START = "2025-11-27 16:00"
ANALYSIS_END = "2026-04-08 09:00"
WINDOWS = (
    ("W1", "2025-12-12 12:00", "2026-02-08 07:00"),
    ("W2", "2026-02-09 09:00", "2026-04-08 09:00"),
)
SENSORS = ("HEMP27", "HEMP19", "HEMP42", "HEMP18", "REF118")
BANDS = ("slow", "diurnal_synoptic", "event")


def buck_saturation_pa(temperature_c):
    """Buck saturation vapour pressure (Pa) recovered from archived metrics."""
    t = np.asarray(temperature_c, dtype=float)
    return 611.21 * np.exp((18.678 - t / 234.5) * (t / (257.14 + t)))


def centered_hourly_medians(raw: pd.DataFrame, utc_hours: pd.DatetimeIndex) -> pd.DataFrame:
    """Raw ±30-minute medians, WITHOUT additional Production-v1.2 QC policy."""
    if not raw.index.is_monotonic_increasing or raw.index.tz is not None:
        raise ValueError("Expected sorted UTC-naive raw measurements")
    times = raw.index.values.astype("datetime64[ns]").view("i8")
    centers = utc_hours.asi8
    radius = 30 * 60 * 1_000_000_000
    left = np.searchsorted(times, centers-radius, side="left")
    right = np.searchsorted(times, centers+radius, side="right")
    result = {}
    for name in ("T", "RH"):
        a = raw[name].to_numpy(dtype=float)
        result[name] = np.asarray(
            [np.median(a[l:r]) if r > l else np.nan for l, r in zip(left, right)],
            dtype=float,
        )
    return pd.DataFrame(result, index=utc_hours)


def model_series(comparison_wxf: Path) -> pd.Series:
    """Read *all* matched-depth WUFI hours, including filtered-out paired hours."""
    record = association(load_wxf(comparison_wxf))
    timestamps = [utc_date_object(x) for x in list_args(record["WUFITargetDatesUTC"])]
    values = np.asarray(list_args(record["WUFIValuesAtSensorDepth"]), dtype=float)
    series = pd.Series(values, index=pd.DatetimeIndex(timestamps), dtype=float)
    if len(series) != len(values) or series.index.has_duplicates:
        raise ValueError("Malformed or duplicate WUFI target timestamps")
    return series.sort_index()


def _band_values(values: np.ndarray, slow_hours: int = 72,
                 event_hours: int = 12, trim_hours: int = 72) -> dict:
    if len(values) < 240 or not (3 <= event_hours < slow_hours):
        raise ValueError("Require 240+ continuous hourly values and ordered cutoffs")
    slow = sosfiltfilt(
        butter(4, 1/slow_hours, btype="low", fs=1, output="sos"), values)
    short = sosfiltfilt(
        butter(4, 1/event_hours, btype="low", fs=1, output="sos"), values)
    core = slice(trim_hours, -trim_hours)
    return {
        "slow": slow[core],
        "diurnal_synoptic": (short-slow)[core],
        "event": (values-short)[core],
    }


def metrics(sensor: np.ndarray, model: np.ndarray) -> dict:
    """The historical archive uses population SD (ddof=0), not ddof=1."""
    a, b = np.asarray(sensor, float), np.asarray(model, float)
    if len(a) != len(b) or len(a) < 3:
        raise ValueError("Insufficient aligned data")
    error = b-a
    sa, sb = np.std(a), np.std(b)
    return {
        "n": len(a), "bias": float(np.mean(error)),
        "rmse": float(np.sqrt(np.mean(error**2))),
        "mae": float(np.mean(np.abs(error))),
        "sensor_sd": float(sa), "wufi_sd": float(sb),
        "amplitude_ratio": float(sb/sa) if sa > 0 else float("nan"),
        "corr": float(np.corrcoef(a,b)[0,1]) if sa > 0 and sb > 0 else float("nan"),
    }


def _windows(series: pd.Series, window: tuple[str, str, str]) -> np.ndarray:
    name, start, end = window
    idx = pd.date_range(start, end, freq="h")
    result = series.reindex(idx).to_numpy(dtype=float)
    if not np.isfinite(result).all():
        raise ValueError(f"Missing or invalid hourly values in {name}")
    return result


def replay(manifest: dict) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Return the 60 basic metrics and 135 RH cutoff-grid metrics."""
    if set(manifest) != set(SENSORS):
        raise ValueError(f"Manifest must select exact sensors: {SENSORS}")
    rows = []
    robustness = []
    for sensor in SENSORS:
        spec = manifest[sensor]
        raw = raw_sensor_samples(spec["sensor_wxf"])
        temp_model = model_series(Path(spec["model_temperature_wxf"]))
        rh_model = model_series(Path(spec["model_humidity_wxf"]))
        if not temp_model.index.equals(rh_model.index):
            raise ValueError(f"{sensor}: model variable UTC grids do not match")
        observed = centered_hourly_medians(raw, temp_model.index)
        pairs = {
            "T": (observed["T"], temp_model),
            "RH": (observed["RH"], rh_model),
            "pv_Pa": (
                pd.Series(
                    buck_saturation_pa(observed["T"])*observed["RH"]/100,
                    index=temp_model.index),
                pd.Series(
                    buck_saturation_pa(temp_model)*rh_model/100,
                    index=temp_model.index),
            ),
        }
        for variable, (a, b) in pairs.items():
            raw_values = pd.concat([a.rename("s"),b.rename("w")],axis=1).loc[
                ANALYSIS_START:ANALYSIS_END].dropna()
            raw_stat = metrics(raw_values["s"].to_numpy(), raw_values["w"].to_numpy())
            rows.append({"sensor":sensor,"variable":variable,"band":"raw", **raw_stat})
            for band in BANDS:
                svals=[]; wvals=[]
                for window in WINDOWS:
                    svals.extend(_band_values(_windows(a,window))[band])
                    wvals.extend(_band_values(_windows(b,window))[band])
                rows.append({"sensor":sensor,"variable":variable,"band":band,
                             **metrics(np.asarray(svals),np.asarray(wvals))})
        a, b = pairs["RH"]
        for slow in (48,72,96):
            for event in (8,12,18):
                for band in BANDS:
                    svals=[];wvals=[]
                    for window in WINDOWS:
                        svals.extend(_band_values(_windows(a,window),slow,event)[band])
                        wvals.extend(_band_values(_windows(b,window),slow,event)[band])
                    stat=metrics(np.asarray(svals),np.asarray(wvals))
                    robustness.append({"sensor":sensor,"slow_cutoff_h":slow,
                                       "event_cutoff_h":event,"band":band,**stat})
    return pd.DataFrame(rows), pd.DataFrame(robustness)


def compare_archives(replayed: pd.DataFrame, reference: pd.DataFrame,
                     columns: dict[str,str], keys: list[str]) -> dict:
    """Return fieldwise max difference; fail on missing/duplicate archive rows."""
    matches = replayed.merge(reference, on=keys, suffixes=("_new","_old"),
                             validate="one_to_one")
    if len(matches) != len(replayed) or len(matches) != len(reference):
        raise ValueError("Archive and replay selectors do not match")
    summary={"rows":len(matches),"max_abs_difference":{}}
    for new_col, archive_col in columns.items():
        new = matches[new_col+"_new"] if new_col in reference else matches[new_col]
        old = matches[archive_col+"_old"] if archive_col in replayed else matches[archive_col]
        summary["max_abs_difference"][new_col] = float(np.max(
            np.abs(new.to_numpy(float)-old.to_numpy(float))))
    return summary


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("private_manifest",type=Path)
    parser.add_argument("historical_band_metrics_csv",type=Path)
    parser.add_argument("historical_cutoff_robustness_csv",type=Path)
    parser.add_argument("--output-dir",type=Path,required=True)
    args=parser.parse_args()
    manifest=json.loads(args.private_manifest.read_text(encoding="utf-8"))
    rows,grid=replay(manifest)
    fields={"n":"n","bias":"bias","rmse":"rmse","mae":"mae",
            "sensor_sd":"sensor_sd","wufi_sd":"wufi_sd",
            "amplitude_ratio":"amplitude_ratio_wufi_sensor","corr":"corr"}
    gridfields={"n":"n","rmse":"rmse","sensor_sd":"sensor_sd",
                "wufi_sd":"wufi_sd","amplitude_ratio":"amplitude_ratio","corr":"corr"}
    report={
        "band_metrics":compare_archives(rows,pd.read_csv(args.historical_band_metrics_csv),
                                        fields,["sensor","variable","band"]),
        "cutoff_robustness":compare_archives(grid,pd.read_csv(args.historical_cutoff_robustness_csv),
                                            gridfields,
                                            ["sensor","slow_cutoff_h","event_cutoff_h","band"]),
        "method":"Phase-4 archived Butterworth + Buck vapour pressure",
        "limitation":"Lag-scanning columns are not part of this regression suite.",
    }
    args.output_dir.mkdir(parents=True,exist_ok=True)
    rows.to_csv(args.output_dir/"replayed_band_metrics.csv",index=False)
    grid.to_csv(args.output_dir/"replayed_cutoff_robustness.csv",index=False)
    (args.output_dir/"scientific_parity.json").write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))


if __name__=="__main__":
    main()
