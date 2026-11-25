#!/usr/bin/env python3
"""Fail-closed validator for published WUFI documentation.

This is a machine guard, not a substitute for scientific or rights review.
Three institutional assets are byte-frozen copies of artwork in the
same maintainer's existing OOC documentation site; not MIT-licensed.
"""
from __future__ import annotations

from pathlib import Path
import hashlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "site_docs"

APPROVED = {
    "index.md",
    "getting-started.md",
    "architecture.md",
    "mathematica.md",
    "python.md",
    "climate.md",
    "campaign2.md",
    "campaign2-climate-methods.md",
    "modal.md",
    "validation.md",
    "data-provenance.md",
    "source-reference.md",
    "contributing.md",
    "licensing.md",
    "credits.md",
    "references.md",
    "stylesheets/inm-wufi-20261020.css",
    "javascripts/mathjax.js",
    "assets/inm-horizontal.svg",
    "assets/inm-mark.svg",
    "assets/inm-square-footer.svg",
    "assets/campaign2-climate-architecture-v08.svg",
}
# Original Git blob SHAs from OOC_Particles_Velocimetry_Docs/main.
APPROVED_INM_BLOBS = {
    "assets/inm-horizontal.svg": "33938b2a9a6ae442b3ede153fb79187a31040a68",
    "assets/inm-mark.svg": "b3a5154d96b0daf24cd44711fa13980689119287",
    "assets/inm-square-footer.svg": "327ffd7d447e8475e4c8f0e0d0fa68f465be841b",
}
# Original, reviewed, schematic-only artwork (no measured data).
APPROVED_SCHEMATIC_BLOBS = {
    "assets/campaign2-climate-architecture-v08.svg": "100e75835f409a2998e340e8ac8db8500da686bf",
}
APPROVED_SVG_BLOBS = {**APPROVED_INM_BLOBS, **APPROVED_SCHEMATIC_BLOBS}
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
        is_approved_svg = name in APPROVED_SVG_BLOBS
        if path.suffix.lower() in BLOCKED_SUFFIXES and not is_approved_svg:
            raise ValueError(f"Data/binary artifact forbidden: {name}")
        if path.suffix.lower() not in {".md", ".css", ".js"} and not is_approved_svg:
            raise ValueError(f"Unreviewed extension: {name}")
        payload = path.read_bytes()
        if len(payload) > 100_000:
            raise ValueError(f"Oversized site asset: {name}")
        if is_approved_svg:
            git_blob = hashlib.sha1(
                f"blob {len(payload)}\0".encode("ascii") + payload
            ).hexdigest()
            if git_blob != APPROVED_SVG_BLOBS[name]:
                raise ValueError(f"Modified/unapproved pinned SVG artwork: {name}")
        raw = payload.decode("utf-8")
        for pattern in PRIVATE_PATTERNS:
            if pattern.search(raw):
                raise ValueError(f"Possible private string/credential: {name}, {pattern.pattern}")
        if "data:image/" in raw or "<script" in raw.lower() or "<iframe" in raw.lower():
            raise ValueError(f"Unexpected embedded image/script/iframe: {name}")
    config = (ROOT / "zensical.toml").read_text(encoding="utf-8")
    js = (DOCS / "javascripts" / "mathjax.js").read_text(encoding="utf-8")
    if not all(fragment in config for fragment in (
        "pymdownx.arithmatex.generic = true", "javascripts/mathjax.js",
        "mathjax@3.2.2/es5/tex-mml-chtml.js"
    )) or 'tags: "all"' not in js or "document$.subscribe" not in js:
        raise ValueError("Missing pinned numbered-equation renderer or navigation hook")
    if actual != APPROVED:
        raise ValueError(
            "Site files differ from approved publication manifest: "
            f"added={sorted(actual - APPROVED)} missing={sorted(APPROVED - actual)}"
        )
    print(f"PASS: exact {len(APPROVED)} public files, 3 pinned INM SVGs and 1 pinned schematic")


if __name__ == "__main__":
    try:
        validate()
    except (ValueError, OSError, UnicodeError) as exc:
        print(f"PUBLICATION GUARD FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
