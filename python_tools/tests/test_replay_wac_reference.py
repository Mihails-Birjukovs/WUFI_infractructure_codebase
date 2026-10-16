import pandas as pd
from python_tools.replay_wac_reference import replay
from python_tools.wac_from_audit import reconstruct_from_audit, write_wac
from python_tools.tests.test_wac import _frame


def test_full_generator_replay_with_synthetic_reference(tmp_path):
    f = _frame()
    audit = tmp_path / "audit.csv"
    f.to_csv(audit, index=False)
    reference = tmp_path / "archive.wac"
    write_wac(reconstruct_from_audit(f), reference)
    report, mismatches = replay(audit, reference, tmp_path / "rebuilt.wac")
    assert report["strict_parity"]
    assert report["radiation_hours_exceed_strict_tolerance"] == 0
    assert report["within_user_selected_science_tolerance"] is None
    assert mismatches.empty
    text = (tmp_path / "rebuilt.wac").read_text(encoding="latin-1")
    assert text.startswith("WUFI®_WAC_02")


def test_replay_detects_distinct_reference(tmp_path):
    f = _frame()
    audit = tmp_path / "audit.csv"
    f.to_csv(audit, index=False)
    rebuilt = reconstruct_from_audit(f)
    rebuilt.loc[123, "ISGH"] += .05
    reference = tmp_path / "modified.wac"
    write_wac(rebuilt, reference)
    report, errors = replay(audit, reference, tmp_path / "new.wac")
    assert not report["strict_parity"]
    assert report["radiation_hours_exceed_strict_tolerance"] == 1
    assert report["within_user_selected_science_tolerance"] is None
