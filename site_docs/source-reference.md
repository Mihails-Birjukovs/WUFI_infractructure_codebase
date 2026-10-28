# Source and reference index

This website documents **two deliberately distinct source branches**. Always select the right branch for complete manuals, runtime configuration and code.

## Mathematica source

- [Default Mathematica branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools)
- [Launcher, ASC post-processor and sensor-comparison packages](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools/Mathematica_tools)
- [Installation and configuration](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_mathematica_tools/docs/INSTALLATION.md)
- [Operational WL workflow](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_mathematica_tools/docs/WORKFLOWS.md)
- [Worked Mathematica examples](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_mathematica_tools/docs/EXAMPLES.md)
- [Historical Wolfram equivalence-gate audit](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_mathematica_tools/docs/WOLFRAM_ARCHIVED_EQUIVALENCE_GATES_2026_10_18.md)
- [Branching policy](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_mathematica_tools/docs/BRANCHING.md)

## Python source

- [Python branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools)
- [Python batch launcher v1.0 — Valters Ribickis](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/WUFI_Batch_Launcher_Automated_v1.0/README.md)
- [Python ASC post-processor v1.0 — Valters Ribickis](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/WUFI_Data_Post_Processor_Automated_v1.0/README.md)
- [Python wall-construction parameter sweep and thickness search — Valters Ribickis](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/WUFI_Wall_Construction_Optimisation/README.md)
- [Module API, example contracts](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/README.md)
- [Python requirements](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/requirements.txt)
- [Synthetic tests](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools/python_tools/tests)
- [Climate replay and limitations](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/WAC_FULL_REPLAY.md)
- [WXF archival reconstruction](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/WXF_PHASE4_REPLAY.md)
- [DMDc complete numerical reproduction](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/DMDc_COMPLETE_NUMERICAL_REPRODUCTION.md)
- [HODMD complete numerical reproduction](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/HODMD_COMPLETE_NUMERICAL_REPRODUCTION.md)
- [Release gates](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/REF_HEMP_RELEASE_GATES.md)
- [Method provenance](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/PROVENANCE.md)

## Scientific context

The separately archived **WUFI Unified Report, draft v1.4** explains original model and material study conditions. It is not reproduced here and is not necessarily approved for open redistribution. This website is software documentation and not a peer-reviewed publication.

Core execution tools include licensed WUFI Pro and Wolfram Mathematica, plus Python libraries under their separate licenses. For a reproducibility citation, record source SHAs for **both** branches, original data/model hashes, execution environment, selected interval, and exact archival evidence.

## Collaborator review backlog

The three Python WUFI-facing packages were added by Valters Ribickis at commit [`c5ec8ce`](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/commit/c5ec8ce095d36eb168db9741f9e28a041daa80bf), on 20 October 2026. [Issues #28–#35](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/issues) record open questions about safe overwriting, functional tests, case mapping, U-value physics, dependencies/concurrency, data QC, Mathematica interoperability and contribution governance. All await Valters's assessment before implementation.
