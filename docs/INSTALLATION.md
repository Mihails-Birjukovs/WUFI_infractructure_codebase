# Python installation, input conventions and source requirements

This guide applies to the **`WUFI_python_tools` branch only**. For validated production WUFI/Mathematica notebooks, see the separate [`WUFI_mathematica_tools` branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools).

## Environment

Recommended Python 3.10+ and Windows PowerShell (Linux/macOS use their shell's virtual-environment activation):

```powershell
git clone --branch WUFI_python_tools https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase.git
cd WUFI_infractructure_codebase
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r python_tools/requirements.txt
python -m pytest -q python_tools/tests
```

Dependencies: NumPy, pandas, pvlib; pytest for regression tests. Version constraints are specified in `python_tools/requirements.txt`. No network or source archive is needed for *synthetic* examples. Do not conclude that the entire scientific pipeline is validated merely because tests pass.

## Audited WAC climate input

`wac_from_audit.py` takes an already-aggregated, approved hourly CSV containing:

| Column | Meaning |
| --- | --- |
| `TIME` | End-labelled local **fixed-standard-time** timestamp, `YYYY-MM-DD HH:MM:SS`; continuous hourly timestamps, no DST jumps |
| `TA` | Air temperature, °C |
| `HREL` | Relative humidity, dimensionless fraction [0, 1] |
| `WD`, `WS` | Wind direction (degrees) and nonnegative wind speed (m/s) |
| `PMSL` | Mean sea-level pressure: preserve and verify WUFI/importer units |
| `source_GHI` | Measured/audited hourly **global horizontal** solar irradiance (W/m²); not diffuse irradiance |
| `source_available` | True/False or 1/0 flag for a valid measured `source_GHI` |

The script interprets each timestamp as the **end of its hourly interval**; solar geometry uses its midpoint (minus 30 min). It uses a *fixed* UTC+2 reference by default; do **not** substitute DST-adjusting `Europe/Riga` wall-clock labels without consistent conversion first.

For the historical REF/HEMP reconstruction, default solar coordinates are approximately 56.97° N / 24.17° E, distinct from the physical source-report coordinates 56.985411° N / 24.085193° E. Override latitude and longitude only for a deliberate new analysis.

The workflow applies astronomical-night zeroing, historical out-of-source-span zero padding, and same-clock-hour, *bracketed* clearness-index interpolation through internal daytime source gaps. That last operation requires valid measured daytime values both before and after the missing hour. WUFI WAC_02 has eight columns: `TIME TA HREL ISGH ISD WD WS PMSL`; output uses Latin-1 encoding. Verify all fields and interpreted units using your WUFI installation before model use.

**Data-quality warning:** historic outside-span zero padding is included for reproducibility, not as recommended missing-weather infilling. Independent measured/reanalysis sources are preferred when filling incomplete scientific campaigns.

## Time series for DMD/DMDc/multiscale

Start with physically aligned, QC-approved equally spaced hourly sensor/model data exported from the separately maintained Mathematica comparison workflow. For `exact_dmd` and `delay_dmd`, inputs are arrays `(channels, samples)`. For `fit_delay_dmdc`, inputs are arrays `(samples, channels)` with equal sample counts for state and forcing. For multiscale, provide time-indexed pandas Series of sensor and corresponding WUFI predictions; missing values are paired by timestamp in the metric calculation.

Decide intentionally whether to standardize states, normalize units, detrend, omit outliers, or interpolate gaps. None of the algorithms infers sampling gaps or physical scaling from raw data, and their gain/lag units follow the input scaling.

## Supported boundaries

Standalone synthetic examples do not require commercial WUFI or Mathematica. Real WUFI projects, production sensor registries, raw MongoDB records, historical WAC audit tables and calibrated simulation results must be obtained from an authorized research archive and are **not in the public repository**.

See [examples](EXAMPLES.md), [workflow](WORKFLOWS.md), and [provenance](PROVENANCE.md).
