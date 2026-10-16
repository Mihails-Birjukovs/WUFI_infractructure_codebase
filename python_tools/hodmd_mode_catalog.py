#!/usr/bin/env python3
"""Produce a PRIVATE full-eigenspectrum audit from the original REF/HEMP WXF.

This is a transparent *reference real-valued delay DMD*, NOT the original
lost HODMD algorithm and NOT the separate paper-style analytic fbDMD.

Outputs two private CSVs: full mode catalog and fit-validity inventory.
Never commit source WXF, hourly series, modes or original-model arrays.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd

from python_tools.dmd import delay_dmd
from python_tools.hodmd_rule_recovery import (
    DELAY_ORDERS, TRUNCATION_RANKS, admissible_configs,
)
from python_tools.replay_phase4_multiscale import (
    WINDOWS, buck_saturation_pa, centered_hourly_medians, model_series,
)
from python_tools.wxf_subset import raw_sensor_samples

SINGLE_SENSOR_TARGETS = ("HEMP19", "HEMP27", "REF118")


def normalize_pair(sensor: np.ndarray, wufi: np.ndarray
                   ) -> tuple[np.ndarray, np.ndarray]:
    """Normalize channels as in the historical REF/HEMP report."""
    a, b = np.asarray(sensor, float), np.asarray(wufi, float)
    if a.shape != b.shape or a.ndim != 2 or a.shape[0] < 1 or \
       not np.isfinite(a).all() or not np.isfinite(b).all():
        raise ValueError("Both series must be finite, shaped [channels, hours]")
    sd = a.std(axis=1)
    if np.any(sd <= 0):
        raise ValueError("Nonvarying experimental state channel")
    return (
        (a-a.mean(axis=1, keepdims=True))/sd[:, None],
        (b-b.mean(axis=1, keepdims=True))/sd[:, None],
    )


def catalog_single_fit(states: np.ndarray, delay: int, rank: int
                      ) -> list[dict]:
    """All positive-frequency modes from real delay DMD for one fit.

    Amplitude is norm of physical first-delay-block reconstruction, not
    necessarily the original HODMD paper's amplitude convention.
    """
    n_features = states.shape[0]
    if rank >= delay*n_features:
        raise ValueError("Proposed strict rank must be below embedding dimension")
    fit = delay_dmd(states, delays=delay, rank=rank)
    eigen = fit["eigenvalues"]
    modes = fit["modes"]
    amplitudes = fit["amplitudes"]
    records = []
    for k, e in enumerate(eigen):
        theta = np.angle(e)
        magnitude = abs(e)
        if not (np.isfinite(theta) and theta > 1e-12 and
                np.isfinite(magnitude) and magnitude > 0):
            continue
        period = float(2*np.pi/theta)
        first_block = modes[:n_features, k]
        loadings = np.abs(first_block * amplitudes[k])
        records.append({
            "mode_id": int(k),
            "period_h": period,
            "growth_per_h": float(np.log(magnitude)),
            "amplitude": float(np.linalg.norm(loadings)),
            "eigenvalue_abs": float(magnitude),
            "eigenvalue_real": float(np.real(e)),
            "eigenvalue_imag": float(np.imag(e)),
            **{f"loading_{j}": float(v) for j, v in enumerate(loadings)},
        })
    return records


def run(manifest: dict, *,
        delays: tuple[int,...] = DELAY_ORDERS,
        ranks: tuple[int,...] = TRUNCATION_RANKS,
        strict_embedding: bool = True
        ) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Recompute every proposed 2-channel fit and retain the full spectra.

    No six-channel HEMP_PRIMARY is silently manufactured; it needs a
    separately documented and authorized multichannel state export.
    """
    if set(manifest) != set(SINGLE_SENSOR_TARGETS):
        raise ValueError(f"Required exactly {SINGLE_SENSOR_TARGETS} source mappings")
    modes_all, fit_all = [], []
    for system in SINGLE_SENSOR_TARGETS:
        spec = manifest[system]
        raw = raw_sensor_samples(spec["sensor_wxf"])
        tm = model_series(spec["model_temperature_wxf"])
        hm = model_series(spec["model_humidity_wxf"])
        if not tm.index.equals(hm.index):
            raise ValueError(f"{system}: mismatched T/RH WUFI time grids")
        observed = centered_hourly_medians(raw, tm.index)
        exp_t = observed["T"]
        exp_pv = buck_saturation_pa(exp_t)*observed["RH"]/100.
        wufi_pv = buck_saturation_pa(tm)*hm/100.
        for window, begin, finish in WINDOWS:
            grid = pd.date_range(begin, finish, freq="h")
            exp = np.vstack([exp_t.reindex(grid),exp_pv.reindex(grid)])
            wufi = np.vstack([tm.reindex(grid),wufi_pv.reindex(grid)])
            exp, wufi = normalize_pair(exp, wufi)
            for source, state in (("exp",exp),("wufi",wufi)):
                for delay in delays:
                    for rank in ranks:
                        selectors = {
                            "system": system,"window":window,"source":source,
                            "delay_h":delay,"rank":rank,
                        }
                        if strict_embedding and rank >= delay*state.shape[0]:
                            fit_all.append({**selectors, "fit_status": "excluded_embedding",
                                            "positive_frequency_modes":0})
                            continue
                        try:
                            entries=catalog_single_fit(state,delay,rank)
                        except (ValueError,np.linalg.LinAlgError):
                            fit_all.append({**selectors, "fit_status": "failed_fit",
                                            "positive_frequency_modes":0})
                            continue
                        fit_all.append({**selectors, "fit_status":"valid_fit",
                                        "positive_frequency_modes":len(entries)})
                        modes_all.extend({**selectors,**mode} for mode in entries)
    return pd.DataFrame(modes_all),pd.DataFrame(fit_all)


def main() -> None:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("private_sensor_manifest",type=Path)
    p.add_argument("--output-dir",type=Path,required=True)
    args=p.parse_args()
    manifest=json.loads(args.private_sensor_manifest.read_text(encoding="utf-8"))
    modes,fit_status=run(manifest)
    args.output_dir.mkdir(parents=True,exist_ok=True)
    modes.to_csv(args.output_dir/"hodmd_private_full_modes.csv",index=False)
    fit_status.to_csv(args.output_dir/"hodmd_private_fit_status.csv",index=False)
    counts=fit_status.groupby(
        ["system","window","source","fit_status"]).size().to_dict()
    print(json.dumps({
        "total_fit_attempts":len(fit_status),"modes":len(modes),
        "fit_groups":[
            {"system":k[0],"window":k[1],"source":k[2],
             "status":k[3],"count":int(v)}
            for k,v in counts.items()
        ],
        "qualification": (
            "REAL delay-DMD candidate eigenspectrum, not the original "
            "Phase-4 HODMD operator or mode acceptance policy"
        ),
    },indent=2))


if __name__ == "__main__":
    main()
