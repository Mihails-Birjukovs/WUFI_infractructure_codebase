# Complete numerical reproduction of the archived Phase-4 HODMD benchmark

**Status — 17 October 2026:** the independent original-WXF replay has
reproduced all 112/112 rows of the frozen HODMD target-stability summary
at stringent numerical tolerances. This is NOT recovery of the missing
original transient HODMD source text, and the inference is retrospective.

## Original state vectors

The three two-channel systems are HEMP19, HEMP27 and REF118, each with
temperature and Buck vapour pressure derived from its raw sensor and
matched-depth WUFI signals.

The six-channel **HEMP_PRIMARY** was recovered as the ordered vector

    [T27, pv27, T42, pv42, T18, pv18]

HEMP19 is an independent diagnostic, not part of the six-channel state.
All inputs use original WXF files and hourly centered-window medians.
The two complete UTC periods are W1 (1388 h) and W2 (1393 h).

Each experiment and WUFI time series is centered independently; both
are scaled by the **experimental sample standard deviation (ddof=1)**
for each channel. This differs from the population-SD convention in
other analyses and must not alter DMDc.

## Inferred historical numerical algorithm

1. Stack real-valued time-delay Hankel snapshots.
2. Scan delays (12, 24, 36, 48, 72) h and ranks
   (4, 6, 8, 10, 12, 16, 20, 24).
3. Require rank strictly below channel count times delay, yielding
   39 two-channel and 40 six-channel admissible fits.
4. Solve the truncated exact DMD spectrum and keep strictly positive
   frequencies (angle of eigenvalue greater than zero).
5. Accept oscillatory modes only if the eigenvalue modulus satisfies

       |lambda| >= 0.9

   and target period P satisfies

       P/1.3 <= period <= 1.3*P

6. Select at most one eigenmode per rank/delay fit using the smallest
   absolute logarithmic period distance from P (ties by amplitude).
7. Archive nfits_found/nfits_total, median period, 10th/90th percentiles,
   growth-rate median, amplitude median, and the six first-physical-block
   reconstructed loading medians (as available for each system).

The modulus cutoff is numerically inferred. The frozen counts alone
constrain the allowable common decay-rate threshold to approximately
0.1034261452 to 0.1054301853 per hour. The physically interpretable
threshold 0.9 corresponds to -log(0.9)=0.1053605157 per hour and
lies within this narrow interval. **Different nearby thresholds could
produce the same 112 count values.** No original constant declaration
has been recovered.

## Independent source-WXF reproduction

All measurements and hourly WUFI outputs remain in the authorized private
REF & HEMP archive. The following figures are aggregate numerical checks,
not copied original data:

| Frozen HODMD output | Coverage | Maximum absolute difference |
| --- | ---: | ---: |
| Accepted-fit counts | 112/112 exact | 0 |
| Period medians | 112/112 | 2.16e-8 hours |
| 10th-period percentiles | 112/112 | 1.38e-6 hours |
| 90th-period percentiles | 112/112 | 7.31e-6 hours |
| Growth-rate medians | 112/112 | 1.36e-11 per hour |
| Mode-amplitude medians | 112/112 | 5.44e-10 |
| Loading components 0 and 1 | 112 each | 7.66e-10 maximum |
| Loading components 2,3,4,5 | 28 each | 8.09e-11 maximum |

The 112 rows encompass four systems, W1/W2, experiment/WUFI and
seven target periodicities (12,24,48,72,168,336,720 h).
The independent source analysis includes 468 admissible two-channel
fits containing 2654 positive-frequency candidate modes, plus
160 valid six-channel HEMP_PRIMARY fits.

The eigenvalues were also checked for four representative configurations
using independent full snapshot SVD. Period/growth discrepancies were
under 6.5e-8 h and 1.9e-12 per hour. The source reconstruction therefore
has a strong independent spectral validation basis.

## Secure replay

Install the Python requirements, then provide an authorized PRIVATE
five-sensor manifest (HEMP27, HEMP19, HEMP42, HEMP18, REF118). Each
sensor entry specifies its original sensor_wxf, model_temperature_wxf
and model_humidity_wxf, following the private manifest documented in
PHASE4_FULL_REPLAY.md.

From the repository root run:

    python -m python_tools.hodmd_historical_replay PRIVATE/five_sensor_manifest.json PRIVATE/hodmd_target_stability.csv --output-dir PRIVATE/hodmd_112_validation

The output directory contains a private 112-row summary, full spectrum,
fit-status records and aggregate JSON comparison. The runner uses strict
numerical thresholds (zero count difference, at most 1e-5 hours for
period summaries and 1e-8 for other numerical medians), and exits
nonzero if parity fails. Source hashes/library versions should be recorded
using scientific_input_manifest.py.

Never commit private WXFs, hourly series, mode catalogs, individual
archived output rows, or internal model data to the public repository.
The public GitHub CI runs synthetic tests only.

## What acceptance means

**Numerical acceptance of the frozen 112-row historical HODMD stability
benchmark is now achieved.** Unlike the earlier 67/84 candidate replay,
the new common eigenmode-quality gate explains all original fit counts
and all archived summary-statistical fields.

This was a retrospective recovery against the same historical outputs,
not a blind holdout experiment. It does not prove unique algorithm
identification or establish literal identity with the lost source code.
Retain the missing-source caveat in publication or code-release metadata.

The independent complex analytic-signal paper-style
480-fit HODMD cross-check is a DIFFERENT method and remains only
partially reproduced. Do not merge those results into this benchmark.


## Mode-ranking falsification checks

Keeping the same eigenvalue modulus >=0.9 and multiplicative 1.3
period gate, all of the following rankings reproduce the same **112
accepted-fit counts**. However, the number of archived **period medians**
reproduced within 1e-7 hours is:

| Candidate fit-mode ranking | Matching median periods |
| --- | ---: |
| Nearest absolute log-period distance | **112/112** |
| Nearest linear relative-period distance | 104/112 |
| Nearest relative frequency | 102/112 |
| Largest modal amplitude | 68/112 |

This is an important independent fingerprint of the recovered selection
rule, beyond matching its count statistics. It does not make the
retrospective reconstruction uniquely identifiable as original source.
