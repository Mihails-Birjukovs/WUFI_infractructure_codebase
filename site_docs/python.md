# Python infrastructure: WUFI automation, climate and diagnostics

The Python tools branch contains software from Mihails Birjukovs and Valters Ribickis. On **20 October 2026, Valters Ribickis added three WUFI-facing Python packages** alongside the established climate and multiscale/modal utilities. The [Python branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools) and [Mathematica branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools) are separate maintained trees.

## New WUFI-facing Python packages

| Package | What it does | Scope and limitations |
| --- | --- | --- |
| [Batch Launcher Automated v1.0](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/WUFI_Batch_Launcher_Automated_v1.0/README.md) | Parses embedded WUFI XML and prepares a Windows batch file | Does **not execute** WUFI or generate Mathematica manifests; can use first-case metadata for multi-case projects |
| [Data Post-Processor Automated v1.0](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/WUFI_Data_Post_Processor_Automated_v1.0/README.md) | ASC to temperature/RH/dew-point/water-content CSV and JPG plots | Not Mathematica's five-WXF outputs; ASC-to-case pairing is positional; regenerates derived directories |
| [Wall Construction Optimisation](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/WUFI_Wall_Construction_Optimisation/README.md) | One parameter-sweep and one adaptive-thickness script, each invoking WUFI | Local heuristic, static XML-based U-value assumptions and moisture criteria require review; may replace candidate folders |

**Environment:** Python 3.10+; Windows and licensed WUFI command-line executable for the WUFI-running scripts. Plotting and optimisation tools require NumPy, pandas and **Matplotlib**, which is not currently in the branch's shared requirements file; SciPy is optional for density plots. Launcher preparation uses the Python standard library.

**Safety:** replace local workstation paths, preserve originals and use isolated disposable working directories. These scripts can overwrite batch files and recursively clear derived outputs. Verify ASC columns/units and project/case identity before reporting results. Plots labelled mould risk do not calculate a biological growth index.

**Acceptance:** existing Python CI on 3.11–3.13 compiles the new scripts and runs the earlier synthetic suite, **not** new WUFI-specific integration tests. Their detailed README files describe local review exercises, but those tests have not been committed. [Issues #28–#35](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/issues) request Valters's assessment before any tests or behavior are changed.

## Existing climate and diagnostic utilities

The pre-existing climate/multiscale/DMD tools remain usable with synthetic fixtures independently of WUFI; they are not the newly introduced Windows execution toolchain.

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

## Other Python modules

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

## Research citations and contributor credit

See [Credits & contributors](credits.md) for software and instrumentation roles and [Research & references](references.md) for the [pvlib project's preferred paper](https://doi.org/10.21105/joss.05994), the Erbs irradiance model, and the original DMD/HODMD/DMDc method papers. Method citations do not imply that code from their authors was imported.
