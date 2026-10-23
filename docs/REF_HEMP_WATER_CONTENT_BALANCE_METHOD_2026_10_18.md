# REF/HEMP layer-to-total water-content dimensional audit (2026-10-18)

## Scope

The archived final two-case production postprocessor exports include one original layer-water TemporalData per layer and one construction-total TemporalData for each model. This read-only Python acceptance adds a *dimensional accounting* check to the earlier per-file/physical-range audit. Private model XMLs, time series, manifests, source hashes and precise layer dimensions are **not** part of this public repository.

## Independent source identity and calculation

1. Read ordered material layer names and actual thickness scalar values (unit m) from the authorized original WUFI model XMLs.
2. Verify layer material names, indices and thicknesses against their original WUFI export manifest; obtain its original one-based layer and total ASC column assignments.
3. Parse the source ASC as a unique, consecutive hourly timeline, and read the original postprocessed WXF layer and total streams using the existing restricted, non-evaluating WXF decoder.
4. Require exact equality between the decoded ASC columns and each numerical WXF value, before computing the balance.
5. For every timestamp, compare the reported construction water content with the thickness-weighted sum of volumetric layer water contents:

    M_total(t) ≈ Σ_i d_i × w_i(t)

   Layer water w_i is in kg/m³; thickness d_i is in m; total M is in kg/m², as identified in the accepted postprocessor's plotting contracts.
6. Fail on incorrect units, inconsistent layer order, unexpected column layout, missing/nonfinite samples, negative water values, unpaired hours, source/WXF value differences, or a balance error beyond **3e-6 kg/m² absolute** or **2e-7 relative**. These are *archive serialization tolerances*, not sensor or model uncertainty estimates.

## Private original-data acceptance

Each of the two final REF and HEMP wall models contains **12 layers and 3,187 hourly records**. Full original XML, manifest, ASC and two water-content WXFs per case were cross-checked. All numeric WXF samples matched their ASC source columns exactly. Both construction-total series agreed with the independently thickness-weighted layer sum under the specified tolerances. The precise layer map, source identifiers and residual diagnostics are maintained in a separate private report.

The 5-test public synthetic regression suite covers success and four independently falsified inputs (wrong WXF total, erroneous source balance, XML/manifest thickness disagreement, timestamp discontinuity). No raw project data are in the tests.

## Reproduce on authorized private copies

Place two WXFs called layer_water_content.wxf.bin and total_water_content.wxf.bin inside an authorized private case directory, and run:

    python -m python_tools.water_content_balance_audit \
      --project Wall_REF_FINAL \
      --wufi-export-manifest-json PRIVATE/WUFI_export_manifest.json \
      --model-xml PRIVATE/Wall_REF_FINAL.xml \
      --asc PRIVATE/Wall_REF_FINAL_0.asc \
      --postprocessor-wxf-dir PRIVATE/REF/time_series \
      --out-json PRIVATE/REF_water_balance_audit.json

Run again with the HEMP model and corresponding paths. Never publish the output report or the private input files.

## Scientific and software boundaries

This measures layer-to-total *storage accounting*, **not** the spatial moisture-flux conservation equation, material parameter validity, independent WUFI numerical convergence, physical calibration, or license-platform certification. No changes are proposed to accepted HODMD/DMDc/WAC implementations or frozen archives. Draft timezone PR #21 remains unmerged. All original input files stay private.