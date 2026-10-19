# Scientific data, provenance and publication boundary

**The code is public; the experimental archive is not distributed from this site.**

The underlying study involves REF and HEMP construction panels, depth-resolved temperature/RH observations, separately recorded climate inputs and independently licensed WUFI Pro projects. The accompanying **WUFI Unified Report, draft v1.4** is a research manuscript and **not a distributable site asset**. No site page should imply an independent grant of rights to reproduce the draft's unpublished plots, tables, photographs or instrument data.

## Separate evidence chains

- **Software source:** GitHub commit/branch, release package, module/config, tests, changes.
- **Experimental data:** source database, MongoDB collection, logger ID, timestamp, QA flags, channel physical positioning.
- **WUFI model:** locked project state, properties, climate forcing, numerical settings, monitored depth and output series.
- **Analysis:** selected observation interval, alignment, metrics, parameters, code provenance.
- **Report:** figure/table source mapping, reproducibility qualification and publication/rights review.

Scientific agreement with measured channels is conditional on instrument identity, placement, calibration, timing and data integrity. In particular, original construction schematics and an analytical sensor registry can disagree; **do not represent such a registry mapping as physically certified** without installer evidence.

## Latest data collection — internal audit context

An October 2026 full MongoDB export was independently audited against the earlier monitoring snapshot. All original documents remained present with matching content; the later export added records. A second collection named XXX contained duplicated meteo and wireless payloads and must **not** be combined naively with the principal collection.

The full dataset is not included in this repository. A known acquisition timestamp collapse and a major meteorological coverage gap require channel- and time-specific QC; the new snapshot is **not** automatically an uninterrupted clean hourly record. No separately identifiable heat-flux readings were found in those two JSON collections, even though construction documentation shows installed heat-flux meters; this is an acquisition/source-location problem, not proof that the meters never logged data.

## Climate provenance and radiation limitation

A database solar_radiation stream was modelled as GHI for WAC reconstruction, but the radiometer's measured plane, orientation, model/serial and calibration have not been confirmed from available sources. Erbs decomposition is a computational transformation, not measured direct/diffuse irradiance.

## Release checklist

1. Confirm project input rights and physical instrumentation metadata.
2. Hash and freeze source datasets and numerical model state.
3. Independently validate time normalization, QC, interpolation, missingness and units.
4. Keep source-defined and reconstructed methods distinguishable.
5. Recompute primary tables and figures where possible; label untested visual outputs.
6. Never publish raw observations, licensed WUFI project bundles or report graphics through this public documentation pipeline without specific rights and scientific approval.

Scientific investigation and article preparation are maintained in a dedicated modelling workspace; this repository's documentation reflects only verified tooling, reproducibility contracts and known limitations.
