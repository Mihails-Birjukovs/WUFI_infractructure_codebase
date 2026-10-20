#%%
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET
import shutil
import numpy as np
import subprocess
import time
import pandas as pd
import matplotlib.pyplot as plt
import re
import math
#%% Define working directory

working_dir = Path(
    r"C:\Users\user\Desktop\Valteram_Ribickim_WUFI_tutorials\testing_ground\automation_optim\automation_try_1"
)

#%% get wufi file from working directory

# Source project discovery happens in main(), after validation.


# %% Define optim parameters

Layer_id = 6

variable = "Thickness"

variable_bounds = [0.001, 0.12]

launch_number = 2

variable_values = np.round(
    np.linspace(
        variable_bounds[0],
        variable_bounds[1],
        launch_number,
    ),
    4,
)

wufi_datetime_format = "%Y-%m-%dT%H:%M:%S"

# zipping settings

POLYNOMIAL = 0x04C11DB7

#%% bat file setting

batch_command = "WUFI "
wufi_settings = " -C -s -v"

skip_series_constant = 19
boundary_sensor_count = 2

temporary_name = "WUFI run script.txt"
batch_file_name = "WUFI run script.bat"

#%% Helper function

def crc32_mpeg2(data: bytes) -> int:
    crc = 0xFFFFFFFF

    for byte in data:
        crc ^= byte << 24

        for _ in range(8):
            if crc & 0x80000000:
                crc = ((crc << 1) ^ POLYNOMIAL) & 0xFFFFFFFF
            else:
                crc = (crc << 1) & 0xFFFFFFFF

    return crc

def build(items):
    """Join a list of 0/1 values into one continuous string."""
    return "".join(str(item) for item in items)


def skip_miscellaneous_info(skip_series):
    return build([0] * skip_series)


def skip_flux_info(n_layers):
    return build([0] * (4 * (n_layers + 2)))


def sensor_data(n_sensors):
    return build([1, 1, 0] * n_sensors)


def water_content(n_layers):
    return build([1] * (n_layers + 1))


def command_line(file_name, n_layers, n_sensors, skip_series):
    output_flags = (
        skip_miscellaneous_info(skip_series)
        + skip_flux_info(n_layers)
        + sensor_data(n_sensors)
        + water_content(n_layers)
    )

    return (
        batch_command
        + f'"{file_name}"'
        + wufi_settings
        + output_flags[::-1]
    )


def xml_number(value):
    """Read a finite WUFI number with either decimal separator."""
    number = float(value.strip().replace(",", "."))
    if not math.isfinite(number):
        raise ValueError(f"Non-finite XML number: {value!r}")
    return number


def count_valid_monitors(case):
    """Match the processor's Component monitor checks and 1e-9 m tolerance."""
    count = 0
    case_name = case.findtext("Name", default="unnamed case")
    for ordinal, layer in enumerate(case.findall("./Component/Layers/Layer"), 1):
        layer_index = layer.get("Index", str(ordinal))
        scalar = layer.find('./Scalars/Scalar[@name="Thickness"]')
        thickness = xml_number(scalar.get("value", "") if scalar is not None else "")
        if thickness <= 0:
            raise ValueError(f"Layer {layer_index}: thickness must be positive")

        for index, monitor in enumerate(
            layer.findall("./MonitorPositions/MonitorPosition"), 1
        ):
            element = (monitor.findtext("ElementID") or "").strip()
            depth_scalar = monitor.find('./Scalars/Scalar[@name="RealDepthInLayer"]')
            try:
                depth = xml_number(
                    depth_scalar.get("value", "") if depth_scalar is not None else ""
                )
            except ValueError:
                depth = None

            reason = None
            if re.fullmatch(r"[0-9]+", element) is None:
                reason = "ElementIDNotNumeric"
            elif depth is None:
                reason = "RealDepthNotNumeric"
            elif not -1e-9 <= depth <= thickness + 1e-9:
                reason = "RealDepthOutsideLayer"

            if reason:
                monitor_index = monitor.get("Index", str(index))
                print(
                    f"WARNING: {case_name}, layer {layer_index}, "
                    f"monitor {monitor_index}: ignored stale monitor ({reason})."
                )
            else:
                count += 1
    return count


def get_file_info_from_xml(xml_file, boundary_sensor_count=2):
    """
    Read all cases from the XML.

    Assumption:
    all cases inside the same .w6p file should have the same number of layers
    and monitor positions.

    If they do not match, print a warning.
    """
    tree = ET.parse(xml_file)
    root = tree.getroot()

    cases = root.findall(".//Case")

    if not cases:
        raise ValueError(f"No <Case> elements found in {xml_file}")

    case_counts = []

    for i, case in enumerate(cases, start=1):
        case_name = case.findtext("Name", default=f"Case_{i}")

        layers = case.findall("./Component/Layers/Layer")

        n_layers = len(layers)
        n_monitors = count_valid_monitors(case)
        n_sensors = n_monitors + boundary_sensor_count

        case_counts.append(
            {
                "case_number": i,
                "case_name": case_name,
                "n_layers": n_layers,
                "n_monitors": n_monitors,
                "n_sensors": n_sensors,
            }
        )

    reference = case_counts[0]

    mismatch_found = False

    for case_info in case_counts[1:]:
        if (
            case_info["n_layers"] != reference["n_layers"]
            or case_info["n_monitors"] != reference["n_monitors"]
        ):
            mismatch_found = True

    if mismatch_found:
        print(f"\nWARNING: Layer/monitor mismatch in {xml_file.name}")
        print(
            f"Reference: Case {reference['case_number']} "
            f"({reference['case_name']}) | "
            f"layers={reference['n_layers']} | "
            f"monitors={reference['n_monitors']} | "
            f"sensors={reference['n_sensors']}"
        )

        for case_info in case_counts:
            print(
                f"  Case {case_info['case_number']} "
                f"({case_info['case_name']}) | "
                f"layers={case_info['n_layers']} | "
                f"monitors={case_info['n_monitors']} | "
                f"sensors={case_info['n_sensors']}"
            )

    return {
        "n_cases": len(cases),
        "n_layers": reference["n_layers"],
        "n_monitors": reference["n_monitors"],
        "n_sensors": reference["n_sensors"],
        "mismatch_found": mismatch_found,
        "case_counts": case_counts,
    }

def create_temp_dir(wufi_file):
    temp_dir = wufi_file.with_name(f"temp{wufi_file.stem}_unzipped")

    if temp_dir.exists():
        shutil.rmtree(temp_dir)

    temp_dir.mkdir()

    with zipfile.ZipFile(wufi_file, "r") as archive:
        archive.extractall(temp_dir)

    return temp_dir

def create_optim_dir(wufi_file):
    optim_dir = wufi_file.with_name(f"temp{wufi_file.stem}_computations")

    if optim_dir.exists():
        shutil.rmtree(optim_dir)

    optim_dir.mkdir()

    return optim_dir

def create_comp_xml_files(
        temp_dir: Path,
        launch_number: int,
        variable_values: list,
        variable: str,
        Layer_id: int,
        optim_dir: Path,
        
):
    xml_files = sorted(temp_dir.glob("*.xml"))
    if not xml_files:
        raise FileNotFoundError(f"No XML file found in {temp_dir}")
    if launch_number != len(variable_values):
        raise ValueError(
            "launch_number must equal the number of variable_values "
            f"({launch_number} != {len(variable_values)})"
        )

    orig_xml_file = xml_files[0]
    created_xml_files = []
    # Keep the existing three-decimal names whenever they preserve the value.
    # Finer candidates need more precision to avoid overwriting another run.
    labels = []
    for value in variable_values:
        number = float(value)
        if not math.isfinite(number) or (variable == "Thickness" and number <= 0):
            raise ValueError(f"Invalid {variable} candidate: {value!r}")
        label = f"{number:.3f}"
        labels.append(label if float(label) == number else f"{number:.12g}")
    if len(set(labels)) != len(labels):
        raise ValueError("Candidate values must have distinct generated project names")

    for i in range(launch_number):
        
        numeric_value = float(variable_values[i])
        var_val = f"{numeric_value:.12g}"

        launch_wufi_dir = optim_dir / (
            f"temp_wufi_layer_{Layer_id}_{variable}_"
            f"f{labels[i]}"
            )
        if launch_wufi_dir.exists():
            shutil.rmtree(launch_wufi_dir)

        # Preserve supporting files referenced by the original project XML.
        shutil.copytree(temp_dir, launch_wufi_dir)
        copied_xml = launch_wufi_dir / orig_xml_file.name

        parser = ET.XMLParser(
            target = ET.TreeBuilder(
                insert_comments = True,
                insert_pis = True
            )
        )

        tree = ET.parse(copied_xml, parser = parser)
        root = tree.getroot()

            # Find the layer using its XML Index attribute.
        layer = root.find(f".//Layer[@Index='{Layer_id}']")

        if layer is None:
            raise ValueError(f"Layer with Index={Layer_id} was not found")

        # First thickness location:
        # <Scalar name="Thickness" value="..."/>
        variable_scalar = layer.find(
            f"./Scalars/Scalar[@name='{variable}']"
        )

        # Second thickness location:
        # <Material><Thickness>...</Thickness></Material>
        material_thickness = layer.find("./Material/Thickness")

        if variable_scalar is None:
            raise ValueError(
                f"Scalar {variable!r} was not found in layer {Layer_id}"
            )

        if variable == "Thickness" and material_thickness is None:
            raise ValueError(
                f"Material Thickness was not found in layer {Layer_id}"
            )

        variable_scalar.set("value", var_val)
        if variable == "Thickness":
            material_thickness.text = var_val


        tree.write(
            copied_xml,
            encoding="utf-8",
            xml_declaration=True,
        )
        created_xml_files.append(copied_xml)

        print(
            f"Layer {Layer_id}: "
            f"{variable} = {variable_scalar.get('value')}"
        )

    return created_xml_files

def comp_wufi_file_dirs (optim_dir:Path):
    return [path for path in optim_dir.iterdir() if path.is_dir()]



def create_checksum_files(
        optim_dir: Path
):

    wufi_dirs_list = comp_wufi_file_dirs(optim_dir)

    for dir in wufi_dirs_list:
        xml_file_local_path = sorted(dir.glob("*.xml"))[0]

        xml_data = xml_file_local_path.read_bytes()

        checksum_path = dir/"~Checksum"

        checksum = crc32_mpeg2(xml_data)

        checksum_path.write_text(
            f"{xml_file_local_path.name}={checksum:08X}\n",
            encoding="ascii",
        )

def zip_comp_wufi_dirs(
        optim_dir: Path
):
    wufi_dirs_list = comp_wufi_file_dirs(optim_dir)

    for wufi_dir in wufi_dirs_list:

        output_wufi = optim_dir / f"{wufi_dir.name}.w6p"

        if output_wufi.exists():
            output_wufi.unlink()

        with zipfile.ZipFile(
            output_wufi,
            mode="w",
            compression = zipfile.ZIP_DEFLATED,
            compresslevel = 5, 
        ) as archive:
            
            for file_path in wufi_dir.rglob("*"):
                if file_path.is_file():

                    archive_name = file_path.relative_to(wufi_dir)

                    archive.write(
                        file_path,
                        arcname = archive_name,
                    )
        print(f"Created = {output_wufi}")

def create_and_run_all_wufi_files(
        optim_dir: Path,
        skip_series: int,
        start_delay: float = 10.0,
):
    """Create one batch file per WUFI project, run them, and return results."""
    wufi_dirs_list = comp_wufi_file_dirs(optim_dir)

    if not wufi_dirs_list:
        raise FileNotFoundError(
            f"No computational WUFI directories found in {optim_dir}"
        )

    batch_files = []

    for wufi_file_dir in wufi_dirs_list:
        generated_wufi = optim_dir / f"{wufi_file_dir.name}.w6p"
        print(f"\nProcessing WUFI file: {generated_wufi.name}")

        xml_files = sorted(wufi_file_dir.glob("*.xml"))
        if not xml_files:
            raise FileNotFoundError(
                f"No XML file found in {wufi_file_dir}"
            )

        if not generated_wufi.exists():
            raise FileNotFoundError(
                f"WUFI project not found: {generated_wufi}"
            )

        file_info = get_file_info_from_xml(xml_files[0], boundary_sensor_count)

        if file_info["mismatch_found"]:
            print(
                f"WARNING: {generated_wufi.name} has inconsistent "
                "layer/monitor counts. Counts from the first case will be used."
            )

        wufi_command = command_line(
            file_name=generated_wufi.name,
            n_layers=file_info["n_layers"],
            n_sensors=file_info["n_sensors"],
            skip_series=skip_series,
        )

        batch_path = optim_dir / f"run_{wufi_file_dir.name}.bat"
        batch_contents = [
            "@echo off",
            'cd /d "%~dp0"',
            "",
            f"echo Running {generated_wufi.name}",
            wufi_command,
            "",
            "set WUFI_EXIT_CODE=%ERRORLEVEL%",
            f"echo Finished {generated_wufi.name}",
            "exit /b %WUFI_EXIT_CODE%",
        ]
        batch_path.write_text(
            "\n".join(batch_contents),
            encoding="utf-8",
        )
        batch_files.append(batch_path)
        print(f"Created batch file: {batch_path.name}")

    processes = []

    for batch_path in batch_files:
        print(f"Starting: {batch_path.name}")
        process = subprocess.Popen(
            ["cmd.exe", "/c", str(batch_path)],
            cwd=optim_dir,
            creationflags=subprocess.CREATE_NEW_CONSOLE,
        )
        processes.append((batch_path, process))

        if start_delay > 0:
            time.sleep(start_delay)

    print(f"\nStarted {len(processes)} WUFI processes in parallel.")

    run_results = []
    for batch_path, process in processes:
        return_code = process.wait()
        run_results.append(
            {
                "batch_file": batch_path.name,
                "return_code": return_code,
                "success": return_code == 0,
            }
        )

        if return_code == 0:
            print(f"Finished successfully: {batch_path.name}")
        else:
            print(
                f"FAILED: {batch_path.name} "
                f"with exit code {return_code}"
            )

    failed_runs = [result for result in run_results if not result["success"]]
    print("\nAll WUFI processes have finished.")

    if failed_runs:
        print("\nFailed calculations:")
        for failed_run in failed_runs:
            print(
                f" - {failed_run['batch_file']}: "
                f"exit code {failed_run['return_code']}"
            )
    else:
        print("All calculations completed successfully.")

    return run_results


def find_wufi_asc_files(
        optim_dir: Path,
):
    
    ascii_file_list = sorted(optim_dir.glob("*.asc"))
    wufi_file_list = sorted(optim_dir.glob("*.w6p"))

    if not ascii_file_list:
        raise FileNotFoundError(
            f"No ASC files found in: {optim_dir}"
        )

    if not wufi_file_list:
        raise FileNotFoundError(
            f"No WUFI files found in: {optim_dir}"
        )
    
    return ascii_file_list, wufi_file_list


def read_wufi_layer_sensor_counts(
    wufi_file: Path,
    boundary_sensor_count: int = 2,
) -> tuple[int, int, int]:
    """
    Read the number of layers, monitor positions, and sensors
    from the first case inside a generated WUFI .w6p file.

    Returns
    -------
    n_layers, n_monitors, n_sensors
    """

    if not wufi_file.exists():
        raise FileNotFoundError(
            f"WUFI file not found: {wufi_file}"
        )

    with zipfile.ZipFile(wufi_file, "r") as archive:

        xml_names = [
            name
            for name in archive.namelist()
            if name.lower().endswith(".xml")
        ]

        if len(xml_names) != 1:
            raise ValueError(
                f"{wufi_file.name}: expected one XML file, "
                f"found {len(xml_names)}."
            )

        xml_data = archive.read(xml_names[0])

    root = ET.fromstring(xml_data)

    first_case = root.find(".//Case")

    if first_case is None:
        raise ValueError(
            f"No <Case> element found in {wufi_file.name}"
        )

    n_layers = len(
        first_case.findall("./Component/Layers/Layer")
    )

    n_monitors = count_valid_monitors(first_case)

    n_sensors = n_monitors + boundary_sensor_count

    if n_layers <= 0:
        raise ValueError(
            f"No layers found in {wufi_file.name}"
        )

    return n_layers, n_monitors, n_sensors

def create_water_content_summary(
    ascii_file_list: list[Path],
    n_layers: int,
    n_sensors: int,
    layer_id: int,
    variable: str,
    wufi_datetime_format: str,
) -> pd.DataFrame:
    """
    Read all WUFI ASC files and calculate the mean and maximum
    water content for every layer.

    The optimization-variable value is extracted from each ASC
    filename from the number following '_f'.

    Returns
    -------
    pd.DataFrame
        One row per ASC file, sorted by the optimization-variable value.
    """

    if not ascii_file_list:
        raise ValueError("The ASC file list is empty.")

    if n_layers <= 0:
        raise ValueError(
            f"n_layers must be positive, received {n_layers}."
        )

    if n_sensors <= 0:
        raise ValueError(
            f"n_sensors must be positive, received {n_sensors}."
        )

    variable_column = f"Layer {layer_id} {variable}"

    summary_rows = []

    for asc in ascii_file_list:

        print(f"\nReading: {asc.name}")

        df = pd.read_csv(
            asc,
            header=None,
            comment="#",
            skip_blank_lines=True,
            sep=r"\s+",
            engine="python",
        )

        df = (
            df
            .dropna(axis=0, how="all")
        )

        if df.empty:
            raise ValueError(
                f"The ASC file contains no readable data: {asc.name}"
            )

        # -------------------------------------------------------------
        # Read the time column
        # -------------------------------------------------------------

        time_raw = df.iloc[:, 0].astype(str).str.strip()

        time_values = pd.to_datetime(
            time_raw,
            format=wufi_datetime_format,
            errors="coerce",
        )

        parsed_as_datetime = (
            time_values.notna().mean() > 0.5
        )

        if not parsed_as_datetime:
            print(
                f"WARNING: Could not parse date/time in {asc.name}. "
                "Using row numbers as the time axis."
            )

            time_values = pd.Series(
                np.arange(len(df)),
                name="TimeStep",
            )

        # -------------------------------------------------------------
        # Convert output columns to numeric values
        # -------------------------------------------------------------

        data = df.iloc[:, 1:].copy()

        for column in data.columns:
            data[column] = pd.to_numeric(
                data[column]
                .astype(str)
                .str.replace(",", ".", regex=False),
                errors="coerce",
            )

        data = data.reset_index(drop=True)
        time_values = pd.Series(
            time_values
        ).reset_index(drop=True)

        # -------------------------------------------------------------
        # Isolate the layer water-content columns
        # -------------------------------------------------------------

        expected_numeric_columns = (
            2 * n_sensors
            + n_layers
            + 1
        )

        if data.shape[1] != expected_numeric_columns:
            raise ValueError(
                f"{asc.name} contains {data.shape[1]} numeric columns, "
                f"but exactly {expected_numeric_columns} were expected.\n"
                f"Sensors: {n_sensors}\n"
                f"Layers: {n_layers}"
            )

        water_start = 2 * n_sensors

        water_layers = data.iloc[
            :,
            water_start : water_start + n_layers,
        ].copy()

        if not np.isfinite(water_layers.to_numpy(dtype=float)).all():
            raise ValueError(f"{asc.name}: water-content columns contain missing or non-finite values")

        water_layers.columns = [
            f"Layer {layer_number}"
            for layer_number in range(1, n_layers + 1)
        ]

        # -------------------------------------------------------------
        # Extract the variable value from the ASC filename
        # -------------------------------------------------------------

        match = re.search(
            r"_f([+-]?\d+(?:[.,]\d+)?(?:[eE][+-]?\d+)?)(?=_|$)",
            asc.stem,
        )

        if match is None:
            raise ValueError(
                "Could not find a variable value after '_f' "
                f"in the ASC filename: {asc.name}"
            )

        variable_value = float(
            match.group(1).replace(",", ".")
        )

        # -------------------------------------------------------------
        # Create one summary row for this ASC file
        # -------------------------------------------------------------

        row = {
            variable_column: variable_value,
        }

        for layer_name in water_layers.columns:

            layer_values = water_layers[layer_name]

            mean_value = layer_values.mean(
                skipna=True
            )

            maximum_value = layer_values.max(
                skipna=True
            )

            row[
                f"{layer_name} mean water content"
            ] = mean_value

            row[
                f"{layer_name} maximum water content"
            ] = maximum_value

            print(
                f"{layer_name}: "
                f"mean={mean_value}, "
                f"maximum={maximum_value}"
            )

        summary_rows.append(row)

    summary_df = pd.DataFrame(summary_rows)

    summary_df = summary_df.sort_values(
        by=variable_column,
        ignore_index=True,
    )

    return summary_df

def plot_layer_water_content_summary(
    summary_df: pd.DataFrame,
    variable_column: str,
    optim_dir: Path,
    statistic: str = "maximum",
    dpi: int = 300,
) -> Path:
    """
    Plot layer water-content statistics against the optimization variable.

    Parameters
    ----------
    summary_df
        Summary table produced by create_water_content_summary().

    variable_column
        Name of the x-axis column, for example:
        "Layer 6 Thickness".

    optim_dir
        Folder where the graph will be saved.

    statistic
        Either "mean" or "maximum".

    dpi
        Resolution of the saved image.

    Returns
    -------
    Path
        Path of the saved graph.
    """

    statistic = statistic.lower().strip()

    if statistic not in {"mean", "maximum"}:
        raise ValueError(
            "statistic must be either 'mean' or 'maximum'."
        )

    if variable_column not in summary_df.columns:
        raise KeyError(
            f"Column {variable_column!r} was not found in summary_df."
        )

    column_pattern = (
        rf"Layer \d+ {statistic} water content"
    )

    water_columns = [
        column
        for column in summary_df.columns
        if re.fullmatch(
            column_pattern,
            column,
        )
    ]

    if not water_columns:
        raise ValueError(
            f"No layer {statistic}-water-content columns "
            "were found in summary_df."
        )

    water_columns = sorted(
        water_columns,
        key=lambda column: int(
            re.search(
                r"Layer (\d+)",
                column,
            ).group(1)
        ),
    )

    fig, ax = plt.subplots(
        figsize=(10, 6),
    )

    for column in water_columns:

        layer_number = re.search(
            r"Layer (\d+)",
            column,
        ).group(1)

        ax.plot(
            summary_df[variable_column],
            summary_df[column],
            marker="o",
            linewidth=1.5,
            label=f"Layer {layer_number}",
        )

    title_statistic = statistic.capitalize()

    ax.set_title(
        f"{title_statistic} layer water content versus "
        f"{variable_column}"
    )

    ax.set_xlabel(variable_column)

    ax.set_ylabel(
        f"{title_statistic} water content [kg/m³]"
    )

    ax.grid(
        True,
        linestyle="--",
        alpha=0.3,
    )

    ax.legend(
        title="Layer",
        bbox_to_anchor=(1.02, 1),
        loc="upper left",
    )

    fig.tight_layout()

    graph_path = (
        optim_dir
        / f"{statistic}_water_content_by_variable.png"
    )

    fig.savefig(
        graph_path,
        dpi=dpi,
        bbox_inches="tight",
    )

    plt.show()
    plt.close(fig)

    print(f"Saved graph: {graph_path}")

    return graph_path
#%% create temp dir (unzipped direcotry of original file)
# =============================================================================
# MAIN WORKFLOW
# =============================================================================

def main():
    """
    Run the complete WUFI optimization workflow:

    1. Find the original WUFI project.
    2. Extract the original project.
    3. Create the optimization directory.
    4. Generate one modified XML/project for every variable value.
    5. Create checksum files.
    6. Repackage the generated projects as WUFI .w6p files.
    7. Create and run the WUFI batch calculations.
    8. Find the resulting ASC files.
    9. Read layer and sensor metadata.
    10. Calculate layer water-content statistics.
    11. Save the summary as CSV.
    12. Plot the selected water-content statistic.

    Returns
    -------
    dict
        Paths and results produced by the workflow.
    """

    workflow_started = time.time()

    print("=" * 70)
    print("Starting WUFI optimization workflow")
    print("=" * 70)

    # ---------------------------------------------------------------------
    # 1. Find the original WUFI project
    # ---------------------------------------------------------------------

    wufi_files = sorted(working_dir.glob("*.w6p"))

    if not wufi_files:
        raise FileNotFoundError(
            f"No original .w6p file found in:\n{working_dir}"
        )

    if len(wufi_files) > 1:
        print(
            f"WARNING: Found {len(wufi_files)} WUFI files in the "
            "working directory."
        )
        print(
            f"Using the first file alphabetically: "
            f"{wufi_files[0].name}"
        )

    source_wufi_file = wufi_files[0]

    print(f"\nSource WUFI project: {source_wufi_file.name}")


    # ---------------------------------------------------------------------
    # 2. Validate optimization settings
    # ---------------------------------------------------------------------

    if launch_number <= 0:
        raise ValueError(
            f"launch_number must be positive, received {launch_number}."
        )

    if len(variable_values) != launch_number:
        raise ValueError(
            f"launch_number is {launch_number}, but "
            f"{len(variable_values)} variable values were generated."
        )

    print(
        f"Optimization variable: "
        f"Layer {Layer_id} {variable}"
    )

    print(
        f"Variable values: "
        f"{variable_values}"
    )


    # ---------------------------------------------------------------------
    # 3. Extract the original WUFI project
    # ---------------------------------------------------------------------

    print("\nExtracting original WUFI project...")

    temp_dir = create_temp_dir(
        source_wufi_file
    )

    print(f"Extracted project to: {temp_dir}")


    # ---------------------------------------------------------------------
    # 4. Create a clean optimization directory
    # ---------------------------------------------------------------------

    print("\nCreating optimization directory...")

    optim_dir = create_optim_dir(
        source_wufi_file
    )

    print(f"Optimization directory: {optim_dir}")


    # ---------------------------------------------------------------------
    # 5. Create modified XML files
    # ---------------------------------------------------------------------

    print("\nCreating modified WUFI project files...")

    created_xml_files = create_comp_xml_files(
        temp_dir=temp_dir,
        launch_number=launch_number,
        variable_values=variable_values,
        variable=variable,
        Layer_id=Layer_id,
        optim_dir=optim_dir,
    )

    print(
        f"Created {len(created_xml_files)} modified XML file(s)."
    )


    # ---------------------------------------------------------------------
    # 6. Create checksum files
    # ---------------------------------------------------------------------

    print("\nCreating checksum files...")

    create_checksum_files(
        optim_dir=optim_dir
    )

    print("Checksum files created.")


    # ---------------------------------------------------------------------
    # 7. Repackage generated projects as .w6p files
    # ---------------------------------------------------------------------

    print("\nRepackaging generated WUFI projects...")

    zip_comp_wufi_dirs(
        optim_dir=optim_dir
    )

    generated_wufi_files = sorted(
        optim_dir.glob("*.w6p")
    )

    if len(generated_wufi_files) != launch_number:
        raise RuntimeError(
            f"Expected {launch_number} generated WUFI files, "
            f"but found {len(generated_wufi_files)}."
        )

    print(
        f"Created {len(generated_wufi_files)} "
        "generated WUFI project(s)."
    )


    # ---------------------------------------------------------------------
    # 8. Create batch files and run WUFI calculations
    # ---------------------------------------------------------------------

    print("\nStarting WUFI calculations...")

    run_results = create_and_run_all_wufi_files(
        optim_dir=optim_dir,
        skip_series=skip_series_constant,
        start_delay=10,
    )

    failed_runs = [
        result
        for result in run_results
        if not result["success"]
    ]

    if failed_runs:
        print(
            f"\nWARNING: {len(failed_runs)} WUFI calculation(s) "
            "reported a nonzero exit code."
        )

        for failed_run in failed_runs:
            print(
                f"  {failed_run['batch_file']}: "
                f"exit code {failed_run['return_code']}"
            )
        raise RuntimeError("WUFI calculations failed; results were not summarised")


    # ---------------------------------------------------------------------
    # 9. Find generated ASC and WUFI files
    # ---------------------------------------------------------------------

    print("\nFinding generated result files...")

    ascii_file_list, wufi_file_list = find_wufi_asc_files(
        optim_dir=optim_dir
    )

    print(f"ASC files found: {len(ascii_file_list)}")
    print(f"WUFI files found: {len(wufi_file_list)}")

    if len(ascii_file_list) != launch_number:
        print(
            f"WARNING: Expected {launch_number} ASC files, "
            f"but found {len(ascii_file_list)}."
        )


    # ---------------------------------------------------------------------
    # 10. Read layer and sensor counts
    # ---------------------------------------------------------------------

    print("\nReading WUFI project metadata...")

    wufi_file_for_metadata = wufi_file_list[0]

    n_layers, n_monitors, n_sensors = (
        read_wufi_layer_sensor_counts(
            wufi_file=wufi_file_for_metadata,
            boundary_sensor_count=boundary_sensor_count,
        )
    )

    print(f"Metadata source: {wufi_file_for_metadata.name}")
    print(f"Detected layers: {n_layers}")
    print(f"Detected monitor positions: {n_monitors}")
    print(f"Detected sensors: {n_sensors}")


    # ---------------------------------------------------------------------
    # 11. Calculate water-content statistics
    # ---------------------------------------------------------------------

    print("\nCalculating water-content statistics...")

    summary_df = create_water_content_summary(
        ascii_file_list=ascii_file_list,
        n_layers=n_layers,
        n_sensors=n_sensors,
        layer_id=Layer_id,
        variable=variable,
        wufi_datetime_format=wufi_datetime_format,
    )

    variable_column = (
        f"Layer {Layer_id} {variable}"
    )


    # ---------------------------------------------------------------------
    # 12. Save water-content summary
    # ---------------------------------------------------------------------

    summary_path = (
        optim_dir
        / "water_content_summary.csv"
    )

    summary_df.to_csv(
        summary_path,
        index=False,
    )

    print(
        f"\nSaved water-content summary:\n"
        f"{summary_path}"
    )


    # ---------------------------------------------------------------------
    # 13. Plot mean layer water content
    # ---------------------------------------------------------------------

    print("\nCreating water-content graph...")

    graph_path = plot_layer_water_content_summary(
        summary_df=summary_df,
        variable_column=variable_column,
        optim_dir=optim_dir,
        statistic="mean",
        dpi=300,
    )


    # ---------------------------------------------------------------------
    # 14. Finish workflow
    # ---------------------------------------------------------------------

    elapsed_seconds = time.time() - workflow_started

    print("\n" + "=" * 70)
    print("WUFI optimization workflow completed")
    print(f"Elapsed time: {elapsed_seconds:.1f} seconds")
    print(f"Optimization directory: {optim_dir}")
    print(f"Summary file: {summary_path}")
    print(f"Graph file: {graph_path}")
    print("=" * 70)

    return {
        "source_wufi_file": source_wufi_file,
        "temp_dir": temp_dir,
        "optim_dir": optim_dir,
        "created_xml_files": created_xml_files,
        "generated_wufi_files": generated_wufi_files,
        "ascii_files": ascii_file_list,
        "run_results": run_results,
        "summary_df": summary_df,
        "summary_path": summary_path,
        "graph_path": graph_path,
        "n_layers": n_layers,
        "n_monitors": n_monitors,
        "n_sensors": n_sensors,
        "elapsed_seconds": elapsed_seconds,
    }


if __name__ == "__main__":
    results = main()
