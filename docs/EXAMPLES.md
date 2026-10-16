# Executable Python examples (synthetic only)

Use a virtual environment prepared as in [installation](INSTALLATION.md). Execute all commands from the repository root on `WUFI_python_tools`.

## Example 1 — Make an hourly climate file

```powershell
python -m python_tools.examples.make_synthetic_inputs --out-dir demo_outputs
python python_tools/wac_from_audit.py demo_outputs/synthetic_wac_audit.csv demo_outputs/synthetic_climate.wac
```

The generator creates an 8-day synthetic meteorological audit containing a labelled interior daylight radiation gap. The `pvlib` script reconstructs the missing GHI from same-clock-hour neighbouring observations and writes `WUFI®_WAC_02` with the eight expected fields `TIME TA HREL ISGH ISD WD WS PMSL`. The fixture deliberately does not represent physical weather. Do not attach the generated WAC to a real scientific WUFI simulation.

## Example 2 — Diagnose a driven daily signal

```powershell
python -m python_tools.examples.run_modal_example --out-dir demo_outputs
```

This generates deterministic synthetic forcing and response signals and writes:

- `synthetic_multiscale.csv`: slow/event/fast RMSE and amplitude comparison;
- `synthetic_window_robustness.csv`: 3×3 cutoff sensitivity grid;
- `synthetic_impulse_response.csv`: 72-hour delay-DMDc impulse trajectory;
- `synthetic_modal_summary.json`: DMD eigenvalues, delay-DMD eigenvalues and impulse-response summary.

## Example 3 — Inspect methods directly

```python
from python_tools.multiscale import split_bands
from python_tools.dmd import exact_dmd, delay_dmd
from python_tools.dmdc import fit_delay_dmdc

# User-supplied, quality-controlled, equally spaced hourly arrays required.
# DMD: shape (channels, time steps)
# DMDc: shape (time steps, state/control channels), aligned and standardized deliberately.
```

The existing `python_tools/README.md` provides the complete API usage. Python synthetic smoke tests are invoked with `python -m pytest -q python_tools/tests`; they do not validate scientific equivalence to historical measured data.
