# Research & references

The WUFI infrastructure combines **original/local software**, **retained or reconstructed research implementations**, and **third-party scientific methods**. Cite the relevant methodological papers when publishing results, and cite the repository's versioned code for the actual implementation. A method citation is **not** a claim that the paper's original software was imported or that our local variant is algorithmically identical.

## Solar irradiance and `pvlib`

The `WUFI_python_tools` branch uses the BSD-3-Clause-licensed [pvlib python](https://github.com/pvlib/pvlib-python) library in its [WAC climate generator](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/wac_from_audit.py).

**Preferred current pvlib software citation** (recommended by pvlib's maintainers):

> **Anderson, K., Hansen, C., Holmgren, W., Jensen, A., Mikofski, M., & Driesse, A. (2023).** *pvlib python: 2023 project update.* Journal of Open Source Software, **8**(92), 5994. [doi:10.21105/joss.05994](https://doi.org/10.21105/joss.05994).

**Historical pvlib citation** (useful when describing original/reconstructed source lineage):

> **Holmgren, W. F., Hansen, C. W., & Mikofski, M. A. (2018).** *pvlib python: a python package for modeling solar energy systems.* Journal of Open Source Software, **3**(29), 884. [doi:10.21105/joss.00884](https://doi.org/10.21105/joss.00884).

The method used for estimating the diffuse fraction from a clearness index is:

> **Erbs, D. G., Klein, S. A., & Duffie, J. A. (1982).** *Estimation of the diffuse radiation fraction for hourly, daily and monthly-average global radiation.* Solar Energy, **28**(4), 293–302. [doi:10.1016/0038-092X(82)90302-4](https://doi.org/10.1016/0038-092X(82)90302-4).

**Interpretation boundary:** the presence of a database `solar_radiation` field does not independently verify a calibrated **global horizontal irradiance** sensor. The Erbs diffuse/direct separation is a computational model, not separate pyranometer measurements.

## Dynamic mode decomposition (DMD)

The local [`dmd.py`](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/dmd.py) implements singular-value-based **exact DMD**, with modes obtained from the projected least-squares evolution operator. The code is a **new research reference implementation**, not the recovered original Phase-4 code and not a dependency on a separate DMD package.

> **Schmid, P. J. (2010).** *Dynamic mode decomposition of numerical and experimental data.* Journal of Fluid Mechanics, **656**, 5–28. [doi:10.1017/S0022112010001217](https://doi.org/10.1017/S0022112010001217). — Original fluid-mechanics formulation.

> **Tu, J. H., Rowley, C. W., Luchtenburg, D. M., Brunton, S. L., & Kutz, J. N. (2014).** *On dynamic mode decomposition: Theory and applications.* Journal of Computational Dynamics, **1**(2), 391–421. [doi:10.3934/jcd.2014.1.391](https://doi.org/10.3934/jcd.2014.1.391). — Exact-DMD operator formulation.

### Delay-embedded / higher-order DMD

The local `delay_dmd` function stacks delayed snapshots and calls the local exact DMD routine. It is described as **HODMD-style**, but it is not a claim to reproduce every algorithmic choice of the cited full HODMD scheme.

> **Le Clainche, S., & Vega, J. M. (2017).** *Higher Order Dynamic Mode Decomposition.* SIAM Journal on Applied Dynamical Systems, **16**(2), 882–925. [doi:10.1137/15M1054924](https://doi.org/10.1137/15M1054924). — Higher-order/time-delay approach.

Independent numerical replays of historical mode-selection statistics in the WUFI repository relied on **inferred** parameters and original private WXF series. Their agreement must not be mistaken for recovery of an unavailable historical script.

## Dynamic mode decomposition with control (DMDc)

The local [`dmdc.py`](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/dmdc.py) is a **reconstructed delay-embedded, ridge-regularized input/state regression**. It includes lagged forcing-history propagation during impulse-response simulation. These choices are not equivalent to claiming the original authors' DMDc software or an identical canonical algorithm.

> **Proctor, J. L., Brunton, S. L., & Kutz, J. N. (2016).** *Dynamic Mode Decomposition with Control.* SIAM Journal on Applied Dynamical Systems, **15**(1), 142–161. [doi:10.1137/15M1013857](https://doi.org/10.1137/15M1013857). — Foundational DMDc method.

The WUFI application of DMDc is a **predictive/diagnostic association** involving observed forcings, not evidence of causal material defects or interface leakage. Parameters, scaling, forcing histories, selection criteria and original input files must be included in a scientific methods description.

## How to cite results produced by this repository

When reporting a scientific result, cite:

1. **The methodological publications relevant to the modules actually used** (above).
2. **The specific WUFI repository branch and source commit SHA**; document package/runtime versions and the exact invoked source module.
3. **The instrument/model provenance** (licensed WUFI project and input hashes, source measurement snapshot, registry, timestamp convention and calibration as applicable).
4. The **research paper** if and when its final author-approved journal version is published. Do not treat an internal draft report as peer-reviewed.

The independent Mathematica toolchain has its own accepted historical release evidence, and the original five-case archives differ from the final two-case wall-model outputs. See [Validation](validation.md), [Credits](credits.md), [Source reference](source-reference.md), and [Licensing](licensing.md).

### Bibliographic provenance

The `pvlib` preferred and historical citations above follow the maintainers' [own citation instructions](https://github.com/pvlib/pvlib-python#citing). The DMD, HODMD, DMDc and Erbs bibliographic details were checked against journal/DOI records; these are **method attribution sources**, not endorsements of our case-specific experiment.
