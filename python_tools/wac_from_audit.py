#!/usr/bin/env python3
"""Reconstruct an hourly WUFI WAC_02 climate file from an already-audited CSV.

Adapted from the retained REF/HEMP project Python implementation reproduced in
WUFI Unified Report draft v1.4, Appendix I.1 (2026).

The input must be end-labelled in a FIXED UTC-offset local standard time, with
source_GHI in W/m^2 and source_available marking valid measured GHI. This does
not replace raw meteorological QA or MongoDB source aggregation.

Historical solar coordinates 56.97N, 24.17E are intentional, and differ from
the documented physical test-house coordinates. Override for a new campaign.
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
import pandas as pd
import pvlib

HISTORICAL_LATITUDE_DEG = 56.97
HISTORICAL_LONGITUDE_DEG = 24.17
HISTORICAL_FIXED_UTC_OFFSET_H = 2.0
MIN_COS_ZENITH = 0.065
MAX_ZENITH_DEG = 87.0
WAC_COLUMNS = ("TIME", "TA", "HREL", "ISGH", "ISD", "WD", "WS", "PMSL")
REQUIRED_INPUT = ("TIME", "TA", "HREL", "WD", "WS", "PMSL", "source_GHI", "source_available")


def _availability(values: pd.Series) -> np.ndarray:
    """Parse explicit booleans / 0/1; never use bool('False') == True."""
    parsed = values.astype("string").str.strip().str.lower()
    mapped = parsed.map({"true": True, "false": False, "1": True, "0": False})
    if mapped.isna().any():
        raise ValueError("source_available must contain only True/False or 1/0")
    return mapped.to_numpy(dtype=bool)


def validate_audit(frame: pd.DataFrame) -> pd.DataFrame:
    """Validate cadence, source flags, units' plausible ranges and timestamps."""
    missing = sorted(set(REQUIRED_INPUT).difference(frame.columns))
    if missing:
        raise ValueError(f"Missing audited input columns: {missing}")
    f = frame.copy().reset_index(drop=True)
    f["TIME"] = pd.to_datetime(f["TIME"], errors="raise")
    if f["TIME"].isna().any() or f["TIME"].dt.tz is not None:
        raise ValueError("TIME must be non-null, timezone-naive FIXED-standard local timestamps")
    if len(f) < 48:
        raise ValueError("Need >=48 hourly rows for bracketed daylight gap treatment")
    if not f["TIME"].is_monotonic_increasing or f["TIME"].duplicated().any():
        raise ValueError("TIME must be sorted and unique")
    if not f["TIME"].diff().iloc[1:].eq(pd.Timedelta(hours=1)).all():
        raise ValueError("TIME must be a continuous hourly series without DST jumps")
    f["source_available"] = _availability(f["source_available"])
    if not f["source_available"].any():
        raise ValueError("No measured source_GHI entries")
    for name in ("source_GHI", "TA", "HREL", "WD", "WS", "PMSL"):
        f[name] = pd.to_numeric(f[name], errors="raise")
    output_cols = ["TA", "HREL", "WD", "WS", "PMSL"]
    if not np.isfinite(f[output_cols].to_numpy(dtype=float)).all():
        raise ValueError("WAC meteorological output fields must be finite")
    present = f["source_available"].to_numpy(dtype=bool)
    if not np.isfinite(f.loc[present, "source_GHI"].to_numpy(dtype=float)).all():
        raise ValueError("GHI must be finite whenever source_available is true")
    if not f["HREL"].between(0, 100).all():
        raise ValueError("HREL must be in percent [0, 100]")
    if (f["WS"] < 0).any() or (f["PMSL"] <= 0).any():
        raise ValueError("Wind speed must be nonnegative; pressure must be positive")
    return f


def noaa_solar_zenith(
    times_local_standard: pd.DatetimeIndex,
    latitude_deg: float = HISTORICAL_LATITUDE_DEG,
    longitude_deg: float = HISTORICAL_LONGITUDE_DEG,
    timezone_hours: float = HISTORICAL_FIXED_UTC_OFFSET_H,
) -> np.ndarray:
    """Approximate NOAA fractional-year true solar zenith (degrees)."""
    day_of_year = times_local_standard.dayofyear.to_numpy(dtype=float)
    hour = (
        times_local_standard.hour.to_numpy(dtype=float)
        + times_local_standard.minute.to_numpy(dtype=float) / 60.0
        + times_local_standard.second.to_numpy(dtype=float) / 3600.0
    )
    gamma = 2 * np.pi / 365 * (day_of_year - 1 + (hour - 12) / 24)
    eot = 229.18 * (
        0.000075 + 0.001868 * np.cos(gamma) - 0.032077 * np.sin(gamma)
        - 0.014615 * np.cos(2 * gamma) - 0.040849 * np.sin(2 * gamma)
    )
    decl = (
        0.006918 - 0.399912 * np.cos(gamma) + 0.070257 * np.sin(gamma)
        - 0.006758 * np.cos(2 * gamma) + 0.000907 * np.sin(2 * gamma)
        - 0.002697 * np.cos(3 * gamma) + 0.001480 * np.sin(3 * gamma)
    )
    tst = hour * 60 + eot + 4 * longitude_deg - 60 * timezone_hours
    ha = np.deg2rad(tst / 4 - 180)
    lat = math.radians(latitude_deg)
    cos_z = np.sin(lat) * np.sin(decl) + np.cos(lat) * np.cos(decl) * np.cos(ha)
    return np.rad2deg(np.arccos(np.clip(cos_z, -1, 1)))


def _bracket_kt(
    times: pd.Series, valid: np.ndarray, kt: np.ndarray, idx: int
) -> float:
    """Linearly interpolate nearest valid *same clock hour* days on each side."""
    target = times.iloc[idx]
    matching_hour = times.dt.hour.to_numpy() == target.hour
    earlier = np.flatnonzero(valid & matching_hour & (times.to_numpy() < target))
    later = np.flatnonzero(valid & matching_hour & (times.to_numpy() > target))
    if len(earlier) == 0 or len(later) == 0:
        raise ValueError(f"No same-hour measured GHI bracket around {target}")
    a, b = int(earlier[-1]), int(later[0])
    weight = (target - times.iloc[a]) / (times.iloc[b] - times.iloc[a])
    return float(kt[a] + weight * (kt[b] - kt[a]))


def reconstruct_from_audit(
    frame: pd.DataFrame,
    latitude_deg: float = HISTORICAL_LATITUDE_DEG,
    longitude_deg: float = HISTORICAL_LONGITUDE_DEG,
    timezone_hours: float = HISTORICAL_FIXED_UTC_OFFSET_H,
) -> pd.DataFrame:
    """Build WAC components without changing source/other meteo fields."""
    if not (-90 <= latitude_deg <= 90 and -180 <= longitude_deg <= 180):
        raise ValueError("Invalid latitude/longitude")
    f = validate_audit(frame)
    times = f["TIME"]
    midpoint = pd.DatetimeIndex(times - pd.Timedelta(minutes=30))
    zenith = noaa_solar_zenith(midpoint, latitude_deg, longitude_deg, timezone_hours)
    cos_z = np.cos(np.deg2rad(zenith))
    dni_extra = np.asarray(pvlib.irradiance.get_extra_radiation(midpoint.dayofyear), dtype=float)
    horizontal_extra = dni_extra * np.maximum(cos_z, 0.0)
    available = f["source_available"].to_numpy(dtype=bool)
    source_ghi = f["source_GHI"].to_numpy(dtype=float)
    measured_indices = np.flatnonzero(available)
    first, last = int(measured_indices[0]), int(measured_indices[-1])
    valid_for_kt = np.where(available & (zenith < 90), np.maximum(source_ghi, 0.0), 0.0)
    source_kt = np.asarray(
        pvlib.irradiance.clearness_index(
            ghi=valid_for_kt,
            solar_zenith=zenith,
            extra_radiation=dni_extra,
            min_cos_zenith=MIN_COS_ZENITH,
            max_clearness_index=1.0,
        ),
        dtype=float,
    )
    ghi = np.zeros(len(f), dtype=float)
    methods = ["outside-source zero padding"] * len(f)
    for i in range(first, last + 1):
        if zenith[i] >= 90:
            methods[i] = "astronomical night set to zero"
        elif available[i]:
            ghi[i] = max(0.0, source_ghi[i])
            methods[i] = "measured GHI hourly mean"
        else:
            ghi[i] = max(0.0, _bracket_kt(times, available, source_kt, i) * horizontal_extra[i])
            methods[i] = "bracketed same-hour kt interpolation"
    components = pvlib.irradiance.erbs(
        ghi=ghi, zenith=zenith, datetime_or_doy=midpoint,
        min_cos_zenith=MIN_COS_ZENITH, max_zenith=MAX_ZENITH_DEG,
    )
    dhi = np.asarray(components["dhi"], dtype=float)
    if not np.isfinite(dhi).all() or np.any(dhi < -1e-9) or np.any(dhi - ghi > 1e-8):
        raise ValueError("Unphysical Erbs radiation split")
    result = f.copy()
    result["ISGH"] = ghi
    result["ISD"] = np.clip(dhi, 0, ghi)
    result["solar_value_method_rebuilt"] = methods
    return result


def write_wac(
    frame: pd.DataFrame, output_path: Path,
    latitude_deg: float = HISTORICAL_LATITUDE_DEG,
    longitude_deg: float = HISTORICAL_LONGITUDE_DEG,
    timezone_hours: float = HISTORICAL_FIXED_UTC_OFFSET_H,
) -> None:
    """Write the retained WUFI WAC_02 eight-column, Latin-1 text convention."""
    path = Path(output_path)
    values = frame.loc[:, list(WAC_COLUMNS)]
    if not np.isfinite(values.drop(columns="TIME").to_numpy(dtype=float)).all():
        raise ValueError("WAC contains nonfinite numerical fields")
    header = [
        "WUFI®_WAC_02",
        "10\tLine Offset to 'Number of Data Columns'",
        "Location",
        "Description; Audited hourly climate; GHI measured/gap-audited; DHI Erbs",
        f"{longitude_deg}\tLongitude[deg]; East is positive",
        f"{latitude_deg}\tLatitude[deg]; North is positive",
        "0\tHeight AMSL[m]",
        f"{timezone_hours}\tTime Zone[h from UTC]; East is positive",
        "1\tTime Step[h]",
        f"{len(values)}\tNumber of DataLines",
        "8\tNumber of DataColumns",
        "\t".join(WAC_COLUMNS),
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="latin-1", newline="\n") as stream:
        stream.write("\n".join(header) + "\n")
        for row in values.itertuples(index=False, name=None):
            time_text = pd.Timestamp(row[0]).strftime("%Y-%m-%d%H:%M")
            stream.write("\t".join([time_text] + [f"{float(v):.12g}" for v in row[1:]]) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audit_csv", type=Path)
    parser.add_argument("output_wac", type=Path)
    parser.add_argument("--latitude", type=float, default=HISTORICAL_LATITUDE_DEG)
    parser.add_argument("--longitude", type=float, default=HISTORICAL_LONGITUDE_DEG)
    parser.add_argument("--utc-offset-hours", type=float, default=HISTORICAL_FIXED_UTC_OFFSET_H)
    parser.add_argument("--expected-dhi-column", default="estimated_DHI_Wm2")
    args = parser.parse_args()
    if args.audit_csv.resolve() == args.output_wac.resolve():
        parser.error("Output WAC must differ from input CSV")
    audit = pd.read_csv(args.audit_csv)
    result = reconstruct_from_audit(audit, args.latitude, args.longitude, args.utc_offset_hours)
    if args.expected_dhi_column in result:
        expected = pd.to_numeric(result[args.expected_dhi_column], errors="raise").to_numpy()
        delta = np.abs(result["ISD"].to_numpy() - expected)
        if np.isfinite(delta).any():
            print(f"Maximum difference against retained DHI column: {np.nanmax(delta):.6g} W/m²")
    write_wac(result, args.output_wac, args.latitude, args.longitude, args.utc_offset_hours)
    print(f"Wrote {args.output_wac} ({len(result)} hourly rows); pvlib {pvlib.__version__}")


if __name__ == "__main__":
    main()
