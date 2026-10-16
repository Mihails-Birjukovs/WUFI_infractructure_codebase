# Historical Phase-4 DMDc — independent replay, not yet full parity

A direct replay of the two original hourly windows from
the private REF & HEMP WXF archive is possible **without Mathematica**.

Original source ingredients:
- \`sensor_hempcrete_27.wxf\`, \`sensor_hempcrete_19.wxf\`,
  \`sensor_reference_118.wxf\`;
- matched Phase-4 WUFI comparison-group T/RH WXF files for
  HEMP80 mm/REF120 mm;
- the original 187,761-record \`meteo_data.wxf\` meteorological stream;
- archived \`dmdc_inputset_robustness_ratios.csv\`.

The implementation builds each hourly state \`[T,p_v]\` using raw
sensor-centered medians (±30 min), WUFI at matched sensor depth,
**Buck** \`p_v\`, separately centered experiment and WUFI, common
experimental population SD scaling, and hourly exterior forcing
\`p_v,out\` reconstructed from raw meteorological centered medians.
The state-lag-only DMDc uses current forcing, two chronological windows
W1/W2, 70/30 joint ridge validation, state delays 12,24,48,
and 72-hour impulse responses. The source archives report five forcing
sets, but this initial constrained replay uses **\`outpv_only\`** to avoid
collinearity; it compares 18 archived rows.

Run with an authorized local private sensor manifest (same schema as
\`docs/PHASE4_FULL_REPLAY.md\`, but only HEMP27/HEMP19/REF118), the
original \`meteo_data.wxf\` and archived DMDc summary:

\`\`\`powershell
python -m python_tools.replay_phase4_dmdc PRIVATE/sensor_manifest.json PRIVATE/meteo_data.wxf PRIVATE/dmdc_inputset_robustness_ratios.csv --output-csv PRIVATE/dmdc_outpv_replay.csv
\`\`\`

**Important:** The original transient Phase-4 source script/ridge grid/
crossvalidation scoring details were not retained. This reference uses
a documented ridge grid \`(0,1e-8,1e-6,1e-4,1e-2,1,100)\` and
teacher-forced one-step validation. No post hoc ridge choice is applied
to make stored results agree. Consequently, this runner is a
**diagnostic research replay**, NOT a historical numerical acceptance
test with guaranteed identity.

An independent local exploration of the same WXF inputs recovered HEMP27
and HEMP19 W2 12/24/48-h peak-gain ratios and lags to displayed
precision when joint ridge was chosen on the 70% training segment.
W1 and REF controls still show differences because the original
preprocessing/ridge decisions are incompletely specified; those results
remain unverified.

Do not publish source WXF, private hourly forcing/state arrays, or
local rowwise outputs without a data-release review.
