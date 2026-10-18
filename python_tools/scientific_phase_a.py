"""Read-only REF/HEMP scientific Phase A source-data QC.

Physical radiometer plane, calibration and logger-channel mapping require
independent evidence: sensor range checks cannot certify them.
"""
from __future__ import annotations
import argparse, json
from pathlib import Path
import numpy as np
import pandas as pd
from python_tools.wxf_subset import raw_sensor_samples
from python_tools.wac_from_audit import validate_audit

SENSOR_FILES = {
    "HEMP27": "sensor_hempcrete_27.wxf.bin",
    "HEMP19": "sensor_hempcrete_19.wxf.bin",
    "HEMP42": "sensor_hempcrete_42.wxf.bin",
    "HEMP18": "sensor_hempcrete_18.wxf.bin",
    "REF118": "sensor_reference_118.wxf.bin",
}

def sensor_quality(frame: pd.DataFrame, large_gap_minutes: int = 60) -> dict:
    if not isinstance(frame.index, pd.DatetimeIndex) or frame.index.tz is not None or not frame.index.is_monotonic_increasing:
        raise ValueError("Require sorted timezone-naive UTC sensor timestamps")
    x = frame[["T", "RH"]].apply(pd.to_numeric, errors="coerce")
    gaps = frame.index.to_series().diff().dt.total_seconds().dropna() / 60
    return {
        "source_records": len(frame),
        "start_utc": str(frame.index.min()),
        "end_utc": str(frame.index.max()),
        "duplicate_timestamps": int(frame.index.duplicated().sum()),
        "missing_or_nonfinite_pairs": int((~np.isfinite(x.to_numpy()).all(axis=1)).sum()),
        "humidity_outside_0_100_count": int(((x.RH < 0) | (x.RH > 100)).sum()),
        "temperature_below_minus_30C_count": int((x["T"] < -30).sum()),
        "RH_ge_99_percent_count": int((x.RH >= 99).sum()),
        "median_sampling_interval_minutes": float(gaps.median()),
        "max_sampling_gap_minutes": float(gaps.max()),
        "gaps_over_60min": int((gaps > large_gap_minutes).sum()),
        "T_min_C": float(x["T"].min()), "T_max_C": float(x["T"].max()),
        "RH_min_percent": float(x.RH.min()), "RH_max_percent": float(x.RH.max()),
    }

def audit_wac(audit: pd.DataFrame) -> dict:
    f = validate_audit(audit)
    measured = f.source_available.to_numpy(bool)
    methods = audit.solar_value_method.astype(str)
    zenith = pd.to_numeric(audit.solar_zenith_deg, errors="coerce").to_numpy()
    return {
        "rows": len(f), "first_hour_fixed_UTC_plus_2": str(f.TIME.iloc[0]),
        "last_hour_fixed_UTC_plus_2": str(f.TIME.iloc[-1]),
        "available_source_measurement_hours": int(measured.sum()),
        "missing_source_measurement_hours": int((~measured).sum()),
        "source_daylight_gap_interpolation_hours": int(methods.str.contains("same-hour kt interpolation",regex=False).sum()),
        "source_available_but_solar_zenith_ge_90": int((measured & (zenith >= 90)).sum()),
        "max_closure_error_Wm2": float(pd.to_numeric(audit.closure_error_Wm2, errors="coerce").abs().max()),
        "radiometer_plane_verified": False,
        "climate_record_time_convention": "end-labelled fixed standard UTC+2; midpoint for zenith",
        "caution": "Unavailable hours include padding; no inference of radiometer mounting/tilt from GHI-labelled audit alone",
    }

def run(audit_csv: Path, raw_root: Path) -> dict:
    results = {"wac": audit_wac(pd.read_csv(audit_csv)), "sensors": {}}
    for name, file in SENSOR_FILES.items():
        results["sensors"][name] = sensor_quality(raw_sensor_samples(raw_root / file))
    return results

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("audit_csv", type=Path); p.add_argument("private_raw_root", type=Path)
    p.add_argument("--report-json", type=Path, required=True)
    args = p.parse_args()
    result = run(args.audit_csv, args.private_raw_root)
    args.report_json.parent.mkdir(parents=True, exist_ok=True)
    args.report_json.write_text(json.dumps(result, indent=2),encoding="utf-8")
    print(json.dumps({"audit_hours": result["wac"]["rows"], "sensor_record_counts": {
        k:v["source_records"] for k,v in result["sensors"].items()}},indent=2))

if __name__ == "__main__":
    main()
