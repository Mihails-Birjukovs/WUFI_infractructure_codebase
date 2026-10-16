"""Read the narrow WXF subset used by archived REF/HEMP comparison and sensor files.

This parser is intentionally **read-only** and never evaluates Wolfram code.
Supported WXF: version 8, optional zlib compression, List/DateObject/
Association/Rule, integer/real/string/symbol tokens and numeric PackedArray.
Unsupported tags fail explicitly. Do not regard it as a general WXF library.
"""
from __future__ import annotations

import datetime as dt
from pathlib import Path
import struct
import zlib

import numpy as np
import pandas as pd


class WXFSubsetParser:
    def __init__(self, content: bytes, max_bytes: int = 100_000_000):
        if len(content) > max_bytes:
            raise ValueError("WXF exceeds configured size limit")
        if content.startswith(b"8:"):
            content = content[2:]
        elif content.startswith(b"8C:"):
            inflater = zlib.decompressobj()
            output = inflater.decompress(content[3:], max_bytes + 1)
            if len(output) > max_bytes or inflater.unconsumed_tail:
                raise ValueError("Uncompressed WXF exceeds configured size limit")
            content = output + inflater.flush()
        else:
            raise ValueError("Only WXF version 8 is supported")
        self.data = memoryview(content)
        self.pos = 0

    def _bytes(self, n: int) -> bytes:
        if n < 0 or self.pos + n > len(self.data):
            raise ValueError("Truncated or corrupt WXF")
        out = self.data[self.pos:self.pos + n].tobytes()
        self.pos += n
        return out

    def _varint(self) -> int:
        value = 0
        for shift in range(0, 70, 7):
            byte = self._bytes(1)[0]
            value |= (byte & 127) << shift
            if byte < 128:
                return value
        raise ValueError("Oversized WXF integer")

    def _expr(self, depth: int = 0):
        if depth > 120:
            raise ValueError("WXF expression too deeply nested")
        token = self._bytes(1)
        if token == b"f":
            n = self._varint()
            if n > 1_000_000:
                raise ValueError("WXF function arity too large")
            head = self._expr(depth + 1)
            return (head, *(self._expr(depth + 1) for _ in range(n)))
        if token in (b"s", b"S", b"I", b"R"):
            count = self._varint()
            value = self._bytes(count).decode("utf-8")
            return ("SYM", value) if token == b"s" else value
        formats = {b"C": "<b", b"j": "<h", b"i": "<i", b"L": "<q", b"r": "<d"}
        if token in formats:
            fmt = formats[token]
            return struct.unpack(fmt, self._bytes(struct.calcsize(fmt)))[0]
        if token == b"A":
            n = self._varint()
            return ("ASSOC", *(self._expr(depth + 1) for _ in range(n)))
        if token in (b"-", b":"):
            return ("RULE", self._expr(depth + 1), self._expr(depth + 1))
        if token == b"\xc1":
            t = self._bytes(1)[0]
            dtype = {0x00: "i1", 0x01: "<i2", 0x02: "<i4",
                     0x03: "<i8", 0x10: "u1", 0x11: "<u2",
                     0x12: "<u4", 0x13: "<u8", 0x22: "<f4",
                     0x23: "<f8"}.get(t)
            if dtype is None:
                raise ValueError(f"Unsupported WXF PackedArray numeric type {t:#x}")
            rank = self._varint()
            if not 1 <= rank <= 8:
                raise ValueError("Unsupported WXF PackedArray rank")
            dims = tuple(self._varint() for _ in range(rank))
            nitems = int(np.prod(dims))
            return np.frombuffer(self._bytes(nitems * np.dtype(dtype).itemsize),
                                 dtype=dtype).reshape(dims)
        if token == b"B":
            return self._bytes(self._varint())
        raise ValueError(f"Unsupported WXF token {token!r} at {self.pos - 1}")

    def parse(self):
        obj = self._expr()
        if self.pos != len(self.data):
            raise ValueError("Trailing WXF bytes")
        return obj


def load_wxf(path: str | Path):
    """Decode a trusted local REF/HEMP WXF file; no Wolfram kernel required."""
    return WXFSubsetParser(Path(path).read_bytes()).parse()


def association(obj: tuple) -> dict:
    if not isinstance(obj, tuple) or obj[0] != "ASSOC":
        raise ValueError("Expected a WXF Association")
    if any(not isinstance(q, tuple) or len(q) != 3 or q[0] != "RULE"
           for q in obj[1:]):
        raise ValueError("Malformed WXF Association rules")
    return {rule[1]: rule[2] for rule in obj[1:]}


def list_args(obj: tuple) -> tuple:
    if not isinstance(obj, tuple) or obj[0] != ("SYM", "List"):
        raise ValueError("Expected a WXF List")
    return obj[1:]


def utc_date_object(obj: tuple) -> dt.datetime:
    if obj[0] != ("SYM", "DateObject"):
        raise ValueError("Expected DateObject in comparison archive")
    if obj[4] != 0:
        raise ValueError("Comparison archive DateObject must be in UTC")
    p = list_args(obj[1])
    if len(p) != 6:
        raise ValueError("Expected six-element DateObject")
    return dt.datetime(*[int(v) for v in p[:5]]) + dt.timedelta(seconds=float(p[5]))


def comparison_pairs(path: str | Path) -> tuple[dict, pd.DataFrame]:
    """Return archive metadata and {sensor, wufi, residual} indexed by UTC.

    Group temperature can aggregate multiple sensors; read SensorIDs before
    claiming parity with a particular individually archived sensor.
    """
    contents = association(load_wxf(path))
    pairs = []
    for expr in list_args(contents["PairedRows"]):
        t, sensor, wufi, residual = list_args(expr)
        pairs.append((utc_date_object(t), float(sensor), float(wufi), float(residual)))
    table = pd.DataFrame(pairs, columns=("TIME_UTC", "sensor", "wufi", "residual"))
    table = table.set_index("TIME_UTC").sort_index()
    if table.index.has_duplicates:
        raise ValueError("Duplicate UTC paired timestamps")
    if not np.isfinite(table.to_numpy()).all():
        raise ValueError("Archive paired values contain nonfinite numbers")
    if not np.allclose(table["wufi"] - table["sensor"], table["residual"],
                       atol=1e-7, rtol=0):
        raise ValueError("Archived residuals are not WUFI minus sensor")
    return {
        "group": contents.get("GroupFolderName"),
        "variable": contents.get("Variable"),
        "sensor_ids": list_args(association(contents["SensorGroupRecord"])["SensorIDs"]),
        "rows": len(table),
    }, table


def raw_sensor_samples(path: str | Path) -> pd.DataFrame:
    """Read original numeric {DateObject, temperature_degC, humidity_pct} rows.

    No QC, deduplication or time-aggregation is performed by this function.
    """
    rows = []
    for item in list_args(load_wxf(path)):
        date, temperature, humidity = list_args(item)
        rows.append((utc_date_object(date), float(temperature), float(humidity)))
    frame = pd.DataFrame(rows, columns=["TIME_UTC", "T", "RH"])
    return frame.set_index("TIME_UTC").sort_index()


def centered_raw_median(frame: pd.DataFrame, timestamp: str | pd.Timestamp,
                        column: str, half_window_minutes: int = 30) -> tuple[float, int]:
    """Exploratory QC-gap sensitivity only; NOT original Production v1.2 QC."""
    t = pd.Timestamp(timestamp)
    delta = pd.Timedelta(minutes=half_window_minutes)
    values = frame.loc[t-delta:t+delta, column].dropna()
    return (float(values.median()) if len(values) else float("nan"), len(values))
