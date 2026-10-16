import numpy as np
import pandas as pd
from python_tools.replay_phase4_multiscale import (
    buck_saturation_pa, centered_hourly_medians, metrics, _band_values
)


def test_buck_and_archive_standard_deviation_policy():
    assert np.isclose(buck_saturation_pa(0),611.21)
    a=np.array([0.,1.,2.,3.])
    assert metrics(a,a)["sensor_sd"] == np.std(a,ddof=0)
    assert metrics(a,a)["rmse"] == 0


def test_historical_cutoff_bands_reconstruct():
    t=np.arange(600)
    signal=np.sin(2*np.pi*t/24)+0.2*np.sin(2*np.pi*t/168)
    parts=_band_values(signal,72,12)
    np.testing.assert_allclose(
        parts["slow"]+parts["diurnal_synoptic"]+parts["event"],
        signal[72:-72], atol=1e-10)
    assert len(parts["slow"])==456


def test_raw_centered_hourly_median_includes_edge_samples():
    raw=pd.DataFrame({"T":[1.,2.,5.,8.],"RH":[60.,70.,75.,80.]},
        index=pd.to_datetime([
            "2026-01-01 00:30","2026-01-01 00:45",
            "2026-01-01 01:30","2026-01-01 02:01"]))
    out=centered_hourly_medians(raw,pd.date_range("2026-01-01 01:00",
                                               periods=2,freq="h"))
    assert out["T"].iloc[0] == 2.
    assert out["T"].iloc[1] == 8.
