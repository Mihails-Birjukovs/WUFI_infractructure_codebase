# Full WAC replay against the authorized REF/HEMP audit

The prior independent **equation-level** replay recovered the 17,520-hour
archived WAC to within 1e-6 W/m² at 17,517 hours. Three near-horizon
daylight gaps remain different by at most ~0.216 W/m²; those three
\`clearness_index_kt\` archive values differ from their adjacent measured
same-clock-hour interpolation. The independent calculation did **not**
import the actual pvlib library, so the official full-module replay is
an *additional* acceptance gate.

Run this utility in a local Python environment with
\`python_tools/requirements.txt\` installed and **authorized** private files:

\`\`\`powershell
python -m python_tools.replay_wac_reference PRIVATE/Spilve_solar_hourly_audit.csv PRIVATE/Spilve_exterior_full_2025_2026_padded_solar_corrected_Erbs_ISGH_ISD.wac PRIVATE/new_rebuilt.wac --report-json PRIVATE/wac_validation.json --diff-csv PRIVATE/wac_deviations.csv
\`\`\`

The script executes the **actual** repository's \`reconstruct_from_audit\`
with installed \`pvlib\`, writes WAC_02 and compares all 17,520 rows,
radiation columns, other meteorological fields, integral solar energy
and timestamps. It reports strict parity against 1e-6 W/m² and exposes
an **optional** \`--science-tolerance\` (W/m²) for an explicitly agreed
scientific threshold. By default, no science tolerance is assumed.

Do not commit the private audit, new WAC, detailed differences, or raw
sensor data. Synthetic tests cover the runner under GitHub Actions.

The physical station \`solar_radiation\` measurement plane and calibration
must still be verified before claiming that the assumed GHI interpretation
is physically validated. WUFI import requires a licensed WUFI installation.
