# WUFI Wall Construction Optimisation

**Target:** Python 3.10+ / Windows / installed WUFI command-line executable  
**Dependencies:** NumPy, pandas and Matplotlib  
**Included scripts:** automated parameter sweep v1.0 and adaptive thickness optimisation v1.0  
**Documentation reviewed:** 2026-10-20

These scripts create modified copies of a source WUFI wall project, run WUFI, and assess the resulting water-content data. They provide two operating modes: a predefined parameter sweep and an adaptive search for a thinner construction satisfying thermal and moisture constraints.

Both scripts **execute WUFI calculations**. They are independent workflows; running one does not require running the other first.

## Active files

| File | Purpose |
| --- | --- |
| [`WUFI_Automated_Run_v1.0.py`](WUFI_Automated_Run_v1.0.py) | Run a predefined set of parameter values and compare layer water-content statistics. |
| [`WUFI_Layer_Thickness_Optimisation_v1.0.py`](WUFI_Layer_Thickness_Optimisation_v1.0.py) | Adaptively search one layer's thickness using U-value and moisture constraints. |
| `README.md` | Configuration, workflows, output contracts and validation notes. |

The adaptive script originated from `layer_thickness_optim_v2.py`; the current v1.0 filename follows this repository's packaging convention.

## Installation and source project

Install the dependencies in the Python environment used to run these scripts:

```powershell
python -m pip install numpy pandas matplotlib
```

The repository's shared Python requirements currently omit Matplotlib, so install it separately if using that requirements file.

Place the source `.w6p` directly inside the configured `working_dir`. WUFI must be available through the supplied `WUFI` command, and project-specific climate or other external resources must remain accessible.

```text
<working_dir>/
  source_wall.w6p
  <external inputs referenced by the project, where applicable>
```

Use a **single-case source project** for these workflows. XML editing changes the first matching layer, thermal calculation uses the first case, and the adaptive evaluator requires exactly one resulting ASC file. A multi-case project is not a supported way to optimise several walls at once.

## Shared project-generation workflow

```text
Source .w6p + candidate parameter value
  -> extract project archive
  -> copy XML and embedded supporting files
  -> update the selected layer scalar
  -> also update Material/Thickness for thickness changes
  -> regenerate ~Checksum using CRC-32/MPEG-2
  -> package a generated .w6p
  -> create and execute a Windows batch file
  -> wait for WUFI and inspect its exit code
  -> read ASC water-content results
```

The target layer is selected by its XML `Index`, not by a zero-based Python position. Confirm that index in the source project.

Generated names retain the original three-decimal format when it represents the candidate exactly. Finer candidates receive enough precision to distinguish runs; duplicate generated names are rejected before candidate folders are written. Both scalar and material thickness values are updated consistently.

Metadata counts use the same valid-monitor rules as the Python launcher and processor: numeric element ID, finite real depth, positive layer thickness and a `1e-9 m` depth tolerance. Invalid monitors are excluded with warnings. This filtering does not reposition monitors when a layer becomes thinner; check the generated construction in WUFI.

## Mode A — automated parameter sweep

### Configuration

Edit the settings near the top of `WUFI_Automated_Run_v1.0.py`:

| Setting | Supplied example / meaning |
| --- | --- |
| `working_dir` | Replace the supplied absolute workstation path. |
| `Layer_id` | `6`; XML layer index to change. |
| `variable` | `"Thickness"`; layer scalar to vary. |
| `variable_bounds` | `[0.001, 0.12]`. |
| `launch_number` | `2`; number of candidate values and generated runs. |
| `variable_values` | Evenly spaced values between the bounds, rounded to four decimal places. |
| `batch_command` / `wufi_settings` | `"WUFI "` / `" -C -s -v"`. |
| `skip_series_constant` / `boundary_sensor_count` | `19` / `2`; export-mask settings. |
| `wufi_datetime_format` | `%Y-%m-%dT%H:%M:%S`. |

When several source projects are present, this script warns and selects the first alphabetically. Keeping exactly one source project avoids ambiguity. Candidate values must be finite, thickness values must be positive, and their count must equal `launch_number`.

### First use

1. Prepare a single-case source project and confirm the layer index, monitor positions and required external resources.
2. Set the source directory and candidate values.
3. Run:

   ```powershell
   python "WUFI_Automated_Run_v1.0.py"
   ```

4. The workflow builds all candidate projects, starts their batch jobs with a 10-second launch delay, and waits for completion. The jobs can overlap; this script does not impose a worker limit.
5. Review the reported exit codes, summary CSV and mean-water-content graph. A nonzero WUFI exit code stops the summary stage.

This mode compares the requested candidates. It does not choose a constrained optimum or calculate a U-value.

### Outputs

For `source_wall.w6p`, the sweep uses:

```text
<working_dir>/
  tempsource_wall_unzipped/          # extracted source
  tempsource_wall_computations/
    temp_wufi_layer_6_Thickness_f<value>/
      <project XML, supporting files and ~Checksum>
    temp_wufi_layer_6_Thickness_f<value>.w6p
    run_temp_wufi_layer_6_Thickness_f<value>.bat
    <WUFI ASC results>
    water_content_summary.csv
    mean_water_content_by_variable.png
```

`water_content_summary.csv` contains one row per ASC, sorted by the candidate value parsed from its filename. It records mean and maximum water content for every layer. The default graph shows mean layer water content against the varied parameter; the plotting helper also supports maximum values.

## Mode B — adaptive thickness optimisation

### Configuration

Edit the `USER SETTINGS` block inside `if __name__ == "__main__":` at the bottom of `WUFI_Layer_Thickness_Optimisation_v1.0.py`.

| Setting | Supplied example / meaning |
| --- | --- |
| `working_dir` | Source folder; exactly one `.w6p` is required. |
| `layer_id` / `variable` | `4` / `"Thickness"`. |
| `variable_bounds` | `(0.01, 0.5)` metres. |
| `initial_thickness` | `0.1 m`. |
| `initial_step` | `0.02 m`. |
| `minimum_step` / `maximum_step` | `0.002 m` / `0.04 m`. |
| `u_target` | `0.18 W/(m²K)`. |
| `max_attempts_per_thickness` | `2` attempts before a candidate is marked failed and skipped. |
| `show_live_graph` | `True`; update the optimisation graph during the search. |
| `layer_limits` | Per-layer maximum water content and allowed water accumulation. |

The supplied moisture limits are examples for layers 2 and 3, not general material acceptance limits. Replace the layer numbers and thresholds for the construction being studied. Maximum layer water content and accumulation thresholds use kg/m³. Constraint thresholds must be finite and positive.

### Search and ranking

1. Evaluate the initial thickness, constrained to the configured bounds and four-decimal search grid.
2. Evaluate a thinner and thicker neighbour at the current step.
3. Compare the three designs using the ranking rule below.
4. After an improvement, move to the better design and increase the step by 10%, up to `maximum_step`.
5. Otherwise halve the step.
6. Stop when the step falls below `minimum_step`, then return the best successful evaluation.

Repeated candidate thicknesses reuse an in-memory cache. Failed calculations are retried up to the configured count; after that, the failed candidate is cached too. The cache does not persist between script runs.

Feasible designs beat infeasible designs. Among feasible designs, thinner is better, with lower U-value as a tie-breaker. Among infeasible designs, the sum of relative constraint exceedances is minimised, with thickness as a tie-breaker. Missing or non-finite results are rejected rather than treated as zero violation.

**The best returned result can still be infeasible if no feasible candidate was found.** Check its rank: a first element of `0` means feasible and `1` means infeasible. If every evaluation fails, the workflow raises an error. This local neighbour search does not establish a global optimum.

### Thermal and moisture calculations

U-value is calculated from the modified first-case XML as the reciprocal of the sum of stored surface resistances and layer resistances `thickness / conductivity`. Design thermal conductivity is used when supplied; otherwise the dry, 10°C conductivity is used. This is an XML-based one-dimensional resistance calculation, not a transient U-value inferred from WUFI output.

The code interprets `HeatTransferCoeffExt` and `HeatTransferCoeffInt` as stored surface resistances despite their names. Confirm that interpretation for the source XML schema; this review did not independently validate that physical convention.

Moisture statistics include mean, maximum, initial and final water content, plus accumulation defined as **last exported value minus first exported value**. Layer columns use kg/m³; total-construction columns use kg/m². The ranking constraints reference the configured layer columns.

### First use and outputs

Run after editing the bottom settings block:

```powershell
python "WUFI_Layer_Thickness_Optimisation_v1.0.py"
```

Each candidate is generated and evaluated before the search selects its next move. Results are written under:

```text
<working_dir>/
  temp_source_wall_unzipped/
  optimisation_runs/
    layer_4_thickness_<candidate-with-underscores>/
      <generated project folder, .w6p, .bat and .asc>
      single_case_summary.csv
  optimisation_history_<timestamp>.csv
  optimisation_history_<timestamp>.png
```

The history records thickness, success/skipped status, attempts, rank, U-value and available water statistics. The graph shows thickness, U-value versus target, and maximum water content versus the configured layer limits. If the CSV is locked by another application, a uniquely named continuation file is used. The final console output displays the selected design and history paths.

## ASC data contract and failure handling

Both scripts expect whitespace-delimited rows with:

```text
time T1 RH1 ... TS RHS water_layer_1 ... water_layer_L water_total
```

The numeric width must be exactly `2*S + L + 1`. Decimal commas and points are accepted, and `#` comments are ignored. Missing or non-finite water-content fields and unexpected widths raise an error. Candidate filenames support ordinary decimals and scientific notation after `_f`.

The automated sweep summarises layer mean/maximum values. The adaptive script additionally summarises total water content and initial/final accumulation. Neither script uses the post-processor's Grafika recovery or verified legacy extra-column handling; use a standard matching export layout.

## Replacement and recovery

The source `.w6p` is read to generate new projects. However, extraction folders and the sweep's computation folder are deleted and recreated on reuse. The adaptive evaluator also replaces an existing candidate run directory when evaluating that candidate again, including retries or a new script run. Preserve previous campaigns before reusing the same paths.

Extraction and generated output folders remain on disk for inspection. There is no automatic resume from an earlier history CSV. The adaptive retry policy handles failed evaluations within the active run, rather than restoring an interrupted campaign.

## Validation status and related tools

Fourteen local regression tests covered source import/syntax, monitor validation, checksums, preservation of embedded assets, distinct candidate names, batch generation with mocked processes, known water-content statistics, invalid-data rejection, failed-run handling, finite ranking and thickness bounds. A deterministic comparison reproduced the original optimiser's candidate sequence and best rank for valid inputs.

Actual WUFI calculations and plotting were not exercised during that review. Those checks therefore establish selected code behaviours, not end-to-end scientific or workstation validation. The regression test harness is retained in the local review workspace and is not bundled in this folder.

For prepared projects without parameter changes, use the [batch launcher](../WUFI_Batch_Launcher_Automated_v1.0/README.md). For detailed sensor plots and CSV exports from a matching result set, use the [post-processor](../WUFI_Data_Post_Processor_Automated_v1.0/README.md); check its mapping rules before processing results from several optimisation candidates together.
