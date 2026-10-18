"""Scientific Phase B: HODMD mode sensitivity and chronological DMDc holdout.

Not the historical DMDc selection/normalization procedure. This protocol uses
60% train/20% validation/20% untouched test, no future test-set scaling,
teacher-forced one-step prediction, and paired moving-block loss resampling.
It does not demonstrate causal impulse responses or autonomous rollouts.
"""
from __future__ import annotations
import argparse, json
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.linalg import solve
from python_tools.wxf_subset import raw_sensor_samples
from python_tools.replay_phase4_multiscale import WINDOWS, buck_saturation_pa, centered_hourly_medians, model_series
from python_tools.hodmd_historical_replay import spectrum, select_modes

SENSORS = {
    "HEMP27": "sensor_hempcrete_27.wxf.bin",
    "HEMP19": "sensor_hempcrete_19.wxf.bin",
    "HEMP42": "sensor_hempcrete_42.wxf.bin",
    "HEMP18": "sensor_hempcrete_18.wxf.bin",
    "REF118": "sensor_reference_118.wxf.bin",
}
RIDGE_GRID = (.001, .01, .1, 1., 10., 100.)

def moving_block_loss_ratio_ci(model_sq, persistence_sq, *,
                               block_hours=24, draws=200, seed=20261018):
    a,b = np.asarray(model_sq,float),np.asarray(persistence_sq,float)
    if a.ndim != 1 or a.shape != b.shape or len(a)<2*block_hours or not np.isfinite(a).all() or not np.isfinite(b).all():
        raise ValueError("Need finite paired losses with at least two blocks")
    rng=np.random.default_rng(seed); n=len(a)
    starts=np.arange(n-block_hours+1); ratios=[]
    for _ in range(draws):
        picks=rng.choice(starts,size=int(np.ceil(n/block_hours)),replace=True)
        idx=np.concatenate([np.arange(i,i+block_hours) for i in picks])[:n]
        if b[idx].mean()<=0:continue
        ratios.append(np.sqrt(a[idx].mean()/b[idx].mean()))
    if len(ratios)<.95*draws:raise ValueError("Bootstrap persistence denominator degenerate")
    return {"block_hours":block_hours,"draws":draws,
            "rmse_ratio_p025_p975":np.quantile(ratios,[.025,.975]).tolist(),
            "fraction_ratio_below_1":float(np.mean(np.asarray(ratios)<1))}

def holdout_dmdc(x,u,p=12,*,train_fraction=.6,validation_fraction=.2):
    x,u=np.asarray(x,float),np.asarray(u,float)
    if x.ndim!=2 or u.ndim!=2 or len(x)!=len(u) or not np.isfinite(x).all() or not np.isfinite(u).all():
        raise ValueError("Aligned complete [time,channels] arrays needed")
    if not(0<train_fraction<1 and 0<validation_fraction<1 and train_fraction+validation_fraction<1):
        raise ValueError("Invalid chronological split")
    n=len(x); k1=int(n*train_fraction); k2=int(n*(train_fraction+validation_fraction))
    if k1<max(80,3*p) or k2-k1<24 or n-k2<144:raise ValueError("Insufficient train/validation/72h-bootstrap test rows")
    xs=x[:k1].std(axis=0); us=u[:k1].std(axis=0)
    if min(xs.min(),us.min())<=0:raise ValueError("Constant training channel")
    xn=(x-x[:k1].mean(axis=0))/xs;un=(u-u[:k1].mean(axis=0))/us
    design=np.asarray([np.r_[xn[t-p+1:t+1][::-1].ravel(),un[t]]
                        for t in range(p-1,n-1)])
    target=xn[p:]; time=np.arange(p-1,n-1)
    train=time<k1;val=(time>=k1)&(time<k2);test=time>=k2
    X=design[train];Y=target[train]
    rhs=X.T@Y; gram=X.T@X
    scores=[]
    for ridge in RIDGE_GRID:
        beta=solve(gram+ridge*np.eye(X.shape[1]),rhs,assume_a="pos")
        mse=float(np.mean((design[val]@beta-target[val])**2))
        scores.append((mse,ridge,beta))
    _,ridge,beta=min(scores,key=lambda a:(a[0],a[1]))
    err=(design[test]@beta-target[test])**2
    baseline=(xn[time[test]]-target[test])**2
    return {"train_rows":int(train.sum()),"validation_rows":int(val.sum()),"test_rows":int(test.sum()),
            "selected_ridge":float(ridge),
            "test_rmse_std":float(np.sqrt(err.mean())),
            "persistence_test_rmse_std":float(np.sqrt(baseline.mean())),
            "model_over_persistence_rmse_ratio":float(np.sqrt(err.mean()/baseline.mean())),
            "per_state_rmse_std":np.sqrt(err.mean(axis=0)).tolist(),
            "block_bootstrap_24h":moving_block_loss_ratio_ci(err.mean(axis=1),baseline.mean(axis=1),block_hours=24),
            "block_bootstrap_72h":moving_block_loss_ratio_ci(err.mean(axis=1),baseline.mean(axis=1),block_hours=72)}

def hodmd_24h_sensitivity(x):
    state=np.asarray(x,float)
    normalized=(state-state.mean(axis=0))/state.std(axis=0,ddof=1)
    modes,fits=spectrum(normalized.T)
    valid=sum(z["fit_status"]=="valid_fit" for z in fits)
    catalog=pd.DataFrame(modes,columns=["delay_h","rank","mode_id","period_h","growth_per_h","amplitude"])
    points=[]
    for threshold in (.88,.9,.92):
        for factor in (1.25,1.30,1.35):
            selected=select_modes(catalog,24.,factor=factor,min_modulus=threshold) if len(catalog) else catalog
            points.append({"min_modulus":threshold,"period_factor":factor,
                "accepted":len(selected),"valid_fits":valid,
                "fraction":len(selected)/valid if valid else None,
                "median_period_h":float(selected.period_h.median()) if len(selected) else None})
    return {"valid_fits":valid,"positive_modes":len(catalog),"grid":points,
            "accepted_min":min(z["accepted"] for z in points),
            "accepted_max":max(z["accepted"] for z in points)}

def prepare_sensor(raw,hours):
    data=centered_hourly_medians(raw,hours)
    state=np.column_stack((data["T"],buck_saturation_pa(data["T"])*data["RH"]/100))
    if not np.isfinite(state).all():raise ValueError("Missing hourly sensor record")
    return state

def run(raw_root,meteo_csv,model_t=None,model_rh=None):
    meteorology=pd.read_csv(meteo_csv,parse_dates=["TIME_UTC"]).set_index("TIME_UTC")
    raw={k:raw_sensor_samples(raw_root/name) for k,name in SENSORS.items()}
    result={"method":"60/20/20 teacher-forced chronological holdout; training-only centering","sensors":{}}
    for sensor,frame in raw.items():
        rows=[]
        for window,start,end in WINDOWS:
            hours=pd.date_range(start,end,freq="h")
            state=prepare_sensor(frame,hours);m=meteorology.reindex(hours)
            outpv=buck_saturation_pa(m.temp_out)*m.humidity_out/100
            inpv=buck_saturation_pa(m.temp_in)*m.humidity_in/100
            forcing=np.column_stack((m.temp_out,outpv,m.solar_radiation,m.wind_speed,m.temp_in,inpv))
            if not np.isfinite(forcing).all():raise ValueError("Missing forcing values")
            models={}
            for lag in (6,12,24):
                for policy,channels in (("outpv_only",(1,)),("full",tuple(range(6)))):
                    models[f"p{lag}_{policy}"]=holdout_dmdc(state,forcing[:,channels],lag)
            rows.append({"window":window,"n_hours":len(hours),
                         "dmdc_holdout":models,"hodmd_sensitivity":hodmd_24h_sensitivity(state)})
        result["sensors"][sensor]=rows
    if model_t is not None and model_rh is not None:
        T=model_series(model_t); RH=model_series(model_rh); rows=[]
        for window,start,end in WINDOWS:
            hours=pd.date_range(start,end,freq="h");t=T.reindex(hours)
            state=np.column_stack((t,buck_saturation_pa(t)*RH.reindex(hours)/100))
            if not np.isfinite(state).all():raise ValueError("WUFI model gaps")
            rows.append({"window":window,"hodmd_sensitivity":hodmd_24h_sensitivity(state)})
        result["HEMP27_WUFI"]=rows
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("private_raw_root",type=Path);p.add_argument("private_meteo_csv",type=Path)
    p.add_argument("--model-temperature",type=Path);p.add_argument("--model-humidity",type=Path)
    p.add_argument("--output-json",type=Path,required=True)
    a=p.parse_args()
    x=run(a.private_raw_root,a.private_meteo_csv,a.model_temperature,a.model_humidity)
    a.output_json.parent.mkdir(parents=True,exist_ok=True)
    a.output_json.write_text(json.dumps(x,indent=2),encoding="utf-8")
    print(json.dumps({"sensors":len(x["sensors"]),"windows":len(WINDOWS)},indent=2))
if __name__=="__main__":main()
