import numpy as np
import pandas as pd
import pytest

from python_tools.dmd import exact_dmd, delay_dmd, time_delay_snapshots
from python_tools.dmdc import delay_embed, fit_delay_dmdc, impulse_response, peak_and_memory
from python_tools.multiscale import split_bands, band_metrics, cutoff_robustness


def test_exact_dmd_known_linear_eigenvalues():
    # independent exponential dynamics, full rank snapshots
    time = np.arange(30)
    x = np.vstack([0.9**time, (-0.6)**time])
    result = exact_dmd(x, rank=2)
    np.testing.assert_allclose(
        np.sort_complex(result["eigenvalues"]), np.sort_complex([0.9, -0.6]), atol=1e-8
    )


def test_delay_snapshots():
    data = np.array([[0, 1, 2, 3, 4]], float)
    z = time_delay_snapshots(data, 3)
    np.testing.assert_array_equal(z, [[0, 1, 2], [1, 2, 3], [2, 3, 4]])
    assert delay_dmd(np.vstack([np.sin(np.arange(40)), np.cos(np.arange(40))]),
                     delays=4, rank=2)["rank"] == 2


def test_exact_dmd_rejects_zero():
    with pytest.raises(ValueError, match="Rank-zero"):
        exact_dmd(np.zeros((2, 30)))


def test_delay_dmdc_one_lag_recovers_linear_model():
    rng = np.random.default_rng(42)
    u = rng.normal(size=(400, 1))
    x = np.zeros((400, 1))
    for k in range(399):
        x[k + 1, 0] = 0.72 * x[k, 0] + 0.3 * u[k, 0]
    a, b = fit_delay_dmdc(x, u, p=1, ridge=1e-10)
    np.testing.assert_allclose(a, [[0.72]], atol=1e-5)
    np.testing.assert_allclose(b, [[0.3]], atol=1e-5)
    ir = impulse_response(a, b, p=1, n_state=1, horizon=4)
    np.testing.assert_allclose(ir[:, 0], [0.3, 0.216, 0.15552, 0.1119744], atol=1e-5)


def test_lagged_control_impulse_shifts():
    a = np.zeros((1, 2))
    b = np.array([[0.0, 1.0]])
    y = impulse_response(a, b, p=2, n_state=1, horizon=4)
    np.testing.assert_allclose(y[:, 0], [0, 1, 0, 0])
    assert peak_and_memory(y)["time_to_peak_h"] == 1.0


def test_multiscale_reconstruction():
    series = pd.Series(np.sin(np.arange(300) / 10.0))
    band = split_bands(series)
    np.testing.assert_allclose(
        (band["slow"] + band["event"] + band["fast"]).to_numpy(),
        series.to_numpy(), atol=1e-12,
    )
    scores = band_metrics(series, series)
    assert np.max(scores["rmse"]) < 1e-12
    assert len(cutoff_robustness(series, series)) == 27


def test_invalid_delay_embed_length():
    with pytest.raises(ValueError):
        delay_embed(np.ones((2, 1)), np.ones((2, 1)), p=2)
