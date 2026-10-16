# Complete historical DMDc numerical parity, 17 October 2026

The original REF & HEMP Phase-4 temporary code is not retained.
However, independent numerical replay against the original private sensor,
WUFI and meteorological WXF datasets identifies a single predictive
state-space model and fitting policy that reproduces the saved results.

## Recovered policy

- State vector: [temperature °C, Buck vapour pressure Pa].
- Force channels: T_out, outdoor_pv, solar, wind speed, T_in, indoor_pv.
- Each state series is centered independently and both use the
  experimental population SD as the shared scale.
- Each forcing channel is centered/standardized within the analysis window.
- Model: x[k+1] = Σ A_j x[k-j] + B u[k] (current forcing, not lagged u).
- Two complete UTC windows W1=1388 h and W2=1393 h.
- Ridge grid **inferred numerically**, not recovered verbatim from source:
  {0.001, 0.01, 0.1, 1, 10, 100}.
- Choose one shared ridge for experiment/WUFI by minimizing summed
  teacher-forced one-step validation MSE over the chronologically final
  30% of lagged observations.
- **Use the training-fit coefficients for all reported impulse and
  companion-memory diagnostics**. Do not refit on all observations.
- Impulse at control time k=0, state responses at hours 1...72.

## Independent private reproduction

| Frozen archive | Comparisons | Numerical result |
| --- | ---: | --- |
| dmdc_inputset_robustness_ratios.csv | 90 rows | All experiment/WUFI peak lags match; peak-gain ratio max abs error 0.003463 |
| delay_dmdc_memory_ratio.csv | 40 rows | Experimental/WUFI spectral-radius max abs errors 5.15e-6 and 8.31e-6; memory ratio max error 0.000292 |
| delay_dmdc_impulse_responses.csv | 960 rows | All peak lag hours exact; max peak-gain error 1.99e-5 and integrated absolute-gain error 6.88e-5; five sampled response values checked |

The 90-row table covers HEMP27, HEMP19, REF118 × W1/W2 × 5 forcing
sets × p=12/24/48. The 40-row memory and 960-row impulse tables cover
all five sensors, both windows, p=6/12/24/48 and six forcing channels.

These near-floating-point numerical deviations may reflect source
rounding, floating-point input conversion or linear-algebra solver
differences. Historical script identity has **not** been established.
The archive outcomes are therefore an independent numerical benchmark,
not evidence that the missing original program was recovered.

## Reproduce with authorized private files

Create a private five-sensor manifest as in PHASE4_FULL_REPLAY.md and run:

\`\`\`powershell
python -m python_tools.replay_phase4_dmdc_complete PRIVATE/manifest.json PRIVATE/meteo_data.wxf PRIVATE/dmdc_inputset_robustness_ratios.csv PRIVATE/delay_dmdc_memory_ratio.csv PRIVATE/delay_dmdc_impulse_responses.csv --output-dir PRIVATE/dmdc_acceptance
\`\`\`

Outputs are **private** comparison tables and a fieldwise difference
summary. No source timeseries or private meteorological arrays are
included in this Git repository. A public GitHub CI run only exercises
synthetic input and mathematical regression cases.

## Scientific interpretation

The archived low-collinearity HEMP27/HEMP19 gains remain ~4–10 times
higher than WUFI, whereas REF118 is near unity; in W2, the WUFI
companion dynamics are often more persistent. This is a diagnostic
association, not unique causal identification of construction defects.
