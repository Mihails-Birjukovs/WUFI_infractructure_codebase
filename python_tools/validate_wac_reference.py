#!/usr/bin/env python3
"""Audit a WAC_02 file numerically against a retained hourly climate audit.

Requires authorized local files; never accesses or publishes research datasets.
Compare ISGH against corrected_ISGH_Wm2 and ISD against estimated_DHI_Wm2,
along with all preserved measured meteorological fields and end-labelled times.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

WAC_FIELDS = ("TIME", "TA", "HREL", "ISGH", "ISD", "WD", "WS", "PMSL")
AUDIT_TO_WAC = {
    "TA": "TA", "HREL": "HREL", "WD": "WD", "WS": "WS", "PMSL": "PMSL",
    "ISGH": "corrected_ISGH_Wm2", "ISD": "estimated_DHI_Wm2",
}


def compare_wac_to_audit(
    audit_csv: Path, reference_wac: Path, radiation_atol: float = 1e-6,
    meteorology_atol: float = 1e-6,
) -> dict:
    """Validate WAC text/row contract and return unit-aware comparison summary.

    A successful comparison means the supplied WAC matches the *audit table*,
    NOT that the upstream pvlib reconstruction was independently re-executed.
    """
    audit_csv, reference_wac = Path(audit_csv), Path(reference_wac)
    if radiation_atol < 0 or meteorology_atol < 0:
        raise ValueError("Tolerances must be nonnegative")
    with reference_wac.open("r", encoding="latin-1") as f:
        header = [next(f).rstrip("\r\n") for _ in range(12)]
    if header[0] != "WUFI®_WAC_02" or header[10].split("\t")[0] != "8":
        raise ValueError("Invalid WAC_02 file header")
    if header[11].split("\t") != list(WAC_FIELDS):
        raise ValueError("Unexpected WAC columns or ordering")
    declared_count = int(header[9].split("\t")[0])
    wac = pd.read_csv(reference_wac, sep="\t", skiprows=12, header=None,
                      names=list(WAC_FIELDS), encoding="latin-1")
    audit = pd.read_csv(audit_csv)
    if len(audit) != declared_count or len(wac) != declared_count:
        raise ValueError("WAC declared line count and audit/data lengths disagree")
    missing = [name for name in ("TIME", *AUDIT_TO_WAC.values()) if name not in audit]
    if missing:
        raise ValueError(f"Audit is missing columns: {missing}")
    audit_time = pd.to_datetime(audit["TIME"], errors="raise")
    wac_time = pd.to_datetime(wac["TIME"], errors="raise")
    if not (audit_time == wac_time).all():
        raise ValueError("WAC and audit timestamps differ")
    errors: dict[str, float] = {}
    violations = []
    for column, audit_column in AUDIT_TO_WAC.items():
        observed = pd.to_numeric(wac[column], errors="raise").to_numpy(float)
        expected = pd.to_numeric(audit[audit_column], errors="raise").to_numpy(float)
        if not np.isfinite(observed).all() or not np.isfinite(expected).all():
            raise ValueError(f"{column}: non-finite WAC or audit values")
        max_error = float(np.max(np.abs(observed - expected))) if len(wac) else 0.0
        errors[column] = max_error
        tolerance = radiation_atol if column in ("ISGH", "ISD") else meteorology_atol
        if max_error > tolerance:
            violations.append(column)
    if not wac["HREL"].between(0, 1).all():
        raise ValueError("WAC HREL must be fractional (0..1)")
    if (wac["ISGH"] < 0).any() or (wac["ISD"] < 0).any():
        raise ValueError("WAC contains negative solar irradiance")
    if (wac["ISD"] > wac["ISGH"] + radiation_atol).any():
        raise ValueError("WAC diffuse irradiance exceeds global")
    return {
        "rows": len(wac),
        "start": str(wac_time.iloc[0]),
        "end": str(wac_time.iloc[-1]),
        "max_abs_error_by_field": errors,
        "tolerances": {"radiation_Wm2": radiation_atol,
                       "other_WAC_fields": meteorology_atol},
        "matching_fields": len(AUDIT_TO_WAC) - len(violations),
        "failed_fields": violations,
        "passed": not bool(violations),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audit_csv", type=Path)
    parser.add_argument("wac_file", type=Path)
    parser.add_argument("--radiation-atol", type=float, default=1e-6)
    parser.add_argument("--meteorology-atol", type=float, default=1e-6)
    args = parser.parse_args()
    results = compare_wac_to_audit(
        args.audit_csv, args.wac_file,
        radiation_atol=args.radiation_atol,
        meteorology_atol=args.meteorology_atol,
    )
    print(json.dumps(results, indent=2))
    if not results["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
