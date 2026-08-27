(* ::Package:: *)

(*
  User-editable configuration for MongoDB/WUFI sensor comparison Production v1.2.0.
  Target platform: Wolfram Mathematica 12.1 on Windows.
*)

If[!ValueQ[sensorComparisonCodeRoot],
  sensorComparisonCodeRoot = Quiet@Check[NotebookDirectory[], Directory[]]
];

mainRoot = "D:\\Science\\NMI\\WEED Project\\Fibrolite Materials RTU 2026";
sensorComparisonWorkingRoot = FileNameJoin@{mainRoot,"Sensors VS WUFI"};
sensorDataRoot = FileNameJoin@{mainRoot,"Sensor Data"};
sensorRegistryRoot = FileNameJoin[{sensorDataRoot, "Sensor_registry"}];
sensorRegistryVersionRoot = FileNameJoin[{sensorRegistryRoot, "2026-08-26_FINAL_runs"}];
projectDataRoot = FileNameJoin@{mainRoot,"WUFI"};
toolsFolder = "D:\\Science\\NMI\\WEED Project\\Tools";

sensorComparisonUserSettings = <|
  "ProjectRoot" -> projectDataRoot,
  "InputMode" -> "SelectedWXF",

  "SensorDataRoot" -> sensorDataRoot,
  "RawJSONPath" -> FileNameJoin[{
    sensorDataRoot,
    "MonitoringHousMaris.spilve_full_dataset.json"
  }],
  "MXCachePath" -> FileNameJoin[{
    sensorDataRoot,
    "MonitoringHousMaris.spilve_full_dataset.mx"
  }],
  "SelectedSensorDirectory" -> FileNameJoin[{
    sensorDataRoot,
    "Selected Sensors"
  }],
  "MeteoWXFPath" -> FileNameJoin[{
    sensorDataRoot,
    "meteo_data.wxf"
  }],

  "CanonicalRegistryPath" -> FileNameJoin[{
    sensorRegistryVersionRoot,
    "canonical_sensor_registry_2026-08-06_v3_calibration.wl"
  }],
  "LIMCurveDirectory" -> FileNameJoin[{
    DirectoryName@sensorComparisonCodeRoot,
    "LIM Curves"
  }],

  "ProductionRunRoot" -> FileNameJoin[{
    projectDataRoot,
    "WUFI_FINAL_Wall_Models_2026-08-25"
  }],
  "WUFIManifestPath" -> FileNameJoin[{
    projectDataRoot,
    "WUFI_FINAL_Wall_Models_2026-08-25",
    "WUFI_export_manifest.wl"
  }],

  "OutputRoot" -> FileNameJoin[{
    sensorComparisonWorkingRoot,
    "WUFI_FINAL_wall_models"
  }],


  "SelectedCases" -> {
  "Wall_REF_P5_L125_CV100_M200_W0_V070_A00",
  "Wall_hemp_P5_CORR_M200_S125_LT1000_W0_V070_A00"
},

"CaseWallSystemRules" -> {
  "Wall_REF" -> "REF",
  "Wall_hemp" -> "HEMP",
  "Wall_HEMP" -> "HEMP"
},

  (* Time handling: MongoDB is UTC; WUFI wall-clock labels are fixed UTC+2. *)
  "SensorTimeZone" -> 0,
  "WUFIFixedTimeZone" -> 2,

  (* Primary robust state-estimation method. *)
  "AggregationMethod" -> "CenteredWindowMedian",
  "MinimumSamplesPerHour" -> 3,
  "MinimumCoverageFraction" -> 0.5,
  "MinimumGroupContributors" -> 1,
  "NearDuplicateToleranceSeconds" -> 1.,

  (* Spatial matching tries exact, then same-material interpolation, then nearest. *)
  "SpatialMethod" -> "Auto",
  "ExactDepthToleranceMetres" -> 0.002,
  "MaximumNearestDepthOffsetMetres" -> 0.03,
  "AllowSameMaterialExtrapolation" -> False,

  (* Partial-coverage temperature channels remain available; secondary RH stays opt-in. *)
  "IncludeSecondaryTemperature" -> True,
  "IncludeSecondaryRH" -> False,

  "UseParallel" -> True,
  (* Automatic caps parallel work to the useful task count. Controller-kernel
     sensor/WUFI caches survive plot-kernel recycling. *)
  "MaximumKernels" -> Automatic,

  (* v1.2 graphics lifecycle: render tasks in parallel, export serially on the
     controller, recycle subkernels at each wall/case boundary, validate every
     JPEG, and retry a failed plot serially on the controller after recycling
     the plot kernels. *)
  "ParallelPlotGeneration" -> True,
  "RecyclePlotKernelsPerBatch" -> True,
  "ClosePlotKernelsAfterBatch" -> True,
  "ClearSystemCacheAfterPlotBatch" -> True,
  "GraphicExportRetryCount" -> 1,
  "GraphicRetryOnController" -> True,
  "GraphicStagingDirectory" -> Automatic,
  "GraphicsAuditFailOnUnexpectedFiles" -> True,
  "GraphicMinimumWidthPixels" -> 200,
  "GraphicMinimumHeightPixels" -> 200,
  "GraphicMinimumByteCount" -> 4096,
  "RunGraphicsAudit" -> True,

  (* Full production output. Set to "ComputeOnly" to defer all JPG rendering;
     later call RenderExistingComparisonOutput[outputRoot, settings]. *)
  "ExecutionProfile" -> "ProductionFull",

  (* Reuse identical wall/grid sensor preparation across WUFI cases. *)
  "ReuseSensorPreparationByWallAndGrid" -> True,
  "WriteSensorOnlyOutputsOncePerWallSystem" -> True,
  "RetainPreparedSensorsInRunResults" -> False,
  "ExportResolution" -> 500
|>;
