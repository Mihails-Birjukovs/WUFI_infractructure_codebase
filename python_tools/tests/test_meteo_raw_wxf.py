import struct
import numpy as np
import pandas as pd
from python_tools.meteo_raw_wxf import meteo_samples, centered_hourly_meteo


def _v(n):
    return bytes([n])


def _s(name):
    return b"S" + _v(len(name)) + name.encode()


def _i(v):
    return b"r" + struct.pack("<d", v)


def _assoc(d):
    return b"A" + _v(len(d)) + b"".join(b"-" + _s(k) + val for k, val in d.items())


def test_meteo_wxf_stream_and_hourly_source(tmp_path):
    iso = lambda text: _assoc({"$date": _s(text)})
    row1 = _assoc({"date": iso("2025-01-01T11:31:00Z"),
                  "temp_out": _i(10), "humidity_out": b"C\x50"})
    row2 = _assoc({"date": iso("2025-01-01T11:49:00Z"),
                  "temp_out": _i(12), "humidity_out": b"C\x52"})
    raw = b"8:f\x02s\x04List" + row1 + row2
    p = tmp_path / "meteo.wxf"
    p.write_bytes(raw)
    f = meteo_samples(p)
    assert len(f) == 2
    hourly = centered_hourly_meteo(
        f, pd.DatetimeIndex([pd.Timestamp("2025-01-01 12:00")]))
    assert hourly["temp_out"].iloc[0] == 11.
    assert hourly["humidity_out"].iloc[0] == 81.
    assert np.isnan(hourly["solar_radiation"].iloc[0])
