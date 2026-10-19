# Climate forcing and WAC files

The Python branch includes a **WAC_02 generator** that prepares end-labelled hourly WUFI climate records from a quality-audited table. It does not measure radiation, establish radiometer calibration or automatically verify the resulting WUFI model.

## Audited input contract

Required CSV columns are **TIME, TA, HREL, WD, WS, PMSL, source_GHI, source_available**. Input timestamps must be hourly, continuous and ordered, and use one explicitly defined **fixed UTC offset**. Confirm solar irradiance units (W/m²), temperature units (°C), humidity as **0–1 fraction**, wind direction/speed and pressure convention before WUFI import.

Output WAC order is **TIME TA HREL ISGH ISD WD WS PMSL**.

The retained REF/HEMP computational configuration uses **56.97°N, 24.17°E** for solar geometry and **UTC+2 fixed time**. The independently documented physical building coordinates are different; a new site scenario must override coordinates deliberately and report it as a change, not a silent correction.

## Solar decomposition

A historical model treated the field named solar_radiation as GHI and applied clearness-index reconstruction and **pvlib Erbs** for diffuse/direct partitioning. The experimental radiometer's physical plane/orientation and calibration have not yet been independently established. Therefore **the database field name and numerical agreement do not certify GHI as the actual measured quantity**.

Daylight gaps require a scientifically justified reconstruction policy. Full-record source comparisons show only **three near-horizon reconstruction exceptions**, each less than approximately 0.216 W/m², under the audited reconstruction tolerance; this does **not** mean exact pointwise replay of the new Python implementation has been achieved. The separately archived WAC and hourly audit compare essentially to floating-point precision, a distinct test.

## Do not conflate time bases

- MongoDB ISO UTC timestamps are observational time coordinates.
- WAC climate labels are **end-of-hour** fixed-standard-time labels.
- **Europe/Riga DST** is not the historical WAC conversion rule.
- A sequence with missing samples or many identical timestamps is not a valid regular hourly series until explicitly cleaned, inspected and documented.

## Production checklist

1. Obtain authorized original meteo records and assess continuity.
2. Confirm radiation acquisition/plane provenance; record assumptions and instrument unknowns.
3. Remove/flag invalid timestamps, never silently infer missing measurement times.
4. Build an immutable hourly source-audit table.
5. Generate WAC with explicitly recorded coordinates and standard-time convention.
6. Run numeric audit and **verify WUFI's imported climate and orientation**.

[Source module](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/python_tools/wac_from_audit.py) · [full replay notes](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_python_tools/docs/WAC_FULL_REPLAY.md).

**No private raw data or report illustrations are distributed from this site.**
