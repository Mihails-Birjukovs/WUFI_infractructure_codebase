# Mathematica implementation provenance

## Established production releases

The `WUFI_mathematica_tools` branch maintains the existing accepted Wolfram Language code:

- Batch Launcher v1.0 (notebook and `WUFIModelMetadata.wl`);
- Data Post-Processor v1.1.1;
- WUFI VS Sensor Comparison v1.2.0.

Release-specific README, CHANGELOG, manifest and smoke-test files should be consulted before changing implementation or asserting a new release status. No established Mathematica algorithm is modified by this documentation change.

## Research context

The *WUFI Unified Report, draft v1.4* (2026) documents the REF and HEMP test-house assemblies and model-validation methodology. REF/HEMP raw monitoring datasets, WUFI production models, site climate audits, and sensor registries are **not published in this repository** and require separately authorized access.

For climate/WAC creation and new Python multiscale, DMD/HODMD, DMDc reference methods, see the separate [`WUFI_python_tools` branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools), which explains retained versus reconstructed algorithm provenance.

## Reproducibility boundary

Release acceptance figures in existing Mathematica README files describe **historical validated configurations**. The committed `SensorComparisonConfig_v1_2.wl` currently selects the two final REF/HEMP case labels, so ordinary execution must not assume the former five-case inventory. End-to-end scientific equivalence requires WUFI 6.5 / Mathematica 12.1 and access to approved project inputs. Use distinct output directories to avoid changing frozen results.

See [branch policy](BRANCHING.md).
