# Changelog

## Production v1.2.0 — 2026-08-05

- Promoted the fully accepted v1.2.0 RC3 implementation to final production.
- Changed active package identities to `Production-1.2.0-2026-08-05`.
- Changed the default output root to `Output_v1_2_Run1`.
- Retained 46 smoke tests and 13 equivalence gates.
- Retained the validated five-case, 30-WXF, 24/24 alignment, and 99/99 graphics behavior.
- Retained complete per-batch graphics accounting and populated `PlotExports` records.
- Removed generated notebook cache/outline blocks after metadata edits; notebook cells and computational code are unchanged.

## v1.2.0 RC3 — 2026-08-05

- Retained the functionally successful RC2 graphics architecture and 99-JPG output behavior.
- Replaced ambiguous local-function `Return` paths in batch export bookkeeping with explicit `Which`/`If` result expressions.
- Normalized every plot-task result against a final on-disk graphics audit.
- Added batch invariants for result count, classification, task-ID coverage, and output-path coverage.
- Made bookkeeping invariant failures propagate into batch/run failures.
- Corrected `SuccessfulExportCount`, `FailedExportCount`, and `UnclassifiedResultCount`.
- Restored populated per-group and per-comparison `PlotExports` records.
- Expanded the declared smoke suite from 42 to 46 tests.
- Changed the default output root to `Output_v1_2_RC3_Run1`.
- RC3 runtime acceptance remains pending local Mathematica 12.1 validation.

## v1.2.0 RC2 — 2026-08-05

- Retained parallel plot construction and per-wall/per-case subkernel recycling.
- Confirmed RC1 numerical integrity: 30/30 WXF files byte-identical, 24/24 metrics equivalent, 17/17 QC rows equivalent, and 24/24 alignment passes.
- Diagnosed 31 missing RC1 JPGs as Windows path overflow in UUID-suffixed same-directory staging files; final paths were valid, staging paths were 260–274 characters.
- Moved raster staging to a short directory under `$TemporaryDirectory` and changed finalization to validated copy plus committed-file validation.
- Replaced the unreliable fresh-subkernel retry with a controller-kernel retry after plot-kernel recycling and system-cache clearing.
- Upgraded the graphics audit from existing-file validation to complete expected-inventory validation, including missing and unexpected counts.
- Added per-batch counter logic; the RC2 runtime later showed that the counters and retained per-record export lists remained empty, which is corrected in RC3.
- Expanded the declared smoke suite from 39 to 42 tests.
- Changed the default output root to `Output_v1_2_RC2_Run1`.
- Runtime and full 99-JPG RC2 acceptance remain pending local Mathematica 12.1 validation.

## Production v1.1.0 — 2026-08-03

- Promoted validated v1.1.0 RC2 implementation to final production.
- Retained exact Production v1.0.0 numerical equivalence.
- Reduced full-run runtime by 74.76% in the validated five-case run.
- Added cached sensor preparation, one-pass numeric UTC handling, shared WUFI grids, compute/render separation, and final manifest sequencing.
- Retained 33 smoke tests and 13 equivalence gates.
- Changed default output root to `Output_v1_1_Run1`.

## Production v1.0.0 — 2026-08-03

- Established the frozen comparison-framework baseline.
- Incorporated the Draft 1.0.8 computational implementation and Draft 1.0.9 smoke-test correction.
- Added Notebook Hotfix 1 for cache-free Mathematica notebook serialization.
