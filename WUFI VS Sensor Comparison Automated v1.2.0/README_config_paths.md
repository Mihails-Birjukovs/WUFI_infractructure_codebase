# Run 2 sensor-comparison configuration update — 2026-08-06

## Registry locations

Both configurations now resolve registries from:

`D:\Science\NMI\WEED Project\Fibrolite Materials RTU 2026\Sensor Data\Sensor_registry\2026-08-06`

The base production configuration uses:

`canonical_sensor_registry_2026-08-06_v2.wl`

The diagnostic patch overrides this with:

`canonical_sensor_registry_2026-08-06_v2_individual_diagnostics.wl`

## Selected production cases

The base configuration now selects only:

- `Wall_REF_60-40_filling`
- `Wall_hempcrete`

The 1GR, 3GR and CGR cases remain available for separately labelled material-hypothesis sensitivity analyses.

## Output directories

Base production-pair comparison:

`Output_v1_2_Prod2_ProductionPair_Run1`

Individual-sensor diagnostic comparison:

`Output_v1_2_Prod2_IndividualSensorDiagnostics_Run1`

## Usage

1. Place the updated `SensorComparisonConfig_v1_2.wl` in the comparison framework code directory, replacing or archiving the prior project-specific config.
2. Run the framework normally for the production canonical registry.
3. For the individual diagnostic run, load the updated base config first, then evaluate `SensorComparisonConfig_Run2_IndividualDiagnostics_patch.wl`.
4. No WUFI rerun or WUFI post-processing rerun is required.
