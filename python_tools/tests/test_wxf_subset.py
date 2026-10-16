import struct
import numpy as np
import pytest

from python_tools.wxf_subset import WXFSubsetParser, association, comparison_pairs


def _var(n):
    out = bytearray()
    while n >= 128:
        out.append((n & 127) | 128)
        n >>= 7
    out.append(n)
    return bytes(out)


def _sym(s):
    return b"s" + _var(len(s)) + s.encode()


def _str(s):
    return b"S" + _var(len(s)) + s.encode()


def _func(head, *values):
    return b"f" + _var(len(values)) + _sym(head) + b"".join(values)


def _real(v):
    return b"r" + struct.pack("<d", v)


def _list(*values):
    return _func("List", *values)


def test_handcrafted_packed_array():
    array = np.array([[1., 2., 3.]], dtype="<f8")
    wxf = b"8:\xc1\x23\x02\x01\x03" + array.tobytes()
    out = WXFSubsetParser(wxf).parse()
    np.testing.assert_array_equal(out, array)


def test_comparison_subset_reader(tmp_path):
    date = _func("DateObject", _list(b"j" + struct.pack("<h", 2026),
                      b"C\x01", b"C\x02", b"C\x03", b"C\x04", _real(0)),
                 _str("Instant"), _str("Gregorian"), _real(0))
    pair = _list(date, _real(10), _real(11), _real(1))
    rule = lambda k, v: b"-" + _str(k) + v
    record = b"A\x03" + rule("PairedRows", _list(pair)) + \
             rule("GroupFolderName", _str("synthetic")) + \
             rule("SensorGroupRecord", b"A\x01" +
                  rule("SensorIDs", _list(b"C\x1b")))
    p = tmp_path / "test.wxf"
    p.write_bytes(b"8:" + record)
    meta, data = comparison_pairs(p)
    assert meta["sensor_ids"] == (27,)
    assert meta["rows"] == 1
    assert data.index[0].year == 2026
    assert data.iloc[0].residual == 1.


def test_reject_unrecognised_tags_and_trailing_content():
    with pytest.raises(ValueError, match="Unsupported WXF token"):
        WXFSubsetParser(b"8:\xff").parse()
    with pytest.raises(ValueError, match="Trailing"):
        WXFSubsetParser(b"8:C\x05x").parse()
