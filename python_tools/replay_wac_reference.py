#!/usr/bin/env python3
"""Replay the real pvlib WAC generator on a *local authorized* historical audit.

Reads the original audited hourly CSV and comparison WAC from disk; no private
measurements or WACs are committed or uploaded. Prints a summary and optionally
writes a local per-row difference CSV. Strict parity and science tolerance
are deliberately distinct gates.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from python_tools.wac_from_audit import (
    HISTORICAL_LATITUDE_DEG, HISTORICAL_LONGITUDE_DEG,
    HISTORICAL_FIXED_UTC_OFFSET_H, reconstruct_from_audit, write_wac,
)

COLUMNS = ["TIME", "TA", "HREL", "ISGH", "ISD", "WD", "WS", "PMSL"]


def replay(audit_csv: Path, archived_wac: Path, rebuilt_wac: Path,
           strict_tolerance_wm2: float = 1e-6,
           science_tolerance_wm2: float | None = None,
           latitude: float = HISTORICAL_LATITUDE_DEG,
           longitude: float = HISTORICAL_LONGITUDE_DEG,
           utc_offset_hours: float = HISTORICAL_FIXED_UTC_OFFSET_H,
           ) -> tuple[dict, pd.DataFrame]:
    """Replay actual pvlib code; compare it with an archived WAC.

    A science tolerance is never assumed. It must be explicitly supplied.
    For time-series WAC data at hourly spacing, sum(W/m^2)/1000 = kWh/m^2.
    """
    if strict_tolerance_wm2 < 0 or (science_tolerance_wm2 is not None
                                   and science_tolerance_wm2 < 0):
        raise ValueError("Tolerances must be nonnegative")
    audit = pd.read_csv(audit_csv)
    result = reconstruct_from_audit(audit, latitude, longitude, utc_offset_hours)
    write_wac(result, rebuilt_wac, latitude, longitude, utc_offset_hours)
    with Path(archived_wac).open(encoding="latin-1") as stream:
        header = [next(stream).rstrip("\n\r") for _ in range(12)]
    if header[0] != "WUFI®_WAC_02" or header[-1].split("\t") != COLUMNS:
        raise ValueError("Reference is not an 8-column WAC_02 with ISD")
    old = pd.read_csv(archived_wac, sep="\t", skiprows=12, header=None,
                      names=COLUMNS, encoding="latin-1")
    if len(old) != len(result) or len(result) != int(header[9].split("\t")[0]):
        raise ValueError("Archived WAC count does not match audited rows")
    old_time = pd.to_datetime(old["TIME"], errors="raise")
    new_time = pd.to_datetime(result["TIME"], errors="raise")
    if not np.array_equal(old_time.to_numpy(), new_time.to_numpy()):
        raise ValueError("Historical and reconstructed WAC timestamps differ")
    delta = pd.DataFrame({"TIME": new_time})
    max_errors = {}
    for field in COLUMNS[1:]:
        numbers = old[field].to_numpy(float)
        rebuilt = result[field].to_numpy(float)
        if not np.isfinite(numbers).all():
            raise ValueError(f"Archived {field} contains nonfinite values")
        diff = rebuilt - numbers
        delta["difference_" + field] = diff
        max_errors[field] = float(np.max(np.abs(diff)))
    radiation = np.maximum(
        np.abs(delta["difference_ISGH"]), np.abs(delta["difference_ISD"])
    )
    mismatches = delta.loc[radiation > strict_tolerance_wm2].reset_index(drop=True)
    radiation_fields = ["ISGH", "ISD"]
    summary = {
        "rows": len(result),
        "strict_tolerance_Wm2": strict_tolerance_wm2,
        "radiation_max_abs_errors_Wm2": {k: max_errors[k] for k in radiation_fields},
        "other_max_abs_errors": {k: max_errors[k] for k in
                                 ("TA", "HREL", "WD", "WS", "PMSL")},
        "radiation_hours_exceed_strict_tolerance": len(mismatches),
        "radiation_signed_energy_delta_kWh_m2": {
            k: float(delta["difference_" + k].sum() / 1000) for k in radiation_fields},
        "radiation_archived_energy_kWh_m2": {
            k: float(old[k].sum() / 1000) for k in radiation_fields},
        "radiation_rebuilt_energy_kWh_m2": {
            k: float(result[k].sum() / 1000) for k in radiation_fields},
        "strict_parity": bool(max(max_errors.values()) <= strict_tolerance_wm2),
        "science_tolerance_Wm2": science_tolerance_wm2,
        "within_user_selected_science_tolerance":
            None if science_tolerance_wm2 is None else
            bool(max(max_errors[k] for k in radiation_fields)
                 <= science_tolerance_wm2),
        "replay_engine": "python_tools.wac_from_audit.reconstruct_from_audit + pvlib",
        "interpretation": "Numerical source parity, not confirmation of radiometer orientation or WUFI import",
    }
    return summary, mismatches


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("audit_csv", type=Path)
    p.add_argument("archived_wac", type=Path)
    p.add_argument("rebuilt_wac", type=Path)
    p.add_argument("--strict-tolerance", type=float, default=1e-6)
    p.add_argument("--science-tolerance", type=float, default=None,
                   help="Optional explicitly approved max W/m^2 difference")
    p.add_argument("--latitude", type=float, default=HISTORICAL_LATITUDE_DEG)
    p.add_argument("--longitude", type=float, default=HISTORICAL_LONGITUDE_DEG)
    p.add_argument("--utc-offset-hours", type=float,
                   default=HISTORICAL_FIXED_UTC_OFFSET_H)
    p.add_argument("--report-json", type=Path)
    p.add_argument("--diff-csv", type=Path)
    args = p.parse_args()
    result, deviations = replay(
        args.audit_csv, args.archived_wac, args.rebuilt_wac,
        args.strict_tolerance, args.science_tolerance,
        args.latitude, args.longitude, args.utc_offset_hours,
    )
    print(json.dumps(result, indent=2))
    if args.report_json:
        args.report_json.parent.mkdir(parents=True, exist_ok=True)
        args.report_json.write_text(json.dumps(result, indent=2), encoding="utf-8")
    if args.diff_csv:
        args.diff_csv.parent.mkdir(parents=True, exist_ok=True)
        deviations.to_csv(args.diff_csv, index=False)


if __name__ == "__main__":
    main()
