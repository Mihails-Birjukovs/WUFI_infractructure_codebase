# Python climate and diagnostic tools

The [WUFI Python branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools) contains standalone analysis tools; it does not bundle the Mathematica production packages. Its README and per-module source are authoritative for the interface in your selected commit.

## Set up and test

~~~powershell
git clone --branch WUFI_python_tools https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase.git WUFI_python
cd WUFI_python
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r python_tools/requirements.txt
python -m pytest -q python_tools/tests
~~~

The published Python CI matrix targets 3.11–3.13 with synthetic fixtures. Passing synthetic regression tests **does not** establish historical-data or WUFI application equivalence.

## Implemented modules

| Module | Purpose | Lineage and interpretation |
| --- | --- | --- |
| [wac_from_audit.py](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/wac_from_audit.py) | Audited hourly CSV to WAC_02 climate forcing using pvlib/Erbs | Adaptation of retained research implementation; full private replay and three horizon exceptions qualified |
| [multiscale.py](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/multiscale.py) | Centered moving-window slow/event/fast bands | Report reconstruction; **not** the historical Butterworth method |
| [multiscale_butterworth.py](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/multiscale_butterworth.py) | Fourth-order Butterworth phase-4-like bands | New reference for archived method class |
| [dmd.py](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/dmd.py) | Exact DMD and delay DMD/HODMD-style analysis | New reference implementation |
| [dmdc.py](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/dmdc.py) | Ridge-regularized delay DMDc with input-history propagation | Reconstructed research method with independent archival comparisons |

## Synthetic first run

~~~powershell
python -m python_tools.examples.make_synthetic_inputs --out-dir demo_outputs
python python_tools/wac_from_audit.py demo_outputs/synthetic_wac_audit.csv demo_outputs/synthetic_climate.wac
python -m python_tools.examples.run_modal_example --out-dir demo_outputs
~~~

Do not run synthetic WAC data through a real REF/HEMP model as production forcing. For real data, establish sensor/channel mapping, time alignment and observed forcing provenance before computing model residuals.

## Detailed authoritative guides

- [Python module API and input contracts](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/README.md)
- [Python installation and test instructions](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/INSTALLATION.md)
- [Methods and provenance](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/PROVENANCE.md)
- [Archival reproduction catalog](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/README.md)

For interpretation and release gates, see [validation](validation.md) and [modal diagnostics](modal.md).
