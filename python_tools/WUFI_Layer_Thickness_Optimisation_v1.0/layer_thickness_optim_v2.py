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
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR

# Internal checksum setting used by WUFI project files.

POLYNOMIAL = 0x04C11DB7

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


def command_line(
    file_name,
    n_layers,
    n_sensors,
    skip_series,
    batch_command,
    wufi_settings,
):
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

def parse_xml_number(value: str) -> float:
    """Convert WUFI numbers using either a decimal comma or decimal point."""
    return xml_number(value)


def calculate_u_value(xml_file: Path) -> float:
    """Calculate the overall 1D U-value of the first WUFI case."""
    root = ET.parse(xml_file).getroot()
    first_case = root.find(".//Case")

    if first_case is None:
        raise ValueError(f"No <Case> element found in {xml_file}")

    layers = first_case.findall("./Component/Layers/Layer")
    if not layers:
        raise ValueError(f"No construction layers found in {xml_file}")

    surface_scalars = first_case.find("./Component/SurfaceTransfer/Scalars")
    if surface_scalars is None:
        raise ValueError(f"No surface-transfer values found in {xml_file}")

    exterior = surface_scalars.find(
        "./Scalar[@name='HeatTransferCoeffExt']"
    )
    interior = surface_scalars.find(
        "./Scalar[@name='HeatTransferCoeffInt']"
    )
    if exterior is None or interior is None:
        raise ValueError(
            "Interior or exterior surface thermal resistance is missing"
        )

    # Despite their XML names, these values have units of (m2 K)/W and are
    # therefore stored surface resistances, not W/(m2 K) coefficients.
    total_resistance = (
        parse_xml_number(exterior.get("value"))
        + parse_xml_number(interior.get("value"))
    )

    for layer in layers:
        layer_index = layer.get("Index", "unknown")
        thickness_scalar = layer.find(
            "./Scalars/Scalar[@name='Thickness']"
        )
        design_lambda = layer.find(
            ".//Scalar[@name='Thermal Conductivity, Design Value']"
        )
        dry_lambda = layer.find(
            ".//Scalar[@name='Thermal Conductivity, Dry, 10°C']"
        )

        if thickness_scalar is None:
            raise ValueError(f"Layer {layer_index} has no thickness")

        conductivity = None
        if design_lambda is not None:
            raw_design_value = design_lambda.get("value", "").strip()
            if raw_design_value:
                conductivity = parse_xml_number(raw_design_value)

        if conductivity is None:
            if dry_lambda is None or not dry_lambda.get("value", "").strip():
                raise ValueError(
                    f"Layer {layer_index} has no usable thermal conductivity"
                )
            conductivity = parse_xml_number(dry_lambda.get("value"))

        if conductivity <= 0:
            raise ValueError(
                f"Layer {layer_index} thermal conductivity must be positive"
            )

        thickness = parse_xml_number(thickness_scalar.get("value"))
        if thickness <= 0:
            raise ValueError(f"Layer {layer_index} thickness must be positive")
        total_resistance += thickness / conductivity

    if total_resistance <= 0:
        raise ValueError("Total thermal resistance must be positive")

    return 1.0 / total_resistance


def create_temp_dir(wufi_file):
    temp_dir = wufi_file.with_name(f"temp_{wufi_file.stem}_unzipped")

    if temp_dir.exists():
        shutil.rmtree(temp_dir)

    temp_dir.mkdir()

    with zipfile.ZipFile(wufi_file, "r") as archive:
        archive.extractall(temp_dir)

    return temp_dir

def create_optim_dir(
        wufi_file: Path,
        run_name: str,
        ):
    
    optim_dir = (
        wufi_file.parent / "optimisation_runs" / run_name
    )

    if optim_dir.exists():
        shutil.rmtree(optim_dir)

    optim_dir.mkdir(
        parents = True,
        exist_ok = True,
    )

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
        batch_command: str,
        wufi_settings: str,
        start_delay: float = 10.0,
        boundary_sensor_count: int = 2,
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
            batch_command=batch_command,
            wufi_settings=wufi_settings,
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
            water_start : water_start + n_layers + 1,
        ].copy()

        if not np.isfinite(water_layers.to_numpy(dtype=float)).all():
            raise ValueError(f"{asc.name}: water-content columns contain missing or non-finite values")

        water_layers.columns = [
            f"Layer {layer_number}"
            for layer_number in range(1, n_layers + 1)
        ] + ["Total construction"]

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

            initial_value = layer_values.iloc[0]
            final_value = layer_values.iloc[-1]
            accumulation = final_value - initial_value

            row[
                f"{layer_name} mean water content"
            ] = mean_value

            row[
                f"{layer_name} maximum water content"
            ] = maximum_value

            row[f"{layer_name} initial water content"] = initial_value
            row[f"{layer_name} final water content"] = final_value
            row[f"{layer_name} water accumulation"] = accumulation

            print(
                f"{layer_name}: "
                f"mean={mean_value}, "
                f"maximum={maximum_value}, "
                f"accumulation={accumulation}"
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


def rank_design(
        result: dict,
        thickness: float,
        u_target: float,
        layer_limits: dict,
):
    """
    Return a comparison tuple. Lower is better.

    Feasible designs always beat infeasible designs.
    Among feasible designs, lower thickness is better.
    Among infeasible designs, lower total violation is better.
    """

    # Missing numerical results must not compare as zero constraint violation.
    if not math.isfinite(u_target) or u_target <= 0:
        raise ValueError("u_target must be finite and positive")
    if not math.isfinite(result["u_value"]) or not math.isfinite(thickness):
        raise ValueError("Design U-value and thickness must be finite")
    water = result["water_content"]

    total_violation = 0.0

    u_violation = max(
        0.0,
        result["u_value"] / u_target - 1
    )

    total_violation += u_violation
    for layer_number, limits in layer_limits.items():

        maximum_water = water[
            f"Layer {layer_number} maximum water content"
        ]

        accumulation = water[
            f"Layer {layer_number} water accumulation"
        ]

        for key in ("maximum", "accumulation"):
            if not math.isfinite(limits[key]) or limits[key] <= 0:
                raise ValueError(f"Layer {layer_number} {key} limit must be finite and positive")
        if not math.isfinite(maximum_water) or not math.isfinite(accumulation):
            raise ValueError(f"Layer {layer_number} water results must be finite")

        maximum_violation = max(
            0.0,
            maximum_water / limits["maximum"] - 1.0
        )

        accumulation_violation = max(
            0.0,
            accumulation / limits["accumulation"] - 1.0,
        )

        total_violation += maximum_violation
        total_violation += accumulation_violation

    feasible = total_violation == 0.0

    if feasible:
        # 0 makes every feasible design better than an infeasible one.

        return (0, thickness, result["u_value"])

    return (1, total_violation, thickness)


def update_optimisation_graph(
    history: list,
    graph_path: Path,
    u_target: float,
    layer_limits: dict,
    show_live: bool = True,
) -> Path | None:
    """Update and save thickness, U-value, and water-content plots."""
    successful = [
        (evaluation_number, evaluation)
        for evaluation_number, evaluation in enumerate(history, start=1)
        if evaluation["success"]
    ]

    if not successful:
        return None

    evaluation_numbers = [item[0] for item in successful]
    evaluations = [item[1] for item in successful]

    thickness_values = [
        evaluation["thickness"]
        for evaluation in evaluations
    ]
    u_values = [
        evaluation["result"]["u_value"]
        for evaluation in evaluations
    ]

    figure = plt.figure(
        num="WUFI optimisation progress",
        figsize=(10, 11),
        clear=True,
    )
    thickness_axis, u_axis, water_axis = figure.subplots(
        3,
        1,
        sharex=True,
    )

    thickness_axis.plot(
        evaluation_numbers,
        thickness_values,
        marker="o",
        linewidth=1.5,
        color="tab:blue",
    )
    thickness_axis.set_ylabel("Thickness [m]")
    thickness_axis.set_title("Selected layer thickness")
    thickness_axis.grid(True, linestyle="--", alpha=0.3)

    u_axis.plot(
        evaluation_numbers,
        u_values,
        marker="o",
        linewidth=1.5,
        color="tab:orange",
        label="Calculated U-value",
    )
    u_axis.axhline(
        u_target,
        color="tab:red",
        linestyle="--",
        label=f"Target: {u_target:.3f} W/(m²K)",
    )
    u_axis.set_ylabel("U-value [W/(m²K)]")
    u_axis.set_title("Overall construction U-value")
    u_axis.grid(True, linestyle="--", alpha=0.3)
    u_axis.legend()

    for layer_number, limits in layer_limits.items():
        column = f"Layer {layer_number} maximum water content"
        water_values = [
            evaluation["result"]["water_content"].get(column, np.nan)
            for evaluation in evaluations
        ]

        line, = water_axis.plot(
            evaluation_numbers,
            water_values,
            marker="o",
            linewidth=1.5,
            label=f"Layer {layer_number} maximum",
        )
        water_axis.axhline(
            limits["maximum"],
            color=line.get_color(),
            linestyle="--",
            alpha=0.7,
            label=f"Layer {layer_number} limit",
        )

    water_axis.set_xlabel("Evaluation number")
    water_axis.set_ylabel("Water content [kg/m³]")
    water_axis.set_title("Maximum water content in critical layers")
    water_axis.grid(True, linestyle="--", alpha=0.3)
    water_axis.legend()

    figure.suptitle("WUFI adaptive thickness optimisation")
    figure.tight_layout()
    figure.savefig(
        graph_path,
        dpi=200,
        bbox_inches="tight",
    )

    if show_live:
        plt.show(block=False)
        plt.pause(0.1)

    return graph_path


def optimise_thickness(
        evaluation_settings: dict,
        initial_thickness: float,
        initial_step: float,
        minimum_step: float,
        maximum_step:float,
        u_target: float,
        layer_limits: dict,
        show_live_graph: bool,
        max_attempts_per_thickness: int,
):

    if max_attempts_per_thickness < 1:
        raise ValueError("max_attempts_per_thickness must be at least 1")

    steps = (initial_step, minimum_step, maximum_step)
    if not all(math.isfinite(step) and step > 0 for step in steps):
        raise ValueError("Optimisation steps must be finite and positive")
    if not minimum_step <= initial_step <= maximum_step:
        raise ValueError("Require minimum_step <= initial_step <= maximum_step")
    lower, upper = evaluation_settings["variable_bounds"]
    if not (math.isfinite(lower) and math.isfinite(upper) and 0 < lower <= upper):
        raise ValueError("Thickness bounds must be finite, positive and ordered")
    if not math.isfinite(initial_thickness):
        raise ValueError("Initial thickness must be finite")

    cache = {}
    history = []
    history_path = (
        evaluation_settings["working_dir"]
        / f"optimisation_history_{time.strftime('%Y%m%d_%H%M%S')}.csv"
    )
    graph_path = history_path.with_suffix(".png")

    print(f"Optimisation history: {history_path}")
    print(f"Optimisation graph: {graph_path}")

    if show_live_graph:
        plt.ion()

    lower_bound, upper_bound = (
        evaluation_settings["variable_bounds"]
    )

    # Decimal avoids moving exact grid boundaries because of float round-off.
    grid_lower = float((Decimal(str(lower_bound)) * 10000).to_integral_value(
        rounding=ROUND_CEILING)) / 10000
    grid_upper = float((Decimal(str(upper_bound)) * 10000).to_integral_value(
        rounding=ROUND_FLOOR)) / 10000
    if grid_lower > grid_upper:
        raise ValueError("Thickness bounds contain no value on the 0.0001 m search grid")

    def evaluate(thickness):
        nonlocal history_path, graph_path

        thickness = round(
            max(
                grid_lower,
                min(grid_upper, thickness),
            ),
            4,
        )

        if thickness in cache: 
            return cache[thickness]

        print(f"\nEvaluating thickness {thickness:.4f} m")

        evaluation = None

        for attempt in range(1, max_attempts_per_thickness + 1):
            try:
                print(
                    f"Attempt {attempt}/{max_attempts_per_thickness} "
                    f"for {thickness:.4f} m"
                )

                result = evaluate_case(
                    candidate_value=thickness,
                    **evaluation_settings,
                )

                rank = rank_design(
                    result=result,
                    thickness=thickness,
                    u_target=u_target,
                    layer_limits=layer_limits,
                )

                evaluation = {
                    "thickness": thickness,
                    "success": True,
                    "skipped": False,
                    "attempts": attempt,
                    "rank": rank,
                    "result": result,
                }
                break

            except Exception as error:
                print(
                    f"Attempt {attempt} failed for {thickness:.4f} m: "
                    f"{error}"
                )

                if attempt == max_attempts_per_thickness:
                    evaluation = {
                        "thickness": thickness,
                        "success": False,
                        "skipped": True,
                        "attempts": attempt,
                        "rank": (2, float("inf"), thickness),
                        "result": None,
                        "error": str(error),
                    }
                    print(
                        f"Skipping thickness {thickness:.4f} m after "
                        f"{attempt} failed attempt(s)."
                    )

        cache[thickness] = evaluation
        history.append(evaluation)

        history_path = save_optimisation_history(
            history = history,
            history_path = history_path,
        )
        graph_path = history_path.with_suffix(".png")
        update_optimisation_graph(
            history=history,
            graph_path=graph_path,
            u_target=u_target,
            layer_limits=layer_limits,
            show_live=show_live_graph,
        )

        return evaluation

    current = evaluate(initial_thickness)
    step = initial_step

    while step >= minimum_step:
        thinner = evaluate(
            current["thickness"] - step
        )

        thicker = evaluate(
            current["thickness"] + step
        )

        best = min(
            [current, thinner, thicker],
            key = lambda item: item["rank"],
        )

        if best["rank"] < current["rank"]:
            old_thickness = current["thickness"]
            current = best

            direction = (
                "thicker"
                if current["thickness"] > old_thickness
                else "thinner"
            )

            #increase step slightly after a succesful move.

            step = min(
                step*1.1,
                maximum_step,
            )

            print(
                f"Moving {direction} to "
                f"{current['thickness']:.4f} m; "
                f"next step = {step:.4f} m"
            )

        else:

            #neither direction improved result

            step /= 2.0

            print(
                f"No improvement; reducing step to "
                f"{step:.4f} m"
            )

    successful_evaluations = [
        evaluation
        for evaluation in history
        if evaluation["success"]
    ]

    if not successful_evaluations:
        errors = "; ".join(
            evaluation.get("error", "unknown error")
            for evaluation in history
        )
        raise RuntimeError(
            f"All WUFI evaluations failed. Errors: {errors}"
        )

    best_successful = min(
        successful_evaluations,
        key=lambda evaluation: evaluation["rank"],
    )

    return {
        "best": best_successful,
        "history": history,
        "history_path": history_path,
        "graph_path": graph_path,
    }

def save_optimisation_history(
        history: list,
        history_path: Path,
) -> Path:
    rows = []

    for evaluation in history:
        row = {
            "Thickness [m]": evaluation["thickness"],
            "Success": evaluation["success"],
            "Skipped": evaluation.get("skipped", False),
            "Attempts": evaluation.get("attempts", 1),
            "Rank": str(evaluation["rank"]),
        }

        if evaluation["success"]:
            result = evaluation["result"]

            row["U-value [W/(m^2K)]"] = (
                result["u_value"]
            )

            row.update(result["water_content"])
        else:
            row["Error"] = evaluation["error"]

        rows.append(row)

    history_df = pd.DataFrame(rows)

    try:
        history_df.to_csv(
            history_path,
            index=False,
        )
    except PermissionError:
        fallback_path = history_path.with_name(
            f"{history_path.stem}_continued_{time.time_ns()}"
            f"{history_path.suffix}"
        )
        history_df.to_csv(
            fallback_path,
            index=False,
        )
        print(
            f"WARNING: Could not update {history_path.name}; it may be "
            f"open in another program. Continuing with {fallback_path.name}."
        )
        history_path = fallback_path

    return history_path


#%% Main workflow
# =============================================================================
# MAIN WORKFLOW
# =============================================================================

# def legacy_main(**settings):
#     """Optional alias that forwards explicit settings to the main workflow."""
#     return main(**settings)


def evaluate_case(
    working_dir: Path,
    layer_id: int,
    variable: str,
    variable_bounds: tuple[float, float],
    candidate_value: float,
    wufi_datetime_format: str,
    batch_command: str,
    wufi_settings: str,
    skip_series_constant: int,
    boundary_sensor_count: int,
):
    """Clone, run, and evaluate one modified WUFI construction."""
    workflow_started = time.time()

    print("=" * 70)
    print("Starting single-case WUFI evaluation")
    print("=" * 70)

    source_files = sorted(working_dir.glob("*.w6p"))
    if not source_files:
        raise FileNotFoundError(
            f"No source .w6p file found in {working_dir}"
        )
    if len(source_files) > 1:
        raise RuntimeError(
            f"Expected one source .w6p file in {working_dir}, "
            f"but found {len(source_files)}"
        )

    if not variable_bounds[0] <= candidate_value <= variable_bounds[1]:
        raise ValueError(
            f"candidate_value={candidate_value} is outside "
            f"variable_bounds={variable_bounds}"
        )

    source_wufi_file = source_files[0]
    print(f"Source project: {source_wufi_file.name}")
    print(f"Layer {layer_id} {variable}: {candidate_value}")

    temp_dir = create_temp_dir(source_wufi_file)

    run_name = (
        f"layer_{layer_id}_"
        f"{variable.lower()}_"
        f"{candidate_value:.4f}"
    ).replace(".", "_")

    optim_dir = create_optim_dir(
        source_wufi_file,
        run_name,
    )

    created_xml_files = create_comp_xml_files(
        temp_dir=temp_dir,
        launch_number=1,
        variable_values=[candidate_value],
        variable=variable,
        Layer_id=layer_id,
        optim_dir=optim_dir,
    )
    if len(created_xml_files) != 1:
        raise RuntimeError("Exactly one modified XML file was expected")

    modified_xml = created_xml_files[0]
    u_value = calculate_u_value(modified_xml)
    print(f"Overall U-value: {u_value:.4f} W/(m²K)")

    create_checksum_files(optim_dir=optim_dir)
    zip_comp_wufi_dirs(optim_dir=optim_dir)

    generated_wufi_files = sorted(optim_dir.glob("*.w6p"))
    if len(generated_wufi_files) != 1:
        raise RuntimeError(
            f"Expected one generated .w6p file, "
            f"but found {len(generated_wufi_files)}"
        )

    run_results = create_and_run_all_wufi_files(
        optim_dir=optim_dir,
        skip_series=skip_series_constant,
        batch_command=batch_command,
        wufi_settings=wufi_settings,
        start_delay=0,
        boundary_sensor_count=boundary_sensor_count,
    )
    if len(run_results) != 1 or not run_results[0]["success"]:
        raise RuntimeError(f"WUFI calculation failed: {run_results}")

    ascii_file_list, wufi_file_list = find_wufi_asc_files(
        optim_dir=optim_dir
    )
    if len(ascii_file_list) != 1 or len(wufi_file_list) != 1:
        raise RuntimeError(
            "Expected exactly one ASC result and one generated WUFI file"
        )

    n_layers, n_monitors, n_sensors = read_wufi_layer_sensor_counts(
        wufi_file=wufi_file_list[0],
        boundary_sensor_count=boundary_sensor_count,
    )

    summary_df = create_water_content_summary(
        ascii_file_list=ascii_file_list,
        n_layers=n_layers,
        n_sensors=n_sensors,
        layer_id=layer_id,
        variable=variable,
        wufi_datetime_format=wufi_datetime_format,
    )
    if len(summary_df) != 1:
        raise RuntimeError("Exactly one summary row was expected")

    variable_column = f"Layer {layer_id} {variable}"
    summary_df.loc[0, variable_column] = candidate_value
    summary_df.insert(1, "Overall U-value [W/(m²K)]", u_value)

    summary_path = optim_dir / "single_case_summary.csv"
    summary_df.to_csv(summary_path, index=False)

    elapsed_seconds = time.time() - workflow_started
    print("\n" + "=" * 70)
    print("Single-case WUFI evaluation completed")
    print(f"Overall U-value: {u_value:.4f} W/(m²K)")
    print(f"Water-content summary: {summary_path}")
    print(f"Elapsed time: {elapsed_seconds:.1f} seconds")
    print("=" * 70)

    return {
        "source_wufi_file": source_wufi_file,
        "generated_wufi_file": generated_wufi_files[0],
        "ascii_file": ascii_file_list[0],
        "modified_xml": modified_xml,
        "u_value": u_value,
        "water_content": summary_df.iloc[0].to_dict(),
        "summary_df": summary_df,
        "summary_path": summary_path,
        "n_layers": n_layers,
        "n_monitors": n_monitors,
        "n_sensors": n_sensors,
        "elapsed_seconds": elapsed_seconds,
    }


if __name__ == "__main__":
    # =====================================================================
    # USER SETTINGS
    # =====================================================================

    working_dir = Path(
        r"C:\Users\user\Desktop\Valteram_Ribickim_WUFI_tutorials\testing_ground\wall_optimisation"
    )

    layer_id = 4
    variable = "Thickness"
    variable_bounds = (0.01, 0.5)


    # WUFI command-line and ASC-export settings.
    batch_command = "WUFI "
    wufi_settings = " -C -s -v"
    skip_series_constant = 19
    boundary_sensor_count = 2
    wufi_datetime_format = "%Y-%m-%dT%H:%M:%S"

    initial_thickness = 0.1
    initial_step = 0.02
    minimum_step = 0.002
    maximum_step = 0.04
    u_target = 0.18
    show_live_graph = True
    max_attempts_per_thickness = 2

    layer_limits = {
        2: {
            "maximum": 22.0,
            "accumulation": 2.0
        },
        3: {
            "maximum": 4.0,
            "accumulation": 1.0,
        }
    }

    evaluation_settings = {
        "working_dir": working_dir,
        "layer_id": layer_id,
        "variable": variable,
        "variable_bounds": variable_bounds,
        "wufi_datetime_format": wufi_datetime_format,
        "batch_command": batch_command,
        "wufi_settings": wufi_settings,
        "skip_series_constant": skip_series_constant,
        "boundary_sensor_count": boundary_sensor_count,
    }

    optimisation = optimise_thickness(
        evaluation_settings=evaluation_settings,
        initial_thickness=initial_thickness,
        initial_step=initial_step,
        minimum_step=minimum_step,
        maximum_step=maximum_step,
        u_target=u_target,
        layer_limits=layer_limits,
        show_live_graph=show_live_graph,
        max_attempts_per_thickness=max_attempts_per_thickness,
    )

    print("\nBest design:")
    print(
        optimisation["best"]["result"]["summary_df"]
    )

    print(f"\nHistory saved to: {optimisation['history_path']}")
    print(f"Graph saved to: {optimisation['graph_path']}")

    if show_live_graph:
        plt.ioff()
        plt.show()
