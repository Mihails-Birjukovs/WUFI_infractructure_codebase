#!/usr/bin/env python3
"""Static validator for WUFI vs Sensor Comparison Production v1.2.0.

This validator does not execute Wolfram Language code. It checks source balance,
release identity, active-file references, graphics lifecycle markers, registry
integrity, notebook cache removal, and packaged test-asset availability.
"""

from __future__ import annotations

import csv
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VERSION = "Production-1.2.0-2026-08-05"

ACTIVE_WOLFRAM = [
    "HygrothermalPlottingUtilities_v1_2.wl",
    "SensorDataUtilities_v1_2.wl",
    "SensorComparisonConfig_v1_2.wl",
    "MongoDB_Data_Analysis_WUFI_Comparison_v1_2.wl",
    "MongoDB_Data_Analysis_WUFI_Comparison_v1_2.nb",
    "Smoke_Tests_v1_2.wl",
    "Equivalence_Tests_v1_2.wl",
    "canonical_sensor_registry_2026-07-30.wl",
]

REQUIRED_FILES = ACTIVE_WOLFRAM + [
    "canonical_sensor_registry_2026-07-30.csv",
    "canonical_sensor_registry_2026-07-30.json",
    "README.md",
    "CHANGELOG.md",
    "PRODUCTION_RELEASE_MANIFEST_v1.2.0.json",
    "TestAssets.7z",
]


@dataclass
class ScanResult:
    path: Path
    ok: bool
    detail: str


def scan_wolfram(path: Path) -> ScanResult:
    text = path.read_text(encoding="utf-8")
    stack: list[tuple[str, int]] = []
    pairs = {"(": ")", "[": "]", "{": "}"}
    closers = {value: key for key, value in pairs.items()}
    association_depth = 0
    comment_depth = 0
    in_string = False
    escaped = False
    line = 1
    i = 0

    while i < len(text):
        c = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if c == "\n":
            line += 1

        if in_string:
            if escaped:
                escaped = False
            elif c == "\\":
                escaped = True
            elif c == '"':
                in_string = False
            i += 1
            continue

        if comment_depth:
            if c == "(" and nxt == "*":
                comment_depth += 1
                i += 2
                continue
            if c == "*" and nxt == ")":
                comment_depth -= 1
                i += 2
                continue
            i += 1
            continue

        if c == '"':
            in_string = True
            i += 1
            continue
        if c == "(" and nxt == "*":
            comment_depth = 1
            i += 2
            continue
        if c == "<" and nxt == "|":
            association_depth += 1
            i += 2
            continue
        if c == "|" and nxt == ">":
            if association_depth == 0:
                return ScanResult(path, False, f"unmatched |> at line {line}")
            association_depth -= 1
            i += 2
            continue
        if c in pairs:
            stack.append((c, line))
        elif c in closers:
            if not stack or stack[-1][0] != closers[c]:
                return ScanResult(path, False, f"unmatched {c} at line {line}")
            stack.pop()
        i += 1

    if in_string:
        return ScanResult(path, False, "unterminated string")
    if comment_depth:
        return ScanResult(path, False, f"unterminated nested comment, depth {comment_depth}")
    if association_depth:
        return ScanResult(path, False, f"unterminated association, depth {association_depth}")
    if stack:
        opener, opener_line = stack[-1]
        return ScanResult(path, False, f"unclosed {opener} from line {opener_line}")
    return ScanResult(path, True, "balanced delimiters, strings, nested comments, and associations")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def validate_registry() -> list[str]:
    path = ROOT / "canonical_sensor_registry_2026-07-30.csv"
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    require(len(rows) == 17, f"expected 17 registry rows, found {len(rows)}")
    ids = [int(float(row["SensorID"])) for row in rows]
    require(len(ids) == len(set(ids)), "duplicate sensor IDs in registry")
    require({row["WallSystem"] for row in rows} == {"REF", "HEMP"}, "unexpected wall systems")
    return ["registry rows: 17", "registry IDs unique", "wall systems: REF, HEMP"]


def validate_sources() -> list[str]:
    messages: list[str] = []
    for filename in ACTIVE_WOLFRAM:
        result = scan_wolfram(ROOT / filename)
        require(result.ok, f"{filename}: {result.detail}")
        messages.append(f"{filename}: {result.detail}")

    plotting = (ROOT / "HygrothermalPlottingUtilities_v1_2.wl").read_text(encoding="utf-8")
    sensor = (ROOT / "SensorDataUtilities_v1_2.wl").read_text(encoding="utf-8")
    driver = (ROOT / "MongoDB_Data_Analysis_WUFI_Comparison_v1_2.wl").read_text(encoding="utf-8")
    config = (ROOT / "SensorComparisonConfig_v1_2.wl").read_text(encoding="utf-8")
    notebook = (ROOT / "MongoDB_Data_Analysis_WUFI_Comparison_v1_2.nb").read_text(encoding="utf-8")
    smoke = (ROOT / "Smoke_Tests_v1_2.wl").read_text(encoding="utf-8")
    equivalence = (ROOT / "Equivalence_Tests_v1_2.wl").read_text(encoding="utf-8")

    require(plotting.count(VERSION) == 1, "plotting package version identity missing or duplicated")
    require(sensor.count(VERSION) == 1, "sensor package version identity missing or duplicated")
    for marker in [
        "GraphicFileAudit",
        "ExportGraphicChecked",
        "graphicTemporaryPath",
        "GraphicExportMalformed",
    ]:
        require(marker in plotting, f"plotting marker missing: {marker}")
    for marker in [
        "recyclePlotKernels",
        "renderPlotTask",
        "renderExportPlotBatch",
        "retryPlotTaskOnController",
        "AuditExistingGraphicsOutput",
        "GraphicsIntegrityAuditSummary",
        "normalizePlotTaskExportResult",
        "plotBatchInvariantAudit",
        "BatchInvariantPassedQ",
        "UnclassifiedResultCount",
    ]:
        require(marker in sensor, f"sensor graphics-lifecycle marker missing: {marker}")

    for old_name in [
        "HygrothermalPlottingUtilities_v1_1.wl",
        "SensorDataUtilities_v1_1.wl",
        "SensorComparisonConfig_v1_1.wl",
        "MongoDB_Data_Analysis_WUFI_Comparison_v1_1.wl",
    ]:
        require(old_name not in driver + config + notebook + smoke, f"active source still references {old_name}")

    require("Output_v1_2_Run1" in config, "v1.2 output root missing from config")
    require("ParallelPlotGeneration" in config, "parallel plot setting missing from config")
    require("RecyclePlotKernelsPerBatch" in config, "kernel recycle setting missing from config")
    require("RunGraphicsAudit" in config, "graphics audit setting missing from config")
    require("Internal cache information" not in notebook, "notebook contains stale internal cache information")
    require("NotebookFileOutline" not in notebook, "notebook contains stale file outline")

    forbidden = ["SetDirectory[", "ClearAll[\"Global`*\"]", "SetSharedVariable["]
    for filename in [
        "HygrothermalPlottingUtilities_v1_2.wl",
        "SensorDataUtilities_v1_2.wl",
        "MongoDB_Data_Analysis_WUFI_Comparison_v1_2.wl",
    ]:
        text = (ROOT / filename).read_text(encoding="utf-8")
        for marker in forbidden:
            require(marker not in text, f"forbidden active-code marker {marker!r} in {filename}")

    smoke_count = smoke.count("VerificationTest[")
    equivalence_count = equivalence.count("VerificationTest[")
    require(smoke_count == 46, f"expected 46 smoke tests, found {smoke_count}")
    require(equivalence_count == 13, f"expected 13 equivalence gates, found {equivalence_count}")
    require("Output_v1_2_Run1" in equivalence, "equivalence candidate root is not v1.2")
    messages.extend([
        "release identities: Production v1.2.0",
        "graphics lifecycle markers: present",
        "active v1.1 filename references: none",
        "notebook generated caches: removed",
        "smoke tests declared: 46",
        "equivalence gates declared: 13",
    ])
    return messages


def validate_release_manifest() -> list[str]:
    path = ROOT / "PRODUCTION_RELEASE_MANIFEST_v1.2.0.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    require(data.get("Release") == "Production v1.2.0", "release manifest identity mismatch")
    require(data.get("VersionString") == VERSION, "release manifest version string mismatch")
    require(
        data.get("DefaultOutputDirectoryName") == "Output_v1_2_Run1",
        "production output-directory identity mismatch",
    )
    evidence = data.get("AcceptanceEvidence", {})
    require(evidence.get("SmokeTestsPassed") == 46, "release manifest smoke-test pass count mismatch")
    require(evidence.get("SmokeTestsTotal") == 46, "release manifest smoke-test total mismatch")
    require(evidence.get("EquivalenceTestsPassed") == 13, "release manifest equivalence pass count mismatch")
    require(evidence.get("EquivalenceTestsTotal") == 13, "release manifest equivalence total mismatch")
    require(evidence.get("AlignmentAuditsPassed") == 24, "release manifest alignment pass count mismatch")
    require(evidence.get("ExpectedJPGCount") == 99, "release manifest expected-JPG count mismatch")
    require(evidence.get("ValidJPGCount") == 99, "release manifest valid-JPG count mismatch")
    return [
        "production release manifest identity: valid",
        "validated acceptance evidence: 46 smoke, 13 equivalence, 24 alignment, 99 graphics",
        "release manifest default output: Output_v1_2_Run1",
    ]


def main() -> int:
    failures: list[str] = []
    passes: list[str] = []

    for filename in REQUIRED_FILES:
        path = ROOT / filename
        if path.exists():
            passes.append(f"required file present: {filename}")
        else:
            failures.append(f"required file missing: {filename}")

    if (ROOT / "TestAssets.7z").exists():
        passes.append("test fixtures packaged as TestAssets.7z; extract beside tests before Wolfram runtime suites")

    for label, validator in [
        ("registry", validate_registry),
        ("sources", validate_sources),
        ("release manifest", validate_release_manifest),
    ]:
        try:
            passes.extend(validator())
        except Exception as exc:  # noqa: BLE001 - validation report should collect every failure
            failures.append(f"{label}: {exc}")

    print("WUFI vs Sensor Comparison Production v1.2.0 static validation")
    print("=" * 64)
    for message in passes:
        print(f"PASS: {message}")
    for message in failures:
        print(f"FAIL: {message}")
    print("=" * 64)
    print(f"PASS count: {len(passes)}")
    print(f"FAIL count: {len(failures)}")
    if failures:
        print("STATIC VALIDATION: FAILED")
        return 1
    print("STATIC VALIDATION: PASSED")
    print("NOTE: Production metadata package is statically valid; runtime acceptance is inherited unchanged from accepted v1.2.0 RC3.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
