# Python climate and residual-dynamics workflows

## 1. Build WAC inputs for WUFI

- Start from validated meteorological source records, with explicit sensor selection and hourly quality control.
- Build a continuous end-labelled hourly CSV in **fixed local standard time** with `TIME,TA,HREL,WD,WS,PMSL,source_GHI,source_available`.
- Generate WAC solar geometry, clear-sky-index gap correction and Erbs diffuse component:

```powershell
python python_tools/wac_from_audit.py climate_hourly_audit.csv climate.wac --latitude 56.97 --longitude 24.17 --utc-offset-hours 2
```

- Inspect the generated `WUFI®_WAC_02` header, 8-column data, nonnegative ISGH/ISD, site location, pressure convention, day/night transitions and import preview in WUFI before running any model.
- For new projects, use the actual site coordinates and audit the outcome against independently observed radiation. Original project climate audit files are **not bundled**.

## 2. Run WUFI and process ASC: distinct toolchains

**Accepted Mathematica workflow:** the separate [Mathematica branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools) builds project manifests, exports ASC, produces five WXF types, aligns sensor timestamps and compares selected REF/HEMP cases. This is the documented production research path.

**New Python workflow (Valters Ribickis, 2026-10-20):** [batch launcher](../python_tools/WUFI_Batch_Launcher_Automated_v1.0/README.md) prepares a .bat file for **manual WUFI execution**; [ASC post-processor](../python_tools/WUFI_Data_Post_Processor_Automated_v1.0/README.md) creates CSV/JPG visualizations. [Wall construction scripts](../python_tools/WUFI_Wall_Construction_Optimisation/README.md) instead generate changed project candidates and **execute WUFI** for parameter sweep and local adaptive thickness optimisation. They require Windows and a licensed installed WUFI command-line tool.

These workflows **differ** in manifests, case mappings, file outputs, audit/recovery support and accepted test coverage. The Python launcher does not create the Mathematica export manifest. The Python processor pairs ASC/case metadata using sorted positions, which may be ambiguous in multi-case campaigns. Verify ASC schema/units, case identity and time basis independently.

**Safety:** consult each package README before use. Some operations replace batch files or recursively delete generated output directories. Keep source and output snapshots isolated and backed up. The new WUFI scripts have not been validated end-to-end against the Mathematica releases. [Open discussion Issues #28–#35](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/issues) track proposed tests, safe execution and interoperability work **without authorizing changes**.

Export paired, quality-controlled hourly sensor/WUFI series with units, depths, excluded periods and documented model source for the analysis steps that follow.

## 3. Evaluate multiscale differences

```python
from python_tools.multiscale import band_metrics, cutoff_robustness

table = band_metrics(sensor_hourly, wufi_hourly, slow_hours=72, event_hours=12)
robustness = cutoff_robustness(sensor_hourly, wufi_hourly)
```

- `slow`: centered 72-hour mean;
- `event`: centered 12-hour mean minus slow;
- `fast`: original minus centered 12-hour mean.

The standard robustness grid is slow 48/72/96 h and event 8/12/18 h. Edges and missing values require separate consideration.

## 4. DMD and HODMD-style delay embedding

```python
from python_tools.dmd import exact_dmd, delay_dmd

dmd = exact_dmd(snapshots_channels_by_times, rank=2, dt_hours=1.0)
hodmd = delay_dmd(snapshots_channels_by_times, delays=12, rank=4, dt_hours=1.0)
```

Review discrete eigenvalues, continuous complex frequencies, rank selection, embedded dimension and parameter sensitivity. These are **new reference methods**, not byte-identical historical recovered scripts.

## 5. Delay DMDc and impulse diagnostics

```python
from python_tools.dmdc import fit_delay_dmdc, impulse_response, peak_and_memory

A, B = fit_delay_dmdc(state_samples_by_channels, forcing_samples_by_channels,
                      p=12, ridge=1e-8)
response = impulse_response(A, B, p=12, n_state=state_samples_by_channels.shape[1], horizon=72)
metrics = peak_and_memory(response)
```

A/B are linear predictive matrices fitted in **whatever units and standardized scale you supplied**; interpret peak gain, time-to-peak and area/peak persistence in that context. This implementation reconstructs published Phase-4 method definitions and advances lagged control inputs correctly, but does **not** demonstrate a causal physical interface mechanism.

## 6. Scientific acceptance

Run tests on synthetic fixtures, then independently cross-check climate reconstruction with approved historical WAC/audit data and modal/multiscale results with frozen REF/HEMP tables. Keep versioned parameter/rank/window choices and review physical assumptions before public release.

**Historical multiscale caveat:** The original Phase-4 archive's `analysis_method.json` specifies fourth-order zero-phase Butterworth filtering and trimming of contiguous valid segments. The centered-window means shown here are the **reconstructed Appendix I** method and are *not directly comparable numerically* with the original archived Phase-4 band tables.

### Independent historical WAC audit comparison

With separately authorized copies of the historical hourly CSV and WAC (not in this public repository):

```powershell
python python_tools/validate_wac_reference.py Spilve_solar_hourly_audit.csv Spilve_exterior_full_2025_2026_padded_solar_corrected_Erbs_ISGH_ISD.wac
```

This compares all **17,520** original WAC records and seven numeric fields against the retained hourly audit; passing only establishes audit-vs-WAC consistency. To check newly generated WAC, replace the WAC path with the new file; a nonzero status indicates disagreement with the historical audit.

### Archived Phase-4 Butterworth variant

For a closer match to the archived **filter class**, use `python_tools.multiscale_butterworth.butterworth_band_metrics` (fourth-order zero-phase Butterworth, 12 h and 72 h cutoffs, at least 240 h contiguous valid samples, 72 h trimmed at each edge). This supplements rather than replaces the Appendix I moving-average reconstruction; the historical alignment/QC and precise filter settings still need independent equivalence tests against the archived tables.
