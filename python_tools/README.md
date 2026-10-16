# Python climate and dynamical diagnostics

Install from repository root:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r python_tools/requirements.txt
python -m pytest -q python_tools/tests
```

The tools are standalone scripts, **not WUFI or Mathematica dependencies**. They intentionally contain **no private REF/HEMP data**.

## WAC from an audited hourly climate CSV

```powershell
python -m python_tools.examples.make_synthetic_inputs --out-dir demo_outputs
python python_tools/wac_from_audit.py demo_outputs/synthetic_wac_audit.csv demo_outputs/synthetic_climate.wac
```

The CSV must contain `TIME,TA,HREL,WD,WS,PMSL,source_GHI,source_available`. TIME must be **continuous, sorted, hourly, timezone-naive and end-labelled using a single fixed UTC offset**. The climate fields follow WAC order: TA °C, HREL 0–1 fraction, ISGH/ISD W/m², wind WD degrees / WS m/s, and PMSL in the original WUFI project convention (verify pressure units with your WUFI version/source). `source_GHI` is global horizontal solar irradiance (W/m²); `source_available` is measured-source availability (0/1 or true/false).

The default historical coordinate is `--latitude 56.97 --longitude 24.17 --utc-offset-hours 2`. For a new physical site, override the two coordinates and confirm fixed-time convention:

```powershell
python python_tools/wac_from_audit.py audit.csv climate.wac --latitude 56.985411 --longitude 24.085193 --utc-offset-hours 2
```

The historical solar reconstruction deliberately used the former approximate coordinates, as documented in the report. The script zeros astronomical night and outside-source intervals, interpolates internal daylight GHI gaps from *bracketing same-clock-hour measured kt values*, then estimates diffuse irradiance via `pvlib.irradiance.erbs`. The file is written as Latin-1 WAC_02 with the eight columns `TIME TA HREL ISGH ISD WD WS PMSL`. Verify header, physical units, timestamp convention and imported values **in WUFI** before production use. Do not use blanket zero padding as a scientific substitute for missing station measurements.

## Multiscale residuals

```python
import pandas as pd
from python_tools.multiscale import band_metrics, cutoff_robustness

# Your previously quality-controlled *aligned hourly* timestamp-indexed series
sensor = pd.Series(...)
model = pd.Series(...)
metrics = band_metrics(sensor, model, slow_hours=72, event_hours=12)
robustness = cutoff_robustness(sensor, model)
```

Slow is a centered 72-hour rolling mean; event is centered 12-hour minus slow; fast is the original minus centered 12-hour. Metrics use pairwise nonmissing values only. Near-edge reduced windows and missing spans should be explicitly disclosed.

## DMD and delay DMD/HODMD

```python
from python_tools.dmd import exact_dmd, delay_dmd

# snapshots: array shape (measurement channels, successive uniform time steps)
dmd = exact_dmd(snapshots, rank=2, dt_hours=1)
hodmd = delay_dmd(snapshots, delays=12, rank=4, dt_hours=1)
```

Eigenvalues, complex frequencies, modes and first-snapshot amplitudes are returned. No built-in scaling or feature weighting is performed; provide a deliberate data normalization appropriate to state variables such as T and vapour pressure.

## Delay DMDc

```python
from python_tools.dmdc import fit_delay_dmdc, impulse_response, peak_and_memory

# x = standardized, uniform-hour states: shape (samples, state channels)
# u = standardized, uniform-hour forcing: shape (samples, forcing channels)
a, b = fit_delay_dmdc(x, u, p=12, ridge=1e-8)
response = impulse_response(a, b, p=12, n_state=x.shape[1], horizon=72)
summary = peak_and_memory(response, dt_hours=1)
```

The control-history simulation advances lagged inputs consistently; impulse peak/gain are expressed **in the chosen standardized input/state units**, not automatically in raw °C/%RH/W/m². Predictive association is not a causal experiment. Diagnose robustness across choices of delay depth and regularization before inferring pathways.

See [method provenance](../docs/PROVENANCE.md). The historical Phase-4 multiscale and DMDc temporary files were **not recovered**; current modules correspond to reconstructed report methods. The DMD/HODMD module is a newly introduced reference implementation.

## Butterworth multiscale method used in the archived Phase-4 analysis

The historical Phase-4 `analysis_method.json` specifies fourth-order zero-phase Butterworth filters at 12h/72h cutoffs, 240-hour minimum contiguous segments, and 72-hour edge trimming. The complementary `multiscale_butterworth.py` follows **that method class**, whereas `multiscale.py` follows the reconstructed centered-mean demonstration in Appendix I.3.

```python
from python_tools.multiscale_butterworth import butterworth_band_metrics

# Provide UTC-normalized hourly sensor and WUFI DatetimeIndex Series.
metrics = butterworth_band_metrics(sensor, model,
    slow_hours=72, event_hours=12, min_segment_hours=240, trim_hours=72)
```

The exact archived source and independent paired-series data-preparation are still required for historical numerical equivalence; two Butterworth implementations may differ in boundary and QC choices.

**Horizon-consistency detail:** internal daytime missing-hour GHI is rebuilt by interpolating clearness index and multiplying by extraterrestrial horizontal irradiance with the **same `min_cos_zenith=0.065` denominator** as `pvlib.irradiance.clearness_index`. This corrects a near-horizon inconsistency in the compact report listing. Astronomical-night hours are still assigned zero. This is an identified methodological refinement, not a claim of byte-identical historical reconstruction.
