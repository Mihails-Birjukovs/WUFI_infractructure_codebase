import pandas as pd
import pytest
from python_tools.diagnose_solar_gap_kt import diagnose


def _audit():
    return pd.DataFrame({
        "TIME": pd.date_range("2026-01-01 12:00", periods=49, freq="h"),
        "source_available": [True]*49,
        "source_GHI": [100.]*49,
        "solar_zenith_deg": [70.]*49,
        "cos_zenith": [0.3]*49,
        "extraterrestrial_DNI_Wm2": [1400.]*49,
        "clearness_index_kt": [100/420.]*49,
        "corrected_ISGH_Wm2": [100.]*49,
        "solar_value_method": ["measured MongoDB hourly mean"]*49,
    })


def test_archived_daylight_gap_audit_detects_local_override():
    a = _audit()
    a.loc[24, "source_available"] = False
    a.loc[24, "source_GHI"] = float("nan")
    a.loc[24, "solar_value_method"] = "source gap: same-hour kt interpolation (bracketed)"
    report, discrepancies = diagnose(a)
    assert report["daylight_gap_count"] == 1
    assert report["gaps_deviating"] == 0
    assert discrepancies.empty
    a.loc[24, "clearness_index_kt"] *= .97
    a.loc[24, "corrected_ISGH_Wm2"] *= .97
    report, deviations = diagnose(a)
    assert report["gaps_deviating"] == 1
    assert float(deviations.GHI_difference_Wm2.iloc[0]) == pytest.approx(3.)


def test_invalid_archive_input():
    with pytest.raises(ValueError, match="Missing audit columns"):
        diagnose(pd.DataFrame())
