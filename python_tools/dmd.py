"""Exact DMD and delay-embedded DMD (HODMD-style) research reference.

This is a new reference implementation for diagnostics described in the
WUFI Unified Report v1.4; it is not an archived historical source script.
Snapshots are columns, with uniform sampling and explicit truncation rank.
"""
from __future__ import annotations

import numpy as np


def _snapshots(data: np.ndarray) -> np.ndarray:
    array = np.asarray(data, dtype=float)
    if array.ndim != 2 or array.shape[1] < 3 or not np.isfinite(array).all():
        raise ValueError("Expected finite 2D snapshots of shape (features, times >= 3)")
    return array


def exact_dmd(data: np.ndarray, rank: int | None = None, dt_hours: float = 1.0) -> dict:
    """Compute exact DMD modes and discrete/continuous eigenvalues.

    Returns modes, eigenvalues, continuous omega, rank, initial amplitudes.
    No automatic centering or standardization is applied.
    """
    snapshots = _snapshots(data)
    if dt_hours <= 0:
        raise ValueError("dt_hours must be positive")
    x, y = snapshots[:, :-1], snapshots[:, 1:]
    u, singular, vh = np.linalg.svd(x, full_matrices=False)
    cutoff = np.finfo(float).eps * max(x.shape) * singular[0]
    numerical_rank = int(np.sum(singular > cutoff))
    if numerical_rank == 0:
        raise ValueError("Rank-zero snapshot matrix")
    if rank is None:
        r = numerical_rank
    else:
        if rank < 1 or rank > numerical_rank:
            raise ValueError(f"Rank must be between 1 and {numerical_rank}")
        r = rank
    u_r, s_r, v_r = u[:, :r], singular[:r], vh[:r].conj().T
    projected = u_r.conj().T @ y @ v_r / s_r
    eigenvalues, w = np.linalg.eig(projected)
    modes = (y @ v_r / s_r) @ w
    amplitudes = np.linalg.lstsq(modes, snapshots[:, 0], rcond=None)[0]
    omega = np.log(eigenvalues.astype(complex)) / dt_hours
    return {"eigenvalues": eigenvalues, "omega_per_hour": omega,
            "modes": modes, "amplitudes": amplitudes, "rank": r}


def time_delay_snapshots(data: np.ndarray, delays: int) -> np.ndarray:
    """Stack [x(t), x(t+1), ..., x(t+delays-1)] in each Hankel column."""
    data = _snapshots(data)
    if not isinstance(delays, int) or not (1 <= delays <= data.shape[1] - 2):
        raise ValueError("Invalid delay depth for input length")
    return np.concatenate(
        [data[:, i:data.shape[1] - delays + i + 1] for i in range(delays)],
        axis=0,
    )


def delay_dmd(data: np.ndarray, delays: int = 12, rank: int | None = None,
              dt_hours: float = 1.0) -> dict:
    """HODMD-style exact DMD of a delay-embedded snapshot trajectory."""
    embedded = time_delay_snapshots(data, delays)
    result = exact_dmd(embedded, rank, dt_hours)
    result["original_feature_count"] = _snapshots(data).shape[0]
    result["delays"] = delays
    return result
