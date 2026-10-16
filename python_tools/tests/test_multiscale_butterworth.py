import numpy as np
import pandas as pd
import pytest

from python_tools.multiscale_butterworth import butterworth_bands, butterworth_band_metrics


def _example(n=600):
    t = pd.date_range("2026-01-01", periods=n, freq="h")
    x = np.sin(2*np.pi*np.arange(n)/24) + 0.1*np.cos(2*np.pi*np.arange(n)/144)
    return pd.Series(x, index=t)


def test_butterworth_reconstructs_and_trims():
    x = _example()
    b = butterworth_bands(x)
    for name in b:
        assert b[name].iloc[:72].isna().all()
        assert b[name].iloc[-72:].isna().all()
        assert b[name].iloc[72:-72].notna().all()
    reconstructed = sum(b.values())
    np.testing.assert_allclose(reconstructed.iloc[72:-72], x.iloc[72:-72], atol=1e-9)
    assert (b["diurnal_synoptic"].iloc[100:500].std() >
            b["slow"].iloc[100:500].std())


def test_butterworth_exact_self_comparison():
    x = _example()
    m = butterworth_band_metrics(x, x)
    assert set(m["band"]) == {"slow", "diurnal_synoptic", "event"}
    assert np.max(m["rmse"]) < 1e-10
    assert set(m["n"]) == {len(x) - 144}


def test_split_segment_does_not_bridge_gap():
    x = _example()
    x.iloc[300] = np.nan
    b = butterworth_bands(x, min_segment_hours=240, trim_hours=72)
    # Two segments, 300 and 299 valid hourly samples, each loses 144 edges.
    assert b["slow"].notna().sum() == 300 - 144 + 299 - 144
    assert b["slow"].iloc[300] != b["slow"].iloc[300]


def test_short_segments_excluded():
    x = _example(200)
    assert butterworth_bands(x)["slow"].isna().all()


def test_bad_timestamp_spacing():
    x = _example()
    x.index = x.index + pd.Timedelta(minutes=30)
    with pytest.raises(ValueError, match="exact hourly"):
        butterworth_bands(x)
