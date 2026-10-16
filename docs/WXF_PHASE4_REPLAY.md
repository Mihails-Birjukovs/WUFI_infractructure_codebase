# Replaying REF/HEMP Phase-4 WXF time-series data

The repository contains no original REF/HEMP measurements. The authorized
Drive archive retains **Wolfram WXF binary** files for the Phase-4 comparison
bundles, including the actual hourly sensor/WUFI pairs. The narrow
\`python_tools/wxf_subset.py\` reader decodes these files without Mathematica.
It **does not evaluate Wolfram code**, and it is not a complete WXF decoder.

Example, with a private local copy of an archived Phase-4
\`S01_temperature.wxf\`:

\`\`\`python
from python_tools.wxf_subset import comparison_pairs

metadata, paired = comparison_pairs("private/HEMP/S01_temperature.wxf")
print(metadata)  # HEMP_COLD_80, sensor_ids=[27], ...
print(paired.head())  # TIME_UTC, sensor, wufi, residual
\`\`\`

The archive also retains \`sensor_hempcrete_27.wxf\` with raw irregular sensor
samples; \`raw_sensor_samples\` can read that. Restore near-boundary hourly
values with \`centered_raw_median\` only for an **explicit sensitivity check**.
That routine does *not* apply all production sensor QC rules.

Historical Phase-4 method: fourth-order zero-phase Butterworth; 72 h and
12 h cutoffs; contiguous segments >=240 hours; trim 72 h on each side.
Run \`butterworth_band_metrics\` on a shared continuous UTC grid and compare
against archived \`band_metrics.csv\`; do not interpolate across gaps.

## Independent reconstruction observation (2026-10-17)

The HEMP27 comparison bundle contains **3026** paired hourly rows. The two
long contiguous segments contain 1386 and 1392 hourly pairs, whereas the
archived historical analysis used 1388 and 1393. The three differences are
2025-12-12 12:00 UTC, 2026-02-08 07:00 UTC and
2026-02-09 09:00 UTC.

In a **private exploratory calculation**, restoring those three hours
from raw HEMP27 WXF using ±30-minute centered medians yielded 2493
band samples, identical to the archived sample count. Across its three
Butterworth bands, temperature and RH band RMSEs then differed from the
archived table by no more than approximately 1.04e-5 in the respective
measurement units. Raw-signal windows and full per-sensor QC still require
reconciliation; this near-match is not a byte-identical production replay.

**Warning:** the REF_COLD_120 *temperature* comparison group includes
sensor IDs 118, 125, 126 and 141, so its temperature group median **must not**
be treated as the archived individual REF118 temperature series. The
REF_COLD_120 RH group includes only sensor 118.

See \`docs/REF_HEMP_ACCEPTANCE_PROTOCOL.md\` for the separate scientific gates.
