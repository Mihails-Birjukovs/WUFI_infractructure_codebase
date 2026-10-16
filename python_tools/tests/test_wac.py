import numpy as np
import pandas as pd
import pytest

from python_tools.wac_from_audit import reconstruct_from_audit, validate_audit, write_wac


def _frame():
    n = 24 * 10
    times = pd.date_range("2026-04-01 01:00", periods=n, freq="h")
    hour = times.hour.to_numpy()
    ghi = 250 * np.maximum(np.sin(np.pi * (hour - 6) / 12), 0)
    available = np.ones(n, dtype=int)
    available[24 * 4 + 12] = 0
    return pd.DataFrame({
        "TIME": times, "source_GHI": ghi, "source_available": available,
        "TA": 10.0, "HREL": 0.65, "WD": 180.0, "WS": 1.5, "PMSL": 1013.25,
    })


def test_wac_gap_infill_and_header(tmp_path):
    f = _frame()
    result = reconstruct_from_audit(f)
    assert len(result) == len(f)
    assert result.loc[24 * 4 + 12, "solar_value_method_rebuilt"] == "bracketed same-hour kt interpolation"
    assert (result["ISGH"] >= 0).all()
    assert (result["ISD"] >= 0).all()
    assert (result["ISD"] <= result["ISGH"] + 1e-9).all()
    path = tmp_path / "test.wac"
    write_wac(result, path)
    text = path.read_text(encoding="latin-1")
    assert text.startswith("WUFI®_WAC_02")
    assert "TIME\tTA\tHREL\tISGH\tISD\tWD\tWS\tPMSL" in text
    assert text.splitlines()[12].startswith("2026-04-01 01:00\\t".replace("\\t", "\t"))
    assert len(text.splitlines()) == len(result) + 12


def test_reject_dst_jump():
    f = _frame()
    f.loc[20:, "TIME"] = f.loc[20:, "TIME"] + pd.Timedelta(hours=1)
    with pytest.raises(ValueError, match="continuous hourly"):
        validate_audit(f)


def test_availability_false_string():
    f = _frame()
    f["source_available"] = f["source_available"].astype(str).replace({"1": "True", "0": "False"})
    assert validate_audit(f)["source_available"].iloc[24 * 4 + 12] == False


def test_missing_ghi_flag():
    f = _frame()
    f.loc[0, "source_GHI"] = float("nan")
    with pytest.raises(ValueError, match="GHI must be finite"):
        validate_audit(f)


def test_reject_percentage_humidity():
    f = _frame()
    f["HREL"] = 65.0  # typical percent input, not the expected 0..1 WAC fraction
    with pytest.raises(ValueError, match="dimensionless fraction"):
        validate_audit(f)


def test_reject_percentage_humidity_at_writer(tmp_path):
    result = reconstruct_from_audit(_frame())
    result["HREL"] = 65.0
    with pytest.raises(ValueError, match="dimensionless fraction"):
        write_wac(result, tmp_path / "bad.wac")


def test_near_horizon_daylight_gap_inverse_clearness_index():
    import pvlib
    from python_tools.wac_from_audit import (
        MIN_COS_ZENITH, noaa_solar_zenith,
    )

    f = _frame()
    f["TIME"] = pd.date_range("2026-02-07 01:00", periods=len(f), freq="h")
    idx = 4 * 24 + 8  # Feb 11 at 09:00 fixed standard local time
    f.loc[idx, "source_available"] = 0
    rebuilt = reconstruct_from_audit(f)
    midpoint = pd.DatetimeIndex(f["TIME"] - pd.Timedelta(minutes=30))
    z = noaa_solar_zenith(midpoint)
    assert 0 < np.cos(np.deg2rad(z[idx])) < MIN_COS_ZENITH
    indices = [idx - 24, idx + 24]
    dni_extra = np.asarray(pvlib.irradiance.get_extra_radiation(midpoint.dayofyear), float)
    kts = pvlib.irradiance.clearness_index(
        ghi=f.loc[indices, "source_GHI"].to_numpy(float),
        solar_zenith=z[indices],
        extra_radiation=dni_extra[indices],
        min_cos_zenith=MIN_COS_ZENITH,
        max_clearness_index=1.0,
    )
    expected = float(np.mean(kts) * dni_extra[idx] * MIN_COS_ZENITH)
    assert rebuilt.loc[idx, "ISGH"] == pytest.approx(expected, abs=1e-8)
