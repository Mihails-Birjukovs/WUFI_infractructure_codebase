import numpy as np
import pandas as pd
import pytest

from python_tools.hodmd_rule_recovery import (
    DELAY_ORDERS, TRUNCATION_RANKS, TARGET_PERIODS, admissible_configs,
    summarize_candidate_spectra, stability_counts, archived_stability_constraints,
)


def test_rank_admissibility_fingerprint_two_vs_six_channels():
    assert len(DELAY_ORDERS)*len(TRUNCATION_RANKS) == 40
    two = admissible_configs(2)
    six = admissible_configs(6)
    assert len(two) == 39
    assert len(six) == 40
    assert (12, 24) not in two
    assert (12, 24) in six
    assert (12, 24) in admissible_configs(2, strict_embedding=False)


def _mode_catalog():
    keys=dict(system="HEMP27", window="W1", source="exp", delay_h=24, rank=6)
    return pd.DataFrame([
        {**keys,"mode_id":"a","period_h":23.8,"growth_per_h":-.01,
         "amplitude":.1},
        {**keys,"mode_id":"b","period_h":24.1,"growth_per_h":-.02,
         "amplitude":.05},
        {**keys,"mode_id":"c","period_h":41.0,"growth_per_h":-.001,
         "amplitude":10.0},
    ])


def test_one_mode_per_fit_rank_by_period_vs_amplitude():
    modes=_mode_catalog()
    near=summarize_candidate_spectra(modes,target=24.,relative_halfwidth=.3)
    assert len(near)==1
    assert near.iloc[0].mode_id=="b"
    amp=summarize_candidate_spectra(
        modes,target=24.,relative_halfwidth=.3,selection="max_amplitude")
    assert amp.iloc[0].mode_id=="a"
    filtered=summarize_candidate_spectra(
        modes,target=24.,relative_halfwidth=.3,max_abs_growth=.015)
    assert filtered.iloc[0].mode_id=="a"
    too_strict=summarize_candidate_spectra(
        modes,target=24.,relative_halfwidth=.3,min_amplitude=1.)
    assert too_strict.empty


def test_count_logic_and_stability():
    f=_mode_catalog()
    selected=summarize_candidate_spectra(f,target=24.)
    valid=f[["system","window","source","delay_h","rank"]].drop_duplicates()
    out=stability_counts(selected,valid,"24h")
    assert out.iloc[0].nfits_total==1
    assert out.iloc[0].nfits_found==1
    assert out.iloc[0].stability_fraction==1.
    with pytest.raises(ValueError,match="Repeated rows"):
        stability_counts(selected,pd.concat([valid,valid]),"24h")


def test_archive_inventory_validation_does_not_silently_accept_bad_counts():
    malformed=pd.DataFrame([dict(system="HEMP27",window="W1",source="exp",
        target="24h",target_h=24,nfits_total=39,nfits_found=32,
        stability_fraction=1, period_q10_h=23,period_median_h=24,
        period_q90_h=25)])
    with pytest.raises(ValueError,match="112-row"):
        archived_stability_constraints(malformed)


def test_target_set_matches_report():
    assert list(TARGET_PERIODS.values())==[12,24,48,72,168,336,720]
