# Phase-4 REF/HEMP delay-DMDc reference model

The archived 2026-08-24 modal report uses `x(t+1)=Σ A_j x(t-j)+B u(t)`,
**state lags but current forcing only**, for two target states `[T,p_v]`.
Input options include `[T_out,p_v,out,solar,wind,T_in,p_v,in]` and a
low-collinearity outdoor-`p_v`-only test. Two complete hourly windows were
W1: 1388 h and W2: 1393 h, scanned over p=6/12/24/48.

The existing `dmdc.py` is a legitimate **lagged-control extension**, but
is not the archived equation. Use `dmdc_phase4.py` for that equation class.

```python
from python_tools.dmdc_phase4 import joint_ridge, impulse, impulse_metrics, spectral_memory
# exp_x and model_x: (n_hours, 2) in the common experimental-SD scale
# u: aligned, normalized forcing (n_hours, n_inputs)
choice=joint_ridge(exp_x, model_x, u, p=12)
A,B=choice["experiment"]
gain=impulse_metrics(impulse(A,B,12,source=1,horizon=72),output=1)
memory=spectral_memory(A,12)
```

**Limitations:** historical code was not retained. The exact source QC masks,
forcing preprocessing, ridge grid, fit/validation scoring, and numerical arrays
are not present in archived summary tables. Numerical agreement with the
frozen historical results therefore remains **unverified**. No unpublished
sensor data are stored in this repository.
