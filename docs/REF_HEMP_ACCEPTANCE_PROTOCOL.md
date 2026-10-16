# REF/HEMP scientific-acceptance protocol (Python branch)

This checklist distinguishes **execution**, **archived-data integrity**,
**algorithmic parity**, and **application integration**. None is implied by
synthetic unit tests alone. The original REF/HEMP sensor data and model inputs
remain in the authorized Drive; never commit them to the public repository.

## WAC reconstruction

1. Use `Climate/Spilve_WAC_solar_correction/Spilve_solar_hourly_audit.csv`
   from authorized Drive and the approved original `ISGH_ISD` WAC.
2. Check 17,520 timestamps are fixed-standard-time, end-labelled, hourly
   without daylight-saving jumps; `HREL` is fractional (0..1), not percent.
3. Run `python python_tools/wac_from_audit.py AUDIT.csv REBUILT.wac`
   on the complete original audit, with project lat=56.97, lon=24.17,
   fixed UTC+2 and a documented pvlib version.
4. Compare both WACs with
   `python python_tools/validate_wac_reference.py AUDIT.csv REBUILT.wac`.
   **This tool compares against the archived audit's corrected outputs**,
   not against a mathematical reconstruction from raw meteorological data.
   Any discrepancy must list timestamps, absolute errors, GHI/DHI energy
   difference, radiation-gap method and a pre-agreed scientific tolerance.
5. Confirm solar sensor mounting/plane and meaning of MongoDB
   `solar_radiation`; the source report explicitly states this is an
   unresolved condition on interpreting the measured field as GHI.
6. Import in **licensed WUFI Pro** and inspect climate settings, units,
   time zone and sample hours. Only an actual WUFI run proves integration.

## Multiscale historic Phase-4

Archive: `Sensors VS WUFI/Phase_4_Multiresolution_Analysis/`.
The archived method is fourth-order zero-phase Butterworth, cutoff periods
72 h and 12 h, contiguous valid intervals at least 240 h, and 72 h
edge trimming. The report's reconstructed moving-average method is
**not numerically equivalent**. Verify using exact UTC-aligned hourly sensor
and WUFI time series: first 2025-11-27 16:00 UTC to
2026-04-08 09:00 UTC, with the original QC masks, and compare
`band_metrics.csv` and `cutoff_robustness.csv` by sensor, variable,
band, cutoff and sample count. The saved aggregates alone cannot be used
to recompute the filters or establish signal-level reproducibility.

## DMD, HODMD and DMDc Phase-4

Archive: `Sensors VS WUFI/Phase_4_DMD_Analysis/`.
The archived report records two continuous hourly windows:
W1 = 2025-12-12 12:00 UTC to 2026-02-08 07:00 UTC;
W2 = 2026-02-09 09:00 UTC to 2026-04-08 09:00 UTC.
Use only complete QC-aligned pairs and common experiment-SD scaling.
For delay-DMDc the documented equation is
`x[k+1] = Σ A_j x[k-j] + B*u[k]`: **current forcing only**.
Use the separate `python_tools/dmdc_phase4.py` reference,
not the more general lagged-control API in `dmdc.py`.

Match p=6,12,24,48 h, forcing-set definitions (especially outdoor
vapour pressure alone), ridge grid, 70/30 chronological training policy,
one-based impulse lag, 72 h integrated response and companion spectral
decay. Evaluate model-output parity separately from the accuracy of
archived gain-ratio and memory-ratio arithmetic.

The original Phase-4 source code was not preserved. Achieving identical
results also requires the original QC and cross-validation choices, so
**method-class match is not proof of historical numerical equality**.

## Application-level acceptance

Mathematica tools remain in `WUFI_mathematica_tools`. On an authorized
Windows machine with WUFI Pro 6.5 and Mathematica 12.1, run its
release-specific smoke/preflight suites and a small licensed WUFI climate
import / simulated case. Do not run large private batches by default.
Record versions, file hashes, expected vs actual output inventory and
errors without publishing source inputs.

## Outcomes to record

- Archive audit/WAC numerical consistency
- WAC generator full-data replay: passes / deviations and tolerances
- Multiscale signal-level replay: passes / blocked (missing aligned series)
- HODMD/DMDc signal-level replay: passes / blocked (missing aligned series)
- WUFI climate import: passes / blocked (no connected licensed desktop)
- Mathematica smoke and integration: passes / blocked (no connected desktop)
