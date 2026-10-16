# WUFI infrastructure: batch simulation, hygrothermal post-processing and diagnostics

Research tools for preparing and launching **WUFI Pro** simulations, parsing exported results, comparing them with monitored temperature/RH data, reconstructing WAC climate files, and analysing residual dynamics. The repository combines validated **Wolfram Language / Mathematica** production releases with Python reproducibility utilities.

> **Scope:** This is companion research software, not WUFI itself. A separately licensed WUFI Pro installation and project-specific inputs are required for actual simulations. Nothing in this repository executes WUFI on GitHub Actions.

## What is included?

| Workflow | Tool / version | Main entry point |
| --- | --- | --- |
| Extract WUFI project XML | Windows PowerShell batch wrapper | [`extract_all_wufi_xml.bat`](extract_all_wufi_xml.bat) |
| Build a case manifest, batch runs and ASC exports | Mathematica, Batch Launcher v1.0 | [Launcher notebook](Mathematica_tools/WUFI%20Batch%20Launcher%20Automated%20v1/WUFI%20Batch%20Launcher%20Automated%20v1.nb) |
| Validate/process ASC outputs to WXF and plots | Mathematica, Data Post-Processor v1.1.1 | [Release notes](Mathematica_tools/WUFI%20Data-Post%20Processor%20Automated%20v1.1.1/README.md) |
| Sensor QC, hourly aggregation, WUFI-to-sensor comparison | Mathematica, Sensor Comparison v1.2.0 | [Release notes](Mathematica_tools/WUFI%20VS%20Sensor%20Comparison%20Automated%20v1.2.0/README.md) |
| Solar reconstruction / WUFI `.wac` writing | Python with `pvlib` | [Python tools](python_tools/README.md) |
| Multiscale residual metrics | Python, reconstructed reference method | [Python tools](python_tools/README.md) |
| DMD, delay DMD / HODMD and delay DMDc | Python, research reference implementations | [Python tools](python_tools/README.md) |

## Getting started

1. Read [installation and configuration](docs/INSTALLATION.md), especially the WUFI/Mathematica versions and absolute project paths.
2. Follow the [end-to-end pipeline](docs/WORKFLOWS.md) for WUFI `.w6p` + XML -> batch -> ASC -> WXF -> sensor comparison.
3. Run the [small examples](docs/EXAMPLES.md) (synthetic Python example data; private monitoring/model inputs are not bundled).
4. Check [method provenance and limitations](docs/PROVENANCE.md) before interpreting reconstructed DMDc/HODMD/multiscale results as evidence.

The Mathematica release folders have **their own release-specific READMEs** and validation records. They remain authoritative for the exact frozen release behaviour. This root guide documents how the tools fit together.

### Quick Python start

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r python_tools/requirements.txt
python -m pytest -q python_tools/tests
python -m python_tools.examples.make_synthetic_inputs --out-dir demo_outputs
python python_tools/wac_from_audit.py demo_outputs/synthetic_wac_audit.csv demo_outputs/synthetic_climate.wac
python -m python_tools.examples.run_modal_example --out-dir demo_outputs
```

The example generation script uses **synthetic data**, not the REF/HEMP measurements. Do not use the resulting synthetic WAC as a physical model boundary condition.

## Public repository / private research data

The repository contains scripts, LUT/LIM curve resources and historical release metadata; it does **not** contain the full REF & HEMP WUFI projects, meteorological source/audit tables, raw MongoDB exports, canonical sensor-registry artifacts or production simulation results. Supply these separately from an authorized research archive. Do not commit third-party/private records, sensor identifiers tied to people, credentials, raw monitoring JSON/MX/WXF, or licensed WUFI project datasets without a publication clearance review.

## Scientific context

The motivating campaigns are the REF and HEMP wall assemblies described in the *WUFI Unified Report, draft v1.4* (2026), including the locked case labels `Wall_REF_P5_L125_CV100_M200_W0_V070_A00` and `Wall_hemp_P5_CORR_M200_S125_LT1000_W0_V070_A00`. These are *example selectors*, not files distributed here.

**Platform used for the production Mathematica tools:** Windows, Wolfram Mathematica 12.1, and WUFI Pro 6.5 for the referenced study. Different environments require independent validation.

## License

See [LICENSE](LICENSE). WUFI, Wolfram Mathematica and any externally sourced reference data retain their respective licenses.
