# REF/HEMP Campaign 2 — experimental climate and indoor-model reconstruction

**Research status (updated 24 November 2026): pre-response research assessment completed; physical source admission pending. No production WUFI climate boundary has been admitted.** This is a curated methods and validation-status snapshot, not a public dataset, an experimental model release or a certificate that the newly available monitoring stream is the correct physical boundary for the wall models.

The authoritative [public Campaign 2 preparation and acceptance record](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/REF_HEMP_C2_PREPARATION_STATUS_2026_11_14.md) is maintained on the separate Python branch. The Python source and this Mathematica-branch website remain intentionally independent.

## The two climate-reconstruction problems

- **Exterior weather:** actual-date ERA5-Land reanalysis from authenticated Copernicus CDS, preliminary source/radiation/precipitation audits and physically bounded local correction. Gridded reanalysis remains *modelled weather*, not independent site measurements.
- **Interior climate:** original MongoDB monitoring has a long recording interruption, but a *separately logged* RTU/Warsaw controller stream has since been recovered and quality-audited over that period. It supplies a candidate measured indoor T/RH history. Physical instrument independence and boundary equivalence remain unverified; wall-sensor observations are a separate evidence chain.

Observed and reconstructed records are distinguished. The old humid indoor scenario **I_WET** remains a frozen sensitivity and validation comparator, not the new measurement record. Dry and assumed-transition scenarios are likewise retained for historical evaluation. The new measured-stream WAC is **research-only**, not a production boundary.

## Experimental model ladder

| Family | Purpose | Current acceptance |
| --- | --- | --- |
| **M0** | Refitted exterior-weather/harmonic regression and measured-boundary interpolation | Tested statistical baseline |
| **M1** | Bounded effective first-order thermal/vapour response | Tested on frozen historical comparisons; future transfer remains unverified |
| **M2** | Extra thermal relaxation timescale | Thermal-only historical comparison completed; additional complexity requires justification |
| **M3** | Physical-state Kalman filtering and retrospective RTS smoothing | Weather-only and auxiliary wall-temperature cases tested; covariance not admitted |
| **M4** | Weather-exogenous SARIMAX | Corrected masked trial and full historical-gap numerical comparison completed |
| **M5** | Controlled DMDc dynamic prediction | Stability corrections and transfer limitations remain |
| **M6** | Dynamic indoor-air/wall lag with latent heating/cooling discrepancy | Tested; conditional long-gap wall benefit, short-gap deterioration and cross-regime drift |
| **M7** | Vapour concentration, equivalent moisture buffering and latent moisture source | Tested; buffering not identifiable from currently admitted data |
| **M8** | Sparse-switch effective thermal-source and dynamic wall-assisted retrospective reconstruction | Frozen masked and historical-gap assessments completed; numerical convergence does not establish physical source admission |

**Public-software boundary:** The private M0–M8 experimental scripts, source-specific adapters, numerical results and measured sensor histories are **not distributed in this repository**. The published Python WAC and DMD utilities are potential integration components, not the completed Campaign 2 framework.

## What the validation actually establishes

The same deterministic artificial gaps were imposed on *genuinely measured* indoor records. All hidden indoor observations were withheld from training and estimation, then used solely for scoring. An auxiliary wall-assisted branch could use actual wall temperatures recorded during the artificial gap. Retrospective smoothers use indoor observations beyond both ends of the gap; they must not be equated with one-sided forecasting.

- **Wall probes can help, conditionally:** some long-gap temperature reconstructions and predictions of other withheld wall probes improve; short-gap results and humidity do not consistently improve.
- **Room–wall coupling changes across operating regimes:** a single static or dynamic transfer calibration cannot be assumed valid across the real missing period.
- **Latent driving states are not instrumentation logs:** reconstructed effective heating/cooling and moisture terms do not identify historical heater power, ventilation rate, humidifier duty or switch time.
- **Moisture-buffer capacity remains unidentifiable:** the effective reservoir is not an accepted WUFI sorption/material coefficient.
- **Long-gap uncertainty is not calibrated:** noise tuning on independent shorter windows did not generalize to the longer blocked intervals.
- **Adversarial withholding checks passed:** deliberately corrupting hidden indoor labels left the tested model predictions unchanged, establishing a limited numerical leakage check, not accuracy during the actual historical outage.

**New evidence since the original M0–M8 experiments:** the separately logged RTU/Warsaw stream contains indoor T/RH and system telemetry throughout the original 2,374-hour interruption. Empirical cross-stream agreement is strong and a samplewise/time-weighted raw-data audit confirms dense hourly coverage. This is not a certification that the two streams use distinct physical sensors or that their measurements are identical to the WUFI model boundary. The gap can now be evaluated with previously unavailable monitoring values; any derived climate remains provisional pending hardware, timing and model acceptance.

## New monitoring assimilation and frozen-scenario external checks

The private research audit (November 2026) checked clock alignment, indoor T/RH and vapour-pressure agreement, raw-source coverage, samplewise glycol calorimetry, controller-state logging and a new **research-only** indoor WAC. No private records or unpublished figures are reproduced on this page.

The earlier three indoor climate scenarios were compared *without refitting* to the newly acquired monitoring stream across the original long gap. **I_WET** was the best historical hypothesis of those three for temperature, RH and vapour pressure, but its humidity error was sufficiently large that the actual available sensor stream should be investigated as the primary new climate candidate. A subsequent private research checkpoint completed a full historical-gap assessment of all M0–M8 model families, preserving the original masked benchmarks. Newly recovered measurements were reserved for evaluation rather than refitting the earlier models. The comparison separates pre-gap indoor calibration with historical weather forcing from retrospective smoothing and wall-assisted configurations. Numerical convergence is a separate acceptance gate from physical plausibility. Conditional timing and measurement-offset sensitivity tests do not constitute calibrated instrument confidence intervals or independent seasonal validation.

The source review also examined abrupt observed-hour changes, empirical clock alignment, possible inter-logger offsets, repeated daylight-saving hours and climate-file metadata. Source flags and earlier versions are preserved; no unverified bias correction or smoothing is authorized. The glycol property calculation was independently compared with a reference thermophysical backend at sample level; this does not certify delivered room heat or sensor and flow calibration. Static WAC checks distinguish the experimental calculation horizon from artificial file padding and surface pressure from sea-level pressure.

Glycol-loop calculations remain preliminary calorimetric estimates; controller flags are not necessarily physical device feedback. Historical humidifier-state encoding and actual water consumption remain unresolved. The audit preserves the original 26 masked windows, avoids claiming independent folds and makes no material-parameter inference.

## Outstanding scientific gates

1. Certify whether the original and RTU/Warsaw streams share physical instruments; identify sensor positions, calibration, local-clock/DST and buffered-upload semantics.
2. Certify actual heating/cooling, humidification, outdoor-air exchange, glycol properties, device feedback and heat-flux records; controller commands do not by themselves establish delivered energy or water.
3. Retain the completed historical-gap assessment and matched-information comparisons; require independent physical-source certification and cross-regime validation before promoting any method.
4. Establish calibrated instrument and model uncertainties for temperature, vapour pressure, RH and near-saturation events; retain the conditional sensitivity tests and negative results.
5. Admit exterior forcing physically, including site exposure, solar, wind-driven rain, pressure, WAC time convention and full simulation period.
6. Test the research-only indoor WAC, exterior boundary and initial states on **disposable WUFI6 project copies**; reconcile native import clock and historical outputs before any material inversion.

The proposed future physically constrained material-function optimizers remain **designed but not implemented or accepted**.

## Source and methods

- [Authoritative Campaign 2 research preparation record](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/REF_HEMP_C2_PREPARATION_STATUS_2026_11_14.md)
- [Python source and limitations](python.md)
- [Climate and WAC conventions](climate.md)
- [Validation gates](validation.md)
- [Experimental data rights and provenance](data-provenance.md)
- [Separate source branches](source-reference.md)

*No private monitoring records, WUFI6 projects, unpublished charts, experimental archives, exact sensor maps or local paths are reproduced on this public page.*
