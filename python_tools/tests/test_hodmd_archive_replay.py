import numpy as np
import pandas as pd
import pytest

from python_tools.hodmd_archive_replay import (
    _candidate_modes, reproduce, score, FIT_KEYS, TARGET_PERIODS,
)


def test_multiplicative_gate_vs_additive_gate():
    key={"system":"HEMP27","window":"W1","source":"exp","delay_h":12,"rank":4}
    modes=pd.DataFrame([
        {**key,"mode_id":0,"period_h":24.*1.28,"growth_per_h":-.01,
         "amplitude":1.,"loading_0":.8,"loading_1":.6},
        {**key,"mode_id":1,"period_h":24.8,"growth_per_h":-.001,
         "amplitude":.5,"loading_0":.3,"loading_1":.4},
    ])
    assert len(_candidate_modes(modes,24.,rule="multiplicative"))==1
    assert _candidate_modes(modes,24.).iloc[0].period_h==pytest.approx(24.8)
    assert len(_candidate_modes(modes,24.,rule="additive_25pct"))==1
    assert len(_candidate_modes(modes[modes.mode_id==0],24.,rule="additive_25pct"))==0
    assert len(_candidate_modes(modes[modes.mode_id==0],24.,rule="multiplicative"))==1


def test_invalid_period_gate_rejected():
    with pytest.raises(ValueError,match="exceed"):
        _candidate_modes(pd.DataFrame(),24.,period_factor=1.)
    with pytest.raises(ValueError,match="Invalid candidate"):
        _candidate_modes(pd.DataFrame(),24.,rule="unknown")


def _synthetic_archive_and_spectra():
    archive=[]
    modes=[]
    fits=[]
    for system in ("HEMP19","HEMP27","REF118"):
        for window in ("W1","W2"):
            n=1388 if window=="W1" else 1393
            norm=np.sqrt((n-1)/n)
            for source in ("exp","wufi"):
                for i in range(39):
                    fit={"system":system,"window":window,"source":source,
                         "delay_h":12+(i//8)*12,"rank":4+i%8}
                    fits.append({**fit,"fit_status":"valid_fit"})
                    modes.append({**fit,"mode_id":0,"period_h":24.,
                                  "growth_per_h":-.01,"amplitude":1.,
                                  "loading_0":.8,"loading_1":.6})
                for target,period in TARGET_PERIODS.items():
                    count=39 if target=="24h" else 0
                    archive.append({
                        "system":system,"window":window,"source":source,
                        "target":target,"target_h":period,"nfits_total":39,
                        "nfits_found":count,"period_median_h":24.,
                        "period_q10_h":24.,"period_q90_h":24.,
                        "growth_median_per_h":-.01,
                        "amp_median":norm,"loading_0_median":.8*norm,
                        "loading_1_median":.6*norm,
                    })
    return pd.DataFrame(modes),pd.DataFrame(fits),pd.DataFrame(archive)


def test_frozen_source_count_and_sample_sd_contract():
    modes,fits,archive=_synthetic_archive_and_spectra()
    summary=reproduce(modes,fits,archive)
    assert len(summary)==84
    daily=summary.loc[summary.target=="24h"]
    assert (daily.count_error==0).all()
    assert np.allclose(daily.replayed_amp_median,daily.archived_amp_median,
                       rtol=0,atol=1e-12)
    assert score(summary)["exact_fit_count_rows"]==84


def test_reject_synthetic_missing_or_duplicated_inventory():
    modes,fits,archive=_synthetic_archive_and_spectra()
    with pytest.raises(ValueError,match="duplicates"):
        reproduce(pd.concat([modes,modes.iloc[:1]]),fits,archive)
    with pytest.raises(ValueError,match="39 valid"):
        reproduce(modes,fits.iloc[1:],archive)
