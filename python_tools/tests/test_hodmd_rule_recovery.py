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



def _complete_archived_fingerprint_fixture():
    rows=[]
    for system in ("HEMP19","HEMP27","REF118","HEMP_PRIMARY"):
        total=40 if system=="HEMP_PRIMARY" else 39
        for window in ("W1","W2"):
            for source in ("exp","wufi"):
                for target, period in TARGET_PERIODS.items():
                    rows.append({
                        "system":system,"window":window,"source":source,
                        "target":target,"target_h":period,
                        "nfits_total":total,"nfits_found":20,
                        "stability_fraction":20/total,
                        "period_q10_h":period*.95,
                        "period_median_h":period,
                        "period_q90_h":period*1.05,
                    })
    table=pd.DataFrame(rows)
    table.loc[(table.system=="HEMP19") & (table.window=="W1") &
              (table.source=="exp") & (table.target=="weekly"),
              "period_q90_h"]=168*1.2830929615020918
    return table


def test_valid_archive_fingerprint_and_halfwidth_lower_bound():
    fixture=_complete_archived_fingerprint_fixture()
    audit=archived_stability_constraints(fixture)
    assert audit["archive_rows"]==112
    assert audit["group_count"]==16
    assert audit["two_channel_configurations_if_rank_strict"]==39
    assert audit["six_channel_configurations_if_rank_strict"]==40
    assert audit["excluded_two_channel_grid_pairs_if_strict"]==[[12,24]]
    assert audit["minimum_symmetric_relative_period_halfwidth_from_q10_q90"]==pytest.approx(.2830929615020918)
    assert audit["quantile_rows_incompatible_with_25pct_window"]==1
    assert audit["quantile_rows_incompatible_with_30pct_window"]==0


def test_archive_rejects_inconsistent_stability_fraction():
    f=_complete_archived_fingerprint_fixture()
    f.loc[0,"stability_fraction"]=.9
    with pytest.raises(ValueError,match="inconsistent"):
        archived_stability_constraints(f)


def test_480_fit_paperstyle_coverage_and_log_eigenvalue_identity():
    from python_tools.hodmd_rule_recovery import paperstyle_coverage
    rows=[]
    for system in ("HEMP27","HEMP19","REF118","HEMP42","HEMP18"):
        for window in ("W1","W2"):
            for source in ("exp","wufi"):
                for delay in (24,36,48,72):
                    for rank in (6,8,10,12,16,20):
                        has_detail=system not in ("HEMP42","HEMP18")
                        rows.append({
                            "system":system,"window":window,"source":source,
                            "delay_h":delay,"rank":rank,
                            "period24_h":24.,"eig_abs":.99,
                            "growth_per_h":np.log(.99) if has_detail else np.nan,
                            "load_T":.1 if has_detail else np.nan,
                            "load_pv":.2 if has_detail else np.nan,
                        })
    report=paperstyle_coverage(pd.DataFrame(rows))
    assert report["fits"]==480
    assert report["group_count"]==20
    assert report["coverage"]["HEMP27"]["growth_rows"]==96
    assert report["coverage"]["HEMP18"]["growth_rows"]==0
    assert report["growth_is_log_eigenvalue_modulus_to_max_absolute_error"]<1e-12



def test_growth_sign_can_be_evaluated_without_claiming_historical_rule():
    x = _mode_catalog()
    selected = summarize_candidate_spectra(
        x, target=24., require_nonpositive_growth=True)
    assert selected.iloc[0].mode_id == "b"
    x.loc[x.mode_id=="b","growth_per_h"] = .003
    y = summarize_candidate_spectra(
        x, target=24., require_nonpositive_growth=True)
    assert y.iloc[0].mode_id == "a"
    x.loc[x.mode_id=="a","growth_per_h"] = .001
    z = summarize_candidate_spectra(
        x, target=24., require_nonpositive_growth=True)
    assert z.empty
