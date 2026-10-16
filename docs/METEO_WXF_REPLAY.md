# Streaming meteorological WXF conversion for Phase-4 modal replay

The private REF & HEMP sensor archive includes raw
\`meteo_data.wxf\` (187,761 minute-level observations, ~45 MiB).
\`meteo_raw_wxf.py\` streams its Wolfram WXF List of Associations to pandas
without Mathematica or publishing any raw data. It does **not evaluate**
Wolfram source expressions.

\`\`\`python
from python_tools.meteo_raw_wxf import meteo_samples, centered_hourly_meteo
import pandas as pd
raw = meteo_samples("PRIVATE/meteo_data.wxf")
grid = pd.date_range("2025-12-12 12:00",
                     "2026-02-08 07:00", freq="h")
hours = centered_hourly_meteo(raw, grid)
\`\`\`

Original meteo fields: \`temp_out\`, \`humidity_out\`, \`temp_in\`,
\`humidity_in\`, \`solar_radiation\`, \`wind_speed\`. Meteo
\`humidity_out\`/\`humidity_in\` are percentages; derivation of
vapour pressure uses the Buck relationship. Missing source intervals
remain NaN rather than being silently zero-padded or interpolated.

This reader is limited to the actual version-8 uncompressed archived
WXF record form and is intentionally not a generic Wolfram exchange parser.
Historic source QC and forcing normalization are separate acceptance steps.
