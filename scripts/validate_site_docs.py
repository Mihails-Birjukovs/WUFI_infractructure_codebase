#!/usr/bin/env python3
"""Fail-closed validation of curated, PUBLIC WUFI Zensical content.

A passing scan is not scientific, privacy, trademark or copyright approval.
Do not recursively publish original reports, raw sensor data, WXF, WUFI models,
licensed third-party files, external images or unpublished experimental data.
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "site_docs"

# Deliberate exact publication manifest: add a file only in a reviewed PR.
APPROVED = {
    "index.md",
    "getting-started.md",
    "architecture.md",
    "mathematica.md",
    "python.md",
    "climate.md",
    "modal.md",
    "validation.md",
    "data-provenance.md",
    "source-reference.md",
    "contributing.md",
    "licensing.md",
    "stylesheets/wufi.css",
}
BLOCKED_SUFFIXES = {
    ".csv", ".json", ".jsonl", ".7z", ".zip", ".wxf", ".mx",
    ".w6p", ".xml", ".asc", ".wac", ".pdf", ".jpg", ".png",
    ".svg", ".tiff", ".mp4", ".exe", ".dll", ".nb", ".wl",
    ".pkl", ".parquet", ".sqlite", ".db", ".key", ".pem",
}
PRIVATE_PATTERNS = [
    re.compile(r"/mnt/data/|/home/oai/|[A-Za-z]:\\\\", re.I),
    re.compile(r"(?i)(?:api[_-]?key|password|access[_-]?token|secret)\s*[:=]\s*[\"']?[A-Za-z0-9_./+-]{12,}"),
    re.compile(r"(?i)mongodb(?:\+srv)?://"),
    re.compile(r"(?i)-----BEGIN (?:RSA |OPENSSH )?PRIVATE KEY-----"),
]


def validate() -> None:
    if not DOCS.is_dir() or DOCS.is_symlink():
        raise ValueError("Missing or symlinked site_docs directory")
    actual: set[str] = set()
    for path in DOCS.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"Symlink forbidden: {path}")
        if not path.is_file():
            continue
        name = path.relative_to(DOCS).as_posix()
        actual.add(name)
        if path.suffix.lower() in BLOCKED_SUFFIXES:
            raise ValueError(f"Data/binary artifact forbidden: {name}")
        if path.suffix.lower() not in {".md", ".css"}:
            raise ValueError(f"Unreviewed extension: {name}")
        if path.stat().st_size > 100_000:
            raise ValueError(f"Unexpected oversized page: {name}")
        raw = path.read_text(encoding="utf-8")
        for pattern in PRIVATE_PATTERNS:
            if pattern.search(raw):
                raise ValueError(f"Possible private string/credential: {name}, {pattern.pattern}")
        if "data:image/" in raw or "<script" in raw.lower() or "<iframe" in raw.lower():
            raise ValueError(f"Unexpected embedded image/script/iframe: {name}")
    if actual != APPROVED:
        raise ValueError(
            "Site files differ from approved publication manifest: "
            f"added={sorted(actual - APPROVED)} missing={sorted(APPROVED - actual)}"
        )
    print(f"PASS: exactly {len(APPROVED)} publication-allowlisted public website files")


if __name__ == "__main__":
    try:
        validate()
    except (ValueError, OSError, UnicodeError) as exc:
        print(f"PUBLICATION GUARD FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
