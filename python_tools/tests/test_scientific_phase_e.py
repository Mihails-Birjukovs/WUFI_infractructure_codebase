"""Public synthetic checks; no private measurements in CI."""
import numpy as np
import pandas as pd
import pytest
from python_tools.scientific_phase_e import (
    REGISTRY_ROLES, vapor_pressure_scenario, calibration_scenario,
    daily_mode_bias_sensitivity, ar1_surrogate, daily_hodmd_surrogates,
    recursive_path, recursive_holdout,
)

def test_bounded_vapour_pressure_and_registry_roles():
    f=pd.DataFrame({"T":[5.,20.,30.],"RH":[0.,80.,100.]})
    ref,lo,hi=vapor_pressure_scenario(f["T"],f["RH"])
    assert np.all(lo<=ref) and np.all(ref<=hi) and lo[0]==0
    assert calibration_scenario(f)["uncertainty_certified"] is False
    assert calibration_scenario(f)["median_pv_fullwidth_Pa"]>0
    assert REGISTRY_ROLES["HEMP19"][2]==0.
    with pytest.raises(ValueError):
        vapor_pressure_scenario([2.,5.],[101.,80.])

def test_ar1_surrogate_reproducible():
    x=np.random.default_rng(45).standard_normal((360,2)).cumsum(0)
    a=ar1_surrogate(x,seed=3);b=ar1_surrogate(x,seed=3)
    np.testing.assert_array_equal(a,b)
    with pytest.raises(ValueError):ar1_surrogate(x[:12],seed=3)

def test_surrogate_and_bias_scans_run_on_periodic_synthetic():
    t=np.arange(390);rng=np.random.default_rng(31)
    f=pd.DataFrame({
        "T":3+np.sin(2*np.pi*t/24)+rng.normal(0,.01,len(t)),
        "RH":70+2*np.cos(2*np.pi*t/24)+rng.normal(0,.01,len(t))})
    s=daily_mode_bias_sensitivity(f)
    assert len(s["cases"])==5 and s["assumptions_not_certified"]
    x=np.column_stack((f["T"],f["RH"]))
    a=daily_hodmd_surrogates(x,draws=3)
    assert a["null_draws"]==3 and len(a["null_counts"])==3
    assert a["physical_significance_p_value"] is False
    assert 0<a["empirical_upper_tail_fraction"]<=1

def test_recursive_path_does_not_consume_future_sensor_values():
    history=np.array([[1.,2.],[2.,1.]])
    weather=np.array([[1.],[3.],[4.]])
    coeff=np.zeros((5,2))
    coeff[:2]=np.eye(2)*.8
    coeff[-1,0]=.2
    a=recursive_path(history,weather,coeff,2)
    mutated=weather.copy();mutated[-1]=200.
    b=recursive_path(history,mutated,coeff,2)
    assert a.shape==(3,2)
    np.testing.assert_array_equal(a[:2],b[:2])
    assert a[-1,0]!=b[-1,0]
    with pytest.raises(ValueError):
        recursive_path(history,weather,np.zeros((3,2)),2)

def test_holdout_synthetic_stable_dynamics():
    n=1100;u=np.random.default_rng(4).standard_normal((n,1))
    x=np.zeros((n,2))
    for i in range(1,n):x[i]=.7*x[i-1]+u[i-1]*np.array([.12,-.04])
    z=recursive_holdout(x,u,p=4)
    assert z["no_future_state_injected"]
    assert z["diverged_origins"]==0
    assert z["horizons"]["72"]["n_origins"]>1
    assert z["horizons"]["24"]["rmse_ratio_vs_issuance_persistence"]<1

def test_invalid_forecast_inputs():
    with pytest.raises(ValueError):
        recursive_holdout(np.ones((100,2)),np.ones((100,1)))
