# Fresh independent HODMD and WAC acceptance — 18 October 2026

## Scope and security

The exact Python source committed at `cb522e843f36da7a354955ef80c5a4f43c3fd478` was retrieved alongside the publicly distributed `pvlib==0.16.1` wheel through a **temporary, unmerged** GitHub Actions dependency-export PR #14. Source and wheel SHA-256 checks passed. The wheel was installed offline in an isolated container, and the **original private REF/HEMP WXFs, audit, WAC and reference outputs were processed only locally**. No private data were uploaded to GitHub. The temporary PR was closed unmerged. A local private SHA-256 input manifest records all 16 research-source files.

Versions: Python 3.13.5, NumPy 2.3.5, pandas 2.2.3, SciPy 1.17.0, pvlib 0.16.1.

## Exact committed HODMD replay: passed

Executed `python -m python_tools.hodmd_historical_replay` using original WXF and frozen `hodmd_target_stability.csv`. The resulting **112/112 archived accepted/total fit counts** match exactly; all 112 available median periods, q10/q90, growth rates, mode amplitudes and loading components match within the committed script's numeric tolerances. Six-channel HEMP_PRIMARY output was included.

- Valid rank/delay/source fits: **628**.
- Positive-frequency candidate modes: **3,581**.
- Largest median-period error: **1.08411e-7 h**.
- Largest period-q90 error: **2.76754e-6 h**.
- Largest median-growth error: **1.03620e-11 h⁻¹**.
- Largest median-amplitude error: **6.39081e-10**.
- Source-identity cross-check: original committed source SHA-256 verified; a separate prior local numerical implementation generated identical 112 rows.

**Historical-source qualification:** the lost original HODMD transient script remains missing; the recovered selection conditions and `ddof=1` normalization were inferred retrospectively. This is independent source-WXF numerical reproducibility, not original code-text provenance or prospective threshold identification.

## Actual pvlib WAC replay: executed, three strict differences

Executed `python -m python_tools.replay_wac_reference` using the original **17,520-row** Spilve solar hourly audit and canonical archived eight-column WAC.

- All timestamps agree exactly; TA, HREL, WD, WS and PMSL match with zero maximum difference.
- **17,517/17,520 hours** agree in both radiation outputs within the strict `1e-6 W/m²` tolerance.
- **3 daylight source-gap hours** differ, all within a total of 23 daylight gap-interpolation records.
- Maximum ISGH/ISD absolute difference: **0.215687258 W/m²**.
- Archived integrated ISGH = **72.819339174173 kWh/m²**; rebuilt = **72.819362928522 kWh/m²**. Signed difference = **2.37543489531e-5 kWh/m²**, approximately **0.00003262%**.
- The committed replay correctly reports `strict_parity: false`.

| Fixed UTC+2 local-standard hour | New minus archived ISGH (W/m²) | New minus archived ISD (W/m²) |
|---|---:|---:|
| 2025-11-27 16:00 | +0.215687258 | +0.215687258 |
| 2026-02-08 17:00 | −0.010729653 | −0.010446985 |
| 2026-02-09 09:00 | −0.181203255 | −0.181203255 |

All three original audited clearness-index entries differ from what the retained same-clock-hour measured-kt interpolation reconstructs. The retained audit does **not** explain the historic processing overrides. Do not patch the reference dataset merely to force equality.

### Optional, not yet adopted scientific acceptance policy

Keep **global strict parity marked failed**. A narrow explicit exception could be scientifically reviewed: retain `1e-6 W/m²` everywhere else, allow at most **0.25 W/m² only at the three listed near-horizon source-gap hours**, preserve the exact exception and signed-energy table, and never present this as byte-identical historical output. This is an **unapproved proposal**, not a released default or a claim that the solar sensor's physical measurement plane is verified.

## Gates remaining

- Actual WAC CLI execution: **done**.
- Original HODMD 112-row end-to-end numerical regression: **done**.
- Historical WAC **strict** identity: **open**, three archival differences documented.
- Physical meaning/orientation of the original solar-radiation sensor: **not independently verified**.
- WUFI Pro import and Mathematica 12.1 on Windows: **pending authorized workstation**.

Publication approval must reflect the provenance and scientific-tolerance policy explicitly. No private datasets, reconstructed hour-level signals or modal eigenvalue catalogs are included in this repo.
