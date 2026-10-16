import numpy as np
import pandas as pd
import pytest

from python_tools.hodmd_paperstyle_reference import (
    nearest_daily_mode, compare_paperstyle,
    SCAN_DELAYS, SCAN_RANKS,
)


def test_analytic_fb_mean_recovers_known_daily_mode():
    time = np.arange(480)
    x = np.vstack([
        np.sin(2*np.pi*time/24),
        np.sin(2*np.pi*time/18),
    ])
    result = nearest_daily_mode(x, delay=24, rank=2, trim_h=0)
    assert result["period24_h"] == pytest.approx(24., abs=.02)
    assert result["eig_abs"] == pytest.approx(1., abs=.002)
    assert "forward/backward" in result["algorithm"]


def test_paperstyle_comparison_keeps_historical_non_equivalence_explicit():
    keys = dict(system="HEMP27", window="W2", source="exp", delay_h=24, rank=6)
    a = pd.DataFrame([{**keys, "period24_h": 24.0, "eig_abs": 1.0}])
    b = pd.DataFrame([{**keys, "period24_h": 24.2, "eig_abs": .999}])
    report = compare_paperstyle(a, b)
    assert report["rows"] == 1
    assert report["period_count_within_0_1_h"] == 0
    assert report["median_abs_period_error_h"] == pytest.approx(.2)
    assert report["historical_equivalence"] is False


def test_delay_rank_grid_and_bad_inputs():
    assert len(SCAN_DELAYS) * len(SCAN_RANKS) == 24
    with pytest.raises(ValueError, match="Too few samples"):
        nearest_daily_mode(np.ones((2, 40)), delay=24, rank=6, trim_h=12)
