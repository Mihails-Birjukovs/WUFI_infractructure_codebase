"""Regularized delay DMDc reconstructed reference for REF/HEMP dynamics.

The original Phase-4 temporary source was not retained. This implementation
recreates the report's predictive Y = Z A^T + U B^T lag-regression method,
with a corrected propagation of forcing histories in impulse simulations.

States and controls have shape (samples, channels). Standardize/align upstream.
"""
from __future__ import annotations

import numpy as np


def _matrix(values: np.ndarray, name: str) -> np.ndarray:
    result = np.asarray(values, dtype=float)
    if result.ndim == 1:
        result = result[:, None]
    if result.ndim != 2 or not np.isfinite(result).all():
        raise ValueError(f"{name} must be a finite [n_samples, n_channels] array")
    return result


def delay_embed(x: np.ndarray, u: np.ndarray, p: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Create lagged predictors z_k, u_k and one-step targets y_(k+1)."""
    x, u = _matrix(x, "x"), _matrix(u, "u")
    if x.shape[0] != u.shape[0] or not isinstance(p, int) or p < 1 or x.shape[0] <= p + 1:
        raise ValueError("Require equal numbers of samples and 1 <= p < n_samples-1")
    z, controls, y = [], [], []
    for k in range(p - 1, len(x) - 1):
        z.append(x[k - p + 1:k + 1][::-1].reshape(-1))
        controls.append(u[k - p + 1:k + 1][::-1].reshape(-1))
        y.append(x[k + 1])
    return np.asarray(z), np.asarray(controls), np.asarray(y)


def fit_delay_dmdc(x: np.ndarray, u: np.ndarray, p: int = 12,
                   ridge: float = 1e-8) -> tuple[np.ndarray, np.ndarray]:
    """Ridge-regularized least squares; rows of A/B are output channels."""
    if ridge < 0:
        raise ValueError("ridge must be >= 0")
    z, ctrl, y = delay_embed(x, u, p)
    predictors = np.hstack([z, ctrl])
    if ridge > 0:
        # Augmented least squares avoids explicitly forming normal equations.
        regularizer = np.sqrt(ridge) * np.eye(predictors.shape[1])
        coef = np.linalg.lstsq(
            np.vstack([predictors, regularizer]),
            np.vstack([y, np.zeros((regularizer.shape[0], y.shape[1]))]),
            rcond=None,
        )[0].T
    else:
        coef = np.linalg.lstsq(predictors, y, rcond=None)[0].T
    split = z.shape[1]
    return coef[:, :split], coef[:, split:]


def impulse_response(
    a: np.ndarray, b: np.ndarray, p: int, n_state: int,
    forcing_index: int = 0, horizon: int = 72,
) -> np.ndarray:
    """Return a zero-initial-state response to a unit input at k=0.

    The lagged control vector is shifted each step; this is essential for a
    correct response when B contains delayed forcing coefficients.
    """
    a, b = np.asarray(a, dtype=float), np.asarray(b, dtype=float)
    if p < 1 or n_state < 1 or horizon < 1 or a.shape != (n_state, p * n_state):
        raise ValueError("State/model dimensions or horizon invalid")
    if b.ndim != 2 or b.shape[0] != n_state or b.shape[1] % p:
        raise ValueError("B must have n_state rows and p * n_control columns")
    n_ctrl = b.shape[1] // p
    if not 0 <= forcing_index < n_ctrl:
        raise ValueError("Invalid forcing channel")
    if not np.isfinite(a).all() or not np.isfinite(b).all():
        raise ValueError("A/B must be finite")
    history_state = np.zeros(p * n_state)
    history_control = np.zeros(p * n_ctrl)
    out = []
    for k in range(horizon):
        control = np.zeros(n_ctrl)
        if k == 0:
            control[forcing_index] = 1.0
        history_control = np.r_[control, history_control[: (p - 1) * n_ctrl]]
        next_state = a @ history_state + b @ history_control
        out.append(next_state.copy())
        history_state = np.r_[next_state, history_state[: (p - 1) * n_state]]
    return np.asarray(out)


def peak_and_memory(
    response: np.ndarray, dt_hours: float = 1.0, state_index: int = 0
) -> dict[str, float]:
    """Absolute peak, peak time and area/peak effective memory for one channel."""
    signal = _matrix(response, "response")
    if not 0 <= state_index < signal.shape[1] or dt_hours <= 0 or not len(signal):
        raise ValueError("Invalid response channel or time step")
    a = np.abs(signal[:, state_index])
    idx = int(np.argmax(a))
    peak = float(a[idx])
    return {
        "peak_gain": peak,
        "time_to_peak_h": float(idx * dt_hours),
        "effective_memory_h": float(np.sum(a) * dt_hours / peak) if peak > 0 else float("nan"),
    }
