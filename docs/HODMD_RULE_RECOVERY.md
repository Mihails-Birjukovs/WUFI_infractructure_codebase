# Phase-4 HODMD original-rule recovery: auditable constraints and candidates

The original HODMD script is still missing. This branch deliberately avoids
modifying the earlier accepted DMDc implementation or declaring historical
HODMD numerical equivalence.

## Original archival evidence

The connected REF & HEMP Drive's \`Phase_4_DMD_Analysis\` contains:

- \`hodmd_target_stability.csv\`: **112 aggregate records**, 4 systems ×
  2 complete UTC windows × 2 sources × 7 target periodicities.
- \`paperstyle_hodmd_24h_crosscheck.csv\`: **480 individual per-fit
  records**, 5 systems × 2 windows × 2 sources × (4 delays × 6 ranks).
- \`modal_assessment_report.md\`: original 5 delays
  \`[12,24,36,48,72]\`, 8 ranks \`[4,6,8,10,12,16,20,24]\`,
  two state channels \`[T,p_v]\`; \`HEMP_PRIMARY\` has six channels.
- \`hodmd_24h_feasibility.csv\`: a separate feasibility analysis,
  not a retained HODMD original-spectrum catalog.

All 112 source-derived stability fractions are exactly
\`nfits_found / nfits_total\`; no inference is necessary for this identity.

## Rank admissibility hypothesis (not source-code recovery)

The nominal scan contains 40 combinations. Exactly **39** are reported
for the two-channel HEMP19, HEMP27 and REF118, but **40** for
six-channel \`HEMP_PRIMARY\`.

If \`rank < n_channels × delay\` was required (strict inequality), then
for the two-channel \`delay=12, rank=24\` configuration only,
the condition fails (24 is not less than 24). It passes for
six channels (24 < 72). This predicts the observed denominator
counts perfectly, but does **not** establish that strict inequality
rather than failed numerical rank or another exclusion was the
historical rule. Only the original per-fit validity log/code can do so.

## Target-period window bounds

The archived 10% and 90% accepted-period quantiles across all 112
rows imply that a *hard symmetric relative period window* must have
halfwidth **at least 0.2830929615** (28.31%), assuming the quantiles
indeed summarize only accepted-period fits and use that hard window.

- ±25% is incompatible with the archived quantiles in **10/112** rows.
- ±30% is **consistent** with all recorded quantiles, but may still
  exclude unobserved tails: it is a candidate, not a recovered rule.

The nearest-period selection, largest-amplitude selection,
growth-rate screen and relative-amplitude screen are kept as explicit,
parameterized hypotheses. None is asserted to be the historical policy.

## Critical archive separation / missing data

The 480-fit cross-check is a **different algorithm**, not the original
39/40-fit scan. Its fields \`growth_per_h\`, \`load_T\` and \`load_pv\`
are present for **288 of 480** fits (HEMP27, HEMP19, REF118), and
absent for HEMP42 and HEMP18 (192 rows).

Where present, \`growth_per_h\` equals \`log(eig_abs)\` to floating-point
precision, so it is **not an independent constraint** on the eigenvalue
transformation; it is a derived field. Loadings may constrain modes
independently only if the original amplitude/mode normalization is known.

## Reproducible archive-only constraints

With authorized local copies of the two archival CSVs:

\`\`\`powershell
python -m python_tools.hodmd_rule_recovery PRIVATE/hodmd_target_stability.csv PRIVATE/paperstyle_hodmd_24h_crosscheck.csv --output-json PRIVATE/hodmd_rule_constraints.json
\`\`\`

For a **private candidate full-eigenspectrum** table with columns
\`system,window,source,delay_h,rank,mode_id,period_h,growth_per_h,amplitude\`,
test a pre-registered candidate rule:

\`\`\`powershell
python -m python_tools.hodmd_rule_recovery PRIVATE/hodmd_target_stability.csv PRIVATE/paperstyle_hodmd_24h_crosscheck.csv --candidate-modes PRIVATE/full_modes.csv --target 24h --relative-halfwidth 0.30 --selection nearest_period --output-json PRIVATE/candidate_24h.json
\`\`\`

Always compare exact accepted-fit counts **before** using period
medians/quantiles, amplitude or modal loadings to refine a rule.
Use HEMP27 W1 for rule exploration, then hold out HEMP19, REF118
and W2 for independent validation. Do not choose parameters after
viewing the held-out targets. \`HEMP_PRIMARY\` needs its own
six-channel aligned inputs; don't substitute any two-channel data.

## Source search completed

- The Drive report and the two named archive files each expose only
  **one retained version**; no older source-bearing revisions were
  discoverable through Drive version history.
- Search of the connected Drive and available WUFI repository source
  did not locate the transient Phase-4 original HODMD script.
- A Gmail search found HODMD mentions in correspondence/report
  attachments but no HODMD source-code attachment in the reviewed
  hits.

## Scientific status

**Recovered exactly:** archived fractions from numerator/denominator.
**Strong hypotheses:** one invalid (12,24) two-channel fit; approximate
±30%-target period admission window.
**Unrecovered:** full original eigenmode spectrum, amplitude threshold,
mode ranking, analytic-signal preprocessing for the main HODMD scan,
numeric rank tolerance, and modal stability acceptance logic.

No acceptance/release threshold has been changed. See
\`docs/HODMD_PAPERSTYLE_NUMERICAL_COMPARISON.md\` for the distinct
480-fit cross-check and remaining numerical mismatch.

## Generate full candidate spectra without the original HODMD code

The original archive lacks a per-fit, per-eigenmode spectrum. To test
period-window and ranking hypotheses rather than infer them from only
quantiles, \`python_tools/hodmd_mode_catalog.py\` regenerates **all**
positive-frequency modes for a transparent reference *real-valued*
delay-DMD implementation.

Input: private three-sensor WXF manifest with HEMP19, HEMP27, REF118.
The 6-channel \`HEMP_PRIMARY\` is intentionally excluded because its
specific combined state matrix is not contained in that manifest.

\`\`\`powershell
python -m python_tools.hodmd_mode_catalog PRIVATE/three_sensors.json --output-dir PRIVATE/hodmd_rules
python -m python_tools.hodmd_rule_recovery PRIVATE/hodmd_target_stability.csv PRIVATE/paperstyle_hodmd_24h_crosscheck.csv --candidate-modes PRIVATE/hodmd_rules/hodmd_private_full_modes.csv --valid-fits PRIVATE/hodmd_rules/hodmd_private_fit_status.csv --target 24h --relative-halfwidth 0.30 --selection nearest_period
\`\`\`

\`hodmd_private_full_modes.csv\` contains per-mode period, growth, modulus
and first-physical-block contribution estimates. \`hodmd_private_fit_status.csv\`
separately lists **all nominal fit attempts**, including exclusions and
numerically failed fits. This is required to distinguish a fit that
contains no positive-frequency modes from an invalid fit, and to count
denominators correctly.

**This is not historical HODMD identity.** Real delay-DMD, unlike the
paper-style complex analytic forward/backward operator, has different
modes and amplitudes. Any apparent rule fit is conditional on matching
the original spectral generation method. Do not export the private
per-mode catalog into public GitHub.


## Growth-rate sign audit (17 October 2026)

Every one of the **112** archived original stability-summary rows has
\`growth_median_per_h < 0\`. This does **not** imply that every accepted
mode decayed; it only constrains the selected-modes' group medians.
By contrast, in the separate *paper-style* 480-fit archive,
\`growth_per_h\` is populated in **288** rows; **263** of these are
positive and **25** negative, and \`growth_per_h = log(eig_abs)\` exactly
to floating-point precision.

This discrepancy strongly reinforces the need to treat the original
stability extraction and the paper-style analysis as distinct operator
and/or mode-selection procedures, rather than substituting one archive
for the other. \`--require-nonpositive-growth\` is now an explicit
**hypothesis test** in the candidate-rule CLI; it is NOT asserted as
the historical filtering rule.
