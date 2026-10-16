import numpy as np
import pandas as pd
import pytest
from python_tools.hodmd_historical_replay import (
    PRIMARY_ORDER, PERIOD_FACTOR, MIN_EIGENVALUE_MODULUS, standardized_pair,
    spectrum, select_modes, aggregate_modes, compare_archive,
)


def test_recovered_primary_and_common_gates():
    assert PRIMARY_ORDER==("HEMP27","HEMP42","HEMP18")
    assert PERIOD_FACTOR==1.3
    assert MIN_EIGENVALUE_MODULUS==.9


def test_sample_sd_and_strict_embedding_rank():
    t=np.arange(300)
    z=np.vstack([np.sin(2*np.pi*t/24),np.cos(2*np.pi*t/24)])
    a,b=standardized_pair(z,2*z+1)
    np.testing.assert_allclose(a.std(axis=1,ddof=1),1.,atol=1e-13)
    np.testing.assert_allclose(b.std(axis=1,ddof=1),2.,atol=1e-13)
    modes,fits=spectrum(a,delays=(12,),ranks=(4,12,24))
    assert len(fits)==3
    assert fits[-1]["fit_status"]=="excluded_embedding"
    assert any(abs(m["period_h"]-24)<1e-4 for m in modes)


def test_one_quality_accepted_mode_per_fit():
    f=dict(delay_h=12,rank=6)
    modes=pd.DataFrame([
        {**f,"mode_id":1,"period_h":24.,"growth_per_h":np.log(.899),
         "amplitude":5.,"loading_0":4.,"loading_1":3.},
        {**f,"mode_id":2,"period_h":24.4,"growth_per_h":np.log(.95),
         "amplitude":2.,"loading_0":1.,"loading_1":1.},
        {**f,"mode_id":3,"period_h":100.,"growth_per_h":np.log(.98),
         "amplitude":1.,"loading_0":1.,"loading_1":1.},
    ])
    chosen=select_modes(modes,24.)
    assert len(chosen)==1 and chosen.iloc[0].mode_id==2
    assert aggregate_modes(chosen,2)["nfits_found"]==1
    with pytest.raises(ValueError,match="Invalid"):
        select_modes(modes,24.,min_modulus=0)


def test_full_112_record_comparison_and_corruption_detection():
    cases=[]
    for system in ("HEMP19","HEMP27","REF118","HEMP_PRIMARY"):
        for window in ("W1","W2"):
            for source in ("exp","wufi"):
                for name,p in [
                    ("12h",12),("24h",24),("48h",48),("72h",72),
                    ("weekly",168),("2week",336),("monthly",720)
                ]:
                    case={"system":system,"window":window,"source":source,
                          "target":name,"target_h":p,
                          "nfits_total":40 if system=="HEMP_PRIMARY" else 39,
                          "nfits_found":12,"period_median_h":p,
                          "period_q10_h":p*.9,"period_q90_h":p*1.1,
                          "growth_median_per_h":-.02,"amp_median":.4}
                    for j in range(6):
                        case[f"loading_{j}_median"]=(
                            .1*(j+1) if (system=="HEMP_PRIMARY" or j<2)
                            else np.nan)
                    cases.append(case)
    frame=pd.DataFrame(cases)
    assert compare_archive(frame,frame)["all_numerical_fields_pass"]
    tampered=frame.copy()
    tampered.loc[0,"nfits_found"]=99
    assert not compare_archive(tampered,frame)["all_numerical_fields_pass"]
    with pytest.raises(ValueError,match="112"):
        compare_archive(frame.iloc[:-1],frame)
