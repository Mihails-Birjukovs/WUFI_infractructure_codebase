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

## Archived near-horizon gap forensic check

The retained solar audit records 23 daytime GHI source gaps filled using
"source gap: same-hour kt interpolation (bracketed)". The documented
method predicts 20 archived hours within 1e-6 W/m². Three near-horizon
hours have *stored* kt values different from linear interpolation of the
audited source measurements at the preceding and succeeding clock-hour days.

- 2025-11-27 16:00 fixed UTC+2: rebuilt-minus-archive GHI ≈ +0.215687 W/m²
- 2026-02-08 17:00 fixed UTC+2: ≈ −0.010730 W/m²
- 2026-02-09 09:00 fixed UTC+2: ≈ −0.181203 W/m²

Run \`python -m python_tools.diagnose_solar_gap_kt PRIVATE/Spilve_solar_hourly_audit.csv --report-json PRIVATE/solar_gap_report.json --difference-csv PRIVATE/solar_gap_differences.csv\`.

The script reuses the archive's own solar geometry and extraterrestrial
radiation fields, so its differences isolate archived clearness-index
gap handling rather than Erbs DHI or new solar-position calculations.
It does not identify whether these three records were created by an
unretained source-code branch, a manual correction or another stage of
processing. Do not force the reconstructed results to equal the archived
kt values without such evidence.

The actual repository's pvlib CLI still requires a full original-audit
replay in an environment where pvlib is installed; the isolated container
used for this forensic check has no pvlib package or PyPI network access.
