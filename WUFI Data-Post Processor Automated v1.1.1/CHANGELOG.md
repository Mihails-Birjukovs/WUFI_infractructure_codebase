# Changelog — WUFI Data Post-Processor Automated

## Production v1.1.1 — 2026-08-12

### Fixed

- JPEG temporary exports are validated explicitly as JPEG even though the atomic temporary filename ends in `.tmp`.
- Fresh graphics-kernel launch success is determined from the actual launched kernel pool rather than a generic message-sensitive `Check[LaunchKernels[…]]` result; this avoids false launch failure from the Mathematica 12.1 obsolete Wolfram Cloud warning.
- Parallel graphics scheduling uses queued `ParallelSubmit`/`WaitNext` execution with controller-side completion tracking.
- Date-series frame ticks are generated explicitly and deterministically; date coordinates use numeric `AbsoluteTime` values. This addresses the rare parallel-rendering defect observed during RC1 where scientifically valid plots sometimes lost date/numeric tick labels.
- Retry reporting retains the underlying `LastFailureStage` instead of collapsing all failures into an uninformative exhausted-retries stage.

### Added / restored

- Controller-side graphics progress display.
- Permanent per-case stage logging.
- Per-stage timing telemetry and requested/launched graphics-kernel counts in manifests.
- `ShowProgress`, `VerboseLogging`, and `ExplicitTimeSeriesTicks` settings.
- Fast smoke tests covering RC2/Production defaults, JPEG atomic export, explicit tick construction, and fresh-kernel rendering.
- Separate high-load graphics stress-regression harness.

### Production graphics policy

- Default graphics workers: **8**.
- Validated high-throughput override: **12**.
- Counts above 12 warn; a 16-kernel reference run stalled and failed to create some graphics.
- `Automatic` remains accepted but is not recommended for production campaigns.

### Validation

- 14/14 smoke tests passed.
- Three repeated 8-kernel Full validation runs each completed 5/5 cases with 25/25 WXFs and 265/265 JPGs, zero failures and zero retries.
- 25/25 WXFs were byte-identical across all three runs.
- 265/265 JPEG render payloads were identical across all three runs after non-semantic APP/COM metadata was removed.
- Mean five-case summed processing time: ~420.75 s (~7.01 min), CV ~1.04%.

### Compatibility

- Batch Launcher v1.0 manifest contract unchanged.
- `WUFIModelMetadata.wl` unchanged.
- Five WXF filenames and directory layout unchanged.
- WUFI VS Sensor Comparison v1.2.0 downstream paths/contracts unchanged.
- Public `...V11` Wolfram symbols preserved.

## Production v1.1 — 2026-08-08

Production v1.1 introduced Full/Sweep graphics modes, per-case fresh graphics-kernel isolation, direct subkernel JPEG export, restart/recovery, atomic WXF/JPEG export, checkpoint manifests, final output audits, and the initial configurable graphics-kernel cap while preserving the v1.0 data contract.
