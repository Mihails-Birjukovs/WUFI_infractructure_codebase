# REF/HEMP scientific follow-up: calibration scenarios, HODMD nulls and recursive DMDc

Study performed on original authorized REF/HEMP sensor WXFs, W1/W2, 18 October 2026. Status: exploratory scientific validation, not instrument-calibration sign-off, a significance study, or a new archived numerical replay policy. No original measurements or private source hashes are committed.

## Calibration uncertainty scenarios

The original canonical v3 calibration registry marks HEMP19 as diagnostic/excluded from default calibration; HEMP27 and REF118 RH as conditional primary (qualitative weight 0.5); HEMP42 and HEMP18 as primary (weight 1). These weights are not uncertainty standard deviations.

A scenario with uniform systematic ±0.3 °C and ±2 RH percentage-point offsets (NOT certified accuracy) yields a median full envelope in derived Buck vapour pressure from 33 to 180 Pa across sensor/window combinations, approximately 8.2 to 12.2% of baseline median signal. Static-offset HODMD 24-hour accepted counts did not change in any of 10 cases when tested against all four bias corners in a six-fit rank/delay subset. No conclusion is drawn about drift, saturation nonlinearities or time-varying noise.

## AR(1) red-noise surrogate pilot

Each two-channel recorded series was compared with 99 correlated-innovation stationary AR(1) realizations. Six valid rank/delay fits per case: delays 24/48, ranks 6/10/16; original HODMD acceptance thresholds (factor 1.3, eigenvalue modulus >=0.9).

| Sensor | W1 original /6 | W2 original /6 | W1 empirical upper-tail fraction | W2 |
| --- | ---: | ---: | ---: | ---: |
| HEMP27 | 6 | 6 | 0.01 | 0.01 |
| HEMP19 | 5 | 6 | 0.20 | 0.01 |
| HEMP42 | 2 | 5 | 1.00 | 0.05 |
| HEMP18 | 2 | 4 | 1.00 | 0.11 |
| REF118 | 3 | 6 | 0.66 | 0.01 |

Tail fraction is (1+number of null draws with count >= observed)/100. It is NOT a physical p-value: only first-order memory/innovation covariance are matched, not the measured spectrum, seasonal trend or other physical influences. Results are exploratory and uncorrected for multiple comparisons.

## Genuine multi-step state recursion

60% train / 20% ridge selection on validation / 20% untouched test, split on TARGET hour (prevents one-hour boundary leakage). All preprocessing uses TRAINING-only statistics. At each 12-hour-spaced issuance, the next 72 hours are generated without any future true state values; only realized subsequent OUTDOOR meteorology is supplied as an oracle. Eighteen overlapping forecast origins per case; comparisons use issuance-state persistence and joint standardized temperature/vapour-pressure RMSE.

| Sensor/window | 1h ratio, T+pv+solar | 72h ratio, T+pv+solar | 72h ratio, pv only |
| --- | ---: | ---: | ---: |
| HEMP27 W1 | 0.518 | 0.356 | 0.575 |
| HEMP27 W2 | 0.527 | 0.425 | 0.744 |
| HEMP19 W1 | 0.636 | 0.308 | 0.595 |
| HEMP19 W2 | 0.664 | 0.512 | 0.806 |
| HEMP42 W1 | 0.440 | 2.839 | 1.231 |
| HEMP42 W2 | 0.435 | 4.457 | 1.993 |
| HEMP18 W1 | 0.575 | 2.584 | 1.133 |
| HEMP18 W2 | 0.988 | 1.537 | 0.653 |
| REF118 W1 | 0.428 | 0.443 | 0.542 |
| REF118 W2 | 0.319 | 1.620 | 1.806 |

Ratios below one outperform persistence. Forecasts use known future measured outdoor forcing: an optimistic hindcast, NOT an operational forecast. Overlapping 18 origins do not provide independent replicates; confidence bounds are not asserted. The heterogeneous outcome warns against universal predictive claims.

## Reproduce with PRIVATE authorized data

Prepare five original sensor WXFs with their established names and a compatible hourly median meteorology CSV containing TIME_UTC, temp_out, humidity_out and solar_radiation. Execute from the repository root:

    OPENBLAS_NUM_THREADS=1 python -m python_tools.scientific_phase_e PRIVATE/sensors PRIVATE/meteo_hourly_median.csv --sensors HEMP27 HEMP19 HEMP42 HEMP18 REF118 --draws 99 --output-json PRIVATE/phase_e.json

GitHub CI only executes synthetic tests. The historical HODMD/DMDc code is unchanged; the WAC strict 3-gap mismatch, unapproved exception, radiometer plane/calibration and WUFI/Mathematica application gates remain open.

## Proposed next research gate

Obtain real serial-specific calibration uncertainties and sensor drift, implement realistic spectral/multivariate seasonal surrogates with preregistration and multiplicity handling, and test recursive forecast transfer across independent campaigns using operational weather predictions and more independent forecast origins. Do not tag a publication-grade scientific release yet.
