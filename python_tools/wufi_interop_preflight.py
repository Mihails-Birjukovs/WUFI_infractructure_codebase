"""Read-only WAC/WXF structural preflight, not a WUFI/Mathematica application test."""
from pathlib import Path
import argparse
import json
import numpy as np
import pandas as pd
from python_tools.wac_from_audit import WAC_COLUMNS
from python_tools.replay_phase4_multiscale import model_series

def inspect_wac(path):
    lines=Path(path).read_text(encoding="latin-1").splitlines()
    if len(lines)<14 or not lines[0].startswith("WUFI®_WAC_02"):
        raise ValueError("Not WUFI WAC_02")
    count=int(lines[9].split("\t")[0])
    fields=int(lines[10].split("\t")[0])
    if count!=len(lines)-12 or count<2:
        raise ValueError("WAC header data-line count mismatch")
    if fields!=8 or tuple(lines[11].split("\t"))!=WAC_COLUMNS:
        raise ValueError("WAC ordered columns mismatch")
    tz=float(lines[7].split("\t")[0]); step=float(lines[8].split("\t")[0])
    if (tz,step)!=(2.,1.):
        raise ValueError("Historical fixed UTC+2 hourly convention mismatch")
    df=pd.read_csv(path,sep="\t",skiprows=12,header=None,names=list(WAC_COLUMNS),encoding="latin-1")
    df["TIME"]=pd.to_datetime(df["TIME"],errors="raise")
    ts=df["TIME"]
    if ts.isna().any() or ts.dt.tz is not None or ts.duplicated().any() or not ts.is_monotonic_increasing or not ts.diff().iloc[1:].eq(pd.Timedelta(hours=1)).all():
        raise ValueError("WAC timestamp/cadence mismatch")
    x=df.drop(columns="TIME").apply(pd.to_numeric,errors="raise")
    if not np.isfinite(x.to_numpy()).all():
        raise ValueError("Nonfinite climate")
    if not x.HREL.between(0,1).all():
        raise ValueError("WAC RH must be a 0..1 fraction")
    if ((x.ISGH<0)|(x.ISD<0)|(x.ISD>x.ISGH+1e-7)|(x.WS<0)|(x.PMSL<=0)).any():
        raise ValueError("Invalid physical units/ranges")
    return {"format":"WUFI_WAC_02","rows":count,"columns":list(WAC_COLUMNS),
        "fixed_utc_offset_h":tz,"hourly":True,
        "first_hour":str(ts.iloc[0]),"last_hour":str(ts.iloc[-1]),
        "wuFI_pro_import_verified":False}

def inspect_wufi_pair(temperature,rh):
    t=model_series(temperature);h=model_series(rh)
    if not t.index.equals(h.index):
        raise ValueError("WUFI T/RH timestamps differ")
    if len(t)<24 or not np.isfinite(t.to_numpy()).all() or not np.isfinite(h.to_numpy()).all() or not h.between(0,100).all():
        raise ValueError("WUFI values invalid or RH not in percent")
    return {"format":"WXF_v8_read_only_subset","rows":len(t),
        "first_utc":str(t.index[0]),"last_utc":str(t.index[-1]),
        "hourly":bool(t.index.to_series().diff().iloc[1:].eq(pd.Timedelta(hours=1)).all()),
        "aligned":True,"mathematica_12_1_desktop_verified":False}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for arg in ("--wac","--temperature-wxf","--humidity-wxf","--out-json"):
        p.add_argument(arg,type=Path,required=True)
    a=p.parse_args()
    result={"wac":inspect_wac(a.wac),"wufi":inspect_wufi_pair(a.temperature_wxf,a.humidity_wxf),
        "preflight":"passed","real_WUFI_Pro_import":"not_executed"}
    a.out_json.parent.mkdir(parents=True,exist_ok=True)
    a.out_json.write_text(json.dumps(result,indent=2),encoding="utf-8")
    print(json.dumps(result,indent=2))

if __name__=="__main__":
    main()
