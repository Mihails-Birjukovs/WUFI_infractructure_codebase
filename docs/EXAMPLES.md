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

## Example C: generate a demonstrator WAC without private monitoring data

```powershell
python -m python_tools.examples.make_synthetic_inputs --out-dir demo_outputs
python python_tools/wac_from_audit.py demo_outputs/synthetic_wac_audit.csv demo_outputs/synthetic_climate.wac
```

The input contains toy hourly temperatures, humidity, pressure, wind and solar irradiance, plus a single labelled internal daytime GHI gap. The generator writes a WAC_02 text file. Verify that the result starts with `WUFI®_WAC_02` (Latin-1 encoding) and contains an eight-column header. Its climate numbers are made up and must **never** be used for scientific WUFI simulations.

## Example D: DMD, DMDc and multiscale diagnostic from a known synthetic signal

```powershell
python -m python_tools.examples.run_modal_example --out-dir demo_outputs
```

The example constructs two signals with a known daily periodic component and a driven first-order response. It demonstrates: multiscale band metrics, exact DMD and time-delay DMD, ridge-regularized delay DMDc, and an impulse response. Outputs are local demonstration CSVs/JSON, not validation of the REF/HEMP physical interpretation.

## Examples' reproducibility checklist

- State which data are **synthetic** versus project-measured.
- Record timestamps, UTC conversion, fixed WUFI clock convention, spatial sensor positions and excluded intervals.
- Save method versions, dependencies, parameter choices and code commit SHA.
- Run Python synthetic tests; separately run Mathematica smoke tests and compare any WUFI outputs to appropriate accepted baselines.
- Inspect physical units: T (°C), RH (%), solar irradiance (W/m²), WAC end-labelled hourly time; DMDc responses use input's scaling and time step.
