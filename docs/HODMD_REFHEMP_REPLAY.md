# REF/HEMP Phase-4 HODMD qualitative reproduction

The source archive \`hodmd_target_stability.csv\` contains period
distributions and stability fractions from **39 accepted delay/rank fits**
per system/window/source/target. The original scripts defining frequency
acceptance windows, amplitude weighting and preprocessing were not retained.

The public \`python_tools.dmd.delay_dmd\` module is a *new reference exact
DMD of time-delay snapshots*, not the historical analytic-signal
paper-style higher-order implementation. Recovered private Phase-4
hourly T/p_v arrays support an independent scan using embedding lengths
12/24/36/48/72 and ranks 4/6/8/10/12/16/20/24.

An exploratory private scan in the authorized REF & HEMP archive recovered
**~24-hour eigenperiods in both experiment and WUFI** for HEMP27, HEMP19
and REF118 across both historical windows. Selected W2 modes were within
~0.02–0.1 h of 24 h, consistent with the reported dominant daily
periodicity. However, selecting the nearest 24-hour eigenvalue is **not**
the archive's rank/delay stability aggregation. The archive's period
medians and stability fractions were **not** numerically reproduced.

The historical 2026-08-24 modal report states that ~24-hour frequency
agreement alone does not demonstrate correct moisture-transfer physics.
The stronger physical diagnostic is the low-collinearity outdoor-vapour
pressure DMDc impulse-gain/lag comparison; see \`DMDc_FULL_REPLAY.md\`.

Reproducing archive HODMD numerically would require the original
analytic-signal and edge-trimming specification, mode selection/ranking,
stability-score definition, and exact runtime numerical settings.
Do not treat this method-class check as exact model parity.
