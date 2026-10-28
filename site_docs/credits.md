# Credits & contributors

The software toolchains, sensor-network operations, experimental measurements and material-property tests are **distinct contributions**. Names here identify the roles specified for this documentation, not a transfer of experimental-data rights or a declaration of manuscript authorship.

## Software development — Institute of Numerical Modelling (INM)

| Component | Contributor(s) | Scope |
| --- | --- | --- |
| **Mathematica tools** — original branch (`WUFI_mathematica_tools`) | **Mihails Birjukovs** | WUFI launcher, project metadata/extraction infrastructure, ASC post-processing, and sensor/WUFI comparison tooling |
| **Python tools** (`WUFI_python_tools`) | **Mihails Birjukovs** and **Valters Ribickis** | Python research tools (Mihails Birjukovs and Valters Ribickis); **Valters Ribickis specifically contributed the WUFI batch launcher, ASC post-processor and wall-construction sweep/thickness tools added 20 October 2026** |

These contributions concern the repository’s tooling. Module-by-module **original vs reconstructed vs new-method** distinctions are documented in [Python tools](python.md), [modal methods](modal.md), and the [source reference index](source-reference.md). Individual commits provide the finer-grained code history.

## Sensor data and monitoring infrastructure

- **Jevgēnijs Teličko** — MongoDB data curation and management of the sensor network.
- **Māris Šinka** — sensor installation and maintenance.

These roles are acknowledged for the experimental monitoring infrastructure. The identities, positions, timing and calibration of individual channels require their own records; the contributor listing does not independently certify any disputed physical sensor assignment.

## Laboratory material-property measurements

- **Piotr Lapka** — laboratory measurements of construction-material properties.

Laboratory measurement credit is distinct from authorship of the WUFI code and from responsibility for later calibration or report interpretation.

## Methods and third-party software

Our Python tools use **pvlib** for solar-position / irradiance calculations and the Erbs decomposition. Credit for the **pvlib project** belongs to its contributors; cite their preferred 2023 JOSS paper and, where useful for historical provenance, their 2018 JOSS paper. DMD, higher-order/time-delay DMD and DMD with control are also credited to their **published methodological authors**, even though the local Python source provides separate reference implementations rather than importing those authors’ code. See [Research & references](references.md) for full bibliography and method mappings.

## Institutional identity and rights

**Institute of Numerical Modelling (INM), University of Latvia** identifies the software developer's affiliation. The three INM SVG assets in this website were reused from the same maintainer’s OOC documentation site for consistent visual attribution. **Official institute marks are excluded from the MIT software license** and must not be treated as universally reusable artwork.

The **WUFI Unified Report draft v1.4**, private MongoDB sensor datasets, project-specific WUFI models, photographs and third-party reports have separate scientific and redistribution permissions. Source code ownership, data stewardship and eventual publication authorship are not interchangeable. See [Licensing](licensing.md).
