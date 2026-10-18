"""Synthetic-only WAC/WXF preflight regression tests."""
import numpy as np
import pandas as pd
import pytest
from python_tools import wufi_interop_preflight as p
from python_tools.wac_from_audit import write_wac

def _wac(tmp_path):
    frame=pd.DataFrame({"TIME":pd.date_range("2026-01-01 01:00",periods=48,freq="h"),
        "TA":4.,"HREL":.7,"ISGH":10.,"ISD":8.,"WD":180.,"WS":2.,
        "PMSL":1013.})
    path=tmp_path/"test.wac"
    write_wac(frame,path)
    return path

def test_wac_parses_roundtrip(tmp_path):
    result=p.inspect_wac(_wac(tmp_path))
    assert result["rows"]==48 and result["fixed_utc_offset_h"]==2
    assert result["wuFI_pro_import_verified"] is False

def test_wac_rejects_humidity_percentage(tmp_path):
    path=_wac(tmp_path)
    s=path.read_text(encoding="latin-1").replace("\t0.7\t","\t70\t")
    path.write_text(s,encoding="latin-1")
    with pytest.raises(ValueError,match="fraction"):
        p.inspect_wac(path)

def test_wac_rejects_wrong_rows_and_columns(tmp_path):
    path=_wac(tmp_path)
    s=path.read_text(encoding="latin-1")
    path.write_text(s.replace("48\tNumber of DataLines","47\tNumber of DataLines"),encoding="latin-1")
    with pytest.raises(ValueError,match="count mismatch"):
        p.inspect_wac(path)
    path.write_text(s.replace("8\tNumber of DataColumns","7\tNumber of DataColumns"),encoding="latin-1")
    with pytest.raises(ValueError,match="columns mismatch"):
        p.inspect_wac(path)

def test_wufi_pair_checks_alignment_without_private_wxf(monkeypatch,tmp_path):
    idx=pd.date_range("2025-11-27 16:00",periods=48,freq="h")
    T=pd.Series(np.linspace(5.,15.,48),index=idx)
    R=pd.Series(np.linspace(60.,80.,48),index=idx)
    monkeypatch.setattr(p,"model_series",lambda path: T if path.name=="t.wxf" else R)
    r=p.inspect_wufi_pair(tmp_path/"t.wxf",tmp_path/"rh.wxf")
    assert r["rows"]==48 and r["hourly"]
    assert r["mathematica_12_1_desktop_verified"] is False
    R.index=R.index+pd.Timedelta(minutes=1)
    with pytest.raises(ValueError,match="timestamps differ"):
        p.inspect_wufi_pair(tmp_path/"t.wxf",tmp_path/"rh.wxf")
