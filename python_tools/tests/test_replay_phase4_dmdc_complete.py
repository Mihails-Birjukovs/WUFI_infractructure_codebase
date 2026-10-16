import numpy as np
import pandas as pd
import pytest

from python_tools.dmdc_phase4 import joint_ridge
from python_tools.replay_phase4_dmdc_complete import (
    RIDGE_GRID, FORCING_SETS, INPUT_NAMES, normalize_states,
    normalize_forcing, summarize_impulses, compare,
)


def test_recovered_grid_and_five_forcing_sets():
    assert RIDGE_GRID == (1e-3, 1e-2, 1e-1, 1., 10., 100.)
    assert len(FORCING_SETS) == 5
    assert FORCING_SETS["full"] == INPUT_NAMES
    assert FORCING_SETS["moisture_indoor"] == ("outdoor_pv_Pa", "indoor_pv_Pa")


def test_replay_on_known_synthetic_linear_model():
    rng = np.random.default_rng(2026)
    n = 500
    u = rng.normal(size=(n, 2))
    x = np.zeros((n, 2))
    y = np.zeros_like(x)
    for k in range(1, n - 1):
        x[k + 1] = .65*x[k] + .08*x[k-1] + .17*u[k, 0]
        y[k + 1] = .73*y[k] + .05*y[k-1] + .09*u[k, 0]
    a, b = normalize_states(x, y)
    control = normalize_forcing(u)
    result = joint_ridge(a, b, control, p=2, grid=RIDGE_GRID)
    assert result["ridge"] in RIDGE_GRID
    ae, be = result["experiment"]
    details = summarize_impulses(
        "HEMP27", "W1", 2, "exp", ae, be, ("temp_out", "outdoor_pv_Pa"))
    assert len(details) == 4
    assert all(1 <= row["peak_lag_h"] <= 72 for row in details)
    assert all(np.isfinite(row["integrated_abs_gain_72h"]) for row in details)
    assert sum(row["input"] == "outdoor_pv_Pa" for row in details) == 2


def test_archive_comparison_rejects_missing_keys():
    raw = pd.DataFrame([{"system": "HEMP27", "delay_h": 12, "peak": 1.}])
    report = compare(raw, raw.copy(), ("system", "delay_h"), ("peak",))
    assert report["rows"] == 1
    assert report["max_absolute_difference"]["peak"] == 0.
    with pytest.raises(ValueError, match="different key inventories"):
        compare(raw, raw.iloc[:0], ("system", "delay_h"), ("peak",))


def test_normalization_contract_and_zero_variance():
    x = np.array([[1.,2.],[2.,3.],[3.,4.],[4.,5.]])
    y = x*2 + 100
    a, b = normalize_states(x, y)
    np.testing.assert_allclose(a.mean(0), [0, 0], atol=1e-12)
    np.testing.assert_allclose(b.std(0), [2, 2], atol=1e-12)
    with pytest.raises(ValueError, match="constant"):
        normalize_forcing(np.ones((50, 2)))
