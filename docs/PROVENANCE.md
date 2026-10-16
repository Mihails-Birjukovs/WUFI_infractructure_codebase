# Python source lineage and limitations

**Authoritative scientific source:** *WUFI Unified Report, draft v1.4* (2026), especially Appendix I for selected Python implementations, Appendix G for modal/multiscale methods, and Appendix J for software provenance.

## Lineage

- **WAC:** `python_tools/wac_from_audit.py` adapts the *retained project script* reproduced in Appendix I.1. It uses NOAA/GML solar geometry, fixed-standard-time end-labelled hourly timestamps, astronomical-night zeroing, source-gap clearness-index interpolation and `pvlib.irradiance.erbs`.
- **Multiscale:** `python_tools/multiscale.py` is a cleaned-up **reconstructed reference implementation**. Appendix I.3 states that the original Phase-4 temporary source file was not recovered, and gives a methodological reconstruction.
- **Delay DMDc:** `python_tools/dmdc.py` is likewise a **reconstructed reference** from Appendix I.4, not original recovered code. Lagged control history is propagated in impulse responses; this corrects a compact historical listing's oversimplified one-time input history.
- **Exact DMD and delay DMD/HODMD-style:** `python_tools/dmd.py` is a **new reference implementation**. This code was not presented as a retained historical module in the report.

Do not use these results to claim numerical identity to the original Phase-4 implementation. Historical tables/figures are independent frozen evidence, requiring separately authorized comparison.

## Solar geometry provenance

The historical reconstructed WAC uses **56.97 N, 24.17 E**. The physical test-house report specifies **56.985411 N, 24.085193 E**. This difference is retained for research reproducibility; alternate coordinates require an explicitly labelled new analysis. Fixed WAC time is **UTC+2**, not DST-adjusting `Europe/Riga`.

## Scientific interpretation limits

- Missing meteo radiation is not always repairable using same-hour interpolation: new projects should use station/reanalysis support where warranted.
- Multiscale windows are centered and edge-biased; missing observations and low-variance bands need checking.
- Modal/HODMD eigenspectra are rank-, embedding-, scaling- and preprocessing-dependent.
- DMDc is a linear predictive state/forcing model. Its impulse gain and delay metrics are *diagnostic* associations, not causal proof of a material defect or interface leakage.
- The generated examples are **synthetic**, not REF/HEMP evidence.

## What remains separate

The actual Mathematica launcher, post-processor and sensor comparison production releases remain in the [Mathematica branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools). REF/HEMP monitoring records, production weather audits, physical WUFI models, calibration artifacts and validation tables are not copied into this public repository.

See [branch policy](BRANCHING.md).

## Historical method non-equivalence identified in Drive archive

The archived **Phase-4 multiresolution** `analysis_method.json` specifies a **fourth-order zero-phase Butterworth filter**, slow band above 72 h, 12–72 h middle band, events below 12 h, complete contiguous intervals at least 240 h, and **72 h edge trimming** per segment. By contrast, the report's Appendix I.3 reconstructed pseudocode—and `python_tools/multiscale.py`—uses **centered moving means**. Its numerical results are *not expected to reproduce* the archived Phase-4 `band_metrics.csv` or `cutoff_robustness.csv` exactly. A separate historical Butterworth implementation with the original QC-aligned input series would be required for that comparison. This limitation is recorded rather than misrepresenting the module as already historically validated.
