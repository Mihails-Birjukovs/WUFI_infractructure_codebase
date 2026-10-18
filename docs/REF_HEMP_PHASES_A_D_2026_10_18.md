# REF/HEMP pre-WUFI scientific verification — Phases A–D (18 October 2026)

**Status:** internal pre-WUFI scientific-validation candidate. Historical replay, original-data QC, physical validity, predictive generalization and licensed application execution are separate gates.

## A. Raw data and solar QC
The Spilve WAC audit has 17,520 fixed UTC+2 end-labelled hours, of which 3,143 are marked original source-radiation observations; unavailable hours include padding, not just sensor failure. Twenty-three interpolated daylight gaps include the three known mismatches (+0.215687, −0.010730 and −0.181203 W/m² in GHI). Strict 1e-6 W/m² WAC historical identity remains FAILED; the optional 0.25 W/m² three-hour scientific exception remains NOT APPROVED.

Five original sensor WXFs contain 303,068 T/RH observations, with no duplicated timestamps, nonfinite pairs or RH outside 0–100%. Each has five closely synchronized sampling gaps exceeding one hour. HEMP19 has 4,213 measurements at RH >=99%; REF118 has 1,544. Flag saturation but do not delete automatically.

The historical solar position uses 56.97°N, 24.17°E and the previous half-hour midpoint of an end-labelled hour. Repeating the pvlib reconstruction at approximate reported physical coordinates 56.985411°N, 24.085193°E changes Erbs DHI at most 0.341275 W/m² and total DHI −0.010594 kWh/m² (−0.0151%). Coordinate sensitivity does not establish installed radiometer plane/orientation. Physical acceptance requires sensor model, mounting tilt/azimuth, calibration and logger-channel mapping.

## B. Scientific sensitivity and chronological test
New *distinct-from-historical-fit* DMDc-style protocol: 60% chronological training, 20% validation for ridge selection, 20% untouched testing, training-only state/forcing centering, teacher-forced one-step prediction against persistence. Ridge grid 0.001, 0.01, 0.1, 1, 10, 100; p=6/12/24 and outdoor-pv-only versus full six forcing channels. Test-loss ratio uncertainty was evaluated through deterministic paired moving-block resampling (24/72-hour blocks, 200 draws). Intervals are descriptive, not causal confidence intervals.

| Experimental sensor, p=12 | Outdoor-pv-only test RMSE / persistence | Six-input test RMSE / persistence | 72-hour block interval for full |
| --- | ---: | ---: | --- |
| HEMP27 W1 | 0.761 | 0.705 | 0.662–0.741 |
| HEMP27 W2 | 0.719 | 0.844 | 0.764–0.881 |
| HEMP18 W2 | 0.999 | **4.317** | **3.810–5.003** |
| REF118 W2 | 0.275 | 0.250 | 0.189–0.331 |

Thus broad correlated forcing can hurt predictive generalization even when frozen impulse-response archive parity is excellent. These predictions use observed lag states: they are NOT multi-step autonomous forecasts.

HODMD daily-mode parameter sweep: modulus minimum 0.88/0.90/0.92, target-period factor 1.25/1.30/1.35, nine settings per measured sensor and window. Each two-channel system has 39 eligible rank/delay fits. Accepted-count ranges: HEMP27 W1 30–32/W2 37; HEMP19 W1 31–32/W2 34–37; HEMP42 W1 19–21/W2 31–32; HEMP18 W1 16–20/W2 20–24; REF118 W1 22–24/W2 33. Optional HEMP27 WUFI W1 29–31/W2 38. Daily oscillation detection does not uniquely establish mechanism.

Remaining scientific tests: alternative-campaign transfer, multi-step rollouts, sensor calibration-aware uncertainty, HODMD null/surrogate false-positive cases, physical causal interpretability.

## C. Provenance and acceptance governance
New scientific_acceptance.py accepts prior private aggregate HODMD and WAC JSON (including nested report formats), optional Phase A/B results and labelled SHA-256 input fingerprints. It outputs a private consolidated JSON distinguishing historical HODMD numerical parity, **strict** WAC parity, radiometer physical evidence, unapproved scientific exception, source QC, sensitivity, licensed WUFI and Windows Mathematica. It NEVER automatically turns three exceptions into a strict parity pass. CI uses synthetic tests, not raw REF/HEMP data.

Historical replay reference stack: Python 3.13.5, NumPy 2.3.5, pandas 2.2.3, SciPy 1.17.0, pvlib 0.16.1. Record the actual environment and input hashes on every rerun.

## D. Documentation and release recommendation
Separate claims of (1) archival numerical reproduction, (2) independently valid physical inputs and calibration, (3) chronological generalization and causality, and (4) actual licensed WUFI/Mathematica application acceptance. The HODMD factor-1.3/modulus-0.9 gates are retrospective inferences and the original transient script remains missing. The separate 480-fit paper-style HODMD method is not yet numerically matched.

**Classification: internal scientific-validation candidate**. Do not publish final scientific tag, imply correct radiometer mounting from file labels, or include private datasets before separate source-license decisions.

### Local authorized data commands
- python -m python_tools.scientific_phase_a PRIVATE/audit.csv PRIVATE/raw_sensors --report-json PRIVATE/phase_a.json
- python -m python_tools.scientific_phase_b PRIVATE/raw_sensors PRIVATE/meteo_hourly_median.csv --model-temperature PRIVATE/S01_temperature.wxf --model-humidity PRIVATE/S01_relative_humidity.wxf --output-json PRIVATE/phase_b.json
- python -m python_tools.scientific_acceptance --hodmd-json PRIVATE/prior_acceptance.json --wac-json PRIVATE/prior_acceptance.json --phase-a-json PRIVATE/phase_a.json --phase-b-json PRIVATE/phase_b.json --fingerprint WAC_AUDIT=PRIVATE/audit.csv --git-sha ACTUAL_COMMIT --output-json PRIVATE/combined.json

Keep all original signals, per-hour data, eigenmode catalogues, audit files and private hash manifests out of GitHub.
