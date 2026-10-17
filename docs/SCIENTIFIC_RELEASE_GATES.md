# Reproducibility, baseline acceptance and release gates

The permanent branches remain separate: Python source in
\`WUFI_python_tools\` and Wolfram source in \`WUFI_mathematica_tools\`.
Never merge the branches into one another. Use temporary PR branches
targeting the relevant permanent branch.

## Reproducible source fingerprint

The private original REF/HEMP WXF data, model files, weather audit,
archived WAC and historical metric CSVs must stay in the authorized archive.
Capture their exact SHA-256 fingerprints without publishing the data:

\`\`\`powershell
python -m python_tools.scientific_input_manifest --git-commit YOUR_EXACT_SHA --file weather_audit=PRIVATE/Spilve_solar_hourly_audit.csv --file production_wac=PRIVATE/Spilve_exterior_full_2025_2026_padded_solar_corrected_Erbs_ISGH_ISD.wac --output-json PRIVATE/release_input_manifest.json
\`\`\`

At any later time check for source drift:

\`\`\`powershell
python -m python_tools.scientific_input_manifest --verify PRIVATE/release_input_manifest.json --file weather_audit=PRIVATE/Spilve_solar_hourly_audit.csv --file production_wac=PRIVATE/Spilve_exterior_full_2025_2026_padded_solar_corrected_Erbs_ISGH_ISD.wac
\`\`\`

The tool records logical labels, filename, SHA-256, byte length,
Python/library versions and exact Git commit when supplied, but
**no absolute paths and no raw contents**. Keep private manifests private
unless sharing is cleared. A checksum match is an integrity check,
**not** a scientific-equivalence pass.

## Current independent acceptance evidence (2026-10-17)

| Gate | Status |
|---|---|
| Basic Python unit tests and synthetic examples | Passing on Python 3.11/3.12/3.13 through GitHub Actions |
| Archived 17,520-row WAC versus its source audit | Internal reference consistency passes |
| Independent solar-equation reconstruction | 17,517 rows within 1e-6 W/m²; three near-horizon gap deviations max 0.216 W/m² |
| Execute current repository's pvlib generator against full private audit | **Pending**; CI only exercises synthetic input, and private audit must remain outside public CI |
| Historical Phase-4 Butterworth main 60/60 nonlag metric rows | Independently regenerated from raw sensor and WUFI WXF, max absolute RMSE difference 4.31e-9 |
| Historical Phase-4 RH cutoff robustness 135/135 rows | Independently regenerated, max absolute RMSE difference 2.19e-7 |
| Historical multiscale main best-lag fields | **60/60 best lags exactly reproduced**, correlations within 3.95e-10 |
| Phase-4 DMDc 90 forcing-set robustness rows | **Numerically reproduced, all 180 experiment/WUFI peak lags exact**, max peak-gain ratio error 0.003463 |
| Phase-4 DMDc 40 spectral-memory rows | **Numerically reproduced**, max spectral-radius error 8.31e-6 and max memory ratio error 0.000292 |
| Phase-4 DMDc 960 six-input impulse rows | **Numerically reproduced, all 960 peak lags exact**, max individual peak-gain error 1.99e-5 |
| Original Phase-4 DMDc transient source code | Not recovered; ridge grid and fit policy inferred numerically from independent original-data benchmarks |
| Historical HODMD target-stability summary | **112/112 rows numerically reproduced** from original WXF using inferred period, modulus and rank gates; original script remains unavailable |
| Independent 480-fit paper-style HODMD cross-check | Median period mismatch 0.392 h at 24-h trim; **not** historic numerical equivalence |
| Wolfram 15/Linux cloud postprocessor smoke | 13/14 pass; only fresh-kernel graphics test failed; no launchable subkernels |
| Definitive Mathematica 12.1/Windows + WUFI Pro 6.5 | **Blocked** until authorized connected workstation |

## Scientific numerical thresholds

Do **not** silently replace a strict byte/numeric parity threshold with an
arbitrary permissive tolerance. The WAC replay defaults to 1e-6 W/m²
strict comparison. An additional science tolerance is allowed only with
explicit recorded rationale; the script does not assume one.

The multiscale archived metric tests now check every numeric field,
including the signed maximal absolute Pearson lag-correlation over ±24 h,
and all sample counts; only the private input streams are needed for replay.
Historical hourly WXF, CSV and WAC sources are not published here.

## Release freeze rule

This repository must not be labelled historically equivalent or
publication-grade solely because its synthetic GitHub Actions tests pass.
A publication release or tag should follow independently approved WAC
solar source interpretation and full pvlib replay, historical HODMD
equivalence (or explicit limitation disclosure), and
WUFI/Mathematica production-platform acceptance. Record the Git SHA,
dependency versions and private input checksums before any release.

See \`docs/WAC_FULL_REPLAY.md\`, \`docs/PHASE4_FULL_REPLAY.md\`,
\`docs/DMDc_FULL_REPLAY.md\`, and \`docs/HODMD_REFHEMP_REPLAY.md\`.


## HODMD rule-forensics update (17 October 2026)

Full original HODMD numerical equivalence is still **open**, despite
reproduced DMDc and multiscale benchmarks. The independent archive audit
shows 39 two-channel fits vs 40 six-channel fits and quantile bounds
requiring a symmetric hard target-period halfwindow of at least 28.31%.
The strict rank < (delay × state channels) and ±30%-period rules are
**candidate explanations** only. Original mode ranking, stability gates,
and complete source are not recovered.

The repository now includes \`python_tools.hodmd_mode_catalog\` for
private full-spectrum reference delay-DMD extraction and
\`python_tools.hodmd_rule_recovery\` for explicit independent candidate
policy comparisons. It must not be labelled archival HODMD acceptance
until the operator and selected-mode statistics reproduce the frozen
source records on independent systems. See \`docs/HODMD_RULE_RECOVERY.md\`.


## Independent source-WXF HODMD spectral analysis (17 October 2026)

A private rerun over 468 two-channel admissible delay/rank fits
(HEMP27, HEMP19, REF118 × W1/W2 × experiment/WUFI) extracted 2,654
positive-frequency eigenmodes. A retrospectively identified
multiplicative factor-1.3 period gate plus nearest-log-period selection
reproduces **67/84 original accepted-fit counts** exactly. Median period
and growth match archive within 1e-7 in 70/84 and 67/84 groups.
An inferred sample-SD scaling correction matches amplitude and both
loading medians within 1e-8 in 65/84 groups. The 17 count mismatches
lie at 12/24/48-hour targets. **Original HODMD complete parity remains
OPEN**; 28 HEMP_PRIMARY six-state source combinations are untested.
See `docs/HODMD_PRIVATE_SPECTRAL_REPLAY.md`. The validated DMDc engine
and normalization are not modified by this diagnostic.


## Complete original HODMD numerical benchmark — updated 17 Oct 2026

The subsequent independent replay found the original six-channel order
[T27,pv27,T42,pv42,T18,pv18] and a common eligibility rule of
|lambda|>=0.9, positive eigenfrequency, period in [P/1.3,1.3P],
nearest-log-period selection, plus sample-SD (ddof=1) state scaling.
**All 112/112 archival accepted-fit counts match exactly**; period medians,
10th/90th percentiles, growth-rate medians, amplitudes and all available
loading medians agree within documented numerical tolerances.

The 112-row historical HODMD stability benchmark is now **numerically
accepted**. The lost original script and exact source provenance are **not
recovered**, and the 480-fit complex paper-style reference remains distinct
and partially reproduced. This was retrospective, not blind independent
threshold selection. See docs/HODMD_COMPLETE_NUMERICAL_REPRODUCTION.md.


## Fresh committed-source acceptance, 18 October 2026

The **exact** committed Python source and pvlib==0.16.1 wheel were SHA-256-verified and used locally with the original private Drive WXFs, WAC and solar audit. All **112/112** original HODMD numerical rows passed. The full 17,520-hour **actual pvlib** WAC replay is now completed: 17,517 radiation rows and all non-radiation fields match strictly, with three documented near-horizon gap differences up to 0.215687258 W/m². **Strict WAC parity remains failed**; a three-gap-only scientific exception needs independent approval. The temporary public-dependency PR was closed unmerged. See `docs/REF_HEMP_ACCEPTANCE_2026_10_18.md`.
