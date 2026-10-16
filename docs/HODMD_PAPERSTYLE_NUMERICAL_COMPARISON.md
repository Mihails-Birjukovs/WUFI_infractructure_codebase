# Independent HODMD paper-style cross-check (not accepted historical parity)

The REF & HEMP Drive retains two distinct modal references:

1. **hodmd_target_stability.csv** — 112 aggregated sensor/window/source/
   target records, using *39 valid fits per combination*, from the
   original delay/rank method.
2. **paperstyle_hodmd_24h_crosscheck.csv** — 480 per-fit records from a
   second implementation described in modal_assessment_report.md as
   analytic-signal preprocessing, edge trimming, delay stacking and
   forward/backward reduced operators.

The historical scripts and precise mode-selection/stability criteria are
**not retained**, and the two references must not be conflated.

## Independently tested candidate

A new diagnostic function \`hodmd_paperstyle_reference.py\` implements:

- Two aligned states [T, Buck pv] on experimental population SD scales.
- Complex analytic signal via Hilbert transform, **24-hour** edge trimming.
- Delay stack d=24/36/48/72 with truncated ranks 6/8/10/12/16/20.
- Forward and backward reduced operators from separate truncated SVDs,
  averaged as \`(A_forward + pinv(A_backward))/2\`.
- Positive-frequency eigenmode **nearest 24 h** (this is a documented
  diagnostic choice, not a recovered original mode-acceptance criterion).

The 480-fit comparison to the independent archive yielded:

| Comparison | Result |
| --- | ---: |
| Total fit inventory | 480/480 |
| Median absolute period difference | 0.392 h |
| 90th percentile absolute period difference | 4.947 h |
| Number of periods within 0.1 h | 141/480 |
| Number of periods within 1 h | 314/480 |
| Median absolute eigenvalue-modulus difference | 0.001104 |

No archived HODMD stability fractions were reproduced by this scan. The
period-mode-selection and filtering/edge policies remain underdetermined;
a closer match for an individual example is **not** proof of method parity.

By comparison, using the analytic pipeline without any edge trim gave
a median period difference 0.832 h and 80/480 periods within 0.1 h.
The 24-hour trim is a physically motivated sensitivity case, not
a proven historical setting.

## Private replay

\`\`\`powershell
python -m python_tools.hodmd_paperstyle_reference PRIVATE/five_sensor_manifest.json PRIVATE/paperstyle_hodmd_24h_crosscheck.csv --trim-hours 24 --output-dir PRIVATE/hodmd_replay
\`\`\`

This produces a private per-fit CSV and a JSON discrepancy report. Synthetic
tests verify periodic-mode detection. Do not change published HODMD
frequencies/stability based on a candidate implementation that does not
match the original archive.

**Release gate:** retain HODMD as *method-class/qualitative* reproduced,
not full numerical acceptance. Exact archival stability scoring requires
the original fit mode-selection thresholds/amplitude filters/edge rules,
or a separately sourced full per-fit audit of the original implementation.
