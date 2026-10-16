# Installation and configuration

## Prerequisites

- **Windows** for the provided `.bat` XML extraction and WUFI batch launching. WUFI Pro is separately installed/licensed, and its command-line executable must be accessible (or specified by its full path).
- **Wolfram Mathematica 12.1** is the reference/tested platform for the current Wolfram Language releases. Parallel graphics needs sufficient licensed subkernels, memory and disk space.
- **Python 3.10+** is recommended for the added climate and modal examples (`numpy`, `pandas`, `pvlib`, `pytest`). Use a virtual environment; Python dependencies do not install WUFI or Mathematica.
- **7-Zip** (or compatible) to unpack available `.7z` archives when running historical tests. Archives are not expanded automatically by cloning.

Clone:

```powershell
git clone https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase.git
cd WUFI_infractructure_codebase
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r python_tools/requirements.txt
```

Use `python -m pytest -q python_tools/tests` for synthetic Python regression tests. Do not treat these as substitutes for Mathematica or WUFI production acceptance tests.

## Prepare your local inputs

Maintain a *separate, untracked* project workspace, for example:

```text
D:\WUFI_work\
  models\            # .w6p projects + same-stem extracted .xml files
  monitoring\        # authorized sensor registry, JSON/MX/WXF etc.
  climate\           # measured/quality-audited climate records and .wac files
  results\           # generated ASC/WXF/JPG/manifests
```

The REF/HEMP production inputs are not distributed with the repository. Use your authorized Drive/archive; preserve its original sensor time basis and the actual model metadata. Never overwrite canonical source data just to make an example pass.

### WUFI executable

The launcher notebook exposes `wufiCommand` (default `"WUFI"`) and `calculationSwitches` (default `"-C -s -v"`). If `WUFI` is not on `PATH`, set `wufiCommand` to its fully qualified executable path **in the launcher settings cell**, and verify the command manually. Do not launch a batch before inspecting its generated `.bat` content, case inventory and output destinations.

## Mathematica modules and paths

The launcher expects **its notebook and `WUFIModelMetadata.wl` adjacent to the project `.w6p`/`.xml` files**. The repository stores the notebook and module together in `Mathematica_tools/WUFI Batch Launcher Automated v1/`; copy those two files to the private models workspace, or deliberately revise the notebook's `modelDirectory` and package-loading path.

Post-processor folder:
`Mathematica_tools/WUFI Data-Post Processor Automated v1.1.1/`

- Edit `WUFIDataPostProcessorConfig_v1_1_1.wl`: at minimum set **`"DataDirectory"`** to the batch manifest/ASC campaign directory.
- Keep its notebook, implementation `.wl`, config `.wl`, and `WUFIModelMetadata.wl` together.
- `"GraphicsMode" -> "Full"` additionally uses its bundled `LIM Curves` directory. `"Sweep"` still writes five downstream WXF products, with fewer JPGs.
- Production graphics default is eight kernels; 12 was validated on the reference workstation; more than 12 is not recommended.

Sensor comparison folder:
`Mathematica_tools/WUFI VS Sensor Comparison Automated v1.2.0/`

- Edit `SensorComparisonConfig_v1_2.wl`: `mainRoot`, `sensorDataRoot`, `sensorRegistryVersionRoot`, `projectDataRoot`, `toolsFolder`, `"ProductionRunRoot"`, `"WUFIManifestPath"`, `"OutputRoot"` and `"SelectedCases"`.
- Provide the canonical sensor registry, selected-sensor WXFs and the corresponding production WUFI post-processor output.
- **Important path issue:** the current configuration resolves `"LIMCurveDirectory"` to `FileNameJoin[{DirectoryName@sensorComparisonCodeRoot, "LIM Curves"}]`. From a pristine repository checkout, that means `Mathematica_tools/LIM Curves`, while the shared curves are stored at repository root `LIM Curves/`. Either copy the root `LIM Curves/` directory to the expected location, **or explicitly override** the setting with the absolute path to the repository-root curves **after loading the driver** and before preflight:

```wl
sensorComparisonSettings = Join[
  sensorComparisonSettings,
  <|"LIMCurveDirectory" -> "D:\\path\\to\\WUFI_infractructure_codebase\\LIM Curves"|>
];
```

- The committed default paths are historical project-specific Windows paths and are **not portable**. Treat them as examples only; do not run until preflight returns `"Ready"`.

## Time coordinates and climate provenance

For the referenced REF/HEMP campaign, monitored data is normalized to UTC and WUFI wall-clock labels are treated as **fixed UTC+2**, not DST-adjusting `Europe/Riga`. The report preserves a **historical solar reconstruction** at approximately `56.97 N, 24.17 E` and documents physical test-house coordinates of `56.985411 N, 24.085193 E`. The Python WAC tool defaults to the historical coordinates for reconstructing the retained case; for a *new* experiment specify its measured site coordinates and fixed time basis. Never silently mix these locations or label conventions.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Launcher reports missing/invalid cases | Same-stem `.w6p` and `.xml` pairs, active-case flags and stale monitor positions |
| Batch executable cannot be found | WUFI Pro installation, `wufiCommand` and switches |
| Post-processor preflight blocked | Manifest, expected ASC files, output directory and `LIM Curves` for Full mode |
| Comparison preflight blocked | Sensor registry, WXF data, selected cases, manifest and LIM path |
| WAC cannot interpolate a solar gap | Missing same-hour source observations *before and after* the gap; bring external station/reanalysis data rather than extrapolate |
| 8-kernel graphics stalls | Available subkernels, RAM, disk space; use conservative settings; do not assume `Automatic` is production-validated |
| Test assets not found | Extract `TestAssets.7z` beside relevant test scripts; note that some documented historical registry files are not present in this checkout |

See the two release-specific READMEs for details and frozen validation counts.
