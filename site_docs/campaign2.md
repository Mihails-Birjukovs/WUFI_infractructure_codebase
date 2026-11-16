# REF/HEMP Campaign 2 — experimental climate and indoor-model reconstruction

**Research status: experimental; no production WUFI climate boundary has been admitted.** This is a curated methods and validation-status snapshot, not a public dataset, a released Campaign 2 algorithm package or a claim to have recovered measured indoor conditions during the monitoring outage.

The authoritative [public Campaign 2 preparation and acceptance record](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/REF_HEMP_C2_PREPARATION_STATUS_2026_11_14.md) is maintained on the separate Python branch. The Python source and this Mathematica-branch website remain intentionally independent.

## The two climate-reconstruction problems

- **Exterior weather:** actual-date ERA5-Land reanalysis from authenticated Copernicus CDS, preliminary source/radiation/precipitation audits and physically bounded local correction. Gridded reanalysis remains *modelled weather*, not independent site measurements.
- **Interior climate:** real monitored indoor-air temperature and RH before and after a long recording interruption, with some independent wall-temperature measurements available during parts of the indoor gap.

Observed and reconstructed records are distinguished. The provisional humid indoor history **I_WET** is a sensitivity reference, not a recovered measurement. Dry and assumed-transition scenarios remain research alternatives.

## Experimental model ladder

| Family | Purpose | Current acceptance |
| --- | --- | --- |
| **M0** | Refitted exterior-weather/harmonic regression and measured-boundary interpolation | Tested statistical baseline |
| **M1** | Bounded effective first-order thermal/vapour response | Tested; long-gap forecasts can drift |
| **M2** | Extra thermal relaxation timescale | Tested in a limited subset; complexity not justified |
| **M3** | Physical-state Kalman filtering and retrospective RTS smoothing | Weather-only and auxiliary wall-temperature cases tested; covariance not admitted |
| **M4** | Weather-exogenous SARIMAX | Corrected limited-fold trial converged; complete benchmark pending |
| **M5** | Controlled DMDc dynamic prediction | Stability corrections and transfer limitations remain |
| **M6** | Dynamic indoor-air/wall lag with latent heating/cooling discrepancy | Tested; conditional long-gap wall benefit, short-gap deterioration and cross-regime drift |
| **M7** | Vapour concentration, equivalent moisture buffering and latent moisture source | Tested; buffering not identifiable from currently admitted data |

**Public-software boundary:** The private M0–M7 experimental scripts, source-specific adapters, numerical results and measured sensor histories are **not distributed in this repository**. The published Python WAC and DMD utilities are potential integration components, not the completed Campaign 2 framework.

## What the validation actually establishes

The same deterministic artificial gaps were imposed on *genuinely measured* indoor records. All hidden indoor observations were withheld from training and estimation, then used solely for scoring. An auxiliary wall-assisted branch could use actual wall temperatures recorded during the artificial gap. Retrospective smoothers use indoor observations beyond both ends of the gap; they must not be equated with one-sided forecasting.

- **Wall probes can help, conditionally:** some long-gap temperature reconstructions and predictions of other withheld wall probes improve; short-gap results and humidity do not consistently improve.
- **Room–wall coupling changes across operating regimes:** a single static or dynamic transfer calibration cannot be assumed valid across the real missing period.
- **Latent driving states are not instrumentation logs:** reconstructed effective heating/cooling and moisture terms do not identify historical heater power, ventilation rate, humidifier duty or switch time.
- **Moisture-buffer capacity remains unidentifiable:** the effective reservoir is not an accepted WUFI sorption/material coefficient.
- **Long-gap uncertainty is not calibrated:** noise tuning on independent shorter windows did not generalize to the longer blocked intervals.
- **Adversarial withholding checks passed:** deliberately corrupting hidden indoor labels left the tested model predictions unchanged, establishing a limited numerical leakage check, not accuracy during the actual historical outage.

No independent indoor-air ground truth exists for the main missing interval in the admitted source. An inferred climate history must not be presented as observation.

## Outstanding scientific gates

1. Certify sensor IDs, physical depth/geometry, clock and buffered-upload semantics, especially across the network interruption.
2. Seek actual heating/cooling, humidification, outdoor-air exchange and heat-flux records; installed hardware does not establish its operating history.
3. Test sparse-switch / piecewise operating regimes and sensor-dependent wall lag/bias with real cross-regime validation.
4. Establish credible long-horizon uncertainties for temperature, vapour pressure, RH and near-saturation events.
5. Admit exterior forcing physically, including site exposure, solar, wind-driven rain, pressure, WAC time convention and full simulation period.
6. Test accepted boundary scenarios and initial states on **disposable WUFI6 project copies**; reconcile native and historical outputs before any material inversion.

The proposed future physically constrained material-function optimizers remain **designed but not implemented or accepted**.

## Source and methods

- [Authoritative Campaign 2 research preparation record](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/REF_HEMP_C2_PREPARATION_STATUS_2026_11_14.md)
- [Python source and limitations](python.md)
- [Climate and WAC conventions](climate.md)
- [Validation gates](validation.md)
- [Experimental data rights and provenance](data-provenance.md)
- [Separate source branches](source-reference.md)

*No private monitoring records, WUFI6 projects, unpublished charts, experimental archives, exact sensor maps or local paths are reproduced on this public page.*
