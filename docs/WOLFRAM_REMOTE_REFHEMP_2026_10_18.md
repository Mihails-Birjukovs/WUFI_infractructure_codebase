# REF/HEMP — Wolfram 15/Linux source and archive verification (18 October 2026)

> **Archive clarification (18 October 2026):** The earlier v1.2.0 `Output_v1_2_Run1.7z` comparison was an **RC1** candidate with 155 recorded nested graphics failures and only 68/99 expected JPEGs, not a clean final-production five-case run. Subsequent RC2/RC3 five-case archives meet 11/13 independently mirrored equivalence conditions, failing only the literal Production-v1.2.0 module version identifiers. The separate *final production* run contains **two wall cases**, not the five cases stipulated by the frozen 13-gate script. See [archived-run provenance and gate audit](WOLFRAM_ARCHIVED_EQUIVALENCE_GATES_2026_10_18.md). The original 13-test Wolfram equivalence script remains unexecuted remotely.


**Tested production source:** GitHub Mathematica branch at commit `c3ba01045d754903d276ddb320026851ac85e54b`.
**Environment:** connected Wolfram Language 15.0.1 Linux kernel, stateless between evaluations, with **zero usable parallel subkernels**.

This report is a **supplementary cross-platform diagnostic**, not accepted Mathematica 12.1/Windows compatibility, licensed WUFI Pro import, complete private-data orchestration, or release of original REF/HEMP data. The production executable modules are unchanged.

## Authorized fixture inventory

The private shared Drive **REF & HEMP -- Hygrothermal Models** contains:
- 17 selected sensor WXFs and the complete original monitoring/meteo data;
- canonical 2026-07-30 sensor registry, subsequent v3 calibration registry and test fixtures;
- WUFI manifests, final REF/HEMP ASC outputs, final WUFI post-processor five-WXF product sets, sensor analysis and five-case comparison outputs;
- frozen historical Production v1.0 and v1.2 comparison archives, graphical integrity and UTC alignment reports.

The original July registry was supplied privately to the Wolfram kernel for smoke testing, along with the public repository's extracted `TestAssets.7z`. **No private raw WXF, registry, archived output, checksum manifest or measurement time series is committed here.**

## Original source executed remotely

| Target | Outcome |
| --- | --- |
| WUFIModelMetadata export mask, filename and ASC contracts | Passed bounded synthetic checks |
| HygrothermalPlottingUtilities saturation factor, dew point and UTC alignment | Passed synthetic and bounded original-data checks |
| SensorDataUtilities time pairing, comparison metrics and hourly aggregation | Passed synthetic and bounded original-data checks |
| WUFI Data Post-Processor 1.1.1 full unchanged smoke suite | **13/14 passed** (known cloud fresh-worker graphics limitation) |
| WUFI vs Sensor Comparison 1.2.0 full unchanged smoke suite | **44/46 passed** |
| Sensor comparison isolated ephemeral timezone prototype | **45/46 passed**; only parallel-worker test failed |

The unmodified Sensor Comparison failures were:
1. `Parallel path executes on subkernels with package definitions and closure values` — no subkernels are available.
2. `WUFI 18:00 fixed UTC+2 converts to 16:00Z` — returned **08:00Z**, a timezone-dependent behavior in `forceWallClockToUTC`.

In the Wolfram 15 remote evaluator, `$TimeZone == -5.`. The code `Take[DateList@date,6]` extracts components of the date translated into the kernel's timezone rather than the date's explicitly supplied timezone. Rewrapping those components with `TimeZone->2` corrupts the wall-clock interpretation. A **temporary uncommitted** replacement of that extraction with `DateValue[date, {"Year","Month","Day","Hour","Minute","Second"}]` reproduced the expected 16:00Z and increased smoke performance to 45/46. This is evidence for a targeted compatibility change, but should NOT be promoted without Mathematica 12.1/Windows and regression acceptance.

## Original data and frozen archive crosschecks

- Using bounded WUFI-derived data, the *actual* `DewPointC`, `AlignTemperatureRH` and `AggregateSensorChannel` functions reproduce independent calculations to the displayed numerical precision.
- From the final HEMP post-processing output, independently decoded archived temperature/RH/dew point WXFs contain **17 × 3,187 = 54,179** aligned triples. The dew-point equation matches all archived dew-point values with maximum absolute discrepancy **1.78e-14 °C**. The full-array calculation was carried out privately in Python; only bounded samples were evaluated in Wolfram.
- Original archived comparison Production v1.0 versus v1.2: **30/30 WXF outputs byte-identical**; **17/17 QC rows identical**; all **24/24 UTC alignment rows identical excluding the expected output-root paths**; all **24/24 common comparison metric payloads identical**.
- v1.2 adds only three fields within each comparison period's metric payload: `LagSearchMinimumHours`, `LagSearchMaximumHours`, `BestLagAtSearchBoundaryQ`. These are genuine additional diagnostics, so the JSON strings are not byte-identical.
- The original source-defined **13 equivalence gates were NOT rerun** in the remote kernel. Full remote private archive staging remains separate from this read-only independent archive comparison.

## Next acceptance steps

1. Optional review-only candidate for `forceWallClockToUTC` (explicit date-object component extraction), with multizone regression cases. Keep the accepted production branch and historical 46/46 Windows status intact until target-platform approval.
2. For full 13-gate Wolfram equivalence execution, stage the two original private archive trees into one authorized Wolfram filesystem without posting their raw contents publicly, or use the licensed Windows target.
3. WUFI Pro import/execution, 12.1/Windows notebooks and parallel graphics still need target-environment tests.

The main scientific methods and data are preserved unchanged; this document records evidence and limitations only.
