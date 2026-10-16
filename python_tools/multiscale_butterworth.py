"""Butterworth multiscale decomposition matching the archived Phase-4 method class.

Source of method settings: REF & HEMP Drive /
Sensors VS WUFI / Phase_4_Multiresolution_Analysis / analysis_method.json.
This is a fresh implementation of the documented method specification;
the lost historical Phase-4 script and its exact preprocessing are not recovered.

Raw data are sampled hourly, each contiguous complete segment is filtered
independently, segments < min_segment_hours are omitted, and edge samples
are masked after zero-phase filtering to avoid boundary transients.
"""
from __future__ import annotations

import numpy as np
import pandas as pd
from scipy.signal import butter, sosfiltfilt


def butterworth_bands(
    series: pd.Series,
    slow_hours: float = 72.0,
    event_hours: float = 12.0,
    order: int = 4,
    min_segment_hours: int = 240,
    trim_hours: int = 72,
) -> dict[str, pd.Series]:
    """Return slow (>72h), diurnal_synoptic (12–72h) and event (<12h).

    For timestamp-indexed data a missing hour separates segments. NaNs and
    infinite values also break segments. All filtered bands are NaN outside
    valid, sufficiently long, edge-trimmed segments.
    """
    if not isinstance(series, pd.Series) or not isinstance(series.index, pd.DatetimeIndex):
        raise TypeError("Input must be a pandas Series with hourly DatetimeIndex")
    if series.index.tz is not None:
        raise ValueError("Pass a single pre-normalized timezone-naive hourly index")
    if not series.index.is_monotonic_increasing or series.index.has_duplicates:
        raise ValueError("Time index must be strictly increasing and unique")
    if not (3 <= event_hours < slow_hours and order >= 1
            and min_segment_hours > 2 * trim_hours and trim_hours >= 0):
        raise ValueError("Invalid cutoff/order/segment/trim settings")
    if not np.all(np.abs((series.index - series.index.floor("h")).total_seconds()) < 1e-6):
        raise ValueError("Expected exact hourly timestamps")
    values = pd.to_numeric(series, errors="raise").to_numpy(float)
    valid = np.isfinite(values)
    contiguous = np.zeros(len(series), dtype=bool)
    if len(contiguous):
        contiguous[0] = True
    if len(contiguous) > 1:
        contiguous[1:] = (series.index[1:] - series.index[:-1]) == pd.Timedelta(hours=1)
    segments = []
    begin = None
    for idx in range(len(values) + 1):
        good = idx < len(values) and valid[idx]
        if good and (begin is None or not contiguous[idx]):
            if begin is not None:
                segments.append((begin, idx))
            begin = idx
        if not good and begin is not None:
            segments.append((begin, idx))
            begin = None
    result = {band: np.full(len(series), np.nan) for band in
              ("slow", "diurnal_synoptic", "event")}
    slow_sos = butter(order, 1.0 / slow_hours, btype="lowpass", fs=1.0, output="sos")
    short_sos = butter(order, 1.0 / event_hours, btype="lowpass", fs=1.0, output="sos")
    for start, stop in segments:
        if stop - start < min_segment_hours or stop - start <= 2 * trim_hours:
            continue
        x = values[start:stop]
        slow = sosfiltfilt(slow_sos, x)
        short = sosfiltfilt(short_sos, x)
        core = slice(start + trim_hours, stop - trim_hours)
        local = slice(trim_hours, len(x) - trim_hours)
        result["slow"][core] = slow[local]
        result["diurnal_synoptic"][core] = (short - slow)[local]
        result["event"][core] = (x - short)[local]
    return {k: pd.Series(v, index=series.index, name=k) for k, v in result.items()}


def butterworth_band_metrics(
    sensor: pd.Series, model: pd.Series, **kwargs,
) -> pd.DataFrame:
    """Pairwise-complete band RMSE, bias, SD ratio and Pearson correlation."""
    # Filter the same union of valid hourly timestamps to preserve a common
    # segment mask, rather than borrowing signals across sensor gaps.
    combined = pd.concat([sensor.rename("sensor"), model.rename("model")], axis=1)
    common = combined["sensor"].notna() & combined["model"].notna()
    sensor_data = combined["sensor"].where(common)
    model_data = combined["model"].where(common)
    ss = butterworth_bands(sensor_data, **kwargs)
    mm = butterworth_bands(model_data, **kwargs)
    records = []
    for band in ("slow", "diurnal_synoptic", "event"):
        f = pd.concat([ss[band], mm[band]], axis=1).dropna()
        a = f.iloc[:, 0].to_numpy()
        b = f.iloc[:, 1].to_numpy()
        if len(a) < 3:
            records.append({"band": band, "n": len(a), "bias": np.nan,
                            "rmse": np.nan, "sensor_sd": np.nan, "model_sd": np.nan,
                            "amplitude_ratio": np.nan, "correlation": np.nan})
            continue
        sa = float(np.std(a, ddof=1))
        sb = float(np.std(b, ddof=1))
        records.append({
            "band": band, "n": len(a), "bias": float(np.mean(b-a)),
            "rmse": float(np.sqrt(np.mean((b-a)**2))),
            "sensor_sd": sa, "model_sd": sb,
            "amplitude_ratio": sb / sa if sa > 0 else np.nan,
            "correlation": float(np.corrcoef(a, b)[0, 1])
            if sa > 0 and sb > 0 else np.nan,
        })
    return pd.DataFrame(records)
