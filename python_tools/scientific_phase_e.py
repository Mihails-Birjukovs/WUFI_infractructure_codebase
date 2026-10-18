"""Exploratory REF/HEMP: calibration scenarios, HODMD AR1 nulls, recursive DMDc.

No calibration certificate, physical periodicity claim, or operational weather
forecast follows from these *retrospective* diagnostics. Private data stay local.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.linalg import solve
from python_tools.scientific_phase_b import SENSORS, RIDGE_GRID, prepare_sensor
from python_tools.wxf_subset import raw_sensor_samples
from python_tools.replay_phase4_multiscale import WINDOWS, buck_saturation_pa, centered_hourly_medians
from python_tools.hodmd_historical_replay import spectrum, select_modes

REGISTRY_ROLES={
 "HEMP27":("primary","conditional",.5),
 "HEMP19":("diagnostic_excluded","diagnostic_excluded",0.),
 "HEMP42":("primary","primary",1.),
 "HEMP18":("primary","primary",1.),
 "REF118":("primary","conditional",.5),
}

def vapor_pressure_scenario(T,RH,temperature_offset_C=.3,rh_offset_percentage_points=2.):
    """Hypothetical bounded window-wide offsets, not an uncertainty CI."""
    t=np.asarray(T,float);r=np.asarray(RH,float)
    if t.shape!=r.shape or not np.isfinite(t).all() or not np.isfinite(r).all() or (r<0).any() or (r>100).any() or temperature_offset_C<0 or rh_offset_percentage_points<0:
        raise ValueError("Invalid temperature/RH scenario")
    sat=buck_saturation_pa
    ref=sat(t)*r/100
    lo=sat(t-temperature_offset_C)*np.maximum(0,r-rh_offset_percentage_points)/100
    hi=sat(t+temperature_offset_C)*np.minimum(100,r+rh_offset_percentage_points)/100
    if (lo>ref+1e-8).any() or (hi<ref-1e-8).any():raise ValueError("Unbracketed reference")
    return ref,lo,hi

def calibration_scenario(frame,temperature_offset_C=.3,rh_offset_percentage_points=2.):
    pv,lo,hi=vapor_pressure_scenario(frame.T,frame.RH,temperature_offset_C,rh_offset_percentage_points)
    return {"uncertainty_certified":False,"assumed_temperature_offset_C":temperature_offset_C,
      "assumed_RH_offset_pp":rh_offset_percentage_points,
      "median_pv_fullwidth_Pa":float(np.median(hi-lo)),
      "median_relative_fullwidth_percent":float(100*np.median((hi-lo)/np.maximum(1,pv)))}

def daily_mode_bias_sensitivity(frame,temperature_offset_C=.3,rh_offset_percentage_points=2.):
    t=np.asarray(frame["T"],float);r=np.asarray(frame["RH"],float)
    cases=[]
    for dt,dr in ((0.,0.),(-temperature_offset_C,-rh_offset_percentage_points),
                  (-temperature_offset_C,rh_offset_percentage_points),
                  (temperature_offset_C,-rh_offset_percentage_points),
                  (temperature_offset_C,rh_offset_percentage_points)):
        zt=t+dt;zr=np.clip(r+dr,0,100)
        x=np.column_stack((zt,buck_saturation_pa(zt)*zr/100))
        x=(x-x.mean(0))/x.std(0,ddof=1)
        modes,fits=spectrum(x.T,delays=(24,48),ranks=(6,10,16))
        count=len(select_modes(pd.DataFrame(modes),24.)) if modes else 0
        cases.append({"T_bias_C":dt,"RH_bias_pp":dr,"accepted":count})
    return {"assumptions_not_certified":True,"cases":cases,
      "count_min":min(c["accepted"] for c in cases),
      "count_max":max(c["accepted"] for c in cases)}

def ar1_surrogate(state,seed):
    """Stationary red-noise model, preserves neither trend nor full spectrum."""
    x=np.asarray(state,float)
    if x.ndim!=2 or len(x)<100 or not np.isfinite(x).all():raise ValueError("Invalid AR1 input")
    z=(x-x.mean(0))/x.std(0,ddof=1)
    phi=np.clip((z[1:]*z[:-1]).sum(0)/np.maximum(1e-9,(z[:-1]**2).sum(0)),-.995,.995)
    residual=z[1:]-phi*z[:-1]
    cov=np.atleast_2d(np.cov(residual,rowvar=False))+np.eye(x.shape[1])*1e-10
    white=np.random.default_rng(seed).multivariate_normal(np.zeros(x.shape[1]),cov,size=len(x)+300)
    out=np.zeros_like(white)
    for i in range(1,len(out)):out[i]=phi*out[i-1]+white[i]
    return out[300:]

def daily_hodmd_surrogates(state,draws=99,seed=20261018):
    if draws<3:raise ValueError("Need at least three simulations")
    x=np.asarray(state,float)
    normalized=(x-x.mean(0))/x.std(0,ddof=1)
    modes,fits=spectrum(normalized.T,delays=(24,48),ranks=(6,10,16))
    def count(candidates):
        return len(select_modes(pd.DataFrame(candidates),24.)) if candidates else 0
    obs=count(modes);null=[]
    for j in range(draws):
        sim=ar1_surrogate(x,seed+j+1)
        sim=(sim-sim.mean(0))/sim.std(0,ddof=1)
        candidates,_=spectrum(sim.T,delays=(24,48),ranks=(6,10,16))
        null.append(count(candidates))
    return {"observed":obs,"valid_fits":sum(f["fit_status"]=="valid_fit" for f in fits),
      "null_draws":draws,"null_counts":null,"null_median":float(np.median(null)),
      "null_max":int(np.max(null)),"empirical_upper_tail_fraction":float(
       (1+sum(v>=obs for v in null))/(draws+1)),
      "null_condition":"stationary_correlated_AR1_not_spectrally_matched",
      "physical_significance_p_value":False}

def recursive_path(history,weather,beta,p):
    """Explicit free-running recursion: NO future actual sensor states."""
    init=np.asarray(history,float);u=np.asarray(weather,float)
    b=np.asarray(beta,float)
    if init.ndim!=2 or len(init)!=p or u.ndim!=2 or b.shape!=(p*init.shape[1]+u.shape[1],init.shape[1]):
        raise ValueError("Incorrect recursive forecast input dimensions")
    queue=list(init.copy());out=[]
    for control in u:
        state=np.r_[np.asarray(queue[-p:][::-1]).reshape(-1),control]@b
        if not np.isfinite(state).all() or np.max(np.abs(state))>1e10:break
        out.append(state);queue.append(state)
    return np.asarray(out).reshape((-1,init.shape[1]))

def recursive_holdout(states,controls,p=12,horizons=(1,6,12,24,48,72),stride=12):
    """60/20/20, ridge chosen on validation TARGET times only."""
    x=np.asarray(states,float);u=np.asarray(controls,float)
    if x.ndim!=2 or u.ndim!=2 or len(x)!=len(u) or not np.isfinite(x).all() or not np.isfinite(u).all():
        raise ValueError("Require aligned finite hourly arrays")
    n=len(x);t1=int(.6*n);t2=int(.8*n)
    if p<1 or t1<4*p or n-t2<max(horizons)+20 or stride<1:raise ValueError("Invalid holdout dimensions")
    stdx=x[:t1].std(0);stdu=u[:t1].std(0)
    if min(stdx.min(),stdu.min())<=1e-12:raise ValueError("Constant training data")
    x=(x-x[:t1].mean(0))/stdx;u=(u-u[:t1].mean(0))/stdu
    pred=np.asarray([np.r_[x[k-p+1:k+1][::-1].reshape(-1),u[k]] for k in range(p-1,n-1)])
    y=x[p:];t=np.arange(p-1,n-1)
    train=t+1<t1;validation=(t+1>=t1)&(t+1<t2)
    design=pred[train];response=y[train];gram=design.T@design;rhs=design.T@response
    choices=[]
    for ridge in RIDGE_GRID:
        beta=solve(gram+ridge*np.eye(pred.shape[1]),rhs,assume_a="pos")
        choices.append((float(np.mean((pred[validation]@beta-y[validation])**2)),ridge,beta))
    _,ridge,beta=min(choices,key=lambda a:(a[0],a[1]))
    errors={h:[] for h in horizons};persistent={h:[] for h in horizons}
    origins=range(t2,n-max(horizons),stride)
    diverged=0
    for start in origins:
        forecast=recursive_path(x[start-p+1:start+1],u[start:start+max(horizons)],beta,p)
        if len(forecast)<max(horizons):diverged+=1
        for h in horizons:
            if len(forecast)>=h:
                errors[h].append((forecast[h-1]-x[start+h])**2)
                persistent[h].append((x[start]-x[start+h])**2)
    metrics={}
    for h in horizons:
        a=np.asarray(errors[h]);b=np.asarray(persistent[h])
        metrics[str(h)]={"n_origins":len(a),
         "rmse_ratio_vs_issuance_persistence":float(np.sqrt(a.mean()/b.mean())) if len(a) and b.mean()>0 else None,
         "rmse_per_channel_original_units":(np.sqrt(a.mean(0))*stdx).tolist() if len(a) else None}
    return {"selected_ridge":float(ridge),"origins":len(origins),"diverged_origins":diverged,
      "test_start_hour_index":t2,"no_future_state_injected":True,
      "future_weather_policy":"observed_weather_oracle_not_operational",
      "horizons":metrics}

def run(raw_root,meteorology,sensors=("HEMP27","HEMP18","REF118"),draws=99):
    met=pd.read_csv(meteorology,parse_dates=["TIME_UTC"]).set_index("TIME_UTC")
    output={"status":"exploratory_not_calibrated_or_prospective","sensors":{}}
    for sensor in sensors:
        raw=raw_sensor_samples(Path(raw_root)/SENSORS[sensor]);cases=[]
        for label,start,end in WINDOWS:
            hours=pd.date_range(start,end,freq="h")
            med=centered_hourly_medians(raw,hours)
            frame=pd.DataFrame({"T":med["T"],"RH":med["RH"]})
            states=prepare_sensor(raw,hours)
            m=met.reindex(hours)
            pv=buck_saturation_pa(m.temp_out)*m.humidity_out/100
            forcings={"pv_only":np.asarray(pv).reshape(-1,1),
                      "T_pv_solar":np.column_stack((m.temp_out,pv,m.solar_radiation))}
            forecasts={name:recursive_holdout(states,f) for name,f in forcings.items()}
            cases.append({"window":label,"sensor_registry_roles":REGISTRY_ROLES[sensor],
             "calibration_scenario":calibration_scenario(frame),
             "hodmd_static_offset_sensitivity":daily_mode_bias_sensitivity(frame),
             "hodmd_AR1_surrogate":daily_hodmd_surrogates(states,draws=draws),
             "DMDc_recursive_oracle":forecasts})
        output["sensors"][sensor]=cases
    return output

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("private_raw_root",type=Path)
    p.add_argument("private_meteo_hourly_csv",type=Path)
    p.add_argument("--sensors",nargs="+",choices=list(SENSORS),
                   default=["HEMP27","HEMP18","REF118"])
    p.add_argument("--draws",type=int,default=99)
    p.add_argument("--output-json",type=Path,required=True)
    args=p.parse_args()
    report=run(args.private_raw_root,args.private_meteo_hourly_csv,
               sensors=args.sensors,draws=args.draws)
    args.output_json.parent.mkdir(parents=True,exist_ok=True)
    args.output_json.write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(json.dumps({"evaluated_sensors":list(report["sensors"])},indent=2))
if __name__=="__main__":main()
