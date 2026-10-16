#!/usr/bin/env python3
"""Forensic consistency check of archived same-hour clearness-index gaps.

This checks whether the *stored audited* gap kt and GHI equal the stated
same-clock-hour, bracketing linear interpolation of **measured** kt.
It does not invoke pvlib, rerun Erbs or prove why exceptions occurred.
All underlying meteo measurements and per-hour discrepancy tables stay local.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd

REQUIRED = {
    "TIME", "source_available", "source_GHI", "solar_zenith_deg",
    "cos_zenith", "extraterrestrial_DNI_Wm2", "clearness_index_kt",
    "corrected_ISGH_Wm2", "solar_value_method",
}


def diagnose(audit: pd.DataFrame, min_cos: float = 0.065,
             tolerance_Wm2: float = 1e-6) -> tuple[dict, pd.DataFrame]:
    """Compare all archived internal *daylight* kt-interpolated gaps."""
    missing = sorted(REQUIRED - set(audit.columns))
    if missing:
        raise ValueError(f"Missing audit columns: {missing}")
    if not 0 < min_cos < 1 or tolerance_Wm2 < 0:
        raise ValueError("Invalid solar cosine floor or tolerance")
    f = audit.reset_index(drop=True).copy()
    times = pd.to_datetime(f["TIME"], errors="raise")
    if (times.isna().any() or times.dt.tz is not None
        or not times.is_monotonic_increasing or times.duplicated().any()):
        raise ValueError("Audit TIME must be sorted, unique, fixed-standard time")
    source_flag = f["source_available"].astype("string").str.lower().map(
        {"true": True, "false": False, "1": True, "0": False})
    if source_flag.isna().any():
        raise ValueError("Invalid source_available values")
    available = source_flag.to_numpy(dtype=bool)
    methods = f["solar_value_method"].fillna("").astype(str)
    daylight_gaps = np.flatnonzero(methods.str.contains(
        "source gap: same-hour kt interpolation", regex=False).to_numpy())
    if len(daylight_gaps) == 0:
        raise ValueError("No archived same-hour interpolated daylight gaps found")
    hours = times.dt.hour.to_numpy()
    index = np.arange(len(f))
    source = pd.to_numeric(f["source_GHI"], errors="coerce").to_numpy(float)
    zen = pd.to_numeric(f["solar_zenith_deg"], errors="raise").to_numpy(float)
    cosz = pd.to_numeric(f["cos_zenith"], errors="raise").to_numpy(float)
    dni = pd.to_numeric(f["extraterrestrial_DNI_Wm2"], errors="raise").to_numpy(float)
    archive_ghi = pd.to_numeric(f["corrected_ISGH_Wm2"], errors="raise").to_numpy(float)
    archive_kt = pd.to_numeric(f["clearness_index_kt"], errors="raise").to_numpy(float)
    valid_measured = available & (zen < 90.) & np.isfinite(source)
    source_kt = np.zeros(len(f), dtype=float)
    source_kt[valid_measured] = np.minimum(
        np.maximum(source[valid_measured], 0.) /
        (dni[valid_measured] * np.maximum(cosz[valid_measured], min_cos)),
        1.,
    )
    rows = []
    for i in daylight_gaps:
        earlier = np.flatnonzero(valid_measured & (hours == hours[i]) & (index < i))
        later = np.flatnonzero(valid_measured & (hours == hours[i]) & (index > i))
        if len(earlier) == 0 or len(later) == 0:
            raise ValueError(f"No same-hour source bracket for {times.iloc[i]}")
        a, b = int(earlier[-1]), int(later[0])
        weight = (times.iloc[i] - times.iloc[a]) / (times.iloc[b] - times.iloc[a])
        expected_kt = float((1-weight)*source_kt[a] + weight*source_kt[b])
        expected_ghi = max(0., expected_kt * dni[i] * max(cosz[i], min_cos))
        rows.append({
            "TIME": times.iloc[i], "before": times.iloc[a], "after": times.iloc[b],
            "archived_kt": archive_kt[i], "reconstructed_kt": expected_kt,
            "kt_difference": expected_kt - archive_kt[i],
            "archived_GHI_Wm2": archive_ghi[i], "reconstructed_GHI_Wm2": expected_ghi,
            "GHI_difference_Wm2": expected_ghi - archive_ghi[i],
        })
    rows = pd.DataFrame(rows)
    absdiff = np.abs(rows["GHI_difference_Wm2"])
    discrepancies = rows.loc[absdiff > tolerance_Wm2].reset_index(drop=True)
    report = {
        "daylight_gap_count": len(rows),
        "gaps_matching_linear_bracketed_kt": len(rows) - len(discrepancies),
        "gaps_deviating": len(discrepancies),
        "max_abs_GHI_difference_Wm2": float(absdiff.max()),
        "max_abs_kt_difference": float(np.abs(rows["kt_difference"]).max()),
        "signed_gap_energy_difference_kWh_m2":
            float(rows["GHI_difference_Wm2"].sum()/1000),
        "tolerance_Wm2": tolerance_Wm2,
        "source_of_expectation": "Source-measured GHI, audited solar geometry, same-clock-hour kt linear brackets",
        "interpretation": "Detects exceptions in retained audit; does not determine provenance or rerun pvlib",
    }
    return report, discrepancies


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("private_audit_csv", type=Path)
    p.add_argument("--difference-csv", type=Path,
                   help="Private per-gap detailed discrepancies (never commit)")
    p.add_argument("--report-json", type=Path)
    args = p.parse_args()
    report, exceptions = diagnose(pd.read_csv(args.private_audit_csv))
    print(json.dumps(report, indent=2))
    if args.difference_csv:
        args.difference_csv.parent.mkdir(parents=True, exist_ok=True)
        exceptions.to_csv(args.difference_csv, index=False)
    if args.report_json:
        args.report_json.parent.mkdir(parents=True, exist_ok=True)
        args.report_json.write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
