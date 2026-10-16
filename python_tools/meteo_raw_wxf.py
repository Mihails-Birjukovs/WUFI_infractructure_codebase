"""Streaming, read-only extraction of archived REF/HEMP meteorological WXF.

Supported subset: raw version-8, top-level List of Associations with '$date'
ISO string, numeric meteo fields; handles WXF Null as a missing numeric value.
This deliberately does not evaluate Wolfram language expressions, publish
private measurements, or promise support for arbitrary WXF archives.
"""
from __future__ import annotations

from pathlib import Path
import struct

import numpy as np
import pandas as pd


FIELDS = ("temp_out", "humidity_out", "temp_in", "humidity_in",
          "solar_radiation", "wind_speed")


class _Reader:
    def __init__(self, data: bytes, max_size: int = 150_000_000):
        if len(data) > max_size or not data.startswith(b"8:"):
            raise ValueError("Expected uncompressed version-8 WXF below size limit")
        self.data = memoryview(data)[2:]
        self.i = 0

    def varint(self) -> int:
        number, shift = 0, 0
        while shift <= 63:
            if self.i >= len(self.data):
                raise ValueError("Truncated WXF varint")
            b = self.data[self.i]
            self.i += 1
            number |= (b & 127) << shift
            if b < 128:
                return number
            shift += 7
        raise ValueError("Oversized WXF varint")

    def parse(self, depth: int = 0):
        if depth > 80 or self.i >= len(self.data):
            raise ValueError("Truncated or nested WXF")
        tag = self.data[self.i]
        self.i += 1
        if tag == ord("f"):
            n = self.varint()
            if n > 100_000_000:
                raise ValueError("WXF excessive function arity")
            head = self.parse(depth + 1)
            return (head, *(self.parse(depth + 1) for _ in range(n)))
        if tag == ord("A"):
            n = self.varint()
            if n > 50_000:
                raise ValueError("Excessively large WXF Association")
            entries = [self.parse(depth + 1) for _ in range(n)]
            if any(not isinstance(e, tuple) or len(e) != 3 or e[0] != "RULE"
                   for e in entries):
                raise ValueError("Malformed WXF Association")
            return {e[1]: e[2] for e in entries}
        if tag in (ord("-"), ord(":")):
            return ("RULE", self.parse(depth + 1), self.parse(depth + 1))
        if tag in (ord("s"), ord("S"), ord("I"), ord("R")):
            length = self.varint()
            if length > 10_000_000 or self.i + length > len(self.data):
                raise ValueError("Oversized/truncated WXF text field")
            result = self.data[self.i:self.i+length].tobytes().decode("utf-8")
            self.i += length
            return result
        if tag in (ord("C"), ord("j"), ord("i"), ord("L"), ord("r")):
            spec = {ord("C"): "<b", ord("j"): "<h", ord("i"): "<i",
                    ord("L"): "<q", ord("r"): "<d"}[tag]
            size = struct.calcsize(spec)
            if self.i + size > len(self.data):
                raise ValueError("Truncated numeric WXF")
            result = struct.unpack_from(spec, self.data, self.i)[0]
            self.i += size
            return result
        raise ValueError(f"Unsupported raw-meteo WXF token 0x{tag:x}")

    def list_head(self) -> int:
        if self.data[self.i] != ord("f"):
            raise ValueError("Expected top-level WXF List function")
        self.i += 1
        n = self.varint()
        if self.parse() != "List" or n > 1_000_000:
            raise ValueError("Expected List of <=1 million meteo records")
        return n


def meteo_samples(path: str | Path) -> pd.DataFrame:
    """Read dated minute-resolution meteo records (private local file only)."""
    reader = _Reader(Path(path).read_bytes())
    count = reader.list_head()
    rows = []
    for _ in range(count):
        record = reader.parse()
        if not isinstance(record, dict) or not isinstance(record.get("date"), dict):
            raise ValueError("Meteo record missing date Association")
        date = record["date"].get("$date")
        if not isinstance(date, str):
            raise ValueError("Meteo record missing ISO date")
        rows.append((date, *(record.get(c, np.nan) for c in FIELDS)))
    if reader.i != len(reader.data):
        raise ValueError("Unexpected trailing WXF bytes")
    frame = pd.DataFrame(rows, columns=("date", *FIELDS))
    frame["date"] = pd.to_datetime(frame["date"], utc=True, errors="raise")
    for name in FIELDS:
        frame[name] = pd.to_numeric(frame[name], errors="coerce")
    return frame.set_index(frame.pop("date").dt.tz_convert(None)).sort_index()


def centered_hourly_meteo(raw: pd.DataFrame, utc_grid: pd.DatetimeIndex,
                          half_window_minutes: int = 30) -> pd.DataFrame:
    """Compute finite-value centered medians; do not silently fill source gaps.

    The published Phase-4 report specifies centered-hourly medians but not
    every source QC decision. This is therefore a method-class implementation.
    """
    if (not isinstance(raw.index, pd.DatetimeIndex) or
            not isinstance(utc_grid, pd.DatetimeIndex) or
            raw.index.tz is not None or utc_grid.tz is not None):
        raise ValueError("Both indexes must be timezone-naive DatetimeIndex")
    if not raw.index.is_monotonic_increasing or raw.index.has_duplicates:
        raise ValueError("Raw meteorological timestamps must be sorted and unique")
    if half_window_minutes <= 0:
        raise ValueError("Window radius must be positive")
    raw_ns = raw.index.to_numpy(dtype="datetime64[ns]").view("i8")
    centers_ns = utc_grid.to_numpy(dtype="datetime64[ns]").view("i8")
    delta = half_window_minutes * 60 * 1_000_000_000
    start = np.searchsorted(raw_ns, centers_ns - delta, side="left")
    end = np.searchsorted(raw_ns, centers_ns + delta, side="right")
    out = pd.DataFrame(index=utc_grid)
    for name in FIELDS:
        values = pd.to_numeric(raw[name], errors="coerce").to_numpy(dtype=float)
        result = []
        for a, b in zip(start, end):
            block = values[a:b]
            finite = block[np.isfinite(block)]
            result.append(float(np.median(finite)) if len(finite) else np.nan)
        out[name] = result
    return out
