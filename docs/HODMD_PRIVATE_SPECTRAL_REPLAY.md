# Full private WXF HODMD spectral replay — 17 October 2026

The original REF & HEMP Phase-4 HODMD transient script has not been found.
Unlike previous paper-style/Hilbert tests, this forensic replay used the
original private sensor/WUFI WXF time series and a real-valued delay-DMD
operator on all **468 two-channel admissible fits**:
HEMP27, HEMP19, REF118 × W1/W2 × experiment/WUFI × 39 fits.

The independent source-level analysis produced 2,654 positive-frequency
candidate modes and compared **84 archived stability groups** (3 systems ×
2 windows × 2 sources × 7 targets) from \`hodmd_target_stability.csv\`.
The original full archive has 112 rows; the 28 six-channel
\`HEMP_PRIMARY\` rows were not tested because its original combined
six-state input mapping is not available in the individual sensor manifest.

## Strong recovered algorithm evidence

A transparent real delay-DMD and nearest-period eigenmode ranking
match archived periods and growth rates at machine-like precision
in many rows. The **39 valid configurations** per two-channel group
also match, after excluding nominal \`delay=12, rank=24\` (rank is not
strictly less than 24-dimensional embedding).

### Candidate multiplicative acceptance gate

A high-performing, **retrospectively inferred candidate** selects
eigenmode periods within:

\`\`\`text
target_period / 1.3 <= mode_period <= target_period * 1.3
\`\`\`

Then it selects the candidate mode closest in log-period to the target,
using at most one mode per delay/rank fit.

| Compared from original WXF | Multiplicative 1.3 | Additive ±25% baseline |
|---|---:|---:|
| Archived original HODMD groups | 84 | 84 |
| Exactly reproduced accepted-fit counts | **67/84** | 41/84 |
| Median absolute accepted-fit count error | — | — |
| Max accepted-fit count error | 4 | See private report |

In the multiplicative candidate, exact accepted counts:
**12/12 weekly, 12/12 two-week, 12/12 monthly, 12/12 72 h**;
also 9/12 at 48 h, 6/12 at 24 h, 4/12 at 12 h.
All remaining count mismatches are **positive** (our reference accepts
1–4 more fits than archived).

### Amplitude normalization

After recovering the eigenperiods and growth rates, the archived mode
amplitudes and the two component loadings showed a systematic ratio
between reference and archive of \`sqrt(N/(N-1))\`, for the original
window lengths N=1388 and N=1393. Correcting the reference amplitudes
by \`sqrt((N-1)/N)\` produces **65/84 archived group median amplitudes
and each component-loading median within 1e-8**, supporting
\`std(ddof=1)\` in the historical HODMD scaling.

At the multiplicative 1.3 gate, **70/84 period medians** and
**67/84 growth medians** match within 1e-7 of the archived value.
These exceptionally close values corroborate the **underlying real
delay-DMD operator** more strongly than the earlier paper-style
cross-check, but do not identify the original period/quality gates.

## Remaining short-period discrepancies

**17/84** accepted-fit counts still mismatch, all within the 12/24/48-h
targets. More permissive period gates alone overaccept modes; strict
nonpositive-growth or simple relative-amplitude filters did not
consistently remove the extra fits while preserving longer periods.

The first 84 rows were already examined before testing the multiplicative
gate. Thus it is **not a blind validation** of a predeclared hypothesis.
The 28 six-channel \`HEMP_PRIMARY\` rows are a valuable independent
test once the original six-state mapping is recovered.

## Reproduce securely

\`\`\`powershell
python -m python_tools.hodmd_mode_catalog PRIVATE/three_sensors.json --output-dir PRIVATE/hodmd
python -m python_tools.hodmd_archive_replay PRIVATE/hodmd/hodmd_private_full_modes.csv PRIVATE/hodmd/hodmd_private_fit_status.csv PRIVATE/hodmd_target_stability.csv --output-dir PRIVATE/hodmd
\`\`\`

Only the **public code and numerical summary** belong in GitHub.
All original WXF inputs, full mode catalogs, archived per-group
comparison tables and scratch state remain private. This runner
has synthetic CI tests; exact historical WXF reproduction requires
authorized source data.

## Scientific acceptance

- **Strongly supported:** real delay-embedded DMD operator, original
  fit grid, sample rather than population SD scale for modal amplitudes.
- **High-quality candidate, not source-verified:** factor-1.3
  multiplicative period gate and nearest-log-period ranking.
- **Open:** 17 short-period accepted-count discrepancies, original
  six-channel \`HEMP_PRIMARY\` state construction, historical code text,
  and precise eigenmode filters.

Do not label 112/112 HODMD stability results as reproduced or
alter the already accepted DMDc model.
