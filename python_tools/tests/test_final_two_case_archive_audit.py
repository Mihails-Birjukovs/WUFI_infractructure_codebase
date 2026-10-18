"""Synthetic regression tests for WAC/WXF-independent REF/HEMP archive auditor.

No private REF/HEMP measurements or original WXF data are used in CI.
"""
import numpy as np
import pandas as pd
import pytest
from python_tools import final_two_case_archive_audit as audit


def test_nearest_rank_quantile_and_core_metrics():
    x=np.linspace(0.,2.,10)
    error=np.asarray([-20,-3,-2,-1,0,2,5,6,9,20.])
    output=audit.core_metrics(x,x+error)
    assert output["ResidualP05"]==-20
    assert output["ResidualP95"]==20
    assert output["MeanBias_WUFI_minus_sensor"]==pytest.approx(1.6)
    with pytest.raises(ValueError):
        audit.core_metrics([1,2],[3])


def test_timestamp_lag_with_actual_missing_hour_span():
    rng=np.random.default_rng(18)
    hours=pd.date_range("2026-03-01",periods=360,freq="h")
    sensor=rng.standard_normal(360)
    model=np.r_[rng.standard_normal(3),sensor[:-3]]
    included=np.asarray([i for i in range(360)
                         if i not in set(range(85,135)) and i not in {189,270}])
    lag,corr=audit.lag_by_utc(hours[included],sensor[included],model[included])
    assert lag==3 and corr>.999


def test_duplicate_dates_not_accepted():
    t=pd.to_datetime(["2026-01-01","2026-01-01","2026-01-02"])
    with pytest.raises(ValueError,match="timestamps"):
        audit.lag_by_utc(t,[1,2,3],[2,3,4])


def test_full_and_post_exclusion_synthetic(monkeypatch,tmp_path):
    rng=np.random.default_rng(12)
    t=pd.date_range("2026-01-01",periods=100,freq="h")
    sensor=rng.normal(size=100)
    model=.75*sensor+1+rng.normal(scale=.1,size=100)
    monkeypatch.setattr(audit,"extract_paired",
        lambda _:({"GroupFolderName":"S01_TEST","Variable":"Temperature"},t,sensor,model))
    def archived(index):
        x,y=sensor[index],model[index]
        lag,corr=audit.lag_by_utc(t[index],x,y)
        return {**audit.core_metrics(x,y),"PairCount":len(x),
                "BestLagHours":lag,"BestLagCorrelation":corr,
                "BestLagAtSearchBoundaryQ":abs(lag)==24}
    full=archived(slice(None))
    mask=t>=pd.Timestamp("2026-01-01 23:00")
    after=archived(mask)
    after["StartUTC"]="2026-01-01T23:00:00Z"
    align={"GroupFolderName":"S01_TEST","PassQ":True,"PairedPointCount":100}
    result=audit.audit_comparison(tmp_path/"fake.wxf",full,after,align)
    assert result["lag_tests_passed"]==2
    assert result["metric_fields_checked"]==24
    assert result["max_archive_numeric_difference"]<1e-12
    tampered=dict(full);tampered["RMSE"]+=.2
    with pytest.raises(ValueError,match="RMSE"):
        audit.audit_comparison(tmp_path/"fake.wxf",tampered,after,align)


def test_postprocessor_dewpoint_and_layer_contract(monkeypatch,tmp_path):
    def fake_reader(path):
        path=str(path)
        locations=14 if "/REF/" in path else 17
        t=np.full((locations,3187),12.5)
        if path.endswith("relative_humidity.wxf.bin"):
            return np.full((locations,3187),70.)
        if path.endswith("temperature.wxf.bin"):
            return t
        if path.endswith("dew_point.wxf.bin"):
            gamma=np.log(.7)+(18.678-t/234.5)*(t/(257.14+t))
            return 257.14*gamma/(18.678-gamma)
        if path.endswith("layer_water_content.wxf.bin"):
            return np.ones((12,3187))
        if path.endswith("total_water_content.wxf.bin"):
            return np.ones((1,3187))
        raise AssertionError(path)
    monkeypatch.setattr(audit,"postprocessor_matrix",fake_reader)
    result=audit.audit_postprocessor(tmp_path)
    assert result["verified_dewpoint_count"]==98797
    assert result["by_wall"]["REF"]["layer_water_content_series"]==12
    assert result["by_wall"]["HEMP"]["total_water_integral_from_layers_verified"] is False
