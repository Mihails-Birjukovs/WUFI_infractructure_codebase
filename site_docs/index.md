# WUFI Infrastructure

**Research software infrastructure for WUFI Pro automation, measured-sensor comparison, climate-file preparation and time-series diagnostics.**

This site documents code published in [WUFI_infractructure_codebase](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase). It is **software documentation**, not a substitute for licensed WUFI, original monitoring data, validated physics, or the underlying research article.

## Two maintained toolchains

| Wolfram Mathematica: production workflow | Python: climate and diagnostics |
| --- | --- |
| WUFI batch launcher v1.0; ASC post-processor v1.1.1; sensor comparison v1.2.0 | pvlib-based WAC generation; multiscale diagnostics; DMD, delay/HODMD and DMDc references |
| [Mathematica branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools) — repository default | [Python branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools) |
| Historical acceptance archives and source-controlled tools | Synthetic CI plus separately documented private-data numerical replay |
| Windows + WUFI Pro + Wolfram Mathematica | Python 3.10+ and project requirements |

**The branches are deliberately different working trees. Do not merge them to combine the tools.** Follow [the documented coordination boundary](contributing.md).

## Start with evidence, not claims

- [Get started](getting-started.md) with a safe, isolated workspace.
- [Understand the pipeline](architecture.md) and the two branches.
- Use the [Mathematica walkthrough](mathematica.md) to generate manifests, post-process ASC and compare sensors.
- Use the [Python walkthrough](python.md) with **synthetic fixtures** before authorized measured data.
- Check the [validation matrix](validation.md) before citing equivalence or interpreting scientific results.
- Read [scientific data and rights limitations](data-provenance.md) before distributing outputs.

## Publication boundary

The public repository does **not** distribute WUFI Pro, private REF/HEMP sensor histories, raw MongoDB collections, calibration projects, original WAC audit files, unpublished article figures, or protected third-party material. The independently audited scientific campaign remains in its authorized archive. A passing unit test or documentation build does not prove physical model validity.

**Documentation status:** proposed website, versioned with the authoritative Mathematica branch; site deployment requires a reviewed pull request and GitHub Pages acceptance.
