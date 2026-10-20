#%%
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET
import shutil
import re
import sys
import time
import os
import traceback
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor, as_completed

import numpy as np
import pandas as pd

# Use a non-interactive Matplotlib backend.
# This is safer when saving plots from multiple parallel worker processes.
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from matplotlib.patches import Rectangle

try:
    from scipy.stats import gaussian_kde
    SCIPY_AVAILABLE = True
except ImportError:
    gaussian_kde = None
    SCIPY_AVAILABLE = False


# =============================================================================
# USER SETTINGS
# =============================================================================

current_dir = Path(
    r"C:\Users\user\Desktop\RTU_WUFI_projekts\analysis_14102026\reference")

raw_data_file_format = ".asc"

boundary_sensor_count = 2
window_size_fraction = 0.01

image_dpi = 200

purge_number = 1

wufi_datetime_format = "%Y-%m-%dT%H:%M:%S"

# =============================================================================
# PARALLEL SETTINGS
# =============================================================================


PARALLEL_SETTINGS = {
    "enabled": True,

    # Backend options:
    #
    #   "thread"
    #       Best for running inside Spyder/Jupyter/notebook cells.
    #       Avoids BrokenProcessPool on Windows.
    #
    #   "process"
    #       Usually faster for CPU-heavy work, but on Windows it should be run
    #       as a normal .py script from Anaconda Prompt / PowerShell, not
    #       cell-by-cell.
    #
    # Recommended:
    #   - Use "thread" while developing in Spyder/Jupyter.
    #   - Use "process" only when running this file as a script.
    "backend": "thread",

    # None = automatic based on CPU count.
    # Start with 2. Try 3 or 4 after confirming it works.
    "max_workers": None,

    # Used only if max_workers is None.
    "leave_free_cores": 1,

    # Worker-level progress bars are disabled in parallel mode because multiple
    # workers printing at the same time makes the console unreadable.
    "show_worker_progress": False,

    # Keep worker print output quiet in parallel mode.
    "verbose_workers": False,
}


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

class SimpleProgressBar:
    def __init__(self, total, desc="", width=40):
        self.total = max(int(total), 1)
        self.desc = desc
        self.width = width
        self.current = 0
        self.start_time = time.time()
        self._print()

    def update(self, step=1):
        self.current += step
        if self.current > self.total:
            self.current = self.total
        self._print()

    def _print(self):
        fraction = self.current / self.total
        filled = int(self.width * fraction)
        bar = "█" * filled + "-" * (self.width - filled)
        percent = 100 * fraction

        elapsed = time.time() - self.start_time

        message = (
            f"\r{self.desc} |{bar}| "
            f"{self.current}/{self.total} "
            f"({percent:5.1f}%) "
            f"elapsed: {elapsed:5.1f}s\n"
        )

        sys.stdout.write(message)
        sys.stdout.flush()

    def close(self):
        self.current = self.total
        self._print()
        sys.stdout.write("\n")
        sys.stdout.flush()


def count_expected_plot_steps(config: dict) -> int:
    n_sensors = config["n_sensors"]
    n_layers = config["n_layers"]

    # Per sensor:
    # humidity, temperature, dew point, mould history, mould risk = 5 plots
    # Per layer:
    # water-content plot = n_layers
    # Plus:
    # total water-content plot = 1
    return 5 * n_sensors + n_layers + 1


# =============================================================================
# WUFI XML READING
# =============================================================================

def extract_wufi_file(wufi_file: Path) -> Path:
    """Temporarily extract a .w6p file and return the extracted folder path."""
    temp_dir = wufi_file.with_name(f"temp_{wufi_file.stem}_unzipped")

    if temp_dir.exists():
        shutil.rmtree(temp_dir)

    temp_dir.mkdir()

    with zipfile.ZipFile(wufi_file, "r") as archive:
        archive.extractall(temp_dir)

    return temp_dir


def get_xml_file_from_extracted_folder(temp_dir: Path) -> Path:
    xml_files = list(temp_dir.glob("*.xml"))

    if not xml_files:
        raise FileNotFoundError(f"No XML file found in {temp_dir}")

    return xml_files[0]


def xml_number(value: str) -> float:
    """Read WUFI numbers with either decimal separator."""
    number = float(value.strip().replace(",", "."))
    if not np.isfinite(number):
        raise ValueError(f"Non-finite XML number: {value!r}")
    return number


def read_case_monitors(case: ET.Element) -> dict:
    """Port monitor validation/order from WUFIModelMetadata.wl parseCase.

    Only numeric ElementID and RealDepthInLayer records within their layer
    are exported sensors. Requested depths do not revive stale records.
    The WUFI tolerance is 1e-9 metres. Sort by global exterior-to-interior
    depth, keeping XML order for ties.
    """
    valid, stale, depth_records = [], [], []
    layer_start = 0.0
    layers = case.findall("./Component/Layers/Layer")
    for ordinal, layer in enumerate(layers, start=1):
        layer_index = layer.get("Index", str(ordinal))
        scalar = layer.find('./Scalars/Scalar[@name="Thickness"]')
        thickness = xml_number(scalar.get("value", "") if scalar is not None else "")
        if thickness <= 0:
            raise ValueError(f"Layer {layer_index}: thickness must be positive")
        material = (layer.findtext("./Material/Name") or "Unnamed material").strip()
        for index, monitor in enumerate(layer.findall('./MonitorPositions/MonitorPosition'), 1):
            element = (monitor.findtext("ElementID") or "").strip()
            depth_scalar = monitor.find('./Scalars/Scalar[@name="RealDepthInLayer"]')
            try:
                depth = xml_number(depth_scalar.get("value", "") if depth_scalar is not None else "")
            except ValueError:
                depth = None
            reason = None
            if re.fullmatch(r"[0-9]+", element) is None:
                reason = "ElementIDNotNumeric"
            elif depth is None:
                reason = "RealDepthNotNumeric"
            elif not -1e-9 <= depth <= thickness + 1e-9:
                reason = "RealDepthOutsideLayer"
            record = {
                "layer_index": layer_index,
                "monitor_index": monitor.get("Index", str(index)),
                "material_name": material,
                "real_depth": depth,
                "element_id_text": element,
            }
            if depth is not None and -1e-9 <= depth <= thickness + 1e-9:
                fraction = min(1.0, max(0.0, depth / thickness))
                third = ("exterior" if fraction <= 1 / 3 + 1e-12 else
                         "middle" if fraction <= 2 / 3 + 1e-12 else "interior")
                record.update(global_depth=layer_start + depth,
                              name=f"{material} - {third} third")
                depth_records.append(record)
            if reason:
                record["reason"] = reason
                stale.append(record)
                continue
            fraction = min(1.0, max(0.0, depth / thickness))
            third = ("exterior" if fraction <= 1 / 3 + 1e-12 else
                     "middle" if fraction <= 2 / 3 + 1e-12 else "interior")
            record.update(global_depth=layer_start + depth,
                          name=f"{material} - {third} third")
            valid.append(record)
        layer_start += thickness
    valid.sort(key=lambda monitor: monitor["global_depth"])

    # Same optional T/RH position-count cross-check as parseGrafikaSensors.
    positions = {}
    for curve in case.findall('./Grafika/CoursesCurves/Curve'):
        type_text = (curve.findtext('CurveTypeID') or '').strip()
        position_text = (curve.findtext('CurvePositionIndex') or '').strip()
        if not (re.fullmatch(r'[0-9]+', type_text) and
                re.fullmatch(r'[0-9]+', position_text)):
            continue
        curve_type = int(type_text)
        if curve_type not in {9, 10, 15}:
            continue
        group = positions.setdefault(int(position_text), {"types": set(), "names": [], "by_type": {}})
        group['types'].add(curve_type)
        group['names'].append(curve.findtext('Name') or '')
        group['by_type'][curve_type] = curve.findtext('Name') or ''
    grafika_internal = None
    if positions:
        grafika_internal = 0
        for group in positions.values():
            names = ' '.join(group['names']).lower()
            if ({9, 10} <= group['types'] and
                    'exterior surface' not in names and 'interior surface' not in names):
                grafika_internal += 1
    case_name = case.findtext('Name', default='unnamed case')
    for record in stale:
        print(f"WARNING: {case_name}, layer {record['layer_index']}, "
              f"monitor {record['monitor_index']}: ignored stale monitor "
              f"({record['reason']}).")
    if grafika_internal is not None and grafika_internal != len(valid):
        print(f"WARNING: {case_name}: {len(valid)} valid Component monitors "
              f"but {grafika_internal} Grafika T/RH positions; check the export.")
    # Recover computed sensors from Grafika only when every T/RH pair maps
    # unambiguously to a material and real depth in the current component.
    graph_names = []
    used = set()
    for position, group in sorted(positions.items()):
        if not {9, 10} <= group['types']:
            graph_names = []
            break
        pair_names = []
        for curve_type in (9, 10):
            label = group['by_type'][curve_type]
            if 'exterior surface' in label.lower():
                pair_names.append(('Exterior', None))
            elif 'interior surface' in label.lower():
                pair_names.append(('Interior', None))
            else:
                match = re.fullmatch(
                    r'(?:Temperature|Relative Humidity) \((.*) \(([+-]?[0-9.,eE+-]+) m\)\)', label)
                matches = []
                if match:
                    depth = xml_number(match.group(2))
                    matches = [i for i, m in enumerate(depth_records)
                               if m['material_name'] == match.group(1)
                               and abs(m['real_depth'] - depth) <= 1e-9]
                if len(matches) != 1:
                    pair_names.append((None, None))
                else:
                    i = matches[0]
                    pair_names.append((depth_records[i]['name'], i))
        if pair_names[0] != pair_names[1] or pair_names[0][0] is None:
            graph_names = []
            break
        label, record_index = pair_names[0]
        if record_index is not None:
            if record_index in used:
                graph_names = []
                break
            used.add(record_index)
        graph_names.append(label)
    if not (len(graph_names) >= 2 and graph_names[0] == 'Exterior'
            and graph_names[-1] == 'Interior'
            and graph_names.count('Exterior') == graph_names.count('Interior') == 1):
        graph_names = []
    return {
        "sensor_names": ["Exterior"] + [m['name'] for m in valid] + ["Interior"],
        "valid_monitors": valid,
        "stale_monitors": stale,
        "raw_monitor_count": len(valid) + len(stale),
        "grafika_internal_count": grafika_internal,
        "grafika_sensor_names": graph_names,
    }


def read_wufi_metadata(wufi_file: Path) -> dict:
    """
    Read layer and monitor counts from a .w6p file.

    The temporary extracted folder is deleted after the XML has been read.
    """
    temp_dir = extract_wufi_file(wufi_file)

    try:
        xml_file = get_xml_file_from_extracted_folder(temp_dir)

        tree = ET.parse(xml_file)
        root = tree.getroot()

        cases = root.findall(".//Case")

        if not cases:
            raise ValueError(f"No <Case> elements found in {xml_file}")

        case_counts = []

        for i, case in enumerate(cases, start=1):
            case_name = case.findtext("Name", default=f"Case_{i}")
            is_active = case.findtext("IsActive", default="UNKNOWN")

            layers = case.findall("./Component/Layers/Layer")
            monitor_info = read_case_monitors(case)

            case_counts.append(
                {
                    "case_number": i,
                    "case_name": case_name,
                    "is_active": is_active,
                    "n_layers": len(layers),
                    "n_monitors": len(monitor_info["valid_monitors"]),
                    "n_sensors": len(monitor_info["sensor_names"]),
                    **monitor_info,
                }
            )

        reference = case_counts[0]

        mismatch_found = any(
            row["n_layers"] != reference["n_layers"]
            or row["n_monitors"] != reference["n_monitors"]
            for row in case_counts[1:]
        )

        if mismatch_found:
            print(f"\nWARNING: Layer/monitor mismatch in {wufi_file.name}")
            for row in case_counts:
                print(
                    f"  Case {row['case_number']} ({row['case_name']}) | "
                    f"active={row['is_active']} | "
                    f"layers={row['n_layers']} | "
                    f"monitors={row['n_monitors']}"
                )
            print("  Per-case exports use each case's own monitor counts and names.\n")

        n_layers = reference["n_layers"]
        n_monitors = reference["n_monitors"]
        n_sensors = n_monitors + boundary_sensor_count

        return {
            "wufi_file": wufi_file,
            "n_cases": len(cases),
            "n_layers": n_layers,
            "n_monitors": n_monitors,
            "n_sensors": n_sensors,
            "sensor_names": reference["sensor_names"],
            "mismatch_found": mismatch_found,
            "case_counts": case_counts,
            "raw_monitor_count": reference["raw_monitor_count"],
            "grafika_sensor_names": reference["grafika_sensor_names"],
        }

    finally:
        if temp_dir.exists():
            shutil.rmtree(temp_dir)
            print(f"Deleted temporary folder: {temp_dir.name}")


# =============================================================================
# ASC FILE READING
# =============================================================================

def read_asc_file(asc_file: Path) -> tuple[pd.Series, pd.DataFrame, bool]:
    """
    Read a WUFI .asc file.

    Expected format:
    2026-10-01T00:00:00   value1   value2   value3 ...

    Returns:
    - time values
    - numeric data columns excluding the time column
    - whether the time column was successfully parsed as datetime
    """
    df = pd.read_csv(
        asc_file,
        header=None,
        comment="#",
        skip_blank_lines=True,
        sep=r"\s+",
        engine="python",
    )

    df = df.dropna(axis=0, how="all").dropna(axis=1, how="all")

    if df.shape[1] <= 1:
        raise ValueError(f"Could not read {asc_file} as a table.")

    time_raw = df.iloc[:, 0].astype(str).str.strip()

    time_values = pd.to_datetime(
        time_raw,
        format=wufi_datetime_format,
        errors="coerce",
    )

    parsed_as_datetime = time_values.notna().mean() > 0.5

    if not parsed_as_datetime:
        print(
            f"WARNING: Could not parse date/time in {asc_file.name}. "
            "Using row number as time axis."
        )
        time_values = pd.Series(np.arange(len(df)), name="TimeStep")

    data = df.iloc[:, 1:].copy()

    for col in data.columns:
        data[col] = pd.to_numeric(
            data[col].astype(str).str.replace(",", ".", regex=False),
            errors="coerce",
        )

    data = data.reset_index(drop=True)
    time_values = pd.Series(time_values).reset_index(drop=True)

    return time_values, data, parsed_as_datetime

def purge_time_series(
    time_values: pd.Series,
    data: pd.DataFrame,
    purge: int,
) -> tuple[pd.Series, pd.DataFrame]:
    """
    Keep only every n-th data point.

    purge = 1 keeps all rows.
    purge = 10 keeps rows 0, 10, 20, 30, ...
    """
    purge = int(purge)

    if purge <= 1:
        return time_values.reset_index(drop=True), data.reset_index(drop=True)

    time_values_purged = time_values.iloc[::purge].reset_index(drop=True)
    data_purged = data.iloc[::purge].reset_index(drop=True)

    return time_values_purged, data_purged


def calculate_padded_limits(
    values: np.ndarray,
    default: tuple[float, float],
    padding_fraction: float = 0.05,
) -> tuple[float, float]:
    """
    Calculate padded plot limits.

    Handles empty arrays, non-finite values, and constant data.
    """
    values = np.asarray(values, dtype=float)
    finite_values = values[np.isfinite(values)]

    if finite_values.size == 0:
        return default

    value_min = float(np.min(finite_values))
    value_max = float(np.max(finite_values))
    value_range = value_max - value_min

    if value_range > 0:
        padding = padding_fraction * value_range
    else:
        padding = 1.0

    return value_min - padding, value_max + padding


def draw_density_histogram(
    ax,
    fig,
    x: np.ndarray,
    y: np.ndarray,
    plot_range: list[list[float]],
) -> None:
    """Draw a 2D density histogram and its color bar."""
    hist = ax.hist2d(
        x,
        y,
        bins=100,
        range=plot_range,
        density=True,
        cmap="viridis",
    )

    fig.colorbar(
        hist[3],
        ax=ax,
        label="Density",
    )


# =============================================================================
# POST-PROCESSING CALCULATIONS
# =============================================================================

def dew_point_celsius(
    temperature_c: pd.DataFrame,
    rh_percent: pd.DataFrame,
) -> pd.DataFrame:
    b = 18.678
    c = 257.14
    d = 234.5

    t = temperature_c.to_numpy(dtype=float)
    rh = rh_percent.to_numpy(dtype=float)

    rh = np.clip(rh, 0.01, 100.0)

    gamma = np.log(rh / 100.0) + (b - t / d) * (t / (c + t))
    # Invert the same Buck exponent used above, including its t / d term.
    # Use the rationalized quadratic root to avoid cancellation near gamma = 0.
    discriminant = (b - gamma) ** 2 - 4.0 * c * gamma / d
    dew = 2.0 * c * gamma / (b - gamma + np.sqrt(discriminant))

    dew = np.where(np.isfinite(dew), dew, np.nan)

    return pd.DataFrame(
        dew,
        index=temperature_c.index,
        columns=temperature_c.columns,
    )


def moving_average(series: pd.Series) -> pd.Series:
    window = max(1, int(round(window_size_fraction * len(series))))
    return series.rolling(window=window, center=True, min_periods=1).mean()


def split_wufi_columns(
    data: pd.DataFrame,
    n_sensors: int,
    n_layers: int,
) -> dict:
    """
    Split WUFI ASC numeric columns according to the notebook logic.

    Expected layout after time column:

    T1, RH1, T2, RH2, ..., Tn, RHn,
    water_layer_1, ..., water_layer_m, water_total
    """
    expected_columns = 2 * n_sensors + n_layers + 1

    if data.shape[1] != expected_columns:
        raise ValueError(
            f"ASC file has {data.shape[1]} numeric columns, but expected exactly "
            f"{expected_columns} columns for {n_sensors} sensors and {n_layers} layers."
        )

    temp = data.iloc[:, 0 : 2 * n_sensors : 2].copy()
    rh = data.iloc[:, 1 : 2 * n_sensors : 2].copy()

    water_start = 2 * n_sensors
    water_merged = data.iloc[:, water_start : water_start + n_layers + 1].copy()

    water_layers = water_merged.iloc[:, :-1].copy()
    water_total = water_merged.iloc[:, -1].copy()

    dew = dew_point_celsius(temp, rh)

    return {
        "temperature": temp,
        "humidity": rh,
        "dew_point": dew,
        "water_layers": water_layers,
        "water_total": water_total,
    }


# =============================================================================
# PLOTTING
# =============================================================================

def safe_name(text: str) -> str:
    return re.sub(r'[<>:"/\\|?*]', "_", text)


def setup_axis(ax, title: str, ylabel: str, parsed_as_datetime: bool):
    ax.set_title(title)
    ax.set_ylabel(ylabel)
    ax.grid(True, alpha=0.3)

    if parsed_as_datetime:
        ax.set_xlabel("Date")
        fig = ax.get_figure()
        fig.autofmt_xdate()
    else:
        ax.set_xlabel("Time step")


def save_series_plot(
    time_values: pd.Series,
    values: pd.Series,
    output_path: Path,
    title: str,
    ylabel: str,
    parsed_as_datetime: bool,
):
    fig, ax = plt.subplots(figsize=(8, 4.5))

    ax.scatter(
        time_values,
        values,
        s=4,
        alpha=0.6,
        label="Raw",
        color="salmon",
    )

    ax.plot(
        time_values,
        moving_average(values),
        linewidth=1.5,
        label="Filtered",
        color="black",
    )

    setup_axis(ax, title, ylabel, parsed_as_datetime)
    ax.legend()
    ax.grid(True, linestyle = "--", alpha = 0.3)
    fig.tight_layout()
    fig.savefig(output_path, dpi=image_dpi)
    plt.close(fig)


def save_dew_plot(
    time_values: pd.Series,
    temperature: pd.Series,
    dew_point: pd.Series,
    output_path: Path,
    title: str,
    parsed_as_datetime: bool,
):
    fig, ax = plt.subplots(figsize=(8, 4.5))

    ax.scatter(time_values, temperature, color="tomato", s=4, alpha=0.35)
    ax.scatter(time_values, dew_point, color="lime", s=4, alpha=0.35)

    ax.plot(
        time_values,
        moving_average(temperature),
        color="red",
        label="Temperature",
    )

    ax.plot(
        time_values,
        moving_average(dew_point),
        color="green",
        label="Dew point",
    )

    temp_min, temp_max = np.nanmin(temperature), np.nanmax(temperature)
    time_min, time_max = np.nanmin(time_values), np.nanmax(time_values)
    dew_min, dew_max = np.nanmin(dew_point), np.nanmax(dew_point)

    below_dew = (
        temperature.notna()
        & dew_point.notna()
        & (temperature <= dew_point + 2)
    )

    # print(np.sum(below_dew))
    line_length = 0.05*(np.max([temp_max, dew_max])-np.min([temp_min, dew_min]))

    rectangle = Rectangle(
        (time_min, np.min([temp_min, dew_min]) - line_length),  # lower-left corner: (x, y)
        time_max - time_min,                 # width
        line_length,                         # height
        facecolor="khaki",
        alpha=1
    )

    ax.add_patch(rectangle)

    ax.vlines(
        x=time_values[below_dew],
        ymin=np.min([temp_min, dew_min]) - line_length,
        ymax=np.min([temp_min, dew_min]),
        color="cornflowerblue",
        linewidth=1,
        label="Within 2°C of dew point",
    )

    setup_axis(ax, title, "T, °C", parsed_as_datetime)
    ax.legend(
        loc="upper left",
        bbox_to_anchor=(0.01, 0.99),
        borderaxespad=0,
        fontsize = 7
    )
    ax.grid(True, linestyle = "--", alpha = 0.3)
    fig.tight_layout()
    fig.savefig(output_path, dpi=image_dpi)
    plt.close(fig)


def load_lim_curves(base_dir: Path) -> list[dict]:
    """
    Optional: load LIM curves if a 'LIM Curves' folder exists.

    Each file should contain at least two numeric columns:
    temperature and relative humidity.

    Returns a list of dictionaries:
    {
        "name": curve name,
        "data": dataframe with T and RH columns
    }
    """
    lim_dir = base_dir / "LIM Curves"

    if not lim_dir.exists():
        return []

    curves = []

    for file in sorted(lim_dir.iterdir()):
        if not file.is_file():
            continue

        try:
            df = pd.read_csv(file, header=None, sep=None, engine="python")
            df = df.dropna(axis=0, how="all").dropna(axis=1, how="all")

            if df.shape[1] >= 2:
                curve = df.iloc[:, :2].copy()

                for col in curve.columns:
                    curve[col] = pd.to_numeric(
                        curve[col].astype(str).str.replace(",", ".", regex=False),
                        errors="coerce",
                    )

                curve = curve.dropna()

                if not curve.empty:
                    curves.append(
                        {
                            "name": file.stem,
                            "data": curve,
                        }
                    )
                    print(f"Loaded LIM curve: {file.stem}")

        except Exception as error:
            print(f"Could not read LIM curve file {file.name}: {error}")

    return curves


def save_mould_history_plot(
    temperature: pd.Series,
    humidity: pd.Series,
    output_path: Path,
    title: str,
    lim_curves: list[dict],
) -> None:
    fig, ax = plt.subplots(figsize=(6, 5))

    try:
        # Keep the original position for the color-coded time index.
        data = pd.DataFrame(
            {
                "temperature": pd.to_numeric(
                    temperature,
                    errors="coerce",
                ),
                "humidity": pd.to_numeric(
                    humidity,
                    errors="coerce",
                ),
                "time_index": np.arange(len(temperature)),
            }
        )

        # Keep rows where temperature and humidity are both finite.
        finite_mask = (
            np.isfinite(data["temperature"])
            & np.isfinite(data["humidity"])
        )

        data = data.loc[finite_mask]

        x = data["temperature"].to_numpy(dtype=float)
        y = data["humidity"].to_numpy(dtype=float)
        time_index = data["time_index"].to_numpy()

        # Calculate safe limits for empty, constant, or normal data.
        x_min, x_max = calculate_padded_limits(
            x,
            default=(0.0, 40.0),
        )

        y_min, y_max = calculate_padded_limits(
            y,
            default=(40.0, 100.0),
        )

        if len(x) > 0:
            points = ax.scatter(
                x,
                y,
                c=time_index,
                s=4,
                alpha=0.6,
            )

            fig.colorbar(
                points,
                ax=ax,
                label="Time index",
            )

        else:
            ax.text(
                0.5,
                0.5,
                "No valid temperature/humidity data",
                transform=ax.transAxes,
                ha="center",
                va="center",
            )

        lim_colors = [
            "magenta",
            "cyan",
            "lawngreen",
            "orange",
            "purple",
            "brown",
            "red",
            "blue",
        ]

        for i, curve_info in enumerate(lim_curves):
            curve = curve_info["data"]
            label = curve_info["name"]
            color = lim_colors[i % len(lim_colors)]

            ax.plot(
                curve.iloc[:, 0],
                curve.iloc[:, 1],
                linewidth=2.0,
                color=color,
                linestyle="--",
                label=label,
            )

        ax.set_xlim(x_min, x_max)
        ax.set_ylim(y_min, y_max)

        ax.set_title(title)
        ax.set_xlabel("T, °C")
        ax.set_ylabel("RH, %")
        ax.grid(
            True,
            linestyle="--",
            alpha=0.3,
        )

        if lim_curves:
            ax.legend()

        fig.tight_layout()
        fig.savefig(
            output_path,
            dpi=image_dpi,
        )

    finally:
        plt.close(fig)


def save_mould_risk_plot(
    temperature: pd.Series,
    humidity: pd.Series,
    output_path: Path,
    title: str,
    lim_curves: list[dict],
) -> None:
    fig, ax = plt.subplots(figsize=(7, 6))

    try:
        # Convert non-numeric values to NaN.
        data = pd.DataFrame(
            {
                "temperature": pd.to_numeric(
                    temperature,
                    errors="coerce",
                ),
                "humidity": pd.to_numeric(
                    humidity,
                    errors="coerce",
                ),
            }
        )

        # Keep only rows where both values are finite.
        finite_mask = (
            np.isfinite(data["temperature"])
            & np.isfinite(data["humidity"])
        )

        data = data.loc[finite_mask]

        x = data["temperature"].to_numpy(dtype=float)
        y = data["humidity"].to_numpy(dtype=float)

        # Optional mould-relevant restriction:
        #
        # relevant_mask = (
        #     (x >= 0)
        #     & (x <= 40)
        #     & (y >= 40)
        #     & (y <= 100)
        # )
        # x = x[relevant_mask]
        # y = y[relevant_mask]

        x_min, x_max = calculate_padded_limits(
            x,
            default=(0.0, 40.0),
        )

        y_min, y_max = calculate_padded_limits(
            y,
            default=(40.0, 100.0),
        )

        plot_range = [
            [x_min, x_max],
            [y_min, y_max],
        ]

        if len(x) == 0:
            ax.text(
                0.5,
                0.5,
                "No valid temperature/humidity data",
                transform=ax.transAxes,
                ha="center",
                va="center",
            )

        elif SCIPY_AVAILABLE and len(x) > 10:
            try:
                # KDE requires variation in both dimensions.
                if np.ptp(x) == 0 or np.ptp(y) == 0:
                    raise ValueError(
                        "KDE cannot process constant data."
                    )

                xy = np.vstack([x, y])
                kde = gaussian_kde(xy)

                grid_resolution = 200

                xi, yi = np.mgrid[
                    x_min:x_max:complex(grid_resolution),
                    y_min:y_max:complex(grid_resolution),
                ]

                positions = np.vstack(
                    [xi.ravel(), yi.ravel()]
                )

                zi = kde(positions).reshape(xi.shape)

                contour = ax.contourf(
                    xi,
                    yi,
                    zi,
                    levels=100,
                    cmap="pink",
                )

                fig.colorbar(
                    contour,
                    ax=ax,
                    label="Density",
                )

            except (ValueError, np.linalg.LinAlgError):
                draw_density_histogram(
                    ax=ax,
                    fig=fig,
                    x=x,
                    y=y,
                    plot_range=plot_range,
                )

        else:
            draw_density_histogram(
                ax=ax,
                fig=fig,
                x=x,
                y=y,
                plot_range=plot_range,
            )

        lim_colors = [
            "magenta",
            "cyan",
            "lawngreen",
            "orange",
            "purple",
            "brown",
            "red",
            "blue",
        ]

        for i, curve_info in enumerate(lim_curves):
            curve = curve_info["data"]
            label = curve_info["name"]
            color = lim_colors[i % len(lim_colors)]

            ax.plot(
                curve.iloc[:, 0],
                curve.iloc[:, 1],
                linewidth=2.0,
                color=color,
                linestyle="--",
                label=label,
            )

        ax.set_title(title)
        ax.set_xlabel("T, °C")
        ax.set_ylabel("RH, %")
        ax.set_xlim(x_min, x_max)
        ax.set_ylim(y_min, y_max)
        ax.grid(
            True,
            linestyle="--",
            alpha=0.25,
        )

        if lim_curves:
            ax.legend()

        fig.tight_layout()
        fig.savefig(
            output_path,
            dpi=image_dpi,
        )

    finally:
        plt.close(fig)

# =============================================================================
# EXPORT HELPERS
# =============================================================================

def make_case_folder_name(asc_file: Path) -> tuple[str, str]:
    """
    Recreate the Mathematica notebook folder naming:

    I_PII_03_0.asc -> parent folder I_PII_03, case folder I_PII_03_v1
    """
    parts = asc_file.stem.split("_")

    if parts and parts[-1].isdigit():
        version_number = int(parts[-1]) + 1
        case_folder = "_".join(parts[:-1] + [f"v{version_number}"])
    else:
        case_folder = asc_file.stem

    parent_folder = case_folder.split("_v")[0]

    return parent_folder, case_folder


def clear_output_parent_folders(asc_files: list[Path]) -> None:
    """
    Delete existing output parent folders before creating new results.
    Each parent folder is cleared only once.
    """
    parent_folder_names = {
        make_case_folder_name(asc_file)[0]
        for asc_file in asc_files
    }

    for parent_folder_name in parent_folder_names:
        parent_dir = current_dir / parent_folder_name

        if parent_dir.exists():
            shutil.rmtree(parent_dir)
            print(f"Cleared existing output folder: {parent_dir}")

        parent_dir.mkdir(parents=True, exist_ok=True)


def write_wide_csv(
    output_path: Path,
    time_values: pd.Series,
    data: pd.DataFrame,
    column_names: list[str],
):
    out = pd.DataFrame({"time": time_values})

    for i, name in enumerate(column_names):
        if i < data.shape[1]:
            out[name] = data.iloc[:, i]

    out.to_csv(output_path, index=False)


def process_one_asc_file(
    asc_file: Path,
    config: dict,
    lim_curves: list[pd.DataFrame],
    show_progress: bool = True,
    verbose: bool = True,
) -> dict:
    """
    Process one ASC file.

    This function is intentionally self-contained so it can be run inside
    a parallel worker process.
    """
    started = time.time()

    if verbose:
        print(f"\nProcessing ASC file: {asc_file.name}")

    time_values, data, parsed_as_datetime = read_asc_file(asc_file)

    # The preflight verifies the matching legacy export mask before setting
    # this offset. It never removes columns merely to make the width fit.
    data = data.iloc[:, config.get("leading_export_columns", 0):].copy()

    original_row_count = len(data)

    time_values, data = purge_time_series(
        time_values=time_values,
        data=data,
        purge=purge_number,
    )

    purged_row_count = len(data)

    if verbose and purge_number > 1:
        print(
            f"  Purged data: kept every {purge_number}-th point | "
            f"{original_row_count} → {purged_row_count} rows"
        )

    series = split_wufi_columns(
        data=data,
        n_sensors=config["n_sensors"],
        n_layers=config["n_layers"],
    )

    parent_folder, case_folder = make_case_folder_name(asc_file)

    

    export_dir = current_dir / parent_folder / case_folder
    export_dir.mkdir(parents=True, exist_ok=True)

    sensor_names = config["sensor_names"]
    probe_names = [f"{i} {name}" for i, name in enumerate(sensor_names, start=1)]

    total_steps = count_expected_plot_steps(config)

    progress_bar = None

    if show_progress:
        progress_bar = SimpleProgressBar(
            total=total_steps,
            desc=f"Plotting {asc_file.name}",
        )

    def update_progress():
        if progress_bar is not None:
            progress_bar.update(1)

    try:
        # Sensor plots
        for i, probe_name in enumerate(probe_names):
            probe_dir = export_dir / safe_name(probe_name)
            probe_dir.mkdir(parents=True, exist_ok=True)

            save_series_plot(
                time_values,
                series["humidity"].iloc[:, i],
                probe_dir / f"hum{i + 1}.jpg",
                f"Relative Humidity - {probe_name}",
                "RH, %",
                parsed_as_datetime,
            )
            update_progress()

            save_series_plot(
                time_values,
                series["temperature"].iloc[:, i],
                probe_dir / f"temp{i + 1}.jpg",
                f"Temperature - {probe_name}",
                "T, °C",
                parsed_as_datetime,
            )
            update_progress()

            save_dew_plot(
                time_values,
                series["temperature"].iloc[:, i],
                series["dew_point"].iloc[:, i],
                probe_dir / f"dew{i + 1}.jpg",
                f"Dew Point - {probe_name}",
                parsed_as_datetime,
            )
            update_progress()

            save_mould_history_plot(
                series["temperature"].iloc[:, i],
                series["humidity"].iloc[:, i],
                probe_dir / f"mold{i + 1}.jpg",
                f"Mould Growth History - {probe_name}",
                lim_curves,
            )
            update_progress()

            save_mould_risk_plot(
                series["temperature"].iloc[:, i],
                series["humidity"].iloc[:, i],
                probe_dir / f"risk{i + 1}.jpg",
                f"Mould Growth Risk - {probe_name}",
                lim_curves,
            )
            update_progress()

        # Water-content plots
        for layer_index in range(config["n_layers"]):
            save_series_plot(
                time_values,
                series["water_layers"].iloc[:, layer_index],
                export_dir / f"wat{layer_index + 1}.jpg",
                f"Water Content - Layer {layer_index + 1}",
                "m, kg/m³",
                parsed_as_datetime,
            )
            update_progress()

        save_series_plot(
            time_values,
            series["water_total"],
            export_dir / "wat_total.jpg",
            "Total Water Content",
            "m, kg/m²",
            parsed_as_datetime,
        )
        update_progress()

    finally:
        if progress_bar is not None:
            progress_bar.close()

    # CSV exports
    write_wide_csv(
        export_dir / "hum_time_series.csv",
        time_values,
        series["humidity"],
        probe_names,
    )

    write_wide_csv(
        export_dir / "temp_time_series.csv",
        time_values,
        series["temperature"],
        probe_names,
    )

    write_wide_csv(
        export_dir / "dew_time_series.csv",
        time_values,
        series["dew_point"],
        probe_names,
    )

    layer_names = [f"Layer {i}" for i in range(1, config["n_layers"] + 1)]

    write_wide_csv(
        export_dir / "wat_time_series.csv",
        time_values,
        series["water_layers"],
        layer_names,
    )

    water_total_df = pd.DataFrame({"Total water content": series["water_total"]})

    write_wide_csv(
        export_dir / "wat_all_time_series.csv",
        time_values,
        pd.concat([series["water_layers"], water_total_df], axis=1),
        layer_names + ["Total water content"],
    )

    elapsed = time.time() - started

    if verbose:
        print(f"Exported results to: {export_dir}")

    return {
        "file": asc_file.name,
        "export_dir": str(export_dir),
        "elapsed_seconds": elapsed,
        "plot_steps": total_steps,
    }


def process_one_asc_file_worker(args: tuple[Path, dict, list[pd.DataFrame]]) -> dict:
    """
    Worker wrapper for ProcessPoolExecutor.

    It catches exceptions and sends them back to the main process.
    """
    asc_file, config, lim_curves = args

    try:
        result = process_one_asc_file(
            asc_file=asc_file,
            config=config,
            lim_curves=lim_curves,
            show_progress=PARALLEL_SETTINGS["show_worker_progress"],
            verbose=PARALLEL_SETTINGS["verbose_workers"],
        )

        return {
            "ok": True,
            "file": asc_file.name,
            "result": result,
        }

    except Exception:
        return {
            "ok": False,
            "file": asc_file.name,
            "error": traceback.format_exc(),
        }


# =============================================================================
# MAIN WORKFLOW
# =============================================================================

def build_configs_for_asc_files() -> tuple[list[Path], list[dict], list[pd.DataFrame]]:
    """
    Read WUFI metadata and create the list of configs that corresponds to ASC files.
    """
    wufi_files = sorted(current_dir.glob("*.w6p"))
    asc_files = sorted(current_dir.glob(f"*{raw_data_file_format}"))

    if not wufi_files:
        raise FileNotFoundError(f"No .w6p files found in {current_dir}")

    if not asc_files:
        raise FileNotFoundError(f"No {raw_data_file_format} files found in {current_dir}")

    print("WUFI files found:")
    for file in wufi_files:
        print(" -", file.name)

    print("\nASC files found:")
    for file in asc_files:
        print(" -", file.name)

    # Read metadata from .w6p files.
    file_configs = []
    case_configs = []

    for wufi_file in wufi_files:
        print(f"\nReading WUFI metadata: {wufi_file.name}")

        info = read_wufi_metadata(wufi_file)

        file_config = {
            "wufi_file": wufi_file.name,
            "n_layers": info["n_layers"],
            "n_monitors": info["n_monitors"],
            "n_sensors": info["n_sensors"],
            "sensor_names": info["sensor_names"],
            "raw_monitor_count": info["raw_monitor_count"],
            "grafika_sensor_names": info["grafika_sensor_names"],
        }

        file_configs.append(file_config)

        # Each case has its own valid sensors and exterior-to-interior order.
        for case in info["case_counts"]:
            case_configs.append({
                "wufi_file": wufi_file.name,
                "n_layers": case["n_layers"],
                "n_monitors": case["n_monitors"],
                "n_sensors": case["n_sensors"],
                "sensor_names": case["sensor_names"],
                "raw_monitor_count": case["raw_monitor_count"],
                "grafika_sensor_names": case["grafika_sensor_names"],
            })

        print(
            f"  Cases: {info['n_cases']} | "
            f"Layers: {info['n_layers']} | "
            f"Monitors: {info['n_monitors']} | "
            f"Sensors: {info['n_sensors']}"
        )
        print(f"  Sensor names: {info['sensor_names']}")

    # Decide how to map ASC files to metadata.
    #
    # Case A:
    #   number of ASC files equals total number of WUFI cases
    #   -> one ASC file per case
    #
    # Case B:
    #   number of ASC files equals number of WUFI files
    #   -> one ASC file per WUFI file

    if len(asc_files) == len(case_configs):
        configs_for_asc = case_configs
        print("\nMapping mode: one ASC file per WUFI case.")
    elif len(asc_files) == len(file_configs):
        configs_for_asc = file_configs
        print("\nMapping mode: one ASC file per WUFI file.")
    else:
        raise ValueError(
            "Could not map ASC files to WUFI metadata.\n"
            f"ASC files found: {len(asc_files)}\n"
            f"WUFI files found: {len(wufi_files)}\n"
            f"Total WUFI cases found: {len(case_configs)}\n\n"
            "Either export one ASC file per WUFI case, or one ASC file per WUFI file."
        )

    lim_curves = load_lim_curves(current_dir)

    if lim_curves:
        print(f"\nLoaded {len(lim_curves)} LIM curve file(s).")
    else:
        print("\nNo LIM curve files found. Mould plots will be drawn without LIM curves.")

    return asc_files, configs_for_asc, lim_curves


def get_parallel_worker_count(task_count: int) -> int:
    """
    Decide how many worker processes to use.
    """
    if task_count <= 0:
        return 1

    requested_workers = PARALLEL_SETTINGS["max_workers"]

    if requested_workers is not None:
        return max(1, min(int(requested_workers), task_count))

    cpu_count = os.cpu_count() or 1
    leave_free = int(PARALLEL_SETTINGS["leave_free_cores"])

    return max(1, min(task_count, cpu_count - leave_free))


def run_parallel_processing(
    asc_files: list[Path],
    configs_for_asc: list[dict],
    lim_curves: list[pd.DataFrame],
):
    """
    Process ASC files in parallel.

    Two backends are supported:

    - backend = "thread"
        Safer in Spyder/Jupyter/notebook cells on Windows.
        This avoids BrokenProcessPool because it does not start separate
        Python interpreters.

    - backend = "process"
        Usually faster for CPU-heavy plotting/KDE work, but on Windows this
        should be run as a normal .py file from PowerShell/Anaconda Prompt.
    """
    tasks = list(zip(asc_files, configs_for_asc, [lim_curves] * len(asc_files)))

    max_workers = get_parallel_worker_count(len(tasks))
    cpu_count = os.cpu_count() or 1
    backend = PARALLEL_SETTINGS["backend"].lower().strip()

    if backend not in {"thread", "process"}:
        raise ValueError(
            f"Unknown parallel backend: {backend}. "
            'Use "thread" or "process".'
        )

    if backend == "thread":
        executor_class = ThreadPoolExecutor
        backend_label = "threaded"
    else:
        executor_class = ProcessPoolExecutor
        backend_label = "multiprocessing"

    print(f"\nParallel processing enabled using {backend_label} backend.")
    print(f"CPU cores detected: {cpu_count}")
    print(f"ASC files to process: {len(tasks)}")
    print(f"Workers used: {max_workers}")

    if backend == "process":
        print(
            "Important: on Windows, process backend should be run as a .py file, "
            "not cell-by-cell in Spyder/Jupyter."
        )

    print(
        "Note: the progress bar advances when each ASC file is completely processed."
    )

    main_progress = SimpleProgressBar(
        total=len(tasks),
        desc=f"Processing ASC files in parallel ({backend})",
    )

    errors = []
    successful_results = []

    with executor_class(max_workers=max_workers) as executor:
        futures = [
            executor.submit(process_one_asc_file_worker, task)
            for task in tasks
        ]

        for future in as_completed(futures):
            try:
                result = future.result()
            except Exception:
                result = {
                    "ok": False,
                    "file": "unknown",
                    "error": traceback.format_exc(),
                }

            main_progress.update(1)

            if result["ok"]:
                successful_results.append(result["result"])
            else:
                errors.append(result)

    main_progress.close()

    if successful_results:
        print("\nCompleted files:")
        for result in successful_results:
            print(
                f" - {result['file']} | "
                f"{result['plot_steps']} plot step(s) | "
                f"{result['elapsed_seconds']:.1f} s | "
                f"{result['export_dir']}"
            )

    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"\nERROR while processing {error['file']}:")
            print(error["error"])

        raise RuntimeError(
            f"{len(errors)} ASC file(s) failed during parallel processing."
        )

def run_sequential_processing(
    asc_files: list[Path],
    configs_for_asc: list[dict],
    lim_curves: list[pd.DataFrame],
):
    """
    Process ASC files sequentially.

    This mode keeps the detailed per-plot progress bar.
    """
    print("\nSequential processing enabled.")

    main_progress = SimpleProgressBar(
        total=len(asc_files),
        desc="Processing ASC files",
    )

    for asc_file, config in zip(asc_files, configs_for_asc):
        process_one_asc_file(
            asc_file=asc_file,
            config=config,
            lim_curves=lim_curves,
            show_progress=True,
            verbose=True,
        )
        main_progress.update(1)

    main_progress.close()


def validate_monitor_export_columns(asc_file: Path, config: dict) -> None:
    """Validate strict, computed Grafika, or verified legacy export layouts."""
    expected = 1 + 2 * config['n_sensors'] + config['n_layers'] + 1
    chosen_names = config['sensor_names']
    offset = 0
    rows = 0
    with asc_file.open(encoding='utf-8-sig') as stream:
        for line_number, line in enumerate(stream, 1):
            values = line.split('#', 1)[0].split()
            if not values:
                continue
            rows += 1
            if rows == 1:
                graph_names = config.get('grafika_sensor_names', [])
                graph_width = 1 + 2 * len(graph_names) + config['n_layers'] + 1
                if graph_names and len(values) == graph_width:
                    chosen_names = graph_names
                    expected = graph_width
                elif graph_names and len(values) == graph_width + 4:
                    # Legacy raw-count mask: two extra requested sensors
                    # select four leading non-sensor result columns.
                    raw_sensors = config.get('raw_monitor_count', -2) + 2
                    mask = ('1' * (config['n_layers'] + 1) + '011' * raw_sensors
                            + '0' * (4 * (config['n_layers'] + 2) + 19))
                    matching_masks = set()
                    for batch in asc_file.parent.glob('*.bat'):
                        for command in batch.read_text(encoding='utf-8-sig', errors='replace').splitlines():
                            if (command.strip().lower().startswith(('rem ', '::')) or
                                    config['wufi_file'].lower() not in command.lower()):
                                continue
                            matching_masks.update(re.findall(r'-v\s*([01]+)(?=\s|$)', command))
                    if raw_sensors == len(graph_names) + 2 and matching_masks == {mask}:
                        chosen_names = graph_names
                        offset = 4
                        expected = graph_width + offset
            if len(values) != expected:
                raise ValueError(
                    f"{asc_file.name}, line {line_number}: {len(values)} columns "
                    f"including time, expected {expected} for "
                    f"{config['n_monitors']} valid internal monitors, "
                    f"2 boundary sensors and {config['n_layers']} layers. "
                    "The ASC export does not match the valid-monitor XML schema. "
                    "Resolve stale monitors in WUFI and re-export matching results "
                    "with T/RH at valid sensors, layer water contents and total "
                    "water content. Existing output folders have not been cleared."
                )
    if not rows:
        raise ValueError(f"{asc_file.name}: no data rows found")
    config.update(sensor_names=chosen_names, n_sensors=len(chosen_names),
                  n_monitors=len(chosen_names) - 2, leading_export_columns=offset)
    if offset:
        print(f"{asc_file.name}: verified legacy batch mask; skipping {offset} "
              "leading non-sensor columns and using Grafika T/RH order.")
    print(f"{asc_file.name}: {len(chosen_names) - 2} internal monitors; "
          f"sensor names: {chosen_names}")


def main():
    started = time.time()

    asc_files, configs_for_asc, lim_curves = build_configs_for_asc_files()

    # Validate the export schema before clearing any existing output folders.
    for asc_file, config in zip(asc_files, configs_for_asc):
        validate_monitor_export_columns(asc_file, config)

    clear_output_parent_folders(asc_files)

    if PARALLEL_SETTINGS["enabled"]:
        run_parallel_processing(
            asc_files=asc_files,
            configs_for_asc=configs_for_asc,
            lim_curves=lim_curves,
        )
    else:
        run_sequential_processing(
            asc_files=asc_files,
            configs_for_asc=configs_for_asc,
            lim_curves=lim_curves,
        )

    elapsed = time.time() - started
    print(f"\nAll ASC files processed in {elapsed:.1f} s.")


if __name__ == "__main__":
    main()


# %%
