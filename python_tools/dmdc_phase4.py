"""Reference implementation of the documented Phase-4 state-lag DMDc model.

x[k+1] = sum_j A_j*x[k-j] + B*u[k], j=0..p-1.
The archived Phase-4 script is not available: this is NOT a claim of exact
historic numerical reproducibility. Inputs must be hourly QC-aligned with
experiment/WUFI centered separately, scaled by experimental SD.
"""
from __future__ import annotations
import numpy as np


def _mat(a, name):
    v = np.asarray(a, float)
    if v.ndim == 1:
        v = v[:, None]
    if v.ndim != 2 or not np.isfinite(v).all():
        raise ValueError(f"{name} must be finite two-dimensional")
    return v


def design(x, u, p):
    x, u = _mat(x, "x"), _mat(u, "u")
    if len(x) != len(u) or not isinstance(p, int) or not 1 <= p < len(x)-1:
        raise ValueError("Invalid alignment or lag order")
    z = np.array([x[k-p+1:k+1][::-1].reshape(-1)
                  for k in range(p-1, len(x)-1)])
    return z, u[p-1:-1], x[p:]


def fit(x, u, p=12, ridge=1e-8):
    if not np.isfinite(ridge) or ridge < 0:
        raise ValueError("Invalid ridge")
    z, ctrl, y = design(x, u, p)
    X = np.hstack((z, ctrl))
    if ridge:
        beta = np.linalg.lstsq(
            np.vstack((X, np.sqrt(ridge)*np.eye(X.shape[1]))),
            np.vstack((y, np.zeros((X.shape[1], y.shape[1])))),
            rcond=None)[0]
    else:
        beta = np.linalg.lstsq(X, y, rcond=None)[0]
    return beta[:z.shape[1]].T, beta[z.shape[1]:].T


def joint_ridge(exp_x, model_x, u, p=12, grid=(0., 1e-8, 1e-6, 1e-4, 1e-2),
                train_fraction=.7):
    """Joint chronological 70/30 one-step validation (teacher forcing).

    Archived source does not specify the exact original crossvalidation
    scoring or grid; this is a documented, explicit reference choice.
    """
    e, m, u = _mat(exp_x, "exp"), _mat(model_x, "model"), _mat(u, "u")
    if len(e) != len(m) or len(e) != len(u) or e.shape[1] != m.shape[1]:
        raise ValueError("Input shapes disagree")
    if not 0 < train_fraction < 1:
        raise ValueError("Invalid split")
    cases = [design(e,u,p), design(m,u,p)]
    n = len(cases[0][2])
    ntrain = int(n*train_fraction)
    if ntrain < p or n-ntrain < 3:
        raise ValueError("Insufficient samples for the chosen split")
    candidates = []
    for ridge in grid:
        if ridge < 0 or not np.isfinite(ridge):
            raise ValueError("Invalid ridge grid")
        models, errors = [], []
        for z, ctrl, y in cases:
            X = np.hstack([z, ctrl])
            a, b = (np.linalg.lstsq(
                np.vstack((X[:ntrain], np.sqrt(ridge)*np.eye(X.shape[1]))),
                np.vstack((y[:ntrain], np.zeros((X.shape[1],y.shape[1])))),
                rcond=None)[0] if ridge else
                np.linalg.lstsq(X[:ntrain], y[:ntrain], rcond=None)[0])
            # a is actually the full coefficients; b is residuals from lstsq
            coef = a
            errors.append(float(np.mean((X[ntrain:]@coef - y[ntrain:])**2)))
            models.append((coef[:z.shape[1]].T, coef[z.shape[1]:].T))
        candidates.append((sum(errors), ridge, errors, models))
    if not candidates:
        raise ValueError("Empty ridge grid")
    best=min(candidates,key=lambda q:(q[0],q[1]))
    return {"ridge":best[1], "validation_mse":best[2],
            "experiment":best[3][0], "model":best[3][1],
            "training_rows":ntrain,"validation_rows":n-ntrain}


def impulse(a, b, p, source=0, horizon=72):
    """Return responses at times 1..horizon h after unit u[0] impulse."""
    a, b = _mat(a, "A"), _mat(b, "B")
    n, inputs = b.shape
    if a.shape != (n, p*n) or not 0 <= source < inputs or horizon < 1:
        raise ValueError("Model dimensions or horizon invalid")
    state = np.zeros(p*n)
    out = np.empty((horizon,n))
    for k in range(horizon):
        force = np.zeros(inputs)
        if k == 0:force[source]=1.
        nxt = a@state + b@force
        out[k] = nxt
        state = np.r_[nxt, state[:(p-1)*n]]
    return out


def impulse_metrics(response, output=0, dt_hours=1.):
    a = _mat(response, "response")
    if not 0 <= output < a.shape[1] or dt_hours <= 0:
        raise ValueError("Bad output or sample spacing")
    amp = np.abs(a[:,output])
    i = int(np.argmax(amp))
    return {"peak_abs_gain_std":float(amp[i]),
            "peak_lag_h":float((i+1)*dt_hours),
            "integrated_abs_gain":float(np.sum(amp)*dt_hours)}


def spectral_memory(a, p, dt_hours=1.):
    a = _mat(a, "A")
    n=a.shape[0]
    if a.shape[1] != p*n or p < 1 or dt_hours <= 0:
        raise ValueError("Invalid companion dimensions")
    companion = np.zeros((p*n,p*n))
    companion[:n,:] = a
    if p>1: companion[n:,:-n]=np.eye((p-1)*n)
    rho=float(np.max(np.abs(np.linalg.eigvals(companion))))
    return {"spectral_radius":rho, "dominant_decay_time_h":
            float(-dt_hours/np.log(rho)) if 0<rho<1 else float("inf")}
