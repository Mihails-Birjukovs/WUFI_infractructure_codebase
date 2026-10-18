# Archived v1.2.0 candidate gates vs later final wall-model run

**18 October 2026 — Independent PRIVATE archival audit.** The original
Mathematica 12.1/Windows `Equivalence_Tests_v1_2.wl` was **not** rerun.
Instead the original 13 source-defined gate predicates were mirrored in
Python over the authorized extracted archived-output trees. No original
WXF, manifests, per-sensor signals or private source hashes are committed.

## Three five-case candidate archive checks

Reference: `Output_v1_Run1.7z` (historical Production v1.0).
The three v1.2.0 archived candidates were retrieved from the shared
**REF & HEMP — Hygrothermal Models / Sensors VS WUFI / Archived_tests**
Drive folder.

| Five-case candidate | Gate conditions met /13 | Version from its source manifest | Nested failures | JPG inventory |
| --- | ---: | --- | ---: | ---: |
| Output_v1_2_Run1.7z | **9/13** | ReleaseCandidate-1.2.0-RC1-2026-08-04 | **155** | **68** |
| Output_v1_2_RC2_Run1.7z | **11/13** | ReleaseCandidate-1.2.0-RC2-2026-08-05 | 0 | **99** |
| Output_v1_2_RC3_Run1.7z | **11/13** | ReleaseCandidate-1.2.0-RC3-2026-08-05 | 0 | **99** |

For both RC2 and RC3 the other eleven conditions succeed: the
same **30 relative WXF paths with byte-identical contents**, the same
**24 common comparison metrics** (including the old-key subset),
exactly **17 identical QC records**, 24/24 passing UTC alignment rows,
same 99 JPEG relative paths, the two sensor-preparation bundles/three
cache hits, completed 5 case selections, no nested failures and
completed alignment/graphics audits. Only two **literal
Production-1.2.0-2026-08-05** version-string checks fail because these
archives are release candidates. This is strong numerical/functional
equivalence evidence, not equivalent to an original 13/13 Wolfram
TestReport.

**RC1 is NOT the finished clean production artifact.** It fails both
literal version tests, the 99-JPG inventory check (only 68), and the
five-case clean-run-count gate due to 155 nested failures. Its 30 WXF
outputs and all 24 common numerical comparison metric sets still agree
with v1.0, but do not misstate that artifact as a final release.

A byte-identical WXF is sufficient to establish equality of those
actual source files; the independent Python mirror is not a general
implementation of Wolfram `equivalenceValueQ` or its WXF importer.

## Separate later final-production two-wall-model run

The shared Drive
`Sensors VS WUFI/WUFI_FINAL_wall_models/comparison_manifest.json`
identifies **Production-1.2.0-2026-08-05** for both the sensor and
plotting modules. This is the actual final **two-case wall-model run**,
not the five-case regression candidate:

- **2** selected wall cases completed; **0** selection failures;
  **0** nested failures.
- **12** comparison metric rows, **17** QC rows.
- Alignment audit: **12 passed, 0 failed**, status Passed.
- Graphics integrity audit: **63 valid, 0 invalid**, status Passed.
- Preparation cache: two distinct bundles, **0** cache hits (appropriate
  to two case selections, unlike the five-case criterion).

The final two-wall-model run cannot be spliced into RC3 to manufacture
a final five-case 13/13 report: it has a different case and product
scope. Preserve the two acceptance records separately.

## Additional actual-source Wolfram cross-check

The unmodified production `PairSensorModelSeries` and
`ComparisonMetrics` were executed via connected Wolfram 15/Linux on
24 bounded original-data temperature pairs: sensor HEMP27 versus
matched-depth S01 WUFI, beginning 2025-12-12 12:00 UTC. The full-period
result is **24 pairs**, **+3.7280222104166665 C mean bias**,
**3.8301695289793596 C RMSE**, and the same **3.7280222104166665 C MAE**.
Independent Python extraction/aggregation agrees to under 1e-9 C at
the transferred numerical precision.

The previously reported Wolfram remote smoke tests remain
13/14 post-processor and 44/46 unchanged comparison (45/46 only in an
isolated unmerged timezone patch). Draft compatibility PR #21 remains
unmerged; target 12.1/Windows acceptance and worker graphics are open.

## Unresolved final five-case source archive

The Drive also contains `Archived_results.7z` (352,901,779 bytes).
Its download was rejected by the connected Drive service because the
limit is 268,435,456 bytes per file. Its contents could include a
matching final five-case production archive, **but are uninspected**.
A standalone final *five-case* Production-1.2.0 artifact has not been
identified among the smaller accessible archives.

Suggested next action: use an authorized local workstation to inspect
the large 7z and, if present, place only the relevant final-five-case
versioned manifest, audit files, and equivalence evidence into a
smaller access-controlled Drive subarchive. Otherwise re-run the
historical five-case candidate with Production-1.2.0 under Mathematica
12.1/Windows. **Do not claim a newly verified 13/13 gate run from
the currently available RC1/RC2/RC3 artifacts.**

No production executable or private experiment files were changed.
