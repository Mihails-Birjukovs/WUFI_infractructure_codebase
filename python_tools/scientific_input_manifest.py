#!/usr/bin/env python3
"""Local SHA-256 manifests for authorized WAC and REF/HEMP reference inputs.

Never uploads file contents, hashes or paths. The generated JSON deliberately
records logical identifiers, file basenames and hashes but no absolute paths.
Store private manifests with the source data; do not commit them by default.
"""
from __future__ import annotations

import argparse
import hashlib
from importlib.metadata import PackageNotFoundError, version
import json
from pathlib import Path
import platform
import re


def file_digest(path: Path) -> dict:
    """Hash data in bounded blocks, including large WXF/MX source inputs."""
    path = Path(path)
    if not path.is_file():
        raise FileNotFoundError(path)
    digest = hashlib.sha256()
    length = 0
    with path.open("rb") as stream:
        while True:
            chunk = stream.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
            length += len(chunk)
    return {"file_basename": path.name, "size_bytes": length,
            "sha256": digest.hexdigest()}


def environment() -> dict:
    """Pin versions that influence independent scientific computations."""
    libs = {}
    for name in ("numpy", "pandas", "scipy", "pvlib"):
        try:
            libs[name] = version(name)
        except PackageNotFoundError:
            libs[name] = None
    return {"python": platform.python_version(), "libraries": libs}


def build_manifest(inputs: dict[str, Path], git_commit: str | None = None) -> dict:
    if not inputs or any(not re.fullmatch(r"[A-Za-z0-9_.-]{1,128}", key)
                         for key in inputs):
        raise ValueError("Each source requires a nonempty safe logical label")
    return {
        "schema": "wufi-scientific-inputs-v1",
        "git_commit": git_commit,
        "environment": environment(),
        "inputs": {name: file_digest(inputs[name]) for name in sorted(inputs)},
        "scope": "local fingerprint only: no claim of independent scientific acceptance",
    }


def check_manifest(saved: dict, inputs: dict[str, Path]) -> dict:
    if saved.get("schema") != "wufi-scientific-inputs-v1":
        raise ValueError("Unexpected checksum manifest schema")
    expected = saved.get("inputs")
    if not isinstance(expected, dict):
        raise ValueError("No expected inputs in checksum manifest")
    if set(expected) != set(inputs):
        raise ValueError("Logical source labels differ from the saved manifest")
    actual = {name: file_digest(path) for name, path in inputs.items()}
    errors = {}
    for name in sorted(expected):
        issues = {}
        for field in ("sha256", "size_bytes"):
            if actual[name][field] != expected[name].get(field):
                issues[field] = {"expected": expected[name].get(field),
                                 "actual": actual[name][field]}
        if issues:
            errors[name] = issues
    return {"passed": not bool(errors), "input_count": len(inputs),
            "mismatches": errors}


def _files(specifications: list[str]) -> dict[str, Path]:
    inputs = {}
    for item in specifications:
        if "=" not in item:
            raise ValueError("Use --file LABEL=PATH for every scientific source")
        label, path = item.split("=", 1)
        if label in inputs:
            raise ValueError(f"Duplicate logical label {label}")
        inputs[label] = Path(path)
    return inputs


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--file", action="append", required=True,
                   help="Logical label and private file location as LABEL=PATH")
    p.add_argument("--output-json", type=Path)
    p.add_argument("--git-commit")
    p.add_argument("--verify", type=Path,
                   help="Verify exactly the same source labels against a saved manifest")
    args = p.parse_args()
    inputs = _files(args.file)
    if args.verify:
        saved = json.loads(args.verify.read_text(encoding="utf-8"))
        report = check_manifest(saved, inputs)
        print(json.dumps(report, indent=2))
        if not report["passed"]:
            raise SystemExit(1)
    else:
        if args.output_json is None:
            p.error("--output-json required when creating a new manifest")
        manifest = build_manifest(inputs, args.git_commit)
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        print(f"Recorded {len(inputs)} private source checksums in {args.output_json}")


if __name__ == "__main__":
    main()
