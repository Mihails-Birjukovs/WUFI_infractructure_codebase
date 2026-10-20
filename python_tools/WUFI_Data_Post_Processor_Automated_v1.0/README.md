# WUFI Data Post-Processor Automated — v1.0

**Target:** Python 3.10+ / NumPy / pandas / Matplotlib  
**Optional dependency:** SciPy for smoothed temperature–humidity density plots  
**Main file:** `WUFI_Data_Post_Processor_Automated_v1.0.py`  
**Documentation reviewed:** 2026-10-20

This script converts exported WUFI ASC results into sensor plots, water-content plots and CSV tables. It reads project metadata directly from `.w6p` archives, names valid monitors by material and position, calculates dew point, and processes cases sequentially or in parallel.

It processes existing results; it does not launch WUFI or modify a construction.

## Active files and dependencies

- [`WUFI_Data_Post_Processor_Automated_v1.0.py`](WUFI_Data_Post_Processor_Automated_v1.0.py) — metadata parsing, calculations, plotting and CSV export.
- `README.md` — operating guide and data contract.
- `.gitkeep` — repository placeholder; not required at runtime.

Install the Python plotting and data dependencies in the environment used to run the script:

```powershell
python -m pip install numpy pandas matplotlib
```

For optional kernel-density estimation:

```powershell
python -m pip install scipy
```

The branch-level `python_tools/requirements.txt` also serves other tools and currently does not include Matplotlib. Installing that file alone is not sufficient for this script.

## Workflow

```text
.w6p project metadata + matching .asc exports + optional LIM curves
  -> identify cases, layers and sensors
  -> validate ASC row widths
  -> clear derived output folders
  -> read and optionally subsample data
  -> calculate dew point and plot moving averages
  -> write JPG graphics and five CSV tables per ASC file
```

The script excludes stale Component monitors using numeric IDs, finite real depths and a `1e-9 m` layer-boundary tolerance. Valid monitors are ordered from exterior to interior. Sensor labels include the material name and the exterior, middle or interior third of its layer, with `Exterior` and `Interior` boundary positions.

Where WUFI Grafika metadata unambiguously identifies computed temperature/RH positions, the parser can recover those names and their order. A legacy layout with four leading non-sensor columns is accepted only when its matching batch export mask can be verified; arbitrary extra columns are not removed to make a file fit.

## Input structure and ASC contract

```text
<current_dir>/
  wall_A.w6p
  wall_A_0.asc
  wall_A_1.asc
  LIM Curves/              # optional; place inside the data folder
    <temperature-RH curve files>
```

Discovery is non-recursive. Source projects and ASC files must be directly inside `current_dir`. LIM files are loaded from `current_dir / "LIM Curves"`, not from the script folder or repository root automatically.

Each standard ASC row must contain:

```text
time T1 RH1 T2 RH2 ... TS RHS water_layer_1 ... water_layer_L water_total
```

For `S` sensors and `L` layers, the width is `2*S + L + 2`, including time. The expected timestamp format is `%Y-%m-%dT%H:%M:%S`. Numeric decimal commas are supported, whitespace separates fields, and `#` introduces comments.

The interpretation is temperature in °C, RH in %, layer water content in kg/m³ and total construction water content in kg/m².

## Project and case mapping

The implementation supports two count-based mapping modes:

1. One ASC per XML case across all discovered `.w6p` projects.
2. One ASC per `.w6p`, using that project's first-case metadata.

ASC files and projects are sorted alphabetically; cases retain XML order. Files are paired by these positions, **not by an explicit project/case identifier**. Check that filenames produce the intended order, particularly when numbered suffixes reach `_10` or above. A matching row width cannot prove that a file has the correct case labels.

## Configuration

Edit `USER SETTINGS` and `PARALLEL SETTINGS` near the top of the script.

| Setting | Meaning / supplied value |
| --- | --- |
| `current_dir` | Data folder; replace the supplied absolute workstation path. |
| `raw_data_file_format` | `".asc"`. |
| `window_size_fraction` | Moving-average window as a fraction of retained rows; `0.01`. |
| `image_dpi` | JPG resolution; `200`. |
| `purge_number` | Keep every n-th row; `1` retains all rows. |
| `wufi_datetime_format` | `%Y-%m-%dT%H:%M:%S`. |
| `PARALLEL_SETTINGS["enabled"]` | `True` enables concurrent processing of ASC files. |
| `PARALLEL_SETTINGS["backend"]` | Supplied as `"thread"`; `"process"` is also supported. |
| `PARALLEL_SETTINGS["max_workers"]` | `None` selects automatically, bounded by task count. |
| `PARALLEL_SETTINGS["leave_free_cores"]` | Automatic worker-count allowance; `1`. |

Subsampling affects **CSV data as well as plots**, and summary plots use the retained samples. The centred moving average uses a row-count window, so its duration depends on the sampling interval and record length. CSV values are the retained source values, not the smoothed plotting curves.

## First use

1. Generate and check the WUFI ASC exports, for example using the [Python batch launcher](../WUFI_Batch_Launcher_Automated_v1.0/README.md).
2. Set `current_dir`, verify file ordering, and place any LIM curves inside the data folder.
3. Preserve any previous results that need to be retained: the script clears its derived output parent folders before processing.
4. For an initial check, set `PARALLEL_SETTINGS["enabled"] = False` and run:

   ```powershell
   python "WUFI_Data_Post_Processor_Automated_v1.0.py"
   ```

5. Inspect the sensor labels, CSV values and plots before enabling a larger parallel run.
6. For the `"process"` backend on Windows, run the complete `.py` file from a terminal rather than evaluating notebook cells separately. The supplied thread backend and Matplotlib `Agg` backend do not constitute a guarantee of thread-safe plotting.

## Calculations and graphics

- **Humidity and temperature:** raw samples with a centred moving-average overlay.
- **Dew point:** calculated from temperature and RH using a consistent inversion of the Buck-type saturation expression. RH is clipped to `0.01–100%` for this calculation. A separate strip marks samples within 2°C of the calculated dew point.
- **Mould history:** temperature/RH scatter coloured by sample index.
- **Mould risk:** temperature/RH density, using SciPy KDE when available and suitable, otherwise a two-dimensional histogram.
- **Water content:** time series for each layer and the whole construction.

Optional LIM curves overlay the temperature/RH plots. Despite their existing titles, the mould plots do not calculate a mould-growth index, cumulative growth or a probability of mould occurrence. Density represents how observations are distributed in temperature/RH space.

Each ASC file generates `5*S + L + 1` JPGs and five CSV files.

## Output structure

For an input named `wall_A_0.asc`, the derived case folder is `wall_A/wall_A_v1`:

```text
<current_dir>/wall_A/wall_A_v1/
  1 Exterior/
    hum1.jpg
    temp1.jpg
    dew1.jpg
    mold1.jpg
    risk1.jpg
  <numbered internal and interior sensor folders>/
  wat1.jpg ... watL.jpg
  wat_total.jpg
  hum_time_series.csv
  temp_time_series.csv
  dew_time_series.csv
  wat_time_series.csv
  wat_all_time_series.csv
```

The CSVs contain time plus, respectively, RH sensors, temperature sensors, dew-point sensors, layer water contents, and layer plus total water contents. Sensor headers include their numbered names. The total column in `wat_all_time_series.csv` has different units from its layer columns.

## Progress, replacement and recovery

Sequential mode reports progress per plot. Parallel mode advances the controller's progress bar when an entire ASC file finishes; worker output is quiet by default. Worker exceptions are collected and reported, and a failed parallel run raises an error.

Column-width preflight runs before output deletion, but it does not validate every later calculation or rendering operation. Existing derived **parent folders** are recursively deleted, including any other files placed there. A later failure can leave incomplete replacements; there is no staged replacement, resumable output audit or automatic restart mode.

Numeric conversion can turn unreadable fields into missing values. Date parsing is accepted when more than half the timestamps parse; otherwise row numbers are used. Inspect questionable inputs rather than treating successful image generation as proof of complete data.

## Validation and Mathematica compatibility

The dew-point correction was checked across 15 temperature/RH combinations, including equality of dew point and temperature at 100% RH. The current Python package has not undergone the Mathematica release's complete graphics or WUFI campaign validation.

This tool writes CSV and JPG files, not the Mathematica processor's five WXF products. It does not implement that release's manifest, graphics modes, output-audit or recovery APIs. The documentation follows the same operator-oriented structure, but the two packages have different output contracts.
