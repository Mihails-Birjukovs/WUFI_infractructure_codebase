<section class="wufi-hero" aria-label="WUFI infrastructure documentation">
  <div class="wufi-eyebrow">Hygrothermal simulation · Research software · Mathematica &amp; Python</div>
  <h1>WUFI Infrastructure</h1>
  <p>Reproducible WUFI Pro batch automation, sensor comparisons, site-climate preparation and multiscale/modal diagnostics for hygrothermal research.</p>
  <div class="wufi-actions">
    <a class="wufi-link wufi-link-primary" href="getting-started.md">Get started</a>
    <a class="wufi-link" href="architecture.md">Explore the workflow</a>
    <a class="wufi-link" href="references.md">Methods &amp; references</a>
  </div>
</section>

<img class="wufi-brand-mark" src="assets/inm-horizontal.svg" alt="Institute of Numerical Modelling, University of Latvia" />

<div class="wufi-identity">
  <div><small>Software &amp; documentation · INM</small><strong>Mihails Birjukovs</strong><br />Mathematica tools; Python tools with Valters Ribickis<br />Institute of Numerical Modelling, University of Latvia</div>
  <div><small>Experimental measurements &amp; credit</small><strong>Jevgēnijs Teličko · Māris Šinka · Piotr Lapka</strong><br />Sensor data and network; sensor installation; material-property laboratory measurements</div>
</div>

**WUFI infrastructure and research software documentation.** This site documents published code from the [WUFI infrastructure GitHub repository](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase). It is not a substitute for licensed WUFI Pro, independently verified instrumentation, original monitoring data, or the research manuscript.

## Two maintained toolchains

| Wolfram Mathematica: simulation and comparison | Python: WUFI automation, climate and diagnostics |
| --- | --- |
| WUFI batch launcher v1.0, ASC post-processor v1.1.1, sensor comparison v1.2.0 | `pvlib` WAC generation; new Python WUFI batch-file launcher, ASC-to-CSV/JPG post-processor, construction sweep/thickness search; multiscale and modal diagnostics |
| [Mathematica branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools) (repository default) | [Python branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools) |
| Accepted historical release archives, original WUFI/WXF toolchain | Existing synthetic tests pass; newly added Windows/WUFI workflows await application-level and interoperability acceptance |
| Windows, licensed WUFI Pro, Mathematica | Python; Windows/WUFI for execution scripts, additional Matplotlib for plotting |

**These branches are intentionally separate working trees and must not be merged.** See the [contribution policy](contributing.md).

## Start here

- [Install and set up](getting-started.md) a separate research workspace.
- [Follow the data flow](architecture.md) from weather and sensor inputs through WUFI outputs.
- [Use the Mathematica tools](mathematica.md) for batch execution, post-processing and sensor comparison.
- [Explore Python tools](python.md) including Valters's WUFI workflow scripts; use synthetic climate/modal examples before authorized observations.
- [Review validation scope](validation.md) before interpreting numerical agreement.
- [Credit and cite the methods](references.md), [software and measurement contributors](credits.md).
- [Understand restricted data rights and provenance](data-provenance.md).

**New in the Python branch (20 October 2026):** Valters Ribickis contributed a batch launcher, ASC post-processor and two construction-search scripts. Their outputs and acceptance status are distinct from the Mathematica releases; see [Python tools](python.md) and [open collaborator review issues](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/issues).

## Software, instrumentation and scientific interpretation

The code repository is public; raw MongoDB sensor exports, calibrated WUFI projects, private experiment results, manuscript figures and proprietary software are **not redistributed** here. Physical sensor identity, solar-instrument measurement plane and heat-flow provenance remain distinct from successful numerical reproduction.

<div class="wufi-credit-strip"><strong>Institutional affiliation:</strong> Institute of Numerical Modelling (INM), University of Latvia. Code credits and experimental contributors are separated on the <a href="credits.md">Credits &amp; contributors</a> page. The INM mark is institutional artwork, not MIT-licensed software.</div>
