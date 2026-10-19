# Multiscale, DMD and DMDc diagnostics

These methods analyse quality-controlled, regularly sampled model/sensor series. They do **not** estimate WUFI physical parameters automatically and do not establish causation from correlations.

## Multiscale methods are not interchangeable

| Historical Phase-4 method | Report-reconstructed reference |
| --- | --- |
| Fourth-order zero-phase Butterworth separation | Centered moving-window means |
| Slow >72 h; middle 12–72 h; fast <12 h | 72 h slow, 12 h average for event/fast splitting |
| Min. contiguous run 240 h, trim 72 h from ends | Centered windows subject to edge effects |
| Archived analysis method JSON | [multiscale.py](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/multiscale.py) |

Use [multiscale_butterworth.py](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/multiscale_butterworth.py) for a separately developed code path that mirrors the archival **method class**. The original temporary script was not recovered.

~~~python
from python_tools.multiscale_butterworth import butterworth_band_metrics

metrics = butterworth_band_metrics(
    sensor, model,
    slow_hours=72, event_hours=12,
    min_segment_hours=240, trim_hours=72
)
~~~

## DMD and delay/HODMD reference

DMD operates on sequential state snapshots. Delay embedding adds time history but makes results sensitive to state scaling, rank, delay depth and mode-selection rules.

~~~python
from python_tools.dmd import exact_dmd, delay_dmd

dmd = exact_dmd(snapshots, rank=2, dt_hours=1)
hodmd = delay_dmd(snapshots, delays=12, rank=4, dt_hours=1)
~~~

Here snapshots are a numeric array shaped (channels, successive **uniformly sampled** time steps). This is a new reference module; it is **not** the lost original Phase-4 source.

## Delay DMDc

DMDc includes measured/exogenous forcing. Control-history propagation and regularization must be stated; impulse gains and memory summaries are in chosen scaled units and **are not causal attribution**.

~~~python
from python_tools.dmdc import fit_delay_dmdc, impulse_response, peak_and_memory

a, b = fit_delay_dmdc(x, u, p=12, ridge=1e-8)
response = impulse_response(a, b, p=12, n_state=x.shape[1], horizon=72)
summary = peak_and_memory(response, dt_hours=1)
~~~

Here x/u are aligned **(samples, variables)** arrays. Source-WXF refits reproduce archived DMDc tabulations under an inferred chronological ridge-selection method; source reconstruction is not original-source recovery or prospective validation.

## Archival comparison boundaries

The private historical analyses have extensive independent numerical replay, including the 112-row HODMD stability study, but with reconstructed parameter rules and not an original lost implementation. Claims must identify exactly **what is compared**: output values, selection predicates, archival WXF data, current Python source or a fresh WUFI run.

See [Python source provenance](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/PROVENANCE.md), [HODMD results](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/HODMD_COMPLETE_NUMERICAL_REPRODUCTION.md), and [DMDc replay](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/DMDc_COMPLETE_NUMERICAL_REPRODUCTION.md).

## Method attribution

The local routines are **separate Python reference implementations**, not third-party DMD packages. Credit [Schmid (2010)](https://doi.org/10.1017/S0022112010001217) and [Tu et al. (2014)](https://doi.org/10.3934/jcd.2014.1.391) for DMD, [Le Clainche & Vega (2017)](https://doi.org/10.1137/15M1054924) for HODMD, and [Proctor, Brunton & Kutz (2016)](https://doi.org/10.1137/15M1013857) for DMDc. Full verified references and implementation-scope distinctions appear in [Research & references](references.md).
