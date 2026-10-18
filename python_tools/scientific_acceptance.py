"""REF/HEMP acceptance consolidation: strict, physical and application gates.

Reads only private aggregate JSON and optional local SHA-256 source
fingerprints. An unapproved 3-hour WAC tolerance NEVER passes strict parity.
A diagnostic report is not a publication release authorization.
"""
from __future__ import annotations
import argparse, hashlib, json, platform
from datetime import datetime, timezone
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
SCHEMA="refhemp-acceptance-v1"

def digest(path: Path) -> dict:
    p=Path(path);hash_=hashlib.sha256();total=0
    with p.open("rb") as f:
        while chunk:=f.read(1024*1024):
            hash_.update(chunk);total+=len(chunk)
    return {"basename":p.name,"size_bytes":total,"sha256":hash_.hexdigest()}

def determine_status(hodmd: dict | None,wac: dict | None,
                     phase_a: dict | None,phase_b: dict | None) -> dict:
    if hodmd is None:
        h="pending"
    elif (hodmd.get("rows")==112 and
          bool(hodmd.get("all_numerical_fields_pass",hodmd.get("all_numerical_fields_within_tolerance",False))) and
          all(x.get("matching",x.get("within_tolerance",-1))==x.get("compared",-2)
              for x in hodmd.get("columns",hodmd.get("fields",{})).values())):
        h="passed"
    else:h="failed"
    w=("pending" if wac is None else
       "passed" if wac.get("rows")==17520 and wac.get("strict_parity") is True
       else "failed")
    return {
        "historical_hodmd_numerical":h,
        "historical_wac_strict":w,
        "radiometer_plane_calibration":"pending_evidence",
        "three_gap_scientific_exception":"not_approved",
        "source_data_qc":"pending" if phase_a is None else "review_required",
        "method_sensitivity":"pending" if phase_b is None else "diagnostic_completed",
        "licensed_wufi_windows":"pending",
        "mathematica_on_windows":"pending",
    }

def environment() -> dict:
    libs={}
    for name in ("numpy","pandas","scipy","pvlib"):
        try:libs[name]=version(name)
        except PackageNotFoundError:libs[name]=None
    return {"python":platform.python_version(),"library_versions":libs}

def consolidate(hodmd,wac,phase_a,phase_b,*,sources=None,git_sha=None):
    status=determine_status(hodmd,wac,phase_a,phase_b)
    result={
        "schema":SCHEMA,"created_utc":datetime.now(timezone.utc).isoformat(),
        "source_commit":git_sha,"environment":environment(),
        "gates":status,
        "source_fingerprints":{key:digest(value) for key,value in sorted((sources or {}).items())},
        "scope":"Private aggregate results only; do not publish source timeseries or input hashes",
        "interpretation":{
            "hodmd":"Retrospective numerical benchmark; original-source identity not shown",
            "wac":"Strict WAC remains failed if any original archived radiation differs",
            "science":"Calibration and radiometer measurement plane not certified",
        },
        "checks":{
            "hodmd_archived_rows":hodmd.get("rows") if hodmd else None,
            "wac_audit_rows":wac.get("rows") if wac else None,
            "wac_radiation_mismatch_hours":wac.get("radiation_hours_exceed_strict_tolerance") if wac else None,
            "sensors_checked":len(phase_a.get("sensors",{})) if phase_a else None,
            "robustness_sensor_count":len(phase_b.get("sensors",{})) if phase_b else None,
        },
    }
    result["unresolved_gates"]=[k for k,v in status.items() if v not in ("passed","diagnostic_completed")]
    result["ready_for_full_scientific_release"]=not bool(result["unresolved_gates"])
    return result

def _read(path, nested=None):
    if path is None:return None
    z=json.loads(Path(path).read_text(encoding="utf-8"))
    return z.get(nested,z) if nested else z

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--hodmd-json",type=Path);p.add_argument("--wac-json",type=Path)
    p.add_argument("--phase-a-json",type=Path);p.add_argument("--phase-b-json",type=Path)
    p.add_argument("--fingerprint",action="append",default=[],help="LABEL=PRIVATE_FILE")
    p.add_argument("--git-sha");p.add_argument("--output-json",type=Path,required=True)
    a=p.parse_args();files={}
    for x in a.fingerprint:
        if "=" not in x:p.error("Use LABEL=FILE")
        label,path=x.split("=",1)
        if not label or label in files:p.error("Nonempty unique fingerprint labels required")
        files[label]=Path(path)
    report=consolidate(_read(a.hodmd_json,"hodmd"),_read(a.wac_json,"wac"),
                       _read(a.phase_a_json),_read(a.phase_b_json),
                       sources=files,git_sha=a.git_sha)
    a.output_json.parent.mkdir(parents=True,exist_ok=True)
    a.output_json.write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(json.dumps({"gates":report["gates"],
        "ready_for_full_scientific_release":report["ready_for_full_scientific_release"]},indent=2))
    # Diagnostic output may include pending gates. Release CI must require
    # ready_for_full_scientific_release=True before publishing a final tag.
if __name__=="__main__":main()
