# WUFI infrastructure — Mathematica tools

**Active branch:** `WUFI_mathematica_tools` (repository default). This branch contains the established Wolfram Mathematica infrastructure for WUFI Pro simulation automation, output processing and comparison with measured wall sensors.

| Production component | Version | Entry point |
| --- | --- | --- |
| WUFI project XML extraction | Windows batch wrapper | [extract_all_wufi_xml.bat](extract_all_wufi_xml.bat) |
| WUFI batch launch / metadata | v1.0 | [Launcher notebook](Mathematica_tools/WUFI%20Batch%20Launcher%20Automated%20v1/WUFI%20Batch%20Launcher%20Automated%20v1.nb) |
| ASC post-processing / WXF / graphics | v1.1.1 | [Release README](Mathematica_tools/WUFI%20Data-Post%20Processor%20Automated%20v1.1.1/README.md) |
| Sensor QC, WUFI comparison | v1.2.0 | [Release README](Mathematica_tools/WUFI%20VS%20Sensor%20Comparison%20Automated%20v1.2.0/README.md) |

## Start here

- [Install and configure Mathematica + WUFI Pro](docs/INSTALLATION.md)
- [Complete batch → ASC → WXF → sensor comparison workflow](docs/WORKFLOWS.md)
- [Worked Mathematica examples](docs/EXAMPLES.md)
- [Implementation / REF & HEMP provenance](docs/PROVENANCE.md)
- [Branching policy](docs/BRANCHING.md)

**Python tools have their own branch:** [`WUFI_python_tools`](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools). Use that branch for the `pvlib` WAC generator and multiscale/DMD/HODMD/DMDc analysis **and** Valters Ribickis's new Windows WUFI batch launcher, ASC post-processor and wall-construction optimization scripts (added 20 October 2026). Do not merge the Python branch into the Mathematica branch: the branches intentionally contain different source trees.

### Additional Python workflows (source on the separate branch)

- [Batch Launcher Automated v1.0](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/WUFI_Batch_Launcher_Automated_v1.0/README.md) — generates a batch file for operator-reviewed execution.
- [Data Post-Processor Automated v1.0](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/WUFI_Data_Post_Processor_Automated_v1.0/README.md) — separate CSV/JPG output pipeline, **not** the Mathematica WXF contract.
- [Wall Construction Optimisation](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/WUFI_Wall_Construction_Optimisation/README.md) — parameter sweep and local adaptive thickness search, executing licensed WUFI.

**Status:** Python source is at `c5ec8ce` (2026-10-20); compilation and existing synthetic CI pass, but these added scripts have no committed WUFI-specific functional suite or demonstrated Mathematica numerical equivalence. A separate [collaborator assessment backlog](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/issues) records proposals before implementation. Keep both source branches separate.

### Requirements

Windows; licensed WUFI Pro (reference study: 6.5); Wolfram Mathematica (reference validated version: 12.1); project-specific WUFI `.w6p`, extracted `.xml`, accepted source/monitoring datasets (not bundled). Configurations contain historical absolute Windows paths and must be edited for a new workspace.

The existing `Mathematica_tools/` release packages have independent acceptance evidence. The documentation update does not modify their executable code.

## Licensing / data

See [LICENSE](LICENSE). The source repository does not include licensed WUFI itself or private REF/HEMP records.
