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
| Historical HODMD daily oscillatory mode | Recovered qualitatively; archived 112-row rank/delay stability fractions **not** reproduced |
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
