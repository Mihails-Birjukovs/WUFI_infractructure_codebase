"""Generate synthetic hourly climate and dynamics fixtures (NOT scientific data)."""
import argparse
from pathlib import Path
import numpy as np
import pandas as pd


def build(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    n = 24 * 8
    hours = np.arange(n)
    times = pd.date_range("2026-03-01 01:00", periods=n, freq="h")
    # Daylight pulses are synthetic and deliberately not a physical solar model.
    local_hour = times.hour.to_numpy()
    ghi = 300 * np.maximum(0, np.sin(np.pi * (local_hour - 6) / 12))
    flag = np.ones(n, dtype=int)
    flag[24 * 4 + 12] = 0  # one internal midday gap, bracketed by other days
    audit = pd.DataFrame({
        "TIME": times, "TA": 4 + 5 * np.sin(2 * np.pi * hours / 24),
        "HREL": 0.70 + 0.15 * np.cos(2 * np.pi * hours / 24),
        "WD": np.full(n, 180.0), "WS": np.full(n, 2.0),
        "PMSL": np.full(n, 1013.25), "source_GHI": ghi,
        "source_available": flag,
    })
    audit.to_csv(out_dir / "synthetic_wac_audit.csv", index=False)
    print("Synthetic WAC audit:", out_dir / "synthetic_wac_audit.csv")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--out-dir", type=Path, default=Path("demo_outputs"))
    build(p.parse_args().out_dir)
