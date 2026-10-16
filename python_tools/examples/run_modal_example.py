"""Demonstrate all modal and multiscale APIs with deterministic synthetic data."""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from python_tools.dmd import exact_dmd, delay_dmd
from python_tools.dmdc import fit_delay_dmdc, impulse_response, peak_and_memory
from python_tools.multiscale import band_metrics, cutoff_robustness


def run(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    n = 24 * 20
    t = np.arange(n)
    forcing = np.sin(2 * np.pi * t / 24) + 0.1 * np.sin(2 * np.pi * t / 73)
    response = np.zeros(n)
    for i in range(1, n):
        response[i] = 0.85 * response[i - 1] + 0.15 * forcing[i - 1]
    model = response * 0.7 + 0.15
    metrics = band_metrics(pd.Series(response), pd.Series(model))
    metrics.to_csv(out_dir / "synthetic_multiscale.csv", index=False)
    cutoff_robustness(pd.Series(response), pd.Series(model)).to_csv(
        out_dir / "synthetic_window_robustness.csv", index=False
    )
    snapshots = np.vstack([response, forcing])
    plain = exact_dmd(snapshots, rank=2)
    delay = delay_dmd(snapshots, delays=12, rank=6)
    a, b = fit_delay_dmdc(response[:, None], forcing[:, None], p=12, ridge=1e-6)
    ir = impulse_response(a, b, p=12, n_state=1, horizon=72)
    pd.DataFrame({"hour": np.arange(len(ir)), "response": ir[:, 0]}).to_csv(
        out_dir / "synthetic_impulse_response.csv", index=False
    )
    summary = {
        "plain_dmd_discrete_eigenvalues": [
            [float(z.real), float(z.imag)] for z in plain["eigenvalues"]
        ],
        "delay_dmd_discrete_eigenvalues": [
            [float(z.real), float(z.imag)] for z in delay["eigenvalues"]
        ],
        "delay_dmdc_response": peak_and_memory(ir),
        "data_notice": "Fully synthetic; no historical REF/HEMP physical inference.",
    }
    (out_dir / "synthetic_modal_summary.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )
    print("Wrote synthetic multiscale and modal diagnostics to", out_dir)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--out-dir", type=Path, default=Path("demo_outputs"))
    run(p.parse_args().out_dir)
