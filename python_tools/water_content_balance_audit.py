"""Read-only REF/HEMP WUFI water-content dimensional consistency acceptance.

Supply ONLY authorized private XML, ASC, WXFs and original export manifest at
runtime. No original source files or data are distributed with this module.

Layer water is treated as kg/m^3, and thickness as m, yielding kg/m^2.
This checks export/aggregation identity; not a moisture-flux conservation law.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timedelta
import json
from pathlib import Path
import xml.etree.ElementTree as ET

import numpy as np


def model_layers(xml_file):
    """Read ordered material names and SI thicknesses from actual model XML."""
    cases = ET.parse(xml_file).getroot().findall("./Cases/Case")
    if len(cases) != 1:
        raise ValueError("Expected one frozen final WUFI model case")
    nodes = cases[0].findall("./Component/Layers/Layer")
    if not nodes:
        raise ValueError("No XML material layers")
    result = []
    for i, node in enumerate(nodes, 1):
        if int(node.attrib.get("Index", "-1")) != i:
            raise ValueError("XML layer indices inconsistent with source order")
        scalar = next((x for x in node.findall("./Scalars/Scalar")
                       if x.attrib.get("name") == "Thickness"), None)
        name = node.findtext("./Material/Name")
        if scalar is None or scalar.attrib.get("unit") != "m" or not name:
            raise ValueError("Missing authoritative layer thickness/unit/material")
        depth = float(scalar.attrib["value"])
        if not np.isfinite(depth) or depth <= 0:
            raise ValueError("Invalid original XML layer thickness")
        result.append((name, depth))
    return result


def _wxf_matrix(path):
    """Read numeric WXF TemporalData with the existing safe, non-evaluating parser."""
    from python_tools.wxf_subset import load_wxf, list_args
    node = load_wxf(path)
    series = list_args(node) if node[0] == ("SYM", "List") else (node,)
    vectors = []
    for item in series:
        if item[0] != ("SYM", "TemporalData"):
            raise ValueError("Expected exported TemporalData")
        values = np.asarray(item[2][1], dtype=float)
        if values.ndim != 2 or values.shape[0] != 1:
            raise ValueError("Unexpected WXF numeric shape")
        vectors.append(values[0])
    if not vectors or len({len(x) for x in vectors}) != 1:
        raise ValueError("WXF vectors empty or irregular")
    return np.vstack(vectors)


def audit_case(project, *, manifest, xml_file, asc_file, wxf_dir,
               reader=_wxf_matrix, abs_tolerance=3e-6, rel_tolerance=2e-7):
    """Cross-check actual XML/manifest, ASC/WXF and weighted layer/total series."""
    if abs_tolerance <= 0 or rel_tolerance <= 0:
        raise ValueError("Positive numerical tolerances required")
    projects = [x for x in manifest["Projects"] if x["ProjectBaseName"] == project]
    if len(projects) != 1 or len(projects[0]["Cases"]) != 1:
        raise ValueError("Requested source project/case not unique")
    record = projects[0]["Cases"][0]
    original_layers = model_layers(xml_file)
    layers = record["Layers"]
    if len(original_layers) != len(layers):
        raise ValueError("XML and manifest layer count differ")
    for i, ((name, thick), item) in enumerate(zip(original_layers, layers), 1):
        if (item["LayerIndex"] != i or item["MaterialName"] != name or
                abs(float(item["ThicknessMetres"]) - thick) > 5e-13):
            raise ValueError(f"XML/manifest order/material/thickness discrepancy: {i}")

    lines = [row.split() for row in Path(asc_file).read_text().splitlines() if row.strip()]
    expected_columns = record["ExpectedASCColumnCount"]
    if not lines or any(len(row) != expected_columns for row in lines):
        raise ValueError("Unexpected ASC column count")
    timestamps = [datetime.fromisoformat(row[0]) for row in lines]
    if (len(timestamps) != len(set(timestamps)) or
            any(b - a != timedelta(hours=1) for a, b
                in zip(timestamps, timestamps[1:]))):
        raise ValueError("ASC timeline must be unique, consecutive hourly labels")
    values = np.asarray([[float(v) for v in row[1:]] for row in lines], dtype=float)
    if not np.isfinite(values).all():
        raise ValueError("Nonfinite ASC values")

    cols = [x["WaterContentColumn"] for x in layers]
    total_col = record["TotalWaterContentColumn"]
    if cols != list(range(cols[0], cols[0] + len(cols))) or total_col != cols[-1] + 1:
        raise ValueError("Unexpected source water columns")
    # Original manifest uses 1-based indices; ASC column 1 is its date field.
    expected_layer = values[:, np.asarray(cols) - 2].T
    expected_total = values[:, total_col - 2]
    folder = Path(wxf_dir)
    layer = reader(folder / "layer_water_content.wxf.bin")
    total = reader(folder / "total_water_content.wxf.bin")
    if layer.shape != expected_layer.shape or total.shape != (1, len(timestamps)):
        raise ValueError("Unexpected postprocessor WXF inventory")
    if not (np.array_equal(layer, expected_layer) and
            np.array_equal(total[0], expected_total)):
        raise ValueError("WXF differs from original ASC values")
    if not (np.isfinite(layer).all() and np.isfinite(total).all() and
            (layer >= 0).all() and (total >= 0).all()):
        raise ValueError("Nonfinite or negative water content")

    depths = np.asarray([depth for _, depth in original_layers])
    residual = depths @ layer - total[0]
    maximum = float(np.max(np.abs(residual)))
    max_relative = float(np.max(np.abs(residual) /
                                np.maximum(np.abs(total[0]), 1e-300)))
    if maximum > abs_tolerance or max_relative > rel_tolerance:
        raise ValueError("Layer/total residual exceeds serialization tolerance")
    return {
        "project": project, "status": "passed",
        "layer_count": len(layers), "wall_thickness_m": float(sum(depths)),
        "hours_checked": len(timestamps),
        "first_ASC_timestamp": timestamps[0].isoformat(),
        "last_ASC_timestamp": timestamps[-1].isoformat(),
        "source_asc_to_wxf_value_parity": "exact",
        "max_absolute_residual_kg_m2": maximum,
        "rmse_residual_kg_m2": float(np.sqrt(np.mean(residual ** 2))),
        "mean_residual_kg_m2": float(np.mean(residual)),
        "max_relative_residual": max_relative,
        "absolute_tolerance_kg_m2": abs_tolerance,
        "relative_tolerance": rel_tolerance,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True)
    parser.add_argument("--wufi-export-manifest-json", type=Path, required=True)
    parser.add_argument("--model-xml", type=Path, required=True)
    parser.add_argument("--asc", type=Path, required=True)
    parser.add_argument("--postprocessor-wxf-dir", type=Path, required=True)
    parser.add_argument("--out-json", type=Path, required=True)
    args = parser.parse_args()
    source = json.loads(args.wufi_export_manifest_json.read_text(encoding="utf-8-sig"))
    result = audit_case(args.project, manifest=source, xml_file=args.model_xml,
                        asc_file=args.asc, wxf_dir=args.postprocessor_wxf_dir)
    args.out_json.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"project": result["project"], "status": result["status"],
                      "hours_checked": result["hours_checked"],
                      "max_absolute_residual_kg_m2": result["max_absolute_residual_kg_m2"]}))


if __name__ == "__main__":
    main()
