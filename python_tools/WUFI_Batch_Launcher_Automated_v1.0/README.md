# WUFI Batch Launcher Automated — v1.0

**Target:** Python 3.10+ / Windows / installed WUFI command-line executable  
**Main file:** `WUFI_Batch_Launcher_Automated_v1.0.py`  
**Documentation reviewed:** 2026-10-20

This utility prepares one Windows batch file for a folder of WUFI `.w6p` projects. It reads each project's embedded XML, counts construction layers and valid monitor positions, and builds commands for exporting temperature, relative humidity, layer water content, and total construction water content.

The Python script **creates the batch file and opens its folder in Explorer**. It does not execute WUFI. Review and run the generated batch file separately.

## Active files

- [`WUFI_Batch_Launcher_Automated_v1.0.py`](WUFI_Batch_Launcher_Automated_v1.0.py) — project inspection and batch generation.
- `README.md` — configuration, operating order, and current limitations.
- `.gitkeep` — repository placeholder; not required at runtime.

Only the Python standard library is required by the launcher. WUFI itself must be installed separately.

## Workflow and export contract

```text
Folder of .w6p projects
  -> extract project XML
  -> inspect cases, layers and valid monitors
  -> build export-selection masks
  -> write "WUFI run script.bat"
  -> operator reviews and runs the batch file
  -> WUFI writes ASC results
```

Projects are processed in alphabetical filename order. Each `.w6p` contributes **one command**, even if its XML contains several cases. The launcher does not generate a separate command or export manifest for every case.

The expected downstream numeric layout, after the time column, is:

```text
T1 RH1 T2 RH2 ... TS RHS water_layer_1 ... water_layer_L water_total
```

`S` is the number of valid internal monitors plus the two boundary sensors; `L` is the layer count. Temperature is interpreted downstream in °C, relative humidity in %, layer water content in kg/m³, and total construction water content in kg/m². Confirm the actual export order and units with the WUFI version used for the run.

## Monitor validation

A Component monitor is counted only when:

- its `ElementID` contains ASCII digits;
- its `RealDepthInLayer` is finite and numeric;
- its depth is inside its own layer, allowing a `1e-9 m` tolerance.

Layer thickness must be finite and positive. Decimal commas and decimal points are accepted in XML numbers. Invalid monitor records are reported as warnings and excluded. A requested monitor position alone does not make a stale record valid.

These are the same validity rules used by the Python post-processor. They do not repair monitor positions inside the WUFI project.

## Configuration

Edit the settings near the top of the script before use:

| Setting | Purpose / supplied value |
| --- | --- |
| `current_dir` | Absolute folder containing the source `.w6p` files. Replace the supplied workstation path. |
| `batch_command` | Executable command prefix; supplied as `"WUFI "`. WUFI must be discoverable by that command. |
| `wufi_settings` | Command switches; supplied as `" -C -s -v"`. |
| `skip_series_constant` | Export-mask layout constant; supplied as `19`. |
| `boundary_sensor_count` | Exterior and interior boundary positions; supplied as `2`. |
| `batch_file_name` | Output name; supplied as `"WUFI run script.bat"`. |

The mask combines miscellaneous-result exclusions, flux exclusions, sensor selections and water-content selections, then reverses the complete bit string for the WUFI command. These constants describe an export layout; changing them requires checking the resulting ASC schema against the processor.

## Expected data structure

The script can live separately from the data. Discovery uses `current_dir`, not the script's location.

```text
<current_dir>/
  wall_A.w6p
  wall_B.w6p
  WUFI run script.bat       # generated
```

No manually extracted XML sidecars are required. The launcher opens `.w6p` files as ZIP archives and reads their embedded XML.

## First use

1. Prepare the WUFI projects and verify their cases and monitor positions in WUFI.
2. Set `current_dir` and check the command-line/export settings.
3. Run the script from a Python environment:

   ```powershell
   python "WUFI_Batch_Launcher_Automated_v1.0.py"
   ```

4. Read the reported project names, case counts, layer counts and monitor warnings.
5. Inspect `WUFI run script.bat` in the data folder. Its comments use semicolons, avoiding pipe operators in batch comments.
6. Run the batch file when its commands match the intended campaign.
7. Check that WUFI produced the expected ASC results before using the [Python post-processor](../WUFI_Data_Post_Processor_Automated_v1.0/README.md).

## Replacement and error handling

An existing batch file with the configured name is replaced. Extraction uses `temp_<project-stem>_unzipped` folders beside the projects; an existing folder with that name is deleted before extraction. Successful processing removes each extraction folder. An interrupted or failed parse can leave it behind.

If cases within a project have different layer or valid-monitor counts, the script warns but still builds the command using the **first case's counts**. Resolve those differences before relying on the export. The launcher does not validate the numerical contents of the ASC files created later.

The script executes its workflow at module level, so importing it also performs file operations. Use it as a standalone script.

## Validation and compatibility notes

Focused checks covered stale-monitor rejection, depth tolerances, XML metadata, export-mask generation and generated batch comments. No end-to-end WUFI run was performed as part of that review.

This Python tool does not produce the Mathematica launcher's `WUFI_export_manifest.wl`. Its downstream Python workflow uses XML metadata and ASC files directly; it should not be assumed to satisfy the Mathematica manifest contract.
