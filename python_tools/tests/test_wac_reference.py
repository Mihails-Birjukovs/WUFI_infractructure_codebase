"""Contracts for comparing a synthetic WAC against its own generated audit."""
import numpy as np
import pandas as pd
import pytest

from python_tools.validate_wac_reference import compare_wac_to_audit
from python_tools.wac_from_audit import reconstruct_from_audit, write_wac
from python_tools.tests.test_wac import _frame


def test_reference_contract(tmp_path):
    f = reconstruct_from_audit(_frame())
    wac = tmp_path / "synthetic.wac"
    write_wac(f, wac)
    f["corrected_ISGH_Wm2"] = f["ISGH"]
    f["estimated_DHI_Wm2"] = f["ISD"]
    csv = tmp_path / "synthetic_audit.csv"
    f.to_csv(csv, index=False)
    report = compare_wac_to_audit(csv, wac)
    assert report["passed"]
    assert report["rows"] == len(f)
    assert report["matching_fields"] == 7


def test_reference_detects_radiation_change(tmp_path):
    f = reconstruct_from_audit(_frame())
    wac = tmp_path / "synthetic.wac"
    write_wac(f, wac)
    f["corrected_ISGH_Wm2"] = f["ISGH"].to_numpy() + 0.5
    f["estimated_DHI_Wm2"] = f["ISD"]
    csv = tmp_path / "shifted_audit.csv"
    f.to_csv(csv, index=False)
    report = compare_wac_to_audit(csv, wac, radiation_atol=1e-5)
    assert not report["passed"]
    assert report["failed_fields"] == ["ISGH"]
