#%%
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET
import os
import shutil

# Folder containing the .w6p files

current_dir = Path(
    r"C:\Users\user\Desktop\RTU_WUFI_projekts\analysis_14102026\reference"
)

# Settings

batch_command = "WUFI "
wufi_settings = " -C -s -v"

skip_series_constant = 19
boundary_sensor_count = 2

temporary_name = "WUFI run script.txt"
batch_file_name = "WUFI run script.bat"

# Helper functions

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


def extract_wufi_file(wufi_file):
    """Extract a .w6p file into a temporary folder and return that folder."""
    temp_dir = wufi_file.with_name(f"temp_{wufi_file.stem}_unzipped")

    if temp_dir.exists():
        shutil.rmtree(temp_dir)

    temp_dir.mkdir()

    with zipfile.ZipFile(wufi_file, "r") as archive:
        archive.extractall(temp_dir)

    return temp_dir


def get_file_info_from_xml(xml_file):
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

        layers = case.findall(".//Component/Layers/Layer")
        monitors = case.findall(".//MonitorPosition")

        n_layers = len(layers)
        n_monitors = len(monitors)
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

# Find all .w6p files

list_wufi = sorted(current_dir.glob("*.w6p"))

if not list_wufi:
    raise FileNotFoundError(f"No .w6p files found in {current_dir}")

print("WUFI files found:")
for file in list_wufi:
    print(" -", file.name)

# Build one command per case in every .w6p file

commands = [
    "@echo off",
    'cd /d "%~dp0"',
    "",
]

for wufi_file in list_wufi:
    print(f"\nProcessing WUFI file: {wufi_file.name}")

    temp_dir = extract_wufi_file(wufi_file)

    xml_files = list(temp_dir.glob("*.xml"))
    if not xml_files:
        raise FileNotFoundError(f"No XML file found in {temp_dir}")

    xml_file = xml_files[0]

    file_info = get_file_info_from_xml(xml_file)

    # Delete extracted folder after XML info has been read
    shutil.rmtree(temp_dir)
    print(f"Deleted temporary folder: {temp_dir.name}")

    if file_info["mismatch_found"]:
        print(
            f"WARNING: {wufi_file.name} has inconsistent layer/monitor counts. "
            "The command will use the counts from the first case."
        )

    print(
        f"  Cases inside file: {file_info['n_cases']} | "
        f"Layers: {file_info['n_layers']} | "
        f"Sensors: {file_info['n_sensors']}"
    )

    commands.append(
        f"REM {wufi_file.name} | "
        f"{file_info['n_cases']} case(s) | "
        f"{file_info['n_layers']} layers | "
        f"{file_info['n_sensors']} sensors"
    )

    commands.append(
        command_line(
            file_name=wufi_file.name,
            n_layers=file_info["n_layers"],
            n_sensors=file_info["n_sensors"],
            skip_series=skip_series_constant,
        )
    )

    commands.append("")

# Write the .bat file

temporary_path = current_dir / temporary_name
batch_path = current_dir / batch_file_name

temporary_path.write_text("\n".join(commands), encoding="utf-8")

if batch_path.exists():
    batch_path.unlink()

temporary_path.rename(batch_path)

print(f"\nCreated batch file: {batch_path}")

os.startfile(current_dir)


# %%
