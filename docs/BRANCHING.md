# Two-branch contribution policy

This repository intentionally maintains **two long-lived branches**:

| Target branch | Owns | Excludes |
| --- | --- | --- |
| [`WUFI_mathematica_tools`](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools) | `Mathematica_tools/` packages, release instructions, WUFI launcher and sensor-comparison documentation | New Python WAC/modal modules |
| [`WUFI_python_tools`](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools) | `python_tools/` WAC/DMD/DMDc/multiscale code, Python tests and Python documentation | `Mathematica_tools/` packages |

**Workflow:** branch from the relevant long-lived branch, commit only that workstream, and open a PR whose **base is the same branch**. Never target the repo's default branch merely because GitHub preselected it. In particular, do not merge `WUFI_python_tools` into `WUFI_mathematica_tools` or vice versa: Python-branch history includes the deliberate removal of `Mathematica_tools/`.

A small shared ancestry remains (e.g. `LICENSE`, `LIM Curves/`, `extract_all_wufi_xml.bat`); that is intentional to preserve the user's branch restructuring. Make future changes to shared material **separately on each branch** or explicitly coordinate cherry-picks without copying tree-wide deletions.

Suggested temporary work branches: `docs/mathematica-...`, `fix/mathematica-...`, `feat/python-...`, `test/python-...`. Temporary PR branches are not a third permanent distribution line. Close superseded mixed-workstream PRs; keep both target branches unmerged until reviewed.
