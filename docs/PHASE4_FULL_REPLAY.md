# Full Phase-4 multiscale replay from original REF/HEMP WXF files

**Status:** The archived 60/60 main rows (\`band_metrics.csv\`) and 135/135
RH cutoff robustness rows (\`cutoff_robustness.csv\`) were independently
regenerated in an isolated Python environment on 2026-10-17 from the
authorized Drive sensor/WUFI WXF files; no measured data are in GitHub.

The reproduction uses:
- Five **individual** raw sensors: HEMP27, HEMP19, HEMP42, HEMP18, REF118;
- archived Phase-4 comparison WXF for **WUFI at the matched depth**;
- hourly ±30 min raw-sensor median in UTC; raw period 2025-11-27 16:00
  through 2026-04-08 09:00 UTC inclusive;
- two independent complete filtering windows W1 (1388 h) / W2 (1393 h);
- fourth-order zero-phase Butterworth, low-pass cutoffs 1/72 and 1/12 h⁻¹,
  subtractive 12–72 h band and <12 h event band, with 72 h edge trim;
- **Buck** vapour pressure (Pa):
  \`pv = RH/100 * 611.21 * exp((18.678-T/234.5)*T/(257.14+T))\`;
- **population SD (ddof=0)**, matching the frozen Phase-4 tables;
- cutoff grid 48/72/96 h × 8/12/18 h for RH.

The direct numerical comparison with archived rows yielded:

| Quantity | Maximum absolute difference |
|---|---:|
| Main RMSE (60 rows) | 4.31e-9 in variable's units |
| Main bias | 1.11e-9 |
| Main MAE | 2.84e-9 |
| Main sensor SD | 4.78e-9 |
| Main WUFI SD | 4.01e-9 |
| Main amplitude ratios | 1.17e-9 |
| Main correlations | 2.50e-9 |
| Cutoff RMSE (135 rows) | 2.19e-7 |
| Cutoff correlations | 3.93e-7 |
| Sample count discrepancies | 0 |

The **best-lag correlation/lag columns** in the archived main table are not
evaluated by this runner; the comparisons cover all other numerical columns.

## Running locally with approved data

Create a private JSON manifest with these five exact keys and paths to
the sensor and comparison WXF files:

\`\`\`json
{
  "HEMP27": {
    "sensor_wxf": "PRIVATE/sensor_hempcrete_27.wxf",
    "model_temperature_wxf": "PRIVATE/HEMP/C02/S01_temperature.wxf",
    "model_humidity_wxf": "PRIVATE/HEMP/C02/S01_relative_humidity.wxf"
  },
  "HEMP19": {
    "sensor_wxf": "PRIVATE/sensor_hempcrete_19.wxf",
    "model_temperature_wxf": "PRIVATE/HEMP/C02/S01_temperature.wxf",
    "model_humidity_wxf": "PRIVATE/HEMP/C02/S01_relative_humidity.wxf"
  },
  "HEMP42": {
    "sensor_wxf": "PRIVATE/sensor_hempcrete_42.wxf",
    "model_temperature_wxf": "PRIVATE/HEMP/C02/S04_temperature.wxf",
    "model_humidity_wxf": "PRIVATE/HEMP/C02/S04_relative_humidity.wxf"
  },
  "HEMP18": {
    "sensor_wxf": "PRIVATE/sensor_hempcrete_18.wxf",
    "model_temperature_wxf": "PRIVATE/HEMP/C02/S05_temperature.wxf",
    "model_humidity_wxf": "PRIVATE/HEMP/C02/S05_relative_humidity.wxf"
  },
  "REF118": {
    "sensor_wxf": "PRIVATE/sensor_reference_118.wxf",
    "model_temperature_wxf": "PRIVATE/REF/C02/S01_temperature.wxf",
    "model_humidity_wxf": "PRIVATE/REF/C02/S01_relative_humidity.wxf"
  }
}
\`\`\`

The HEMP19 80 mm WUFI curve is shared with HEMP27, but HEMP19 is explicitly
excluded from default calibration and used only for independent diagnosis.
The REF temperature comparison *group* pools multiple sensors; taking the
individual raw REF118 median avoids incorrectly comparing a group median
against a single-sensor historic result. Similarly, HEMP42 T must be
read from raw sensor 42, not the pooled 42/43 group median.

\`\`\`powershell
python -m python_tools.replay_phase4_multiscale PRIVATE/manifest.json PRIVATE/band_metrics.csv PRIVATE/cutoff_robustness.csv --output-dir PRIVATE/replay_output
\`\`\`

The output contains numerical summaries and archived table comparisons.
Keep the raw manifest, sensor recordings, production WXF inputs and all
private per-hour data out of the public repository.

## Best-lag parity (additional acceptance, 2026-10-17)

The archived two lag columns `best_lag_corr` and `best_lag_h` have now
been recomputed from the original 60 reconstructed sensor/WUFI series.
The historical convention is to scan **all integer lags from −24 through
+24 h**, calculate Pearson correlation of overlapping samples at each lag,
and select the lag with the **maximum absolute correlation**, retaining
its sign. Positive lag compares the sensor at time t with WUFI at t+lag.

The accepted saved metrics operate on the raw 3010 valid hourly pairs or
the concatenation of 2493 edge-trimmed filtered hourly pairs from the
two historical windows. No artificial samples are added at the boundary.

Independent private replay findings:
- **60/60** archived best-lag hours reproduced exactly.
- Maximum absolute best-lag correlation discrepancy: **3.94446e-10**.
- Mean absolute best-lag correlation discrepancy: **3.13139e-11**.
- This completes all numerical fields of the **60 main band-metric rows**.
- The 135 cutoff-robustness comparisons remain as previously passed.
