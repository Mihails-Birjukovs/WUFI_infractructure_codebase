"""Private-data-safe audit of final REF/HEMP two-case WXF comparisons.

Checks archived PairedRows against historical summaries, UTC-aligned
signed lag correlations, and postprocessor temperature/RH/dew-point
relationships. This verifies INTERNAL archive arithmetic and schemas,
not independent raw-sensor preprocessing or WUFI Pro application import.
Never commit the private input WXFs, manifests or per-hour results.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd
from python_tools.wxf_subset import association, load_wxf, list_args, utc_date_object

NUMERIC_FIELDS = (
    "MeanBias_WUFI_minus_sensor", "MAE", "RMSE", "CenteredRMSE",
    "PearsonCorrelation", "RegressionSlope", "RegressionIntercept",
    "StandardDeviationRatio", "ResidualP05", "ResidualMedian",
    "ResidualP95", "MaximumAbsoluteError",
)


def lag_by_utc(times, measured, model, *, lower=-24, upper=24):
    """Select MAXIMUM SIGNED Pearson r after shift of actual UTC instants."""
    t = pd.DatetimeIndex(times)
    if t.has_duplicates or not t.is_monotonic_increasing or t.tz is not None:
        raise ValueError("Require monotonic UTC-naive unique timestamps")
    x, y = np.asarray(measured, float), np.asarray(model, float)
    if x.shape != (len(t),) or y.shape != x.shape or (
        not np.isfinite(x).all()) or (not np.isfinite(y).all()):
        raise ValueError("Invalid paired numeric values")
    sensor = dict(zip(t, x))
    wufi = dict(zip(t, y))
    scored = []
    for lag in range(lower, upper + 1):
        shift = pd.Timedelta(hours=lag)
        pairs = np.asarray([
            (value, wufi[time + shift])
            for time, value in sensor.items()
            if time + shift in wufi
        ], dtype=float)
        if len(pairs) < 3 or min(np.std(pairs[:, 0]), np.std(pairs[:, 1])) == 0:
            continue
        scored.append((lag, float(np.corrcoef(pairs[:, 0], pairs[:, 1])[0, 1])))
    if not scored:
        raise ValueError("No valid UTC lag correlations")
    return max(scored, key=lambda row: row[1])


def core_metrics(measured, model):
    """Archived arithmetic, including Wolfram nearest-rank Quantile."""
    x, y = np.asarray(measured, float), np.asarray(model, float)
    if x.ndim != 1 or x.shape != y.shape or len(x) < 3 or (
        not np.isfinite(x).all()) or (not np.isfinite(y).all()):
        raise ValueError("Invalid paired values")
    if np.std(x) == 0 or np.std(y) == 0:
        raise ValueError("Cannot estimate regression or correlation from constant series")
    e = y - x
    slope, intercept = np.polyfit(x, y, 1)
    return {
        "MeanBias_WUFI_minus_sensor": float(e.mean()),
        "MAE": float(np.mean(np.abs(e))),
        "RMSE": float(np.sqrt(np.mean(e ** 2))),
        "CenteredRMSE": float(np.std(e, ddof=0)),
        "PearsonCorrelation": float(np.corrcoef(x, y)[0, 1]),
        "RegressionSlope": float(slope),
        "RegressionIntercept": float(intercept),
        "StandardDeviationRatio": float(np.std(y, ddof=0)/np.std(x, ddof=0)),
        "ResidualP05": float(np.quantile(e, .05, method="inverted_cdf")),
        "ResidualMedian": float(np.median(e)),
        "ResidualP95": float(np.quantile(e, .95, method="inverted_cdf")),
        "MaximumAbsoluteError": float(np.max(np.abs(e))),
    }


def extract_paired(path):
    obj = association(load_wxf(path))
    records = [list_args(row) for row in list_args(obj["PairedRows"])]
    times = pd.DatetimeIndex([utc_date_object(r[0]) for r in records])
    observed = np.asarray([r[1] for r in records], float)
    predicted = np.asarray([r[2] for r in records], float)
    residual = np.asarray([r[3] for r in records], float)
    if np.max(np.abs(residual - (predicted - observed))) > 1e-9:
        raise ValueError("Serialized paired residual does not match values")
    if len(list_args(obj["WUFITargetDatesUTC"])) != 3187:
        raise ValueError("Expected 3187-hour original model target grid")
    return obj, times, observed, predicted


def audit_comparison(path, full, after, alignment_record, *,
                     metric_tolerance=2e-4, correlation_tolerance=2e-6):
    obj, times, obs, mod = extract_paired(path)
    if obj["GroupFolderName"] != alignment_record["GroupFolderName"] or (
        not bool(alignment_record["PassQ"])) or (
        len(times) != int(alignment_record["PairedPointCount"])) or (
        len(times) != int(full["PairCount"])):
        raise ValueError("Comparison WXF and alignment audit mismatch")
    diffs = pd.Series(times).diff().dt.total_seconds().div(3600).dropna()
    fields_checked = 0
    max_error = 0.0
    max_corr_error = 0.0
    lag_count = 0
    selections = (
        (np.ones(len(times), dtype=bool), full),
        (times >= pd.Timestamp(after["StartUTC"].removesuffix("Z")), after),
    )
    for selected, archived in selections:
        dates, x, y = times[selected], obs[selected], mod[selected]
        if len(x) != int(archived["PairCount"]):
            raise ValueError("After-initial-exclusion count mismatch")
        reproduced = core_metrics(x, y)
        for field in NUMERIC_FIELDS:
            difference = abs(reproduced[field] - float(archived[field]))
            max_error = max(max_error, difference)
            fields_checked += 1
            if difference > metric_tolerance:
                raise ValueError(f"{field} differs beyond serialization tolerance")
        lag, corr = lag_by_utc(dates, x, y)
        if lag != archived["BestLagHours"]:
            raise ValueError("Best lag differs from archive")
        err = abs(corr - float(archived["BestLagCorrelation"]))
        max_corr_error = max(max_corr_error, err)
        if err > correlation_tolerance:
            raise ValueError("Lag correlation differs from archive")
        lag_count += 1
    return {
        "variable": obj["Variable"], "group_folder": obj["GroupFolderName"],
        "full_paired_hours": len(times),
        "post_exclusion_paired_hours": int(after["PairCount"]),
        "missing_hours_between_first_last_pair": int((diffs[diffs > 1]-1).sum()),
        "largest_time_gap_h": float(diffs.max()),
        "lag_at_search_boundary": bool(full["BestLagAtSearchBoundaryQ"]),
        "full_best_lag_h": int(full["BestLagHours"]),
        "max_archive_numeric_difference": max_error,
        "max_archive_lag_correlation_difference": max_corr_error,
        "metric_fields_checked": fields_checked,
        "lag_tests_passed": lag_count,
    }


def postprocessor_matrix(file):
    node = load_wxf(file)
    series = list_args(node) if node[0] == ("SYM", "List") else [node]
    rows = []
    for series_object in series:
        if series_object[0] != ("SYM", "TemporalData"):
            raise ValueError("Not WUFI TemporalData")
        z = np.asarray(series_object[2][1], dtype=float)
        if z.ndim != 2 or z.shape[0] != 1:
            raise ValueError("Invalid postprocessor series shape")
        rows.append(z[0])
    values = np.vstack(rows)
    if values.shape[1] != 3187 or not np.isfinite(values).all():
        raise ValueError("Invalid time-grid or nonfinite postprocessor values")
    return values


def audit_postprocessor(root):
    by_wall = {}
    count = 0
    for wall, locations in (("REF", 14), ("HEMP", 17)):
        directory = Path(root)/wall
        read = lambda key: postprocessor_matrix(directory/(key + ".wxf.bin"))
        t, rh, dew = read("temperature"), read("relative_humidity"), read("dew_point")
        layer, total = read("layer_water_content"), read("total_water_content")
        if not(t.shape == rh.shape == dew.shape == (locations, 3187) and
               layer.shape == (12, 3187) and total.shape == (1, 3187)):
            raise ValueError("Unexpected postprocessor inventory")
        if not ((rh >= 0) & (rh <= 100)).all() or (
            not (layer >= 0).all()) or (not (total >= 0).all()):
            raise ValueError("Nonphysical RH or negative water content")
        gamma = np.log(rh/100.) + (18.678-t/234.5)*(t/(257.14+t))
        expected = 257.14*gamma/(18.678-gamma)
        error = float(np.max(np.abs(dew-expected)))
        if error > 1e-9:
            raise ValueError("Dew-point production formula discrepancy")
        by_wall[wall] = {
            "temperature_humidity_dew_positions": locations,
            "layer_water_content_series": 12,
            "total_water_content_series": 1,
            "hours_per_series": 3187,
            "dew_point_values_verified": int(t.size),
            "max_dewpoint_difference_C": error,
            "physical_range_check": "passed",
            "total_water_integral_from_layers_verified": False,
        }
        count += int(t.size)
    return {"by_wall": by_wall, "verified_dewpoint_count": count}


def audit_archive(root, summary_csv, manifest_json, alignment_json,
                  postproc_root=None):
    manifest = json.loads(Path(manifest_json).read_text(encoding="utf-8"))
    alignment = json.loads(Path(alignment_json).read_text(encoding="utf-8"))
    frame = pd.read_csv(summary_csv)
    if len(frame) != 12 or len(alignment["Rows"]) != 12 or (
        manifest["CompletedSelectionCount"] != 2) or (
        manifest["MetricRowCount"] != 12):
        raise ValueError("Not the frozen final two-case comparison inventory")
    if manifest["SensorDataUtilitiesVersion"] != "Production-1.2.0-2026-08-05":
        raise ValueError("Not the frozen Production v1.2.0 code version")
    if alignment["OverallStatus"] != "Passed" or alignment["FailedCount"] != 0:
        raise ValueError("Original timezone audit not passed")
    output = []
    for _, row in frame.iterrows():
        case = next((x for x in manifest["Results"] if x["WallSystem"] == row.WallSystem), None)
        if case is None:
            raise ValueError("Manifest wall missing")
        record = next((x for x in case["Comparisons"] if
                       x["GroupID"] == row.GroupID and x["Variable"] == row.Variable), None)
        if record is None:
            raise ValueError("Manifest group missing")
        filename = Path(record["TimeSeriesExport"]["Path"].replace("\\", "/")).name
        file = Path(root)/row.WallSystem/(filename + ".bin")
        if not file.is_file():
            raise FileNotFoundError(file)
        matching = [a for a in alignment["Rows"] if (
            a["CaseFolderName"] == row.CaseFolderName and
            a["GroupFolderName"] in record["OutputFolder"] and
            a["Variable"] == row.Variable)]
        if len(matching) != 1:
            raise ValueError("Alignment audit group missing/duplicate")
        detail = audit_comparison(file, json.loads(row.FullPeriod),
            json.loads(row.AfterInitialExclusion), matching[0])
        output.append({"wall_system": row.WallSystem, "group": row.GroupID, **detail})
    result = {
        "schema": "refhemp_final_two_case_private_validation_v1",
        "final_wall_cases": 2,
        "paired_WXF_files_verified": len(output),
        "comparison_periods_verified": len(output)*2,
        "metric_scalar_values_verified": sum(x["metric_fields_checked"] for x in output),
        "best_lag_rows_verified": sum(x["lag_tests_passed"] for x in output),
        "all_numerical_checks_pass": True,
        "maximum_metric_absolute_difference":
            max(x["max_archive_numeric_difference"] for x in output),
        "maximum_best_lag_correlation_difference":
            max(x["max_archive_lag_correlation_difference"] for x in output),
        "RH_boundary_estimate_count":
            sum(x["variable"] == "RelativeHumidity" and
                x["lag_at_search_boundary"] for x in output),
        "details": output,
        "scope": ("Internal paired WXF -> archived metric agreement only; "
                  "not independent raw-sensor preprocessing or WUFI Pro execution"),
    }
    if postproc_root:
        result["postprocessor"] = audit_postprocessor(postproc_root)
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for option in ("--comparison-wxf-root", "--comparison-summary-csv",
                   "--comparison-manifest-json", "--alignment-audit-json", "--out-json"):
        p.add_argument(option, type=Path, required=True)
    p.add_argument("--postprocessor-root", type=Path)
    args = p.parse_args()
    report = audit_archive(args.comparison_wxf_root,
        args.comparison_summary_csv, args.comparison_manifest_json,
        args.alignment_audit_json, args.postprocessor_root)
    args.out_json.parent.mkdir(parents=True, exist_ok=True)
    args.out_json.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({key:value for key,value in report.items() if
                      key != "details"}, indent=2))


if __name__ == "__main__":
    main()
