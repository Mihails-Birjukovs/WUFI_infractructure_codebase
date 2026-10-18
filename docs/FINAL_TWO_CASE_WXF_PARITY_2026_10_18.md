# Final REF/HEMP two-wall-model numerical audit (18 October 2026)

**Status:** complete independent **archived-WXF -> summary** arithmetic and
UTC lag acceptance, on original private Drive outputs. This is NOT original
sensor preprocessing validation, calibration accuracy, independent model
predictive validity, full original 13-gate Mathematica equivalence, or
WUFI Pro/Mathematica 12.1 application acceptance.

The report was produced from the genuine **Production-1.2.0-2026-08-05**
manifest for \`WUFI_FINAL_wall_models\`, its original comparison summary,
the 12 original \`WUFI_vs_Sensors/.../time_series/*.wxf\` files, the
paired UTC alignment audit, and both final REF/HEMP postprocessor
temperature/RH/dew-point, layer-water, total-water WXF outputs.
Private source time series, WXF bytes, CSV, registry and file hashes
were processed locally; they are **not part of the public repository**.

## Two-case sensor/WUFI archive acceptance

| Independent check | Reproduced |
| --- | ---: |
| Source final wall cases | 2 |
| Original paired comparison WXF files | **12/12** |
| Full-period and after-initial-exclusion comparisons | **24/24** |
| Independently recomputed scalar summary metrics | **288/288** within documented tolerance |
| Timestamp-aware best-lag hours | **24/24 exact** |
| Best-lag signed correlations | 24/24 within **2e-6** |
| Maximum numerical scalar summary discrepancy | **1.721e-4** (source variable units) |
| Maximum absolute best-lag correlation discrepancy | **1.4172e-6** |
| Original UTC alignment audit | **12/12 PassQ** |
| Original graphics integrity audit | **63/63 valid** (archive record, not re-rendered) |

Original Mathematica calculation methods explicitly recovered from
\`SensorDataUtilities_v1_2.wl\`:
- paired residual = \`WUFI(t) - measured(t)\`;
- population residual dispersion, Pearson correlation and ordinary
  linear regression;
- residual p05/p95 using **Wolfram default inverse-empirical
  nearest-rank Quantile**, *not* NumPy interpolated percentiles;
- one best lag from **maximum signed Pearson correlation**, scanning
  -24...+24 hours and matching actual UTC dates by the shifted instant.
  Never shift packed arrays across acquisition gaps;
- initial-day exclusion and full-period metrics kept separate.

The declared absolute **2e-4** scalar comparison tolerance accommodates
the small exported-pair versus archived-summary numerical differences
(notably several HEMP records). It does *not* describe physical
measurement uncertainty. The maximum lag-correlation tolerance is 2e-6.
Counts and best-lag hours are exact.

### Important original-data caveats

The common 3,026-pair series have **159 missing hourly positions** across
five shared outages between their first and last paired times:
- 2025-11-28 06:00 -> 13:00 UTC (6 missing);
- 2025-12-01 11:00 -> 2025-12-02 14:00 (26);
- 2025-12-03 01:00 -> 2025-12-04 16:00 (38);
- 2025-12-09 22:00 -> 2025-12-12 13:00 (62);
- 2026-02-08 06:00 -> 2026-02-09 10:00 (27).

**HEMP_INTERMEDIATE_140 temperature sensor 323**, explicitly
secondary/partial-coverage in the frozen registry, provides only
**1,237 paired hours** and ends on 2026-03-19. Its additional gaps
include 773 and 436 missing-hour runs. Do not treat its metrics as
full-campaign comparables.

HEMP_WARM_390 RH has **3,025** pairs instead of the corresponding
3,026 temperature pairs; the extra missing RH hour is
**2025-12-04 16:00 UTC**.

**All five RH comparisons** choose their best lag at one of the
\`[-24,+24]\` search bounds. A boundary-selected lag is a *censored
search result*, not a measured physical response delay. Several RH
correlations are weak or negative, further limiting mechanistic claims.
This caveat applies even though the numerical lag implementation
reproduces the archive exactly.

## Both final WUFI post-processing products

Each wall has original archived WXF files for temperature, RH, dew
point, layer water content and total water content. The complete
real-valued series were independently read and checked:

| Wall | T/RH/dew positions | Hourly points per series | Dew values formula-checked | Max difference |
| --- | ---: | ---: | ---: | ---: |
| REF | 14 | 3187 | 44,618 | 1.78e-14 deg C |
| HEMP | 17 | 3187 | 54,179 | 1.78e-14 deg C |
| **Total** | **31** | 3187 | **98,797** | **1.78e-14 deg C** |

In each case, \`DewPointC\` agrees with independent recomputation from
the stored temperature and RH using the actual Wolfram production
formula \`gamma=log(RH/100)+(18.678-T/234.5)*T/(257.14+T)\`,
\`dew=257.14*gamma/(18.678-gamma)\`. All T/RH/dew series are finite.
In both wall cases **12 layer-water-content series and 1 total-water
series** are present, 3187 hours each, finite and nonnegative.

**Not yet checked:** weighted integration of layer water content to
the total-water-content product. Their physical units/thickness weights
must be verified from the authoritative WUFI layer manifest; directly
adding layer moisture concentrations is dimensionally inappropriate.

## Repeat the private acceptance without publishing source data

Use the public, read-only \`python_tools.final_two_case_archive_audit\`
module with authorized local copies of the final comparison records.
The WXF directory must have \`REF/\` and \`HEMP/\` subdirectories,
each containing \`S01_*.wxf.bin\` etc. Original postprocessor exports
use \`postprocessor/REF|HEMP/{temperature,relative_humidity,dew_point,
layer_water_content,total_water_content}.wxf.bin\`.

\`\`\`bash
python -m python_tools.final_two_case_archive_audit \
  --comparison-wxf-root PRIVATE/final_compare_wxf \
  --comparison-summary-csv PRIVATE/comparison_summary.csv \
  --comparison-manifest-json PRIVATE/comparison_manifest.json \
  --alignment-audit-json PRIVATE/time_alignment_audit.json \
  --postprocessor-root PRIVATE/postprocessor \
  --out-json PRIVATE/final_two_case_archive_acceptance.json
\`\`\`

The command writes only a **private** aggregate JSON comparison;
its public GitHub CI uses entirely **synthetic** tests. The original
WUFI/Mathematica production code is not changed by this audit.

## Git LFS bridge: capability and release boundary

Connected production Research LFS Bridge status: Git-LFS native backend
configured, Google Drive Auth0-WIF input supported, maximum
**536,870,912 bytes** per source file. That is sufficient in principle
for the Drive \`Archived_results.7z\` file (352,901,779 bytes), which
exceeds the regular Drive->ChatGPT 256 MiB download limit.

The actual \`WUFI_infractructure_codebase\` repository is **PUBLIC**.
Git LFS does **not** add content confidentiality and an LFS pointer
committed to a public branch would expose its underlying object.
Therefore **no original private archives were uploaded** to that repo;
no LFS \`prepare_upload\`/\`commit_upload\` was performed. If we ever
need that large archive, first agree a private, access-controlled
destination and its retention/permission policy. This two-wall-model
audit did NOT require a large-file transfer.

## Remaining distinct gates

- Original five-case 13-gate Wolfram equivalence suite has not been
  rerun in Wolfram 15; frozen RC2/RC3 audit is separately documented.
- Timezone portability correction remains draft PR #21 pending
  12.1/Windows verification.
- Historical WAC strict parity remains failed at three near-horizon
  interpolation hours; scientific exception not approved.
- Original radiometer calibration/mounting and licensed WUFI Pro import
  remain pending.
- No final publication-grade software release tag or private dataset
  publication has been authorized.
