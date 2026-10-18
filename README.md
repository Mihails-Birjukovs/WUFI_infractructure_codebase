# WUFI infrastructure — Python tools

**Active branch:** `WUFI_python_tools`. This branch contains Python tools for preparing climate inputs and analysing experimental/WUFI time-series discrepancies. It intentionally **does not contain the production Mathematica packages**; those live on [`WUFI_mathematica_tools`](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools), the repository's default branch.

## Python tools

| Tool | Purpose | Status |
| --- | --- | --- |
| [`wac_from_audit.py`](python_tools/wac_from_audit.py) | Reconstruct end-labelled WUFI WAC_02 climate from audited hourly data using `pvlib`/Erbs | Adapted from retained REF/HEMP report implementation |
| [`multiscale.py`](python_tools/multiscale.py) | Slow, event and fast time-scale decomposition and comparison metrics | Reconstructed moving-window report method (not equivalent to archived Butterworth results) |
| [`multiscale_butterworth.py`](python_tools/multiscale_butterworth.py) | Fourth-order zero-phase Butterworth method from archived Phase-4 settings | New reference implementation, not recovered original source |
| [`dmd.py`](python_tools/dmd.py) | Exact DMD and delay-embedded DMD/HODMD-style analysis | New reference implementation |
| [`dmdc.py`](python_tools/dmdc.py) | Ridge-regularized delay DMDc with lagged forcing and impulse-response metrics | Reconstructed report method |
| [Synthetic examples](python_tools/examples/) | Generate and analyse synthetic climate and state/forcing signals | Demonstrations, not experimental results |
| [Python tests](python_tools/tests/) | Synthetic regression checks | CI synthetic tests and examples pass on Python 3.11–3.13 (2026-10-16) |

## Installation

On Windows PowerShell, from a clone of **this branch**:

```powershell
git clone --branch WUFI_python_tools https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase.git
cd WUFI_infractructure_codebase
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r python_tools/requirements.txt
python -m pytest -q python_tools/tests
```

If you already cloned the repository, switch to `WUFI_python_tools` **only after saving or committing local edits**; the workstream branches deliberately have different working trees.

### Synthetic walkthrough

```powershell
python -m python_tools.examples.make_synthetic_inputs --out-dir demo_outputs
python python_tools/wac_from_audit.py demo_outputs/synthetic_wac_audit.csv demo_outputs/synthetic_climate.wac
python -m python_tools.examples.run_modal_example --out-dir demo_outputs
```

**The examples create artificial data and are not valid WUFI climate forcing or evidence about the REF/HEMP walls.**

## Detailed guides

- [Python installation and input contracts](docs/INSTALLATION.md)
- [Climate and modal-analysis workflows](docs/WORKFLOWS.md)
- [Worked Python examples](docs/EXAMPLES.md)
- [Research provenance and limitations](docs/PROVENANCE.md)
- [Two-branch contribution policy](docs/BRANCHING.md)
- [Python module API instructions](python_tools/README.md)
- [Historical WAC full-replay CLI and limitations](docs/WAC_FULL_REPLAY.md)
- [Phase-4 WXF reader and paired-series reconstruction](docs/WXF_PHASE4_REPLAY.md)
- [Full 60-row/135-row multiscale replay](docs/PHASE4_FULL_REPLAY.md)
- [Meteorological WXF reconstruction](docs/METEO_WXF_REPLAY.md)
- [Phase-4 DMDc source-level replay](docs/DMDc_FULL_REPLAY.md)
- [Complete 90+40+960 archival DMDc numerical reproduction](docs/DMDc_COMPLETE_NUMERICAL_REPRODUCTION.md)
- [Analytic forward/backward HODMD 480-fit sensitivity](docs/HODMD_PAPERSTYLE_NUMERICAL_COMPARISON.md)
- [HODMD original-rule recovery and full-spectrum diagnostics](docs/HODMD_RULE_RECOVERY.md)
- [Private original-WXF HODMD 84-group spectral replay and sample-SD recovery](docs/HODMD_PRIVATE_SPECTRAL_REPLAY.md)
- [Complete 112-record historical HODMD numerical reproduction](docs/HODMD_COMPLETE_NUMERICAL_REPRODUCTION.md)
- [Fresh 18 October 2026 private-data acceptance: HODMD PASS; WAC full pvlib replay, three source-gap exceptions](docs/REF_HEMP_ACCEPTANCE_2026_10_18.md)
- [Pre-WUFI scientific verification Phases A–D](docs/REF_HEMP_PHASES_A_D_2026_10_18.md)
- [Further scientific validation: calibration scenarios, HODMD surrogates and recursive DMDc](docs/REF_HEMP_PHASE_E_2026_10_18.md)
- [Pre-WUFI F1–F4: exact Phase E source acceptance, WAC/WXF interoperability and internal RC](docs/REF_HEMP_PRE_WUFI_PHASE_F1_F4_2026_10_18.md)
- [Final REF/HEMP production two-case 12-WXF and post-processor archival parity](docs/FINAL_TWO_CASE_WXF_PARITY_2026_10_18.md)
- [Pre-WUFI scientific release gates](docs/REF_HEMP_RELEASE_GATES.md)
- [HODMD independent daily-mode check](docs/HODMD_REFHEMP_REPLAY.md)
- [Scientific input SHA-256 manifests and release gates](docs/SCIENTIFIC_RELEASE_GATES.md)

### Relationship to Mathematica

The production Wolfram Launcher v1.0, WUFI ASC Post-Processor v1.1.1 and WUFI Sensor Comparison v1.2.0 are maintained in the [Mathematica branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools). Export **quality-controlled and time-aligned** series from that workflow before Python residual/mode analysis. Never open a PR from this Python branch against the Mathematica branch: the Python branch intentionally excludes `Mathematica_tools/`.

## Data, licensing and release status

Python 3.10+ is recommended. WUFI Pro, Mathematica, project-specific weather audits, sensor measurements and simulation outputs are separate licensed/private inputs; they are not supplied here. Synthetic Python CI is passing on 3.11–3.13. Archived Phase-4 multiscale metrics including best-lag selections and DMDc 90-row input-set, 40-row spectral-memory and 960-row impulse-response results are independently reproduced to high numerical precision from original WXF. Strict full-data pvlib replay, historical HODMD mode/stability equivalence, and licensed WUFI application-level import remain open before a publication-grade release. See [LICENSE](LICENSE).

### Historical WAC baseline comparison

For authorized local copies of the archived hourly audit and WAC, use `python python_tools/validate_wac_reference.py Spilve_solar_hourly_audit.csv original.wac` to validate the file's numerical contract. This checks the provided WAC against the audit table; it does **not** rerun the original meteorological reconstruction.
