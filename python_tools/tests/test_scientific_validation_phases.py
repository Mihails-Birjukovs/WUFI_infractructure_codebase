"""Public synthetic tests — no private REF/HEMP source data."""
import numpy as np
import pandas as pd
import pytest
from python_tools.scientific_phase_a import sensor_quality
from python_tools.scientific_phase_b import moving_block_loss_ratio_ci, holdout_dmdc,hodmd_24h_sensitivity
from python_tools.scientific_acceptance import determine_status,consolidate

def test_sensor_clean_monotonic():
    idx=pd.date_range("2026-01-01",periods=10,freq="3min")
    f=pd.DataFrame({"T":range(10),"RH":np.linspace(10,90,10)},index=idx)
    a=sensor_quality(f)
    assert a["source_records"]==10
    assert a["duplicate_timestamps"]==0
    assert a["humidity_outside_0_100_count"]==0
    assert a["median_sampling_interval_minutes"]==3

def test_sensor_flags_gap_and_oversaturation():
    idx=pd.to_datetime(["2026-01-01 00:00","2026-01-01 02:00","2026-01-01 02:03"])
    x=pd.DataFrame({"T":[2,3,4],"RH":[50,102,30]},index=idx)
    z=sensor_quality(x)
    assert z["gaps_over_60min"]==1
    assert z["humidity_outside_0_100_count"]==1

def test_paired_24h_block_bootstrap():
    a=np.full(400,.25);b=np.ones(400)
    r=moving_block_loss_ratio_ci(a,b,block_hours=24,draws=100)
    assert r["rmse_ratio_p025_p975"]==pytest.approx([.5,.5])
    assert r["fraction_ratio_below_1"]==1
    with pytest.raises(ValueError):
        moving_block_loss_ratio_ci(a[:30],b[:30],block_hours=24)

def test_dmdc_three_chronological_segments():
    rng=np.random.default_rng(4);n=900;u=rng.normal(size=(n,1))
    x=np.zeros((n,2))
    for i in range(n-1): x[i+1]=.75*x[i]+u[i,0]*np.array([.13,.07])
    z=holdout_dmdc(x,u,p=6)
    assert z["train_rows"]>z["validation_rows"]>0
    assert z["test_rows"]>144
    assert z["model_over_persistence_rmse_ratio"]<1
    assert len(z["block_bootstrap_72h"]["rmse_ratio_p025_p975"])==2

def test_hodmd_with_noisy_known_period():
    t=np.arange(420)
    z=np.column_stack((np.sin(2*np.pi*t/24),np.cos(2*np.pi*t/24)))
    z+=np.random.default_rng(18).normal(size=(420,2))*.02
    result=hodmd_24h_sensitivity(z)
    assert result["valid_fits"]==39
    assert len(result["grid"])==9
    assert result["accepted_min"]>=0

def test_wac_strict_fail_cannot_be_overridden():
    h={"rows":112,"all_numerical_fields_pass":True,
       "columns":{"nfits_found":{"compared":112,"matching":112}}}
    w={"rows":17520,"strict_parity":False,"radiation_hours_exceed_strict_tolerance":3}
    g=determine_status(h,w,{"sensors":{}},{"sensors":{}})
    assert g["historical_hodmd_numerical"]=="passed"
    assert g["historical_wac_strict"]=="failed"
    assert g["three_gap_scientific_exception"]=="not_approved"
    assert not consolidate(h,w,None,None)["ready_for_full_scientific_release"]
    h["columns"]["nfits_found"]["matching"]=111
    assert determine_status(h,w,None,None)["historical_hodmd_numerical"]=="failed"
