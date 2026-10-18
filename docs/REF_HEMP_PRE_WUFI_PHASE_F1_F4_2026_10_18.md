# REF/HEMP — Phases F1–F4, pre-WUFI internal RC (18 October 2026)

**Classification: internal scientific software release candidate, not WUFI Pro import certified, not Mathematica 12.1 certified, and not physically calibrated. No release tag is created.**

## F1 — exact committed Phase E execution: PASSED

The Python module scientific_phase_e.py was retrieved from merge commit
73900394c64d1a717eda29283a0900ef931f0305 using a temporary, unmerged
GitHub Actions source-only artifact. The downloaded module's Git blob SHA
(317bf9b31dd62ef9512794049d7f0ab1603ffc77) agrees with GitHub
fetch_file at that commit; its SHA-256 is
c1869052a2d27975995d9188e8456fc5585c1539a82be9a9777e8a52e57ad90b.

It was executed locally with the original authorized five sensor WXFs
and aligned meteorological hourly file: five sensors x W1/W2, each with
99 AR(1) null draws, five constant calibration-offset cases and
recursive 1/6/12/24/48/72-hour DMDc hindcasts.

Compared with the *separately written* prior local implementation:
- 10/10 window/sensor simulated AR(1) sequences' 99 accepted-mode counts
  agree exactly (990/990 individual null outcomes).
- 10/10 static-offset HODMD acceptance-count sets agree exactly.
- Ten calibration vapour-pressure median-envelope widths agree exactly.
- Maximum difference of any recursive forecast RMSE/persistence ratio
  across 10 cases x 2 forcing sets x 6 horizons: 9.13e-11.
- Empirical surrogate-tail fractions agree exactly.

The public CI remains *synthetic only*. The local source hash and private
original-data output fingerprint are retained separately, not posted.

## F2 — interchange preflight: STRUCTURAL PASSED

The original archived WAC_02 file has exactly 17,520 fixed-UTC+2
hourly end-labelled records from 2025-01-01 01:00 to 2027-01-01 00:00,
with columns TIME, TA, HREL, ISGH, ISD, WD, WS, PMSL.
HREL is a fraction (0..1), radiation fields are nonnegative with
DHI <= GHI. The structural WAC checks pass; this is NOT an actual
WUFI Pro import test and does not approve the three known radiation gaps.

The archived S01 paired WUFI temperature/RH WXFs contain 3,187
matching UTC hourly samples from 2025-11-26 16:00 through
2026-04-08 10:00; RH is stored in percent in the WXF output.
Read-only WXF v8 subset parsing and paired UTC alignment pass.

A connected remote Wolfram Language kernel was verified as
**15.0.1 for Linux x86 (64-bit)**. Eigenvalues and binary WXF
export/import roundtrips work. It cannot directly see private
ChatGPT working files: FileExistsQ on a /mnt/data WXF returned False.
Sending an authorized 24-hour bounded S01 WUFI-derived temperature/RH
sample to the kernel independently reproduced the Python results:
mean T=5.282034508333335 C, sample SD=2.2915851673162124 C,
mean Buck vapour pressure=835.5118817831241 Pa.

Thus remote Wolfram enables selected algorithm verification already,
but it is a stateless Mathematica v15 Linux environment; it does
NOT establish full .nb notebook execution, Mathematica 12.1 Windows
compatibility, or WUFI Pro application import.

A new **read-only** Python CLI wufi_interop_preflight.py validates
these structures, historical time/units and paired WXF alignment.
Public tests use generated synthetic WAC and mocked WXF series.

## F3 — provenance closure: PARTIAL, evidence requests remain

Review of the original solar audit/WAC shows:
- radiation column was interpreted as global horizontal irradiance
  (GHI); this is **a data-processing interpretation**, not verified
  pyranometer orientation/calibration;
- actual historical coordinates used by the reconstruction are
  56.97 N, 24.17 E with fixed UTC+2 hour-end labels;
- original pvlib replay differs from archived radiation in exactly three
  near-horizon interpolation hours, at most 0.215687 W/m2;
  original kt overrides or historical script variant remain untraced.
- the optional 0.25 W/m2 *three-hour-specific* exception remains
  UNAPPROVED; strict 1e-6 W/m2 WAC numerical identity remains FAILED.

A targeted Google Drive and Gmail source search found RTU's 40-page
**Deliverable_test_house.docx**, shared 19 May 2026 under the
thread 'Test house monitoring data curation for M-era.net project'.
This document describes the as-built test-house concept and embedded
sensor integration, including wall layouts Figures 3.4–3.7,
and reference/hemp panel monitoring zones.

However, its searchable body did not give an unambiguous MongoDB
sensor-ID-to-layer mapping, a pyranometer model/tilt/azimuth,
radiometer calibration certificate, or serial-specific temperature/RH
sensor accuracy certificate. The report's figure labels/images may
deserve a separate manual original-document inspection: absence from
searchable body is not proof that no figure contains identifying markings.

**Action with experimental partners:** request (a) radiation sensor
model and mounting-plane drawings, (b) calibration/serial certificates,
(c) MongoDB logger-channel ↔ wall-position/depth map,
(d) original clearness-index gap treatment script or processing notes.
Do not silently fill these gaps from model agreement.

## F4 — internal release candidate readiness

Historical multiscale, DMDc and 112-row HODMD numerical reproduction,
Phase A–E exploratory scientific validation, exact merged Phase E
source replay, original WAC/WXF structural preflight and remote Wolfram
24-hour numeric cross-check are now available.

**No publication-ready/final release has been created.**
The readiness gates remain:
- WAC strict identity FAILED (three small archived differences).
- Scientific three-hour-only exception NOT APPROVED.
- Radiometer plane, instrument certificates and sensor IDs PARTIAL/PENDING.
- Actual WUFI Pro WAC import NOT EXECUTED.
- Full Mathematica notebook/Mathematica 12.1 Windows execution NOT EXECUTED.

The independent 480-fit analytic-signal HODMD investigation remains
a separate partially reproduced method, not a blocker for the original
112-row HODMD numerical benchmark.

## Private commands

From repository root with approved local files:

    python -m python_tools.scientific_phase_e PRIVATE/SENSORS PRIVATE/meteo_hourly_median.csv --sensors HEMP27 HEMP19 HEMP42 HEMP18 REF118 --draws 99 --output-json PRIVATE/phase_e_exact.json

    python -m python_tools.wufi_interop_preflight --wac PRIVATE/archived.wac --temperature-wxf PRIVATE/S01_temperature.wxf --humidity-wxf PRIVATE/S01_relative_humidity.wxf --out-json PRIVATE/interop_report.json

Run python -m pytest python_tools/tests, keep pinned reference
requirements-scientific-validation.txt and local SHA-256 source manifest.

Do not commit raw sensor/meteorology WXFs, historical WAC audit,
individual per-mode spectra or private data hashes.
