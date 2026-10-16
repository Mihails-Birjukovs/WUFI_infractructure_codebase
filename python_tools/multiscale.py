"""Centered-window multiscale diagnostics, reconstructed from WUFI report v1.4.

The original Phase-4 temporary implementation was not retained. This is a
tested reproducibility REFERENCE of the reported slow/event/fast definition,
not a claim of exact historical source-code recovery.
"""
from __future__ import annotations

import numpy as np
import pandas as pd


def centered_mean(x: pd.Series, hours: int) -> pd.Series:
    if not isinstance(x, pd.Series) or not isinstance(hours, int) or hours < 3:
        raise ValueError("Expected a pandas Series and a window >= 3 samples")
    return x.rolling(window=hours, center=True, min_periods=max(3, hours // 3)).mean()


def split_bands(x: pd.Series, slow_hours: int = 72, event_hours: int = 12) -> dict:
    """Return slow, event and fast components of *hourly* observations."""
    if not (3 <= event_hours < slow_hours):
        raise ValueError("Require 3 <= event_hours < slow_hours")
    slow = centered_mean(x, slow_hours)
    short = centered_mean(x, event_hours)
    return {"slow": slow, "event": short - slow, "fast": x - short}


def _metric_pair(sensor: np.ndarray, model: np.ndarray) -> dict:
    if len(sensor) < 3:
        return dict(n=len(sensor), rmse=np.nan, sensor_sd=np.nan,
                    model_sd=np.nan, amplitude_ratio=np.nan, correlation=np.nan)
    err = model - sensor
    s_sd = float(np.std(sensor, ddof=1))
    m_sd = float(np.std(model, ddof=1))
    return dict(
        n=len(sensor),
        rmse=float(np.sqrt(np.mean(err**2))),
        sensor_sd=s_sd,
        model_sd=m_sd,
        amplitude_ratio=float(m_sd / s_sd) if s_sd > 0 else np.nan,
        correlation=float(np.corrcoef(sensor, model)[0, 1]) if s_sd > 0 and m_sd > 0 else np.nan,
    )


def band_metrics(sensor: pd.Series, model: pd.Series,
                 slow_hours: int = 72, event_hours: int = 12) -> pd.DataFrame:
    """Evaluate mutually aligned, pairwise complete samples in each band."""
    sb = split_bands(sensor, slow_hours, event_hours)
    mb = split_bands(model, slow_hours, event_hours)
    rows = []
    for band in ("slow", "event", "fast"):
        aligned = pd.concat([sb[band].rename("s"), mb[band].rename("m")], axis=1).dropna()
        metrics = _metric_pair(aligned["s"].to_numpy(dtype=float),
                               aligned["m"].to_numpy(dtype=float))
        rows.append({"band": band, **metrics})
    return pd.DataFrame(rows)


def cutoff_robustness(
    sensor: pd.Series, model: pd.Series,
    slow_grid: tuple[int, ...] = (48, 72, 96),
    event_grid: tuple[int, ...] = (8, 12, 18),
) -> pd.DataFrame:
    results = []
    for slow in slow_grid:
        for event in event_grid:
            if event >= slow:
                continue
            temp = band_metrics(sensor, model, slow, event)
            temp["slow_hours"] = slow
            temp["event_hours"] = event
            results.append(temp)
    if not results:
        raise ValueError("No usable window combinations")
    return pd.concat(results, ignore_index=True)
