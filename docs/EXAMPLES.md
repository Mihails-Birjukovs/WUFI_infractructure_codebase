# Worked examples and expected checks

Examples should be run **on copies of data**. Python fixtures created in this repository are synthetic; the production examples below are configuration recipes requiring the original REF & HEMP research archive.

## Example A: inspect an existing WUFI project's metadata

1. Copy the launcher notebook and `WUFIModelMetadata.wl` into your private `models` folder alongside `MyWall.w6p`.
2. Copy `extract_all_wufi_xml.bat` to the same folder; run it to obtain `MyWall.xml`.
3. Open the launcher notebook in Mathematica 12.1, set `modelDirectory` to that folder, and evaluate the initialization cell.
4. For an inspection-only check:

```wl
manifest = WUFIModelMetadata`BuildWUFIManifest[
  modelDirectory, "RequireGrafikaAgreement" -> False
];
Dataset[Lookup[manifest, "Projects", {}]]
```

Inspect project/case statuses, stale monitor positions, and generated export masks. Only then continue through the notebook's `WriteWUFIManifest` and `WriteWUFIBatchFile` cells. **Do not run** an uninspected generated batch automatically.

## Example B: post-process two completed cases

Follow [workflow steps 2 and 3](WORKFLOWS.md) using the final selectors `Wall_REF_P5_L125_CV100_M200_W0_V070_A00` and `Wall_hemp_P5_CORR_M200_S125_LT1000_W0_V070_A00`. Provide the actual manifest, ASC files, corrected sensor registry and WXF inputs from your authorized archive. Set `"DataDirectory"` correctly and use `"GraphicsMode" -> "Sweep"` for a reduced JPEG inventory while retaining all five WXF outputs. Verify preflight before a costly run.

## Python examples belong to the Python branch

WAC generation using `pvlib`, multiscale analysis, DMD/HODMD and DMDc are documented and demonstrated in [`WUFI_python_tools/python_tools/README.md`](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/README.md). This Mathematica branch contains only the existing production Mathematica infrastructure and its instructions.

## Reproducibility checklist

- Distinguish project-measured data and synthetic examples.
- Record time-zone policy, sensor positions, data-QC decisions, model case IDs and exact source commit.
- Run the Mathematica release smoke/equivalence suites where available; separately verify WUFI command execution and input/output validity.
- Preserve historical frozen acceptance evidence: do not reinterpret two-case REF/HEMP runs as reproducing a prior five-case release acceptance inventory.
