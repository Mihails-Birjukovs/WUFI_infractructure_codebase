import numpy as np
import pytest
from python_tools.replay_phase4_multiscale import best_lag_correlation, metrics


def test_positive_lag_means_model_follows_sensor():
    rng = np.random.default_rng(123)
    original = rng.normal(size=1000)
    sensor, model = original[:-3], original[3:]
    # In this test model leads sensor by 3, hence a negative shift.
    corr, lag = best_lag_correlation(sensor, model)
    assert lag == -3
    assert corr == pytest.approx(1., abs=1e-14)


def test_signed_absolute_correlation_and_lag_selection():
    rng = np.random.default_rng(2026)
    x = rng.normal(size=600)
    y = np.r_[np.zeros(2), -x[:-2]]
    corr, lag = best_lag_correlation(x, y)
    assert lag == 2
    assert corr == pytest.approx(-1., abs=1e-14)
    summary = metrics(x, y, compute_lag=True)
    assert summary["best_lag_h"] == lag
    assert summary["best_lag_corr"] == pytest.approx(corr)


def test_constant_and_short_sequences_rejected():
    with pytest.raises(ValueError, match="Undefined lag correlation"):
        best_lag_correlation(np.ones(100), np.ones(100))
    with pytest.raises(ValueError, match="Not enough"):
        best_lag_correlation(np.arange(7), np.arange(7))
