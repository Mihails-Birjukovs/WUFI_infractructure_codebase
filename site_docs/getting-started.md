# Getting started

## Choose the appropriate branch

The default clone checks out the Mathematica toolchain. To work with Python, clone its branch separately rather than switching over an unsaved working tree.

**Mathematica checkout** (Windows PowerShell):

~~~powershell
git clone --branch WUFI_mathematica_tools https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase.git WUFI_mathematica
~~~

**Python checkout** (Windows PowerShell):

~~~powershell
git clone --branch WUFI_python_tools https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase.git WUFI_python
cd WUFI_python
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r python_tools/requirements.txt
python -m pytest -q python_tools/tests
~~~

Requirements are toolchain-specific. The accepted Mathematica reference platform is **Windows with Mathematica 12.1** and a separately installed/licensed **WUFI Pro 6.5**. A source checkout is not a WUFI installation. For the Python toolchain, use the dependency versions in the selected source branch and verify the recorded CI matrix.

## Separate working data from source

Keep licensed project files, sensor data and generated results in a **private workspace outside the cloned repository**:

~~~text
WORKSPACE/
  models/      WUFI .w6p and same-stem .xml
  climate/     approved WAC input and radiation audit
  monitoring/  authorized measured data and sensor registry
  outputs/     ASC, WXF, plots and manifests
~~~

Never place those working files in a publicly tracked directory. Verify outputs and original case names before enabling batch execution.

## Safe first test

For Python, use the included synthetic demonstration:

~~~powershell
python -m python_tools.examples.make_synthetic_inputs --out-dir demo_outputs
python python_tools/wac_from_audit.py demo_outputs/synthetic_wac_audit.csv demo_outputs/synthetic_climate.wac
python -m python_tools.examples.run_modal_example --out-dir demo_outputs
~~~

These inputs are artificial; the resulting WAC file and modal plots are **not** calibrated model inputs or REF/HEMP evidence.

For Mathematica, begin with the launcher notebook's **metadata inspection** and run the release's smoke suite before invoking the licensed simulator. See [Mathematica tools](mathematica.md), the [branch installation instructions](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_mathematica_tools/docs/INSTALLATION.md) and [source reference](source-reference.md).

## Operating rules

1. Pin repository commit, tool versions, input hashes and timezone convention for any substantive analysis.
2. Inspect batch manifests and selected cases before running.
3. Require release-specific preflight acceptance; do not treat output file existence as model validation.
4. Use a new output directory for each calibration or methods variant.
5. Preserve originals and keep synthetic/archival/private-data evidence separate.
