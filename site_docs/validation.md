# Validation coverage and release gates

**Validation claims are scoped to a source revision, a particular toolchain, input datasets, execution environment and evidence record.** Matching a table, reproducing an archival WXF or passing a synthetic CI test are different statements.

| Evidence tier | Scope / status | What is *not* established |
| --- | --- | --- |
| Python synthetic tests | CI supports Python 3.11–3.13 on synthetic fixtures | WUFI app integration, physical accuracy or private-data source parity |
| Five-case Mathematica candidate archives | RC2 and RC3: 5/5 cases, 24/24 aligned comparisons, 99/99 graphics audits; 30/30 corresponding WXF byte-identical, original archived Wolfram 13/13 equivalence and 42/42 smoke reports recovered | Fresh original Mathematica 12.1 rerun; later two-case validation |
| Independently mirrored historical gate predicates | RC2/RC3: 11/13 in Python, differing only in literal release-versus-RC version checks | A newly executed Wolfram TestReport |
| Final REF/HEMP two-case production | 2/2 cases, 12/12 time alignments, 63/63 graphics integrity; 12 comparison metric rows and 17 QC rows; archived metrics independently recalculated | Four-way separation of temporal metrics does not verify sensor physical assignment |
| REF/HEMP v1.4 manuscript | 68-page source can be rebuilt with matching extracted text; tabulated numerical comparisons agree with archives | Full pointwise regeneration of all figures or unobserved wall physics |
| Constitutive XML properties | 168 function occurrences, 1,236 point nodes; 10/10 shared layers identical across final XML files | Resolution of WUFI precedence rules for dry conductivity scalar versus temperature curve |
| Solar forcing | WAC archival audit strongly reproduced, three near-horizon hours with sub-0.216 W/m² differences | Measured instrument plane and calibration; exact unqualified generator parity |

**Context:** The five-case acceptance tests predate and are distinct from the final calibrated two-case research campaign. Original archived 13/13 TestReport success is a **historical execution record**, whereas 11/13 comes from a new independently mirrored Python predicate implementation. Reporting only one number without its method would mislead.

## Pending release checks

- Test actual licensed WUFI import/execution after any climate-generation change.
- Confirm 12.1/Windows regression for Mathematica changes, including graphics in a supported kernel environment.
- Audit actual instrument logger IDs, radiation plane and heat-flux data source.
- Record whether every scientific figure is *source-identified*, *numeric-source verified* or *independently regenerated*: these are progressively stronger states.
- Retain date-window, time-base, channel QC and source commit in every reproducibility statement.

No public site test runner has access to the raw REF/HEMP research database, calibrated WUFI projects, or original private archived figures. Site CI tests documentation safety and build quality, **not the private experiments**.

For fine-grained test histories see [Mathematica historical gate audit](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_mathematica_tools/docs/WOLFRAM_ARCHIVED_EQUIVALENCE_GATES_2026_10_18.md) and [Python release gate index](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/REF_HEMP_RELEASE_GATES.md).
