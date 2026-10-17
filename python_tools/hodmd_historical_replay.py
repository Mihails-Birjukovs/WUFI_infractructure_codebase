#!/usr/bin/env python3
"""Retrospective source-WXF reproduction of original REF/HEMP HODMD.

Historical source code is lost. The spectral operator and acceptance rules
below are independently inferred by matching the frozen 112-row archive.
No private measurements, eigenmodes or individual results belong in GitHub.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.linalg import eigh
from python_tools.hodmd_rule_recovery import DELAY_ORDERS, TRUNCATION_RANKS, TARGET_PERIODS
from python_tools.replay_phase4_multiscale import (
    WINDOWS, buck_saturation_pa, centered_hourly_medians, model_series)
from python_tools.wxf_subset import raw_sensor_samples

SENSORS = ("HEMP27","HEMP19","HEMP42","HEMP18","REF118")
PRIMARY_ORDER = ("HEMP27","HEMP42","HEMP18")
FIT_KEYS = ("system","window","source","delay_h","rank")
GROUP_KEYS = ("system","window","source","target")
PERIOD_FACTOR = 1.3
MIN_EIGENVALUE_MODULUS = 0.9
FIELDS = ("period_median_h","period_q10_h","period_q90_h",
          "growth_median_per_h","amp_median",
          *(f"loading_{i}_median" for i in range(6)))


def standardized_pair(experiment, model):
    """Independently centered, using experimental *sample SD* (ddof=1)."""
    x,y=np.asarray(experiment,float),np.asarray(model,float)
    if x.ndim!=2 or x.shape!=y.shape or x.shape[1]<75 or (
        not np.isfinite(x).all()) or (not np.isfinite(y).all()):
        raise ValueError("Require complete aligned [features, hours] matrices")
    sd=x.std(axis=1,ddof=1)
    if (sd<=0).any():
        raise ValueError("Zero-variance experimental state")
    return ((x-x.mean(axis=1,keepdims=True))/sd[:,None],
            (y-y.mean(axis=1,keepdims=True))/sd[:,None])


def source_states(manifest):
    """Build HEMP_PRIMARY=[T27,pv27,T42,pv42,T18,pv18] and three controls."""
    if set(manifest)!=set(SENSORS):
        raise ValueError(f"Manifest requires exactly {SENSORS}")
    original={}
    for sensor in SENSORS:
        spec=manifest[sensor]
        raw=raw_sensor_samples(spec["sensor_wxf"])
        tm=model_series(Path(spec["model_temperature_wxf"]))
        rh=model_series(Path(spec["model_humidity_wxf"]))
        if not tm.index.equals(rh.index):
            raise ValueError(f"{sensor} WUFI temperature/humidity grids disagree")
        obs=centered_hourly_medians(raw,tm.index)
        original[sensor]=(
            pd.DataFrame({"T":obs["T"],
                          "pv":buck_saturation_pa(obs["T"])*obs["RH"]/100}),
            pd.DataFrame({"T":tm,"pv":buck_saturation_pa(tm)*rh/100}),
        )
    result={}
    for label,start,end in WINDOWS:
        index=pd.date_range(start,end,freq="h")
        raw_pairs={
            sensor:(ex.reindex(index).to_numpy(float).T,
                    wo.reindex(index).to_numpy(float).T)
            for sensor,(ex,wo) in original.items()
        }
        for sensor in ("HEMP27","HEMP19","REF118"):
            a,b=standardized_pair(*raw_pairs[sensor])
            result[(sensor,label,"exp")]=a
            result[(sensor,label,"wufi")]=b
        six_exp=np.vstack([raw_pairs[s][0] for s in PRIMARY_ORDER])
        six_wufi=np.vstack([raw_pairs[s][1] for s in PRIMARY_ORDER])
        a,b=standardized_pair(six_exp,six_wufi)
        result[("HEMP_PRIMARY",label,"exp")]=a
        result[("HEMP_PRIMARY",label,"wufi")]=b
    return result


def spectrum(state, delays=DELAY_ORDERS, ranks=TRUNCATION_RANKS):
    """Cached real exact delay-DMD spectra: independent SVD per delay.

    Covariance eigendecomposition is cached across the eight ranks.
    This is equivalent to a truncated full-snapshot SVD at checked
    numerical precision. Count invalid rank==embedding as excluded.
    """
    state=np.asarray(state,float)
    if state.ndim!=2 or not np.isfinite(state).all() or state.shape[1]<75:
        raise ValueError("Invalid finite HODMD source")
    channels,n=state.shape
    modes=[];fits=[]
    for delay in delays:
        if not 2<=delay<n-2:
            raise ValueError("Invalid HODMD delay")
        H=np.concatenate([state[:,i:n-delay+i+1] for i in range(delay)],axis=0)
        x,y=H[:,:-1],H[:,1:]
        gram=x@x.T
        cross=y@x.T
        dim=gram.shape[0]
        nranks=min(dim,max(ranks))
        eig,u=eigh(gram,subset_by_index=(dim-nranks,dim-1))
        eig,u=eig[::-1],u[:,::-1]
        for rank in ranks:
            selector={"delay_h":delay,"rank":rank}
            if rank<1 or rank>=delay*channels:
                fits.append({**selector,"fit_status":"excluded_embedding"})
                continue
            if eig[rank-1]<=1e-12*eig[0]:
                fits.append({**selector,"fit_status":"failed_numerical_rank"})
                continue
            basis=u[:,:rank];inv=1/eig[:rank]
            reduced=(basis.T@cross@basis)*inv[None,:]
            eigenvalues,vectors=np.linalg.eig(reduced)
            phi=((cross@basis)*inv[None,:])@vectors
            amplitudes=np.linalg.lstsq(phi,H[:,0],rcond=None)[0]
            nmodes=0
            for j,lam in enumerate(eigenvalues):
                angle=np.angle(lam);absolute=abs(lam)
                if not(np.isfinite(angle) and angle>1e-12 and
                       np.isfinite(absolute) and absolute>0):
                    continue
                period=2*np.pi/angle
                if not np.isfinite(period):
                    continue
                loading=np.abs(phi[:channels,j]*amplitudes[j])
                modes.append({
                    **selector,"mode_id":j,
                    "period_h":float(period),
                    "growth_per_h":float(np.log(absolute)),
                    "amplitude":float(np.linalg.norm(loading)),
                    **{f"loading_{k}":float(z) for k,z in enumerate(loading)},
                })
                nmodes+=1
            fits.append({**selector,"fit_status":"valid_fit",
                         "positive_frequency_modes":nmodes})
    return modes,fits


def select_modes(modes, target_h, *, factor=PERIOD_FACTOR,
                 min_modulus=MIN_EIGENVALUE_MODULUS):
    """One nearest-log-period positive mode per fit after common gates."""
    if target_h<=0 or factor<=1 or not 0<min_modulus<=1:
        raise ValueError("Invalid period/modulus gate")
    x=modes.loc[
        modes["period_h"].between(target_h/factor,target_h*factor)
        & (modes["growth_per_h"]>=np.log(min_modulus))
    ].copy()
    x["log_distance"]=np.abs(np.log(x.period_h/target_h))
    return (x.sort_values(["log_distance","amplitude","mode_id"],
                          ascending=[True,False,True])
            .drop_duplicates(["delay_h","rank"]).reset_index(drop=True))


def aggregate_modes(selected, nfeatures):
    if selected.empty:
        raise ValueError("No matched oscillatory modes")
    results={
        "nfits_found":int(len(selected)),
        "period_median_h":float(selected.period_h.median()),
        "period_q10_h":float(selected.period_h.quantile(.1)),
        "period_q90_h":float(selected.period_h.quantile(.9)),
        "growth_median_per_h":float(selected.growth_per_h.median()),
        "amp_median":float(selected.amplitude.median()),
    }
    for k in range(nfeatures):
        results[f"loading_{k}_median"]=float(selected[f"loading_{k}"].median())
    return results


def replay(manifest):
    """Generate 112 target rows and corresponding PRIVATE full mode catalog."""
    states=source_states(manifest)
    rows,all_modes,all_fits=[],[],[]
    for (system,window,source),state in states.items():
        modes,fits=spectrum(state)
        nvalid=sum(v["fit_status"]=="valid_fit" for v in fits)
        expected=40 if system=="HEMP_PRIMARY" else 39
        if nvalid!=expected:
            raise ValueError("Unexpected valid-fit inventory")
        selector={"system":system,"window":window,"source":source}
        all_modes.extend({**selector,**x} for x in modes)
        all_fits.extend({**selector,**x} for x in fits)
        frame=pd.DataFrame(modes)
        for target,hours in TARGET_PERIODS.items():
            chosen=select_modes(frame,hours)
            rows.append({**selector,"target":target,"target_h":hours,
                         "nfits_total":expected,
                         **aggregate_modes(chosen,state.shape[0])})
    if len(rows)!=112:
        raise ValueError("Unexpected HODMD target inventory")
    return pd.DataFrame(rows),pd.DataFrame(all_modes),pd.DataFrame(all_fits)


def compare_archive(replayed, archived):
    """Strict count parity and explicit numerical tolerances for ALL fields."""
    if replayed.duplicated(list(GROUP_KEYS)).any() or (
            archived.duplicated(list(GROUP_KEYS)).any()):
        raise ValueError("Duplicate HODMD group")
    joined=replayed.merge(archived,on=list(GROUP_KEYS),
                          suffixes=("_new","_old"),validate="one_to_one")
    if len(joined)!=112 or len(joined)!=len(replayed) or len(joined)!=len(archived):
        raise ValueError("Expected complete 112-row archival comparison")
    summary={"rows":112,"columns":{},"all_numerical_fields_pass":True,
             "historical_source_recovered":False}
    for col in ("nfits_found","nfits_total","target_h",*FIELDS):
        if col not in replayed or col not in archived:
            raise ValueError(f"Missing archival field {col}")
        a=pd.to_numeric(joined[col+"_new"],errors="coerce").to_numpy(float)
        b=pd.to_numeric(joined[col+"_old"],errors="coerce").to_numpy(float)
        valid=np.isfinite(b)
        if not np.isfinite(a[valid]).all():
            raise ValueError(f"Nonfinite replay values: {col}")
        error=np.abs(a[valid]-b[valid])
        tolerance=(0 if col in ("nfits_found","nfits_total","target_h")
                   else 1e-5 if col.startswith("period_") else 1e-8)
        pass_count=int(np.sum(error<=tolerance))
        summary["columns"][col]={
            "compared":int(valid.sum()),"matching":pass_count,
            "max_abs_difference":float(error.max()) if len(error) else None,
            "tolerance":tolerance,
        }
        summary["all_numerical_fields_pass"] &= pass_count==len(error)
    summary["inference"]={
        "period_window_factor":PERIOD_FACTOR,
        "eigenvalue_modulus_min":MIN_EIGENVALUE_MODULUS,
        "selection":"nearest absolute log-period distance",
        "normalization":"experimental sample SD, ddof=1",
        "six_channel_order":PRIMARY_ORDER,
        "original_script":"unavailable; rules recovered retrospectively",
    }
    return summary


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("private_manifest",type=Path)
    p.add_argument("archived_stability_csv",type=Path)
    p.add_argument("--output-dir",type=Path,required=True)
    args=p.parse_args()
    manifest=json.loads(args.private_manifest.read_text(encoding="utf-8"))
    rows,modes,fits=replay(manifest)
    report=compare_archive(rows,pd.read_csv(args.archived_stability_csv))
    args.output_dir.mkdir(parents=True,exist_ok=True)
    rows.to_csv(args.output_dir/"hodmd_112_replay_PRIVATE.csv",index=False)
    modes.to_csv(args.output_dir/"hodmd_full_modes_PRIVATE.csv",index=False)
    fits.to_csv(args.output_dir/"hodmd_fit_status_PRIVATE.csv",index=False)
    (args.output_dir/"hodmd_parity_summary.json").write_text(
        json.dumps(report,indent=2),encoding="utf-8")
    print(json.dumps(report,indent=2))
    if not report["all_numerical_fields_pass"]:
        raise SystemExit(1)


if __name__=="__main__":
    main()
