# Python climate and residual-dynamics workflows

## 1. Build WAC inputs for WUFI

- Start from validated meteorological source records, with explicit sensor selection and hourly quality control.
- Build a continuous end-labelled hourly CSV in **fixed local standard time** with `TIME,TA,HREL,WD,WS,PMSL,source_GHI,source_available`.
- Generate WAC solar geometry, clear-sky-index gap correction and Erbs diffuse component:

```powershell
python python_tools/wac_from_audit.py climate_hourly_audit.csv climate.wac --latitude 56.97 --longitude 24.17 --utc-offset-hours 2
```

- Inspect the generated `WUFI®_WAC_02` header, 8-column data, nonnegative ISGH/ISD, site location, pressure convention, day/night transitions and import preview in WUFI before running any model.
- For new projects, use the actual site coordinates and audit the outcome against independently observed radiation. Original project climate audit files are **not bundled**.

## 2. Run simulations and align sensor data

This is handled by the separate [Mathematica production branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools). It builds project manifests, exports ASC, creates WXF, normalizes sensor timestamps and compares selected REF/HEMP cases. Export paired, quality-controlled hourly sensor and WUFI time series with documented units, depth selection and excluded periods.

## 3. Evaluate multiscale differences

```python
from python_tools.multiscale import band_metrics, cutoff_robustness

table = band_metrics(sensor_hourly, wufi_hourly, slow_hours=72, event_hours=12)
robustness = cutoff_robustness(sensor_hourly, wufi_hourly)
```

- `slow`: centered 72-hour mean;
- `event`: centered 12-hour mean minus slow;
- `fast`: original minus centered 12-hour mean.

The standard robustness grid is slow 48/72/96 h and event 8/12/18 h. Edges and missing values require separate consideration.

## 4. DMD and HODMD-style delay embedding

```python
from python_tools.dmd import exact_dmd, delay_dmd

dmd = exact_dmd(snapshots_channels_by_times, rank=2, dt_hours=1.0)
hodmd = delay_dmd(snapshots_channels_by_times, delays=12, rank=4, dt_hours=1.0)
```

Review discrete eigenvalues, continuous complex frequencies, rank selection, embedded dimension and parameter sensitivity. These are **new reference methods**, not byte-identical historical recovered scripts.

## 5. Delay DMDc and impulse diagnostics

```python
from python_tools.dmdc import fit_delay_dmdc, impulse_response, peak_and_memory

A, B = fit_delay_dmdc(state_samples_by_channels, forcing_samples_by_channels,
                      p=12, ridge=1e-8)
response = impulse_response(A, B, p=12, n_state=state_samples_by_channels.shape[1], horizon=72)
metrics = peak_and_memory(response)
```

A/B are linear predictive matrices fitted in **whatever units and standardized scale you supplied**; interpret peak gain, time-to-peak and area/peak persistence in that context. This implementation reconstructs published Phase-4 method definitions and advances lagged control inputs correctly, but does **not** demonstrate a causal physical interface mechanism.

## 6. Scientific acceptance

Run tests on synthetic fixtures, then independently cross-check climate reconstruction with approved historical WAC/audit data and modal/multiscale results with frozen REF/HEMP tables. Keep versioned parameter/rank/window choices and review physical assumptions before public release.
