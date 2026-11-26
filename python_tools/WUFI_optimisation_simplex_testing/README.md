# WUFI Optimisation — Simplex Testing

**Target:** Python 3.10+ / Windows / installed WUFI command-line executable  
**Dependencies:** NumPy, pandas and Matplotlib for both scripts, plus SciPy for simplex optimisation  
**Included scripts:** automated parameter sweep v1.0 and Nelder–Mead thickness optimisation v1.0  
**Documentation reviewed:** 2026-11-26

These scripts create modified copies of a source WUFI wall project, run WUFI, and assess the resulting water-content data. They provide two operating modes: a predefined parameter sweep and an adaptive search for a thinner construction satisfying thermal and moisture constraints.

Both scripts **execute WUFI calculations**. They are independent workflows; running one does not require running the other first.

## Active files

| File | Purpose |
| --- | --- |
| [`WUFI_Automated_Run_v1.0.py`](WUFI_Automated_Run_v1.0.py) | Run a predefined set of parameter values and compare layer water-content statistics. |
| [`WUFI_One_Parameter_Simplex_Thickness_Optimisation_v1.0.py`](WUFI_One_Parameter_Simplex_Thickness_Optimisation_v1.0.py) | Use Nelder–Mead to search one layer's thickness using U-value and moisture constraints. |
| `README.md` | Configuration, workflows, output contracts and validation notes. |

The adaptive script originated from `layer_thickness_optim_v2.py`; the current v1.0 filename follows this repository's packaging convention.

## Installation and source project

Install the dependencies in the Python environment used to run these scripts:

```powershell
python -m pip install numpy pandas matplotlib scipy
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

## Mode B — One-parameter simplex thickness optimisation

### Configuration

Edit the `USER SETTINGS` block inside `if __name__ == "__main__":` at the bottom of `WUFI_One_Parameter_Simplex_Thickness_Optimisation_v1.0.py`.

| Setting | Supplied example / meaning |
| --- | --- |
| `working_dir` | Source folder; exactly one `.w6p` is required. |
| `layer_id` / `variable` | `4` / `"Thickness"`. |
| `variable_bounds` | `(0.01, 0.5)` metres. |
| `initial_thickness` | `0.1 m`. |
| `initial_step` | `0.02 m`. |
| `minimum_step` | Simplex thickness tolerance (`xatol`), 0.002 m. |
| `u_target` | `0.265 W/(m²K)`. |
| `max_attempts_per_thickness` | `2` attempts before a candidate is marked failed and skipped. |
| `show_live_graph` | `True`; update the optimisation graph during the search. |
| `layer_limits` | Per-layer maximum water content and allowed water accumulation. |

The supplied moisture limits are examples for layers 2 and 3, not general material acceptance limits. Replace the layer numbers and thresholds for the construction being studied. Maximum layer water content and accumulation thresholds use kg/m³. Constraint thresholds must be finite and positive.

### Search and ranking

SciPy starts with two thicknesses (100 and 120 mm for the supplied settings). It reflects, expands or contracts the simplex within the bounds. The evaluator rounds each thickness to 0.0001 m. Feasible candidates score from 0 to 1 by thickness, infeasible candidates score from 2 to 3 by total relative violation, and failed evaluations score 4. Lower scores are better.

The search stops when both the thickness and score spreads meet their tolerances (`minimum_step` and `fatol=1e-4`), or after 100 objective calls. Cached calls count towards that limit. The optimiser selects the best successful design from the full evaluation history using the ranking below.

Repeated candidate thicknesses reuse an in-memory cache. Failed calculations are retried up to the configured count; after that, the failed candidate is cached too. The cache does not persist between script runs.

Feasible designs beat infeasible designs. Among feasible designs, thinner is better, with lower U-value as a tie-breaker. Among infeasible designs, the sum of relative constraint exceedances is minimised, with thickness as a tie-breaker. Missing or non-finite results are rejected rather than treated as zero violation.

**The best returned result can still be infeasible if no feasible candidate was found.** Check its rank: a first element of `0` means feasible and `1` means infeasible. If every evaluation fails, the workflow raises an error. This local simplex search does not establish a global optimum.

### Thermal and moisture calculations

U-value is calculated from the modified first-case XML as the reciprocal of the sum of stored surface resistances and layer resistances `thickness / conductivity`. Design thermal conductivity is used when supplied; otherwise the dry, 10°C conductivity is used. This is an XML-based one-dimensional resistance calculation, not a transient U-value inferred from WUFI output.

The code interprets `HeatTransferCoeffExt` and `HeatTransferCoeffInt` as stored surface resistances despite their names. Confirm that interpretation for the source XML schema; this review did not independently validate that physical convention.

Moisture statistics include mean, maximum, initial and final water content, plus accumulation defined as **last exported value minus first exported value**. Layer columns use kg/m³; total-construction columns use kg/m². The ranking constraints reference the configured layer columns.

### First use and outputs

Run after editing the bottom settings block:

```powershell
python "WUFI_One_Parameter_Simplex_Thickness_Optimisation_v1.0.py"
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

### WUFI exit code 0xC0000005 in the simplex optimiser

Previously, a nonzero WUFI exit code stopped the evaluator before it read the ASC. On the test workstation, WUFI sometimes wrote solution data through the final time step and then returned `3221225477` (also reported as `-1073741819`, the same Windows access-violation code). The batch launcher still prints `FAILED` for that process. When the export exists, `evaluate_case()` now prints a warning for this code and continues to parse the ASC. A candidate with valid results can therefore appear in the history and graph and be ranked against the design limits. Other nonzero codes still fail the attempt. The automated parameter sweep retains its original exit-code handling.

The parser checks the summary row count, column layout and finite water-content values. Although the settings include `expected_final_time`, the evaluator currently does not compare it with the last ASC timestamp. Check that timestamp against the project end time before relying on a run accepted with a warning.

## Replacement and recovery

The source `.w6p` is read to generate new projects. However, extraction folders and the sweep's computation folder are deleted and recreated on reuse. The adaptive evaluator also replaces an existing candidate run directory when evaluating that candidate again, including retries or a new script run. Preserve previous campaigns before reusing the same paths.

Extraction and generated output folders remain on disk for inspection. There is no automatic resume from an earlier history CSV. The adaptive retry policy handles failed evaluations within the active run, rather than restoring an interrupted campaign.

## Validation status and related tools

The regression checks reported for the original adaptive optimiser predate this simplex variant. This folder contains the two runnable scripts and this README.

For prepared projects without parameter changes, use the [batch launcher](../WUFI_Batch_Launcher_Automated_v1.0/README.md). For detailed sensor plots and CSV exports from a matching result set, use the [post-processor](../WUFI_Data_Post_Processor_Automated_v1.0/README.md); check its mapping rules before processing results from several optimisation candidates together.
