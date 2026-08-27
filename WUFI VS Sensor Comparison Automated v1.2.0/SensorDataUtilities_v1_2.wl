(* ::Package:: *)

BeginPackage[
  "SensorDataUtilities`",
  {"HygrothermalPlottingUtilities`"}
];

$SensorDataUtilitiesVersion::usage =
  "$SensorDataUtilitiesVersion gives the production package version.";
DefaultSensorComparisonSettings::usage =
  "DefaultSensorComparisonSettings[] returns the Mathematica 12.1-compatible settings Association.";
SensorComparisonPreflight::usage =
  "SensorComparisonPreflight[settings] validates input paths, registry, LIM curves, WUFI manifest, and selected cases.";
BuildMXCacheFromJSON::usage =
  "BuildMXCacheFromJSON[settings] imports the archival RawJSON once, writes an MX cache, and creates a provenance sidecar.";
RegenerateSelectedSensorWXFs::usage =
  "RegenerateSelectedSensorWXFs[settings] regenerates selected sensor WXFs and meteo_data.wxf from JSON or MX input.";
LoadCanonicalSensorRegistry::usage =
  "LoadCanonicalSensorRegistry[path] loads and validates the canonical sensor registry.";
LoadSelectedSensorWXFs::usage =
  "LoadSelectedSensorWXFs[directory,registry] imports the per-sensor WXF files described by the registry.";
NormalizeSensorRows::usage =
  "NormalizeSensorRows[rows,registryRecord,settings] sorts, collapses near duplicates, applies range QC, and returns channel data plus a QC report.";
AggregateSensorChannel::usage =
  "AggregateSensorChannel[pairs,targetDates,method,settings] constructs hourly sensor estimates without filling gaps.";
AggregateSensorGroup::usage =
  "AggregateSensorGroup[preparedSensors,groupRecord,variable,settings] combines per-sensor hourly estimates by an unweighted group median.";
LoadWUFIManifestAny::usage =
  "LoadWUFIManifestAny[path] loads a .wl or .json WUFI export manifest.";
ResolveWUFISelections::usage =
  "ResolveWUFISelections[manifest,selectors] resolves explicit project/case selectors or All.";
LoadWUFICaseSeries::usage =
  "LoadWUFICaseSeries[productionRoot,selection,settings] imports WUFI temperature/RH WXF files and normalizes timestamps to UTC.";
BuildSpatialMatch::usage =
  "BuildSpatialMatch[groupRecord,caseRecord,method,settings] builds Exact, NearestMonitor, LinearWithinSameMaterial, or Auto spatial matching metadata.";
EvaluateSpatialMatch::usage =
  "EvaluateSpatialMatch[caseData,match] evaluates model temperature and RH at the matched depth.";
PairSensorModelSeries::usage =
  "PairSensorModelSeries[sensorSeries,modelSeries] returns exact-time paired rows without temporal interpolation.";
ComparisonMetrics::usage =
  "ComparisonMetrics[pairedRows,variable,settings] calculates bias, MAE, RMSE, correlation, regression, threshold, and lag metrics.";
RunSensorComparison::usage =
  "RunSensorComparison[settings] runs the optimized production sensor QC, cached hourly aggregation, selected WUFI-case comparisons, plots, metrics, and finalized manifests.";
RunSensorComparisonDraft::usage =
  "RunSensorComparisonDraft[settings] is a backward-compatible alias for RunSensorComparison[settings].";
RenderExistingComparisonOutput::usage =
  "RenderExistingComparisonOutput[outputRoot,settings] regenerates sensor-only and WUFI-comparison plots from previously exported WXF bundles without repeating sensor normalization, aggregation, or metrics.";
OutputPathAudit::usage =
  "OutputPathAudit[settings,registry,selections] forecasts planned output paths and Windows MAX_PATH risk.";
AuditExistingComparisonOutput::usage =
  "AuditExistingComparisonOutput[outputRoot,settings] audits UTC serialization and exact sensor/WUFI timestamp alignment in existing comparison WXF bundles without regenerating plots.";
AuditExistingGraphicsOutput::usage =
  "AuditExistingGraphicsOutput[outputRoot,settings,expectedPaths] validates expected and existing JPG/JPEG files, including missing, malformed, undersized, unreadable, and unexpected figures.";

Begin["`Private`"];

$SensorDataUtilitiesVersion = "Production-1.2.0-2026-08-05";

ClearAll[
  DefaultSensorComparisonSettings, SensorComparisonPreflight,
  BuildMXCacheFromJSON, RegenerateSelectedSensorWXFs,
  LoadCanonicalSensorRegistry, LoadSelectedSensorWXFs,
  NormalizeSensorRows, AggregateSensorChannel, AggregateSensorGroup,
  LoadWUFIManifestAny, ResolveWUFISelections, LoadWUFICaseSeries,
  BuildSpatialMatch, EvaluateSpatialMatch, PairSensorModelSeries,
  ComparisonMetrics, RunSensorComparison, RunSensorComparisonDraft,
  RenderExistingComparisonOutput, OutputPathAudit,
  AuditExistingComparisonOutput, AuditExistingGraphicsOutput,
  resolvePath, applyExecutionProfile,
  fileAudit, registrySensorRows, wallFileStem, fastISODateObject,
  getSensorIDFromEntry, splitDatabase, extractSelectedRows,
  buildCacheProvenance, dateQ, numericMedianOrMissing,
  dateUnixSeconds, collapseNearDuplicateRows, rangeClean, channelPairs,
  longestFlatDurationHours, channelQC, regularHourlyGridQ,
  winsorizedMeanCompat, aggregateBinned, aggregatePointInterpolated,
  makeTimeSeries, statusAllowedQ, buildSensorGroups,
  loadManifestExpression, allCaseSelections, resolveOneSelector,
  forceWallClockToUTC, timeSeriesPath, normalizeWUFISeries,
  caseWallSystem, containingLayer, internalMonitorRecords,
  exactSpatialMatch, nearestSpatialMatch, linearSpatialMatch,
  weightedNumeric, evaluateMatchedValues, dateValueAssociation,
  pairedRowsFromAssociations, correlationSafe, regressionSafe,
  bestLagMetric, thresholdMetrics, metricsCore, dropInitialHours,
  ensureDirectory, exportRowsCSV, csvScalar, exportWLAndJSON,
  jsonSafe, utcDateObject, utcDateString, utcMillisecondKey,
  temporalPathDateToUTC, temporalPathMillisecondKey,
  fixedWallClockStringToUTC, hourlyUTCGridQ, hourlyTemporalGridQ,
  comparisonWXFFiles, auditOneComparisonWXF, alignmentAuditRunTimeZone,
  ensureKernelCount, initializeParallelPackages,
  parallelDefinitionsReadyQ, controlledMap,
  resetParallelInitializationState, closeParallelKernels,
  recyclePlotKernels, renderPlotTask, renderAndExportPlotTask,
  retryPlotTaskOnController, renderExportPlotBatch,
  plotTaskMetadata, plotTaskResultValue, plotTaskExportSuccessQ,
  normalizePlotTaskExportResult, plotBatchInvariantAudit,
  plotBatchExportsForKey,
  regularHourlyGridTimesQ, numericDateValuePairs,
  longestFlatDurationHoursUnix, channelQCUnix,
  aggregateBinnedUnix, aggregatePointInterpolatedUnix,
  aggregateSensorChannelUnix, normalizeWUFISeriesCollection,
  sensorPreparationSettingsKey, sensorBundleCacheKey,
  prepareSensorsForGrid, prepareSensorBundle,
  runOneSelectionPrepared, sensorWallCaseFolderName,
  sensorGroupFolderNames, depthMillimetreString,
  compactGroupFileStem, comparisonOutputDirectoryName,
  sensorGroupPlotTasks, exportSensorGroupPlots, exportSensorWallPlots,
  exportSensorWallTimeSeries, comparisonPlotTasks,
  exportComparisonPlots, exportComparisonTimeSeries,
  dewPointGroupSeries, variableFileStem,
  plannedOutputPaths, plannedGraphicPaths, graphicPathQ,
  outputPathSummary, OutputPathAudit,
  logMessage, progressView, nestedFailures,
  serializableSelection, runOneSelection, appendAudit,
  absoluteDateKey, pairExplicitUTCSeries, pairSensorModelData,
  renderSensorOnlyPlotsFromOutput, renderComparisonPlotsFromOutput,
  resolveAutomaticInputPaths
];

$sensorDataUtilitiesSourceFile = Quiet@Check[
  If[
    StringQ[$InputFileName] && StringLength[$InputFileName] > 0,
    ExpandFileName@$InputFileName,
    Missing["SourceFileUnavailable"]
  ],
  Missing["SourceFileUnavailable"]
];

DefaultSensorComparisonSettings[] := <|
  "InputMode" -> "SelectedWXF",
  "ProjectRoot" -> Automatic,
  "SensorDataRoot" -> Automatic,
  "RawJSONPath" -> Automatic,
  "MXCachePath" -> Automatic,
  "SelectedSensorDirectory" -> Automatic,
  "MeteoWXFPath" -> Automatic,
  "CanonicalRegistryPath" -> Automatic,
  "LIMCurveDirectory" -> Automatic,
  "ProductionRunRoot" -> Automatic,
  "WUFIManifestPath" -> Automatic,
  "OutputRoot" -> Automatic,
  "SelectedCases" -> {
    "Wall_REF_60-40_filling",
    "Wall_hempcrete"
  },
  "WUFIFixedTimeZone" -> 2,
  "SensorTimeZone" -> 0,
  "AggregationMethod" -> "CenteredWindowMedian",
  "CenteredWindowHalfWidthSeconds" -> 1800.,
  "PointInterpolationMaxBracketSeconds" -> 1800.,
  "WinsorizationFraction" -> 0.05,
  "MinimumSamplesPerHour" -> 3,
  "MinimumCoverageFraction" -> 0.5,
  "MinimumGroupContributors" -> 1,
  "NearDuplicateToleranceSeconds" -> 1.,
  "TemperatureRangeC" -> {-50., 60.},
  "RelativeHumidityRangePercent" -> {0., 100.},
  "TemperatureJumpFlagC" -> 15.,
  "RelativeHumidityJumpFlagPercent" -> 20.,
  "FlatlineToleranceTemperatureC" -> 0.02,
  "FlatlineToleranceRHPercent" -> 0.02,
  "FlatlineMinimumDurationHours" -> 12.,
  "CeilingThresholdRHPercent" -> 99.9,
  "CeilingFractionWarning" -> 0.2,
  "IncludeSecondaryTemperature" -> True,
  "IncludeSecondaryRH" -> False,
  "SpatialMethod" -> "Auto",
  "ExactDepthToleranceMetres" -> 0.002,
  "MaximumNearestDepthOffsetMetres" -> 0.03,
  "AllowSameMaterialExtrapolation" -> False,
  "ExcludeInitialHoursForSecondaryMetrics" -> 24.,
  "RelativeHumidityThresholds" -> {80., 85., 90., 95.},
  "CrossCorrelationLagHours" -> Range[-24, 24],
  "UseParallel" -> True,
  "MaximumKernels" -> Automatic,
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
  "ExecutionProfile" -> "ProductionFull",
  "ReuseSensorPreparationByWallAndGrid" -> True,
  "WriteSensorOnlyOutputsOncePerWallSystem" -> True,
  "RetainPreparedSensorsInRunResults" -> False,
  "CollectStageTimings" -> True,
  "ExportResolution" -> 500,
  "ComparisonOutputDirectoryName" -> "WUFI_vs_Sensors",
  "PathLengthWarningCharacters" -> 240,
  "PathLengthHardLimitCharacters" -> If[$OperatingSystem === "Windows", 259, 4095],
  "PrintProgressLog" -> True,
  "ShowProgressIndicator" -> True,
  "WriteSensorOnlyPlots" -> True,
  "WriteComparisonPlots" -> True,
  "WriteWXF" -> True,
  "WriteJSONManifest" -> True,
  "RunAlignmentAudit" -> True,
  "CaseWallSystemRules" -> {
    "Wall_hempcrete" -> "HEMP",
    "Wall_REF_" -> "REF"
  }
|>;

applyExecutionProfile[settings_Association] := Module[{profile},
  profile = Lookup[settings, "ExecutionProfile", "ProductionFull"];
  Switch[
    profile,
    "ProductionFull",
      settings,
    "ComputeOnly",
      Join[
        settings,
        <|
          "WriteSensorOnlyPlots" -> False,
          "WriteComparisonPlots" -> False
        |>
      ],
    _,
      settings
  ]
];

resolvePath[value_, root_, fallbackParts_List] := Which[
  StringQ[value], ExpandFileName[value],
  value === Automatic && StringQ[root], ExpandFileName@FileNameJoin[Join[{root}, fallbackParts]],
  True, value
];

resolveAutomaticInputPaths[settings_Association] := Module[
  {s, root, sensorRoot},
  s = settings;
  root = Lookup[s, "ProjectRoot", Automatic];
  If[root === Automatic, root = Quiet@Check[NotebookDirectory[], Directory[]]];
  root = ExpandFileName[root];
  sensorRoot = resolvePath[Lookup[s, "SensorDataRoot", Automatic], root, {"Sensor Data"}];
  Join[
    s,
    <|
      "ProjectRoot" -> root,
      "SensorDataRoot" -> sensorRoot,
      "RawJSONPath" -> resolvePath[Lookup[s, "RawJSONPath", Automatic], sensorRoot, {"MonitoringHousMaris.spilve_full_dataset.json"}],
      "MXCachePath" -> resolvePath[Lookup[s, "MXCachePath", Automatic], sensorRoot, {"MonitoringHousMaris.spilve_full_dataset.mx"}],
      "SelectedSensorDirectory" -> resolvePath[Lookup[s, "SelectedSensorDirectory", Automatic], sensorRoot, {"Selected Sensors"}],
      "MeteoWXFPath" -> resolvePath[Lookup[s, "MeteoWXFPath", Automatic], sensorRoot, {"meteo_data.wxf"}],
      "CanonicalRegistryPath" -> resolvePath[Lookup[s, "CanonicalRegistryPath", Automatic], root, {"canonical_sensor_registry_2026-07-30.wl"}],
      "LIMCurveDirectory" -> resolvePath[Lookup[s, "LIMCurveDirectory", Automatic], root, {"LIM Curves"}],
      "ProductionRunRoot" -> resolvePath[Lookup[s, "ProductionRunRoot", Automatic], root, {"Production_Run_1_2026-07-29"}],
      "WUFIManifestPath" -> resolvePath[Lookup[s, "WUFIManifestPath", Automatic], resolvePath[Lookup[s, "ProductionRunRoot", Automatic], root, {"Production_Run_1_2026-07-29"}], {"WUFI_export_manifest.wl"}],
      "OutputRoot" -> resolvePath[Lookup[s, "OutputRoot", Automatic], root, {"Sensor_WUFI_Comparison_Output"}]
    |>
  ]
];

fileAudit[path_, kind_String, required_:True] := Module[{exists, bytes},
  exists = If[kind === "Directory", DirectoryQ[path], FileExistsQ[path]];
  bytes = If[exists && kind =!= "Directory", Quiet@Check[FileByteCount[path], Missing["Unavailable"]], Missing["NotApplicable"]];
  <|
    "Path" -> path,
    "Kind" -> kind,
    "Required" -> required,
    "Exists" -> exists,
    "ByteCount" -> bytes,
    "Status" -> If[exists || !TrueQ[required], "OK", "Missing"]
  |>
];

LoadCanonicalSensorRegistry[path_String] := Module[{registry, sensors, requiredKeys, invalid},
  If[!FileExistsQ[path], Return@Failure["RegistryMissing", <|"Path" -> path|>]];
  registry = Quiet@Check[Get[ExpandFileName@path], $Failed];
  If[!AssociationQ[registry], Return@Failure["RegistryInvalid", <|"Path" -> path|>]];
  sensors = Lookup[registry, "Sensors", Missing["Sensors"]];
  If[!ListQ[sensors] || !And @@ (AssociationQ /@ sensors),
    Return@Failure["RegistrySensorsInvalid", <|"Path" -> path|>]
  ];
  requiredKeys = {
    "WallSystem", "SensorID", "TemperatureField", "RelativeHumidityField",
    "NominalDepthFromExterior_mm", "ComparisonGroup",
    "TemperatureStatus", "RelativeHumidityStatus"
  };
  invalid = Select[
    sensors,
    Function[record, !And @@ (KeyExistsQ[record, #] & /@ requiredKeys)]
  ];
  If[invalid =!= {},
    Return@Failure["RegistryRecordInvalid", <|"InvalidRecordCount" -> Length@invalid, "RequiredKeys" -> requiredKeys|>]
  ];
  registry
];

registrySensorRows[registry_Association] := Lookup[registry, "Sensors", {}];

wallFileStem["REF"] := "reference";
wallFileStem["HEMP"] := "hempcrete";
wallFileStem[other_] := ToLowerCase@ToString[other];

fastISODateObject[s_String, timeZone_:0] := Module[{t},
  t = If[StringTake[s, -1] === "Z", StringDrop[s, -1], s];
  DateObject[
    {
      FromDigits@StringTake[t, {1, 4}],
      FromDigits@StringTake[t, {6, 7}],
      FromDigits@StringTake[t, {9, 10}],
      FromDigits@StringTake[t, {12, 13}],
      FromDigits@StringTake[t, {15, 16}],
      ToExpression@StringTake[t, {18, -1}]
    },
    TimeZone -> timeZone
  ]
];

getSensorIDFromEntry[entry_Association] := Module[{key},
  key = SelectFirst[Keys@entry, StringStartsQ[#, "Hum"] &, Missing["NotFound"]];
  If[MissingQ[key], Missing["NotFound"], Quiet@Check[ToExpression@StringDrop[key, 3], Missing["InvalidID"]]]
];

splitDatabase[database_List] := GroupBy[
  database,
  Lookup[#, "MesurmentType", "MissingMeasurementType"] &
];

extractSelectedRows[wirelessRows_List, registry_Association] := Module[
  {grouped, sensors, ids},
  grouped = GroupBy[
    Select[wirelessRows, IntegerQ@getSensorIDFromEntry[#] &],
    getSensorIDFromEntry
  ];
  sensors = registrySensorRows@registry;
  ids = DeleteDuplicates@Lookup[sensors, "SensorID"];
  Association@Map[
    Function[id,
      id -> Module[{records, idText, tempKey, rhKey},
        records = Lookup[grouped, id, {}];
        idText = ToString[id];
        tempKey = "Temp" <> idText;
        rhKey = "Hum" <> idText;
        Map[
          {
            Lookup[Lookup[#, "date", <||>], "$date", Missing["Date"]],
            Lookup[#, tempKey, Missing["Temperature"]],
            Lookup[#, rhKey, Missing["RelativeHumidity"]]
          } &,
          records
        ]
      ]
    ],
    ids
  ]
];

buildCacheProvenance[jsonPath_String, mxPath_String, database_List] := <|
  "ProvenanceVersion" -> 1,
  "GeneratedAt" -> DateString[Now, "ISODateTime"],
  "GeneratedAtLocal" -> DateString[Now, "ISODateTime"],
  "GeneratedAtUTC" -> DateString[TimeZoneConvert[Now, 0], {"ISODate", "T", "Time", "Z"}],
  "GeneratedTimeZoneHours" -> $TimeZone,
  "SourceJSONPath" -> ExpandFileName@jsonPath,
  "SourceJSONSHA256" -> Quiet@Check[FileHash[jsonPath, "SHA256", "HexString"], Missing["Unavailable"]],
  "SourceJSONByteCount" -> Quiet@Check[FileByteCount@jsonPath, Missing["Unavailable"]],
  "MXCachePath" -> ExpandFileName@mxPath,
  "RecordCount" -> Length@database,
  "WolframVersion" -> $Version,
  "SystemID" -> $SystemID,
  "SensorDataUtilitiesVersion" -> $SensorDataUtilitiesVersion
|>;

BuildMXCacheFromJSON[inputSettings_Association] := Module[
  {settings, jsonPath, mxPath, database, exportResult, provenance, provenancePath},
  settings = resolveAutomaticInputPaths@Join[DefaultSensorComparisonSettings[], inputSettings];
  jsonPath = Lookup[settings, "RawJSONPath"];
  mxPath = Lookup[settings, "MXCachePath"];
  If[!FileExistsQ[jsonPath], Return@Failure["JSONMissing", <|"Path" -> jsonPath|>]];
  database = Quiet@Check[Import[jsonPath, "RawJSON"], $Failed];
  If[!ListQ[database], Return@Failure["JSONImportFailed", <|"Path" -> jsonPath|>]];
  Quiet@CreateDirectory[DirectoryName@mxPath, CreateIntermediateDirectories -> True];
  exportResult = Quiet@Check[Export[mxPath, database], $Failed];
  If[exportResult === $Failed || !FileExistsQ[mxPath],
    Return@Failure["MXExportFailed", <|"Path" -> mxPath|>]
  ];
  provenance = buildCacheProvenance[jsonPath, mxPath, database];
  provenancePath = mxPath <> ".provenance.wl";
  Put[provenance, provenancePath];
  <|
    "Status" -> "Created",
    "MXCachePath" -> mxPath,
    "ProvenancePath" -> provenancePath,
    "RecordCount" -> Length@database
  |>
];

RegenerateSelectedSensorWXFs[inputSettings_Association] := Module[
  {settings, mode, sourcePath, database, grouped, meteo, wireless,
   registry, selectedRows, sensorDirectory, sensors, exports, meteoPath},
  settings = resolveAutomaticInputPaths@Join[DefaultSensorComparisonSettings[], inputSettings];
  mode = Lookup[settings, "InputMode", "MX"];
  sourcePath = If[mode === "JSON", Lookup[settings, "RawJSONPath"], Lookup[settings, "MXCachePath"]];
  If[!FileExistsQ[sourcePath], Return@Failure["DatabaseSourceMissing", <|"Path" -> sourcePath, "Mode" -> mode|>]];
  database = Quiet@Check[If[mode === "JSON", Import[sourcePath, "RawJSON"], Import[sourcePath]], $Failed];
  If[!ListQ[database], Return@Failure["DatabaseImportFailed", <|"Path" -> sourcePath|>]];
  registry = LoadCanonicalSensorRegistry@Lookup[settings, "CanonicalRegistryPath"];
  If[FailureQ[registry], Return@registry];
  grouped = splitDatabase@database;
  meteo = Lookup[grouped, "meteo", {}];
  wireless = Lookup[grouped, "WirelesNRF", {}];
  selectedRows = extractSelectedRows[wireless, registry];
  sensorDirectory = Lookup[settings, "SelectedSensorDirectory"];
  ensureDirectory@sensorDirectory;
  sensors = registrySensorRows@registry;
  exports = Map[
    Function[record,
      Module[{id, wall, rawRows, convertedRows, path, result},
        id = Lookup[record, "SensorID"];
        wall = Lookup[record, "WallSystem"];
        rawRows = Lookup[selectedRows, id, {}];
        convertedRows = Map[
          {
            If[StringQ[#[[1]]], fastISODateObject[#[[1]], Lookup[settings, "SensorTimeZone"]], #[[1]]],
            #[[2]],
            #[[3]]
          } &,
          rawRows
        ];
        path = FileNameJoin[{
          sensorDirectory,
          "sensor_" <> wallFileStem[wall] <> "_" <> ToString[id] <> ".wxf"
        }];
        result = Quiet@Check[Export[path, convertedRows, "WXF"], $Failed];
        <|"SensorID" -> id, "Path" -> path, "RowCount" -> Length@convertedRows, "Status" -> If[result === $Failed, "Failed", "Exported"]|>
      ]
    ],
    sensors
  ];
  meteoPath = Lookup[settings, "MeteoWXFPath"];
  Quiet@CreateDirectory[DirectoryName@meteoPath, CreateIntermediateDirectories -> True];
  Quiet@Check[Export[meteoPath, meteo, "WXF"], $Failed];
  <|
    "Status" -> If[MemberQ[Lookup[exports, "Status"], "Failed"], "CompletedWithFailures", "Completed"],
    "DatabaseSource" -> sourcePath,
    "MeteoRowCount" -> Length@meteo,
    "WirelessRowCount" -> Length@wireless,
    "SensorExports" -> exports,
    "MeteoPath" -> meteoPath
  |>
];

LoadSelectedSensorWXFs[directory_String, registry_Association] := Module[
  {sensors, results},
  If[!DirectoryQ[directory], Return@Failure["SelectedSensorDirectoryMissing", <|"Directory" -> directory|>]];
  sensors = registrySensorRows@registry;
  results = Association@Map[
    Function[record,
      Module[{id, path, data},
        id = Lookup[record, "SensorID"];
        path = FileNameJoin[{
          directory,
          "sensor_" <> wallFileStem[Lookup[record, "WallSystem"]] <> "_" <> ToString[id] <> ".wxf"
        }];
        data = If[FileExistsQ[path], Quiet@Check[Import[path, "WXF"], $Failed], $Failed];
        id -> <|
          "Registry" -> record,
          "Path" -> path,
          "Data" -> data,
          "Status" -> Which[
            !FileExistsQ[path], "Missing",
            data === $Failed, "ImportFailed",
            !ListQ[data], "InvalidData",
            True, "Loaded"
          ]
        |>
      ]
    ],
    sensors
  ];
  results
];

dateUnixSeconds[value_] := Quiet@Check[
  If[
    Head[value] === DateObject,
    N@UnixTime@TimeZoneConvert[value, 0],
    Missing["InvalidDate"]
  ],
  Missing["InvalidDate"]
];

dateQ[value_] := NumericQ@dateUnixSeconds[value];

numericMedianOrMissing[values_List, tag_String] := Module[{numeric},
  numeric = Cases[values, _?NumericQ];
  If[numeric === {}, Missing[tag], Median@N@numeric]
];

collapseNearDuplicateRows[
  rows_List,
  toleranceSeconds_?NumericQ,
  timeZone_:0
] := Module[
  {validNumericRows, sorted, clusters, collapsedNumeric, collapsed},
  validNumericRows = Cases[
    rows,
    row_List /; Length[row] >= 3 :>
      With[
        {time = dateUnixSeconds@row[[1]]},
        If[
          NumericQ[time],
          {N@time, row[[2]], row[[3]]},
          Nothing
        ]
      ]
  ];
  sorted = SortBy[validNumericRows, First];
  If[
    sorted === {},
    Return@<|
      "Rows" -> {},
      "NumericRows" -> {},
      "RawSortedNumericRows" -> {},
      "CollapsedCount" -> 0,
      "ClusterSizes" -> {}
    |>
  ];
  clusters = Split[
    sorted,
    (#2[[1]] - #1[[1]] <= toleranceSeconds) &
  ];
  collapsedNumeric = Map[
    Function[cluster,
      {
        Median@cluster[[All, 1]],
        numericMedianOrMissing[cluster[[All, 2]], "NoTemperature"],
        numericMedianOrMissing[cluster[[All, 3]], "NoRelativeHumidity"]
      }
    ],
    clusters
  ];
  collapsed = {
    FromUnixTime[#[[1]], TimeZone -> timeZone],
    #[[2]],
    #[[3]]
  } & /@ collapsedNumeric;
  <|
    "Rows" -> collapsed,
    "NumericRows" -> collapsedNumeric,
    "RawSortedNumericRows" -> sorted,
    "CollapsedCount" -> Length[validNumericRows] - Length[collapsed],
    "ClusterSizes" -> Length /@ clusters
  |>
];

rangeClean[value_, {minimum_?NumericQ, maximum_?NumericQ}, tag_String] := Which[
  !NumericQ[value], Missing[tag <> "NonNumeric"],
  value < minimum || value > maximum, Missing[tag <> "OutOfRange"],
  True, N@value
];

channelPairs[rows_List, column_Integer] := Cases[
  rows,
  row_ /; Length[row] >= column && dateQ[row[[1]]] && NumericQ[row[[column]]] :>
    {row[[1]], N@row[[column]]}
];

numericDateValuePairs[pairs_List] := Cases[
  pairs,
  {date_, value_?NumericQ} :>
    With[
      {time = dateUnixSeconds@date},
      If[NumericQ[time], {N@time, N@value}, Nothing]
    ]
];

longestFlatDurationHoursUnix[pairs_List, tolerance_?NumericQ] := Module[
  {sorted, times, values, intervals, typical, maxAllowedGap, runStart, maximum, i},
  If[Length[pairs] < 2, Return[0.]];
  sorted = SortBy[Select[pairs, MatchQ[#, {_?NumericQ, _?NumericQ}] &], First];
  If[Length[sorted] < 2, Return[0.]];
  times = N@sorted[[All, 1]];
  values = N@sorted[[All, 2]];
  intervals = Select[Differences@times, # > 0 &];
  typical = If[intervals === {}, 0., Median@intervals];
  maxAllowedGap = Max[600., 3. * typical];
  runStart = 1;
  maximum = 0.;
  Do[
    If[
      Abs[values[[i]] - values[[i - 1]]] > tolerance ||
        times[[i]] - times[[i - 1]] > maxAllowedGap,
      maximum = Max[maximum, times[[i - 1]] - times[[runStart]]];
      runStart = i
    ],
    {i, 2, Length@times}
  ];
  maximum = Max[maximum, Last@times - times[[runStart]]];
  maximum/3600.
];

longestFlatDurationHours[pairs_List, tolerance_?NumericQ] :=
  longestFlatDurationHoursUnix[numericDateValuePairs@pairs, tolerance];

channelQCUnix[
  pairs_List,
  jumpThreshold_?NumericQ,
  flatTolerance_?NumericQ,
  ceiling_:None
] := Module[
  {
    sorted, times, values, intervals, positiveIntervals, typical, p95,
    gapThreshold, gapCount, jumps, ceilingFraction, flatHours
  },
  sorted = SortBy[Select[pairs, MatchQ[#, {_?NumericQ, _?NumericQ}] &], First];
  If[
    sorted === {},
    Return@<|
      "ValidCount" -> 0,
      "FirstTimestampUTC" -> Missing["NoData"],
      "LastTimestampUTC" -> Missing["NoData"],
      "MedianSamplingIntervalSeconds" -> Missing["NoData"],
      "P95SamplingIntervalSeconds" -> Missing["NoData"],
      "GapCount" -> 0,
      "JumpFlagCount" -> 0,
      "CeilingFraction" -> Missing["NotApplicable"],
      "LongestFlatDurationHours" -> 0.
    |>
  ];
  times = N@sorted[[All, 1]];
  values = N@sorted[[All, 2]];
  intervals = Differences@times;
  positiveIntervals = Select[intervals, # > 0 &];
  typical = If[
    positiveIntervals === {},
    Missing["NoIntervals"],
    Median@positiveIntervals
  ];
  p95 = If[
    positiveIntervals === {},
    Missing["NoIntervals"],
    Quantile[positiveIntervals, 0.95]
  ];
  gapThreshold = If[NumericQ[typical], Max[600., 3. * typical], 600.];
  gapCount = Count[positiveIntervals, x_ /; x > gapThreshold];
  jumps = Count[Abs@Differences@values, x_ /; x > jumpThreshold];
  ceilingFraction = If[
    ceiling === None,
    Missing["NotApplicable"],
    N@Count[values, x_ /; x >= ceiling]/Length@values
  ];
  flatHours = longestFlatDurationHoursUnix[sorted, flatTolerance];
  <|
    "ValidCount" -> Length@sorted,
    "FirstTimestampUTC" -> FromUnixTime[First@times, TimeZone -> 0],
    "LastTimestampUTC" -> FromUnixTime[Last@times, TimeZone -> 0],
    "MedianSamplingIntervalSeconds" -> typical,
    "P95SamplingIntervalSeconds" -> p95,
    "GapCount" -> gapCount,
    "JumpFlagCount" -> jumps,
    "CeilingFraction" -> ceilingFraction,
    "LongestFlatDurationHours" -> flatHours
  |>
];

channelQC[
  pairs_List,
  jumpThreshold_?NumericQ,
  flatTolerance_?NumericQ,
  ceiling_:None
] := channelQCUnix[
  numericDateValuePairs@pairs,
  jumpThreshold,
  flatTolerance,
  ceiling
];

NormalizeSensorRows[
  rawRows_List,
  registryRecord_Association,
  settings_Association
] := Module[
  {
    timeZone, collapsed, numericRows, collapsedRows, collapsedUnixTimes,
    rawSortedNumericRows, temperatureRange, rhRange, cleanedNumericRows, cleanedRows,
    temperatureUnixPairs, rhUnixPairs, temperaturePairs, rhPairs,
    temperatureQC, rhQC, rawTemperatureNumeric, rawRHNumeric,
    outTemperature, outRH
  },
  timeZone = Lookup[settings, "SensorTimeZone", 0];
  collapsed = collapseNearDuplicateRows[
    rawRows,
    Lookup[settings, "NearDuplicateToleranceSeconds", 1.],
    timeZone
  ];
  numericRows = Lookup[collapsed, "NumericRows", {}];
  collapsedRows = Lookup[collapsed, "Rows", {}];
  rawSortedNumericRows = Lookup[collapsed, "RawSortedNumericRows", {}];
  temperatureRange = Lookup[settings, "TemperatureRangeC", {-50., 60.}];
  rhRange = Lookup[settings, "RelativeHumidityRangePercent", {0., 100.}];
  If[
    numericRows === {},
    rawTemperatureNumeric = 0;
    rawRHNumeric = 0,
    rawTemperatureNumeric = Count[numericRows[[All, 2]], _?NumericQ];
    rawRHNumeric = Count[numericRows[[All, 3]], _?NumericQ]
  ];
  collapsedUnixTimes = dateUnixSeconds /@ (First /@ collapsedRows);
  cleanedNumericRows = MapThread[
    {
      #1,
      rangeClean[#2[[2]], temperatureRange, "Temperature"],
      rangeClean[#2[[3]], rhRange, "RelativeHumidity"]
    } &,
    {collapsedUnixTimes, numericRows}
  ];
  cleanedRows = MapThread[
    {
      First@#1,
      #2[[2]],
      #2[[3]]
    } &,
    {collapsedRows, cleanedNumericRows}
  ];
  temperatureUnixPairs = Cases[
    cleanedNumericRows,
    {time_?NumericQ, value_?NumericQ, _} :> {N@time, N@value}
  ];
  rhUnixPairs = Cases[
    cleanedNumericRows,
    {time_?NumericQ, _, value_?NumericQ} :> {N@time, N@value}
  ];
  temperaturePairs = Cases[
    cleanedRows,
    {date_, value_?NumericQ, _} :>
      {date, N@value}
  ];
  rhPairs = Cases[
    cleanedRows,
    {date_, _, value_?NumericQ} :>
      {date, N@value}
  ];
  outTemperature = rawTemperatureNumeric - Length@temperaturePairs;
  outRH = rawRHNumeric - Length@rhPairs;
  temperatureQC = channelQCUnix[
    temperatureUnixPairs,
    Lookup[settings, "TemperatureJumpFlagC", 15.],
    Lookup[settings, "FlatlineToleranceTemperatureC", 0.02]
  ];
  rhQC = channelQCUnix[
    rhUnixPairs,
    Lookup[settings, "RelativeHumidityJumpFlagPercent", 20.],
    Lookup[settings, "FlatlineToleranceRHPercent", 0.02],
    Lookup[settings, "CeilingThresholdRHPercent", 99.9]
  ];
  <|
    "Registry" -> registryRecord,
    "RawRowCount" -> Length@rawRows,
    "RawFirstTimestampUTC" -> If[
      rawSortedNumericRows === {},
      Missing["NoData"],
      FromUnixTime[First@First@rawSortedNumericRows, TimeZone -> 0]
    ],
    "RawLastTimestampUTC" -> If[
      rawSortedNumericRows === {},
      Missing["NoData"],
      FromUnixTime[First@Last@rawSortedNumericRows, TimeZone -> 0]
    ],
    "SortedCollapsedRowCount" -> Length@cleanedRows,
    "NearDuplicateRowsCollapsed" -> Lookup[collapsed, "CollapsedCount", 0],
    "OutOfRangeTemperatureCount" -> outTemperature,
    "OutOfRangeRHCount" -> outRH,
    "Rows" -> cleanedRows,
    "TemperaturePairsUTC" -> temperaturePairs,
    "RelativeHumidityPairsUTC" -> rhPairs,
    "TemperatureUnixValuePairs" -> temperatureUnixPairs,
    "RelativeHumidityUnixValuePairs" -> rhUnixPairs,
    "TemperatureQC" -> temperatureQC,
    "RelativeHumidityQC" -> rhQC
  |>
];

regularHourlyGridTimesQ[targetTimes_List] := Module[{differences},
  If[
    Length[targetTimes] < 2 ||
      !And @@ (NumericQ /@ targetTimes),
    Return[False]
  ];
  differences = Differences@N@targetTimes;
  Max[Abs[differences - 3600.]] < 1.
];

regularHourlyGridQ[targetDates_List] :=
  regularHourlyGridTimesQ[dateUnixSeconds /@ targetDates];

winsorizedMeanCompat[
  data_List,
  fraction_?NumericQ
] := Module[{sorted, n, k, lower, upper, replaced},
  sorted = Sort@N@Cases[data, _?NumericQ];
  n = Length@sorted;
  If[n == 0, Return[Missing["NoData"]]];
  k = Floor[Clip[fraction, {0., 0.49}] * n];
  If[k == 0, Return[Mean@sorted]];
  lower = sorted[[k + 1]];
  upper = sorted[[n - k]];
  replaced = Join[
    ConstantArray[lower, k],
    sorted[[k + 1 ;; n - k]],
    ConstantArray[upper, k]
  ];
  Mean@replaced
];

makeTimeSeries[dates_List, values_List] := Quiet@Check[
  TimeSeries[Transpose[{dates, values}]],
  Transpose[{dates, values}]
];

aggregateBinnedUnix[
  unixPairs_List,
  targetDates_List,
  targetTimes_List,
  method_String,
  settings_Association
] := Module[
  {
    step, start, halfWidth, windowWidth, minimumSamples,
    minimumCoverage, data, indexed, grouped, aggregateFunction, rows,
    values, counts, coverages, bin, binTimes, binValues, coverage, valid,
    firstValidPosition, lastValidPosition
  },
  step = Median@Differences@targetTimes;
  start = First@targetTimes;
  halfWidth = Lookup[
    settings,
    "CenteredWindowHalfWidthSeconds",
    1800.
  ];
  windowWidth = If[
    StringStartsQ[method, "CenteredWindow"],
    2. * halfWidth,
    step
  ];
  minimumSamples = Lookup[settings, "MinimumSamplesPerHour", 3];
  minimumCoverage = Lookup[
    settings,
    "MinimumCoverageFraction",
    0.5
  ];
  data = SortBy[
    Select[
      unixPairs,
      MatchQ[#, {_?NumericQ, _?NumericQ}] &
    ],
    First
  ];
  indexed = Map[
    Function[pair,
      With[
        {
          time = pair[[1]],
          index = If[
            StringStartsQ[method, "CenteredWindow"],
            Floor[
              (pair[[1]] - (start - halfWidth))/step
            ] + 1,
            Ceiling[
              (pair[[1]] - start)/step
            ] + 1
          ]
        },
        {index, time, N@pair[[2]]}
      ]
    ],
    data
  ];
  indexed = Select[
    indexed,
    1 <= First[#] <= Length@targetDates &
  ];
  grouped = GroupBy[
    indexed,
    First -> (#[[2 ;; 3]] &)
  ];
  aggregateFunction = Switch[
    method,
    "CenteredWindowMedian" | "RightClosedHourlyMedian",
      Median,
    "CenteredWindowMean",
      Mean,
    "CenteredWindowWinsorizedMean",
      (
        winsorizedMeanCompat[
          #,
          Lookup[settings, "WinsorizationFraction", 0.05]
        ] &
      ),
    _,
      Median
  ];
  rows = Table[
    bin = Lookup[grouped, i, {}];
    binTimes = If[bin === {}, {}, bin[[All, 1]]];
    binValues = If[bin === {}, {}, bin[[All, 2]]];
    coverage = If[
      Length@binTimes >= 2,
      (Max@binTimes - Min@binTimes)/windowWidth,
      0.
    ];
    valid =
      Length@binValues >= minimumSamples &&
      coverage >= minimumCoverage;
    {
      If[
        valid,
        aggregateFunction@binValues,
        Missing["InsufficientHourlyCoverage"]
      ],
      Length@binValues,
      N@coverage
    },
    {i, Length@targetDates}
  ];
  values = rows[[All, 1]];
  counts = rows[[All, 2]];
  coverages = rows[[All, 3]];
  firstValidPosition = SelectFirst[
    Range@Length@values,
    NumericQ@values[[#]] &,
    Missing["NoValidTargets"]
  ];
  lastValidPosition = SelectFirst[
    Reverse@Range@Length@values,
    NumericQ@values[[#]] &,
    Missing["NoValidTargets"]
  ];
  <|
    "Method" -> method,
    "TargetDatesUTC" -> targetDates,
    "Values" -> values,
    "TimeSeries" -> makeTimeSeries[targetDates, values],
    "SampleCounts" -> counts,
    "CoverageFractions" -> coverages,
    "ValidHourlyCount" -> Count[values, _?NumericQ],
    "InputFirstTimestampUTC" -> If[
      data === {},
      Missing["NoData"],
      FromUnixTime[First@First@data, TimeZone -> 0]
    ],
    "InputLastTimestampUTC" -> If[
      data === {},
      Missing["NoData"],
      FromUnixTime[First@Last@data, TimeZone -> 0]
    ],
    "FirstValidTargetUTC" -> If[
      MissingQ[firstValidPosition],
      firstValidPosition,
      utcDateObject@targetDates[[firstValidPosition]]
    ],
    "LastValidTargetUTC" -> If[
      MissingQ[lastValidPosition],
      lastValidPosition,
      utcDateObject@targetDates[[lastValidPosition]]
    ]
  |>
];

aggregatePointInterpolatedUnix[
  unixPairs_List,
  targetDates_List,
  targetTimes_List,
  settings_Association
] := Module[
  {
    data, times, valuesRaw, maximumBracket, rows, index, before, after,
    value, width, firstValidPosition, lastValidPosition
  },
  data = SortBy[
    Select[
      unixPairs,
      MatchQ[#, {_?NumericQ, _?NumericQ}] &
    ],
    First
  ];
  If[
    data === {},
    times = {};
    valuesRaw = {},
    times = N@data[[All, 1]];
    valuesRaw = N@data[[All, 2]]
  ];
  maximumBracket = Lookup[
    settings,
    "PointInterpolationMaxBracketSeconds",
    1800.
  ];
  index = 1;
  rows = Table[
    While[
      index <= Length@times &&
        times[[index]] < target,
      index++
    ];
    value = Missing["NoInterpolationBracket"];
    width = Missing["NoInterpolationBracket"];
    If[
      index <= Length@times &&
        times[[index]] == target,
      value = valuesRaw[[index]];
      width = 0.;
      {value, width, 1},
      before = index - 1;
      after = index;
      If[
        before >= 1 &&
          after <= Length@times &&
          target - times[[before]] <= maximumBracket &&
          times[[after]] - target <= maximumBracket &&
          times[[after]] > times[[before]],
        value = valuesRaw[[before]] +
          (valuesRaw[[after]] - valuesRaw[[before]]) *
          (target - times[[before]])/
            (times[[after]] - times[[before]]);
        width = times[[after]] - times[[before]];
        {value, width, 2},
        {value, width, 0}
      ]
    ],
    {target, targetTimes}
  ];
  firstValidPosition = SelectFirst[
    Range@Length@rows,
    NumericQ@rows[[#, 1]] &,
    Missing["NoValidTargets"]
  ];
  lastValidPosition = SelectFirst[
    Reverse@Range@Length@rows,
    NumericQ@rows[[#, 1]] &,
    Missing["NoValidTargets"]
  ];
  <|
    "Method" -> "PointInterpolation",
    "TargetDatesUTC" -> targetDates,
    "Values" -> rows[[All, 1]],
    "TimeSeries" -> makeTimeSeries[
      targetDates,
      rows[[All, 1]]
    ],
    "SampleCounts" -> rows[[All, 3]],
    "InterpolationBracketSeconds" -> rows[[All, 2]],
    "ValidHourlyCount" -> Count[rows[[All, 1]], _?NumericQ],
    "InputFirstTimestampUTC" -> If[
      data === {},
      Missing["NoData"],
      FromUnixTime[First@First@data, TimeZone -> 0]
    ],
    "InputLastTimestampUTC" -> If[
      data === {},
      Missing["NoData"],
      FromUnixTime[First@Last@data, TimeZone -> 0]
    ],
    "FirstValidTargetUTC" -> If[
      MissingQ[firstValidPosition],
      firstValidPosition,
      utcDateObject@targetDates[[firstValidPosition]]
    ],
    "LastValidTargetUTC" -> If[
      MissingQ[lastValidPosition],
      lastValidPosition,
      utcDateObject@targetDates[[lastValidPosition]]
    ]
  |>
];

aggregateSensorChannelUnix[
  unixPairs_List,
  targetDates_List,
  targetTimes_List,
  method_String,
  settings_Association
] := Module[{},
  If[
    !regularHourlyGridTimesQ[targetTimes],
    Return@Failure[
      "TargetGridNotHourly",
      <|"TargetCount" -> Length@targetDates|>
    ]
  ];
  Switch[
    method,
    "CenteredWindowMedian" |
      "CenteredWindowMean" |
      "CenteredWindowWinsorizedMean" |
      "RightClosedHourlyMedian",
      aggregateBinnedUnix[
        unixPairs,
        targetDates,
        targetTimes,
        method,
        settings
      ],
    "PointInterpolation",
      aggregatePointInterpolatedUnix[
        unixPairs,
        targetDates,
        targetTimes,
        settings
      ],
    _,
      Failure[
        "UnknownAggregationMethod",
        <|"Method" -> method|>
      ]
  ]
];

AggregateSensorChannel[
  pairs_List,
  targetDates_List,
  method_String,
  settings_Association
] := Module[{targetTimes},
  targetTimes = dateUnixSeconds /@ targetDates;
  aggregateSensorChannelUnix[
    numericDateValuePairs@pairs,
    targetDates,
    targetTimes,
    method,
    settings
  ]
];

statusAllowedQ[status_, includeSecondary_:False] := Module[{text},
  text = ToLowerCase@ToString[status];
  StringStartsQ[text, "primary"] || (TrueQ@includeSecondary && StringContainsQ[text, "secondary"])
];

buildSensorGroups[registry_Association, wallSystem_String, variable_String, settings_Association] := Module[
  {statusKey, includeSecondary, sensors, selected, groups},
  statusKey = If[variable === "Temperature", "TemperatureStatus", "RelativeHumidityStatus"];
  includeSecondary = Which[
    variable === "Temperature",
      TrueQ@Lookup[settings, "IncludeSecondaryTemperature", True],
    variable === "RelativeHumidity",
      TrueQ@Lookup[settings, "IncludeSecondaryRH", False],
    True,
      False
  ];
  sensors = Select[registrySensorRows@registry, Lookup[#, "WallSystem", ""] === wallSystem &];
  selected = Select[sensors, statusAllowedQ[Lookup[#, statusKey, "Exclude"], includeSecondary] &];
  groups = GroupBy[selected, Lookup[#, "ComparisonGroup", "Ungrouped"] &];
  Association@KeyValueMap[
    Function[{groupID, records},
      groupID -> <|
        "GroupID" -> groupID,
        "WallSystem" -> wallSystem,
        "Variable" -> variable,
        "SensorIDs" -> Lookup[records, "SensorID"],
        "SensorRecords" -> records,
        "TargetDepthMetres" -> N@Median[Lookup[records, "NominalDepthFromExterior_mm"]]/1000.,
        "DepthRangeMetres" -> N@MinMax[Lookup[records, "NominalDepthFromExterior_mm"]]/1000.,
        "MappingConfidence" -> DeleteDuplicates@Lookup[records, "MappingConfidence", "unknown"]
      |>
    ],
    groups
  ]
];

AggregateSensorGroup[
  preparedSensors_Association,
  groupRecord_Association,
  variable_String,
  settings_Association
] := Module[
  {
    ids, key, hourly, available, dates, valueMatrix, rows, values,
    lower, upper, q25, q75, contributors, minimumContributors
  },
  ids = Lookup[groupRecord, "SensorIDs", {}];
  key = If[
    variable === "Temperature",
    "TemperatureHourly",
    "RelativeHumidityHourly"
  ];
  hourly = Lookup[
    preparedSensors,
    #,
    Missing["SensorMissing"]
  ] & /@ ids;
  hourly = Select[
    hourly,
    AssociationQ[#] &&
      AssociationQ@Lookup[
        #,
        key,
        Missing["MissingHourly"]
      ] &
  ];
  If[
    hourly === {},
    Return@Failure[
      "NoHourlySensorsForGroup",
      <|
        "Group" -> Lookup[groupRecord, "GroupID"],
        "Variable" -> variable
      |>
    ]
  ];
  available = Lookup[hourly, key];
  dates = Lookup[First@available, "TargetDatesUTC"];
  valueMatrix = Lookup[available, "Values"];
  If[
    !SameQ @@ (Length /@ valueMatrix),
    Return@Failure[
      "GroupHourlyLengthMismatch",
      <|"Group" -> Lookup[groupRecord, "GroupID"]|>
    ]
  ];
  minimumContributors = Lookup[
    settings,
    "MinimumGroupContributors",
    1
  ];
  rows = Map[
    Function[column,
      With[
        {current = Cases[column, _?NumericQ]},
        If[
          Length@current < minimumContributors,
          {
            Missing["NoContributors"],
            Missing["NoContributors"],
            Missing["NoContributors"],
            Missing["NoContributors"],
            Missing["NoContributors"],
            Length@current
          },
          {
            Median@current,
            Min@current,
            Max@current,
            Quantile[current, 0.25],
            Quantile[current, 0.75],
            Length@current
          }
        ]
      ]
    ],
    Transpose@valueMatrix
  ];
  values = rows[[All, 1]];
  lower = rows[[All, 2]];
  upper = rows[[All, 3]];
  q25 = rows[[All, 4]];
  q75 = rows[[All, 5]];
  contributors = rows[[All, 6]];
  <|
    "GroupRecord" -> groupRecord,
    "Variable" -> variable,
    "TargetDatesUTC" -> dates,
    "Values" -> values,
    "TimeSeries" -> makeTimeSeries[dates, values],
    "MinimumSeries" -> makeTimeSeries[dates, lower],
    "MaximumSeries" -> makeTimeSeries[dates, upper],
    "Q25Series" -> makeTimeSeries[dates, q25],
    "Q75Series" -> makeTimeSeries[dates, q75],
    "ContributorCounts" -> contributors,
    "ValidHourlyCount" -> Count[values, _?NumericQ]
  |>
];

loadManifestExpression[path_String] := Which[
  ToLowerCase@FileExtension[path] === "wl", Quiet@Check[Get[path], $Failed],
  ToLowerCase@FileExtension[path] === "json", Quiet@Check[Import[path, "RawJSON"], $Failed],
  True, $Failed
];

LoadWUFIManifestAny[path_String] := Module[{manifest},
  If[!FileExistsQ[path], Return@Failure["ManifestMissing", <|"Path" -> path|>]];
  manifest = loadManifestExpression@ExpandFileName@path;
  If[!AssociationQ[manifest], Return@Failure["ManifestInvalid", <|"Path" -> path|>]];
  If[!ListQ@Lookup[manifest, "Projects", Missing["Projects"]],
    Return@Failure["ManifestProjectsInvalid", <|"Path" -> path|>]
  ];
  manifest
];

allCaseSelections[manifest_Association] := Flatten[
  Map[
    Function[project,
      Map[
        <|"Project" -> project, "Case" -> #|> &,
        Lookup[project, "Cases", {}]
      ]
    ],
    Lookup[manifest, "Projects", {}]
  ],
  1
];

resolveOneSelector[all_List, selector_] := Module[{matches, projectName, caseName, caseIndex},
  matches = Which[
    StringQ[selector],
      Select[
        all,
        MemberQ[
          {
            Lookup[Lookup[#, "Case"], "CaseName", ""],
            Lookup[Lookup[#, "Case"], "CaseFolderName", ""]
          },
          selector
        ] &
      ],
    IntegerQ[selector],
      Select[all, Lookup[Lookup[#, "Case"], "CaseIndex", Missing["NotAvailable"]] === selector &],
    AssociationQ[selector],
      projectName = Lookup[selector, "ProjectBaseName", Lookup[selector, "Project", All]];
      caseName = Lookup[selector, "CaseName", Lookup[selector, "Case", All]];
      caseIndex = Lookup[selector, "CaseIndex", All];
      Select[
        all,
        (projectName === All || Lookup[Lookup[#, "Project"], "ProjectBaseName", ""] === projectName) &&
        (caseName === All || Lookup[Lookup[#, "Case"], "CaseName", ""] === caseName) &&
        (caseIndex === All || Lookup[Lookup[#, "Case"], "CaseIndex", Missing["NotAvailable"]] === caseIndex) &
      ],
    True,
      {}
  ];
  Which[
    Length@matches == 1, First@matches,
    matches === {}, Failure["CaseSelectorNotFound", <|"Selector" -> selector|>],
    True, Failure["CaseSelectorAmbiguous", <|"Selector" -> selector, "MatchCount" -> Length@matches|>]
  ]
];

ResolveWUFISelections[manifest_Association, selectors_] := Module[{all, resolved},
  all = allCaseSelections@manifest;
  If[selectors === All, Return@all];
  resolved = resolveOneSelector[all, #] & /@ Flatten@{selectors};
  If[AnyTrue[resolved, FailureQ], Return@First@Select[resolved, FailureQ]];
  DeleteDuplicatesBy[
    resolved,
    {
      Lookup[Lookup[#, "Project"], "ProjectBaseName"],
      Lookup[Lookup[#, "Case"], "CaseIndex"]
    } &
  ]
];

forceWallClockToUTC[date_, fixedTimeZone_?NumericQ] := Module[{parts, fixed},
  parts = Quiet@Check[Take[DateList@date, 6], $Failed];
  If[parts === $Failed, Return[Missing["InvalidDate"]]];
  fixed = DateObject[parts, TimeZone -> fixedTimeZone];
  TimeZoneConvert[fixed, 0]
];

timeSeriesPath[series_] := Module[{path},
  path = Quiet@Check[series["Path"], $Failed];
  If[ListQ[path], path, If[ListQ[series], series, $Failed]]
];

normalizeWUFISeries[
  series_,
  fixedTimeZone_?NumericQ
] := Module[{path},
  path = timeSeriesPath@series;
  If[
    !ListQ[path],
    Return@Failure["WUFITimeSeriesInvalid", <||>]
  ];
  Cases[
    path,
    {date_, value_?NumericQ} :>
      {
        forceWallClockToUTC[date, fixedTimeZone],
        N@value
      }
  ]
];

normalizeWUFISeriesCollection[
  seriesCollection_List,
  fixedTimeZone_?NumericQ
] := Module[
  {
    paths, numericPaths, lengths, referenceDates, normalizedDates,
    dateLists, fallbackPairs, fallbackDates, fallbackAllDates
  },
  paths = timeSeriesPath /@ seriesCollection;
  If[
    AnyTrue[paths, !ListQ[#] &],
    Return@Failure[
      "WUFITimeSeriesInvalid",
      <|"SeriesCount" -> Length@seriesCollection|>
    ]
  ];
  numericPaths = Map[
    Cases[
      #,
      {date_, value_?NumericQ} :> {date, N@value}
    ] &,
    paths
  ];
  lengths = Length /@ numericPaths;
  If[
    lengths === {} ||
      Length@DeleteDuplicates@lengths =!= 1,
    Return@Failure[
      "WUFISeriesLengthMismatch",
      <|"Lengths" -> lengths|>
    ]
  ];
  referenceDates = First /@ First@numericPaths;
  dateLists = First /@ # & /@ Rest@numericPaths;
  If[
    !And @@ (SameQ[#, referenceDates] & /@ dateLists),
    fallbackPairs = normalizeWUFISeries[
      #,
      fixedTimeZone
    ] & /@ seriesCollection;
    If[
      AnyTrue[fallbackPairs, FailureQ],
      Return@Failure[
        "WUFITimeSeriesNormalizationFailed",
        <|"SeriesCount" -> Length@seriesCollection|>
      ]
    ];
    fallbackDates = First /@ First@fallbackPairs;
    fallbackAllDates = (
      dateUnixSeconds /@ (First /@ #)
    ) & /@ fallbackPairs;
    If[
      !And @@ (
        Max[
          Abs[# - First@fallbackAllDates]
        ] < 0.5 & /@ Rest@fallbackAllDates
      ),
      Return@Failure[
        "WUFITimestampMismatch",
        <|"SeriesCount" -> Length@numericPaths|>
      ]
    ];
    Return@<|
      "TargetDatesUTC" -> fallbackDates,
      "Pairs" -> fallbackPairs,
      "PointCount" -> Length@fallbackDates,
      "SharedRawGridFastPathQ" -> False
    |>
  ];
  normalizedDates = forceWallClockToUTC[
    #,
    fixedTimeZone
  ] & /@ referenceDates;
  If[
    AnyTrue[normalizedDates, MissingQ],
    Return@Failure[
      "WUFITimeSeriesNormalizationFailed",
      <||>
    ]
  ];
  <|
    "TargetDatesUTC" -> normalizedDates,
    "Pairs" -> (
      Transpose[
        {
          normalizedDates,
          #[[All, 2]]
        }
      ] &
    ) /@ numericPaths,
    "PointCount" -> Length@normalizedDates,
    "SharedRawGridFastPathQ" -> True
  |>
];

LoadWUFICaseSeries[
  productionRoot_String,
  selection_Association,
  settings_Association
] := Module[
  {
    project, case, projectName, caseFolder, base, timeSeriesFolder,
    temperaturePath, rhPath, temperatureRaw, rhRaw, expected,
    fixedZone, normalizedCollection, allPairs, temperaturePairs,
    rhPairs, targetDates
  },
  project = Lookup[selection, "Project"];
  case = Lookup[selection, "Case"];
  projectName = Lookup[project, "ProjectBaseName"];
  caseFolder = Lookup[case, "CaseFolderName"];
  base = FileNameJoin[
    {productionRoot, projectName, caseFolder}
  ];
  timeSeriesFolder = FileNameJoin[{base, "time_series"}];
  temperaturePath = FileNameJoin[
    {timeSeriesFolder, "temperature.wxf"}
  ];
  rhPath = FileNameJoin[
    {timeSeriesFolder, "relative_humidity.wxf"}
  ];
  If[
    !FileExistsQ[temperaturePath] ||
      !FileExistsQ[rhPath],
    Return@Failure[
      "WUFITimeSeriesMissing",
      <|
        "TemperaturePath" -> temperaturePath,
        "RHPath" -> rhPath
      |>
    ]
  ];
  temperatureRaw = Quiet@Check[
    Import[temperaturePath, "WXF"],
    $Failed
  ];
  rhRaw = Quiet@Check[
    Import[rhPath, "WXF"],
    $Failed
  ];
  If[
    !ListQ[temperatureRaw] ||
      !ListQ[rhRaw],
    Return@Failure[
      "WUFITimeSeriesImportFailed",
      <|"Case" -> Lookup[case, "CaseName"]|>
    ]
  ];
  expected = Lookup[
    case,
    "TotalSensorCount",
    Length@temperatureRaw
  ];
  If[
    Length@temperatureRaw =!= expected ||
      Length@rhRaw =!= expected,
    Return@Failure[
      "WUFISeriesCountMismatch",
      <|
        "Expected" -> expected,
        "TemperatureCount" -> Length@temperatureRaw,
        "RHCount" -> Length@rhRaw
      |>
    ]
  ];
  fixedZone = Lookup[settings, "WUFIFixedTimeZone", 2];
  normalizedCollection = normalizeWUFISeriesCollection[
    Join[temperatureRaw, rhRaw],
    fixedZone
  ];
  If[
    FailureQ[normalizedCollection],
    Return@normalizedCollection
  ];
  allPairs = Lookup[normalizedCollection, "Pairs"];
  temperaturePairs = Take[allPairs, expected];
  rhPairs = Drop[allPairs, expected];
  targetDates = Lookup[
    normalizedCollection,
    "TargetDatesUTC"
  ];
  <|
    "Selection" -> selection,
    "ProjectRecord" -> project,
    "CaseRecord" -> case,
    "CaseBaseDirectory" -> base,
    "TemperaturePath" -> temperaturePath,
    "RelativeHumidityPath" -> rhPath,
    "TargetDatesUTC" -> targetDates,
    "TargetUnixSecondsUTC" ->
      (dateUnixSeconds /@ targetDates),
    "TemperaturePairsBySensorIndex" ->
      AssociationThread[
        Range[expected],
        temperaturePairs
      ],
    "RelativeHumidityPairsBySensorIndex" ->
      AssociationThread[
        Range[expected],
        rhPairs
      ],
    "PointCount" -> Lookup[
      normalizedCollection,
      "PointCount"
    ],
    "SharedRawGridFastPathQ" -> Lookup[
      normalizedCollection,
      "SharedRawGridFastPathQ",
      False
    ]
  |>
];

caseWallSystem[caseRecord_Association, settings_Association] := Module[{name, rules, match},
  name = Lookup[caseRecord, "CaseName", ""];
  rules = Lookup[settings, "CaseWallSystemRules", {}];
  match = SelectFirst[rules, StringContainsQ[name, First[#]] &, Missing["NoRule"]];
  If[MissingQ[match], Missing["UnknownWallSystem"], Last@match]
];

internalMonitorRecords[caseRecord_Association] := Select[
  Lookup[caseRecord, "Sensors", {}],
  Lookup[#, "Kind", ""] === "Internal" && NumericQ@Lookup[#, "GlobalDepthMetres", Missing["NotAvailable"]] &
];

containingLayer[caseRecord_Association, depth_?NumericQ] := SelectFirst[
  Lookup[caseRecord, "Layers", {}],
  Lookup[#, "StartDepthMetres", Infinity] - 10^-9 <= depth <= Lookup[#, "EndDepthMetres", -Infinity] + 10^-9 &,
  Missing["OutsideAssembly"]
];

exactSpatialMatch[group_, case_, settings_] := Module[{target, monitors, tolerance, candidates, selected},
  target = Lookup[group, "TargetDepthMetres"];
  monitors = internalMonitorRecords@case;
  tolerance = Lookup[settings, "ExactDepthToleranceMetres", 0.002];
  candidates = Select[monitors, Abs[Lookup[#, "GlobalDepthMetres"] - target] <= tolerance &];
  If[candidates === {}, Return@Failure["NoExactMonitor", <|"TargetDepthMetres" -> target|>]];
  selected = First@SortBy[candidates, Abs[Lookup[#, "GlobalDepthMetres"] - target] &];
  <|
    "Method" -> "Exact",
    "TargetDepthMetres" -> target,
    "SeriesIndices" -> {Lookup[selected, "SensorIndex"]},
    "MonitorDepthsMetres" -> {Lookup[selected, "GlobalDepthMetres"]},
    "Weights" -> {1.},
    "LayerIndex" -> Lookup[selected, "LayerIndex"],
    "MaterialName" -> Lookup[selected, "MaterialName"],
    "DepthOffsetMetres" -> Lookup[selected, "GlobalDepthMetres"] - target,
    "Extrapolation" -> False
  |>
];

nearestSpatialMatch[group_, case_, settings_] := Module[{target, monitors, selected, offset, maximum},
  target = Lookup[group, "TargetDepthMetres"];
  monitors = internalMonitorRecords@case;
  If[monitors === {}, Return@Failure["NoInternalMonitors", <||>]];
  selected = First@SortBy[monitors, Abs[Lookup[#, "GlobalDepthMetres"] - target] &];
  offset = Lookup[selected, "GlobalDepthMetres"] - target;
  maximum = Lookup[settings, "MaximumNearestDepthOffsetMetres", 0.03];
  If[Abs[offset] > maximum,
    Return@Failure["NearestMonitorTooFar", <|"TargetDepthMetres" -> target, "OffsetMetres" -> offset, "MaximumMetres" -> maximum|>]
  ];
  <|
    "Method" -> "NearestMonitor",
    "TargetDepthMetres" -> target,
    "SeriesIndices" -> {Lookup[selected, "SensorIndex"]},
    "MonitorDepthsMetres" -> {Lookup[selected, "GlobalDepthMetres"]},
    "Weights" -> {1.},
    "LayerIndex" -> Lookup[selected, "LayerIndex"],
    "MaterialName" -> Lookup[selected, "MaterialName"],
    "DepthOffsetMetres" -> offset,
    "Extrapolation" -> False
  |>
];

linearSpatialMatch[group_, case_, settings_] := Module[
  {target, layer, layerIndex, monitors, sorted, left, right, allowExtrapolation,
   selected, depths, weight, extrapolation},
  target = Lookup[group, "TargetDepthMetres"];
  layer = containingLayer[case, target];
  If[MissingQ[layer], Return@Failure["TargetOutsideAssembly", <|"TargetDepthMetres" -> target|>]];
  layerIndex = Lookup[layer, "LayerIndex"];
  monitors = Select[internalMonitorRecords@case, Lookup[#, "LayerIndex", Missing["NotAvailable"]] === layerIndex &];
  sorted = SortBy[monitors, Lookup[#, "GlobalDepthMetres"] &];
  If[Length@sorted < 2,
    Return@Failure["InsufficientSameMaterialMonitors", <|"LayerIndex" -> layerIndex, "MonitorCount" -> Length@sorted|>]
  ];
  left = Select[sorted, Lookup[#, "GlobalDepthMetres"] <= target &];
  right = Select[sorted, Lookup[#, "GlobalDepthMetres"] >= target &];
  extrapolation = False;
  If[left =!= {} && right =!= {},
    selected = {Last@left, First@right};
    If[Lookup[First@selected, "SensorIndex"] === Lookup[Last@selected, "SensorIndex"],
      Return@exactSpatialMatch[group, case, settings]
    ],
    allowExtrapolation = TrueQ@Lookup[settings, "AllowSameMaterialExtrapolation", False];
    If[!allowExtrapolation,
      Return@Failure["NoSameMaterialBracket", <|"TargetDepthMetres" -> target, "LayerIndex" -> layerIndex|>]
    ];
    selected = Take[SortBy[sorted, Abs[Lookup[#, "GlobalDepthMetres"] - target] &], 2];
    selected = SortBy[selected, Lookup[#, "GlobalDepthMetres"] &];
    extrapolation = True
  ];
  depths = Lookup[selected, "GlobalDepthMetres"];
  If[Last@depths == First@depths, Return@Failure["CoincidentMonitors", <|"Depths" -> depths|>]];
  weight = (target - First@depths)/(Last@depths - First@depths);
  <|
    "Method" -> "LinearWithinSameMaterial",
    "TargetDepthMetres" -> target,
    "SeriesIndices" -> Lookup[selected, "SensorIndex"],
    "MonitorDepthsMetres" -> depths,
    "Weights" -> {1. - weight, weight},
    "LayerIndex" -> layerIndex,
    "MaterialName" -> Lookup[layer, "MaterialName"],
    "DepthOffsetMetres" -> 0.,
    "Extrapolation" -> extrapolation
  |>
];

BuildSpatialMatch[
  groupRecord_Association,
  caseRecord_Association,
  method_String,
  settings_Association
] := Module[{result},
  Switch[method,
    "Exact", exactSpatialMatch[groupRecord, caseRecord, settings],
    "NearestMonitor", nearestSpatialMatch[groupRecord, caseRecord, settings],
    "LinearWithinSameMaterial", linearSpatialMatch[groupRecord, caseRecord, settings],
    "Auto",
      result = exactSpatialMatch[groupRecord, caseRecord, settings];
      If[!FailureQ[result], Return@result];
      result = linearSpatialMatch[groupRecord, caseRecord, settings];
      If[!FailureQ[result], Return@result];
      nearestSpatialMatch[groupRecord, caseRecord, settings],
    _, Failure["UnknownSpatialMethod", <|"Method" -> method|>]
  ]
];

weightedNumeric[values_List, weights_List] := If[
  Length@values === Length@weights && And @@ (NumericQ /@ values),
  Total[N@values * N@weights],
  Missing["MissingSpatialInput"]
];

evaluateMatchedValues[caseData_Association, match_Association] := Module[
  {indices, weights, temperatureSeries, rhSeries, dates, temperatureValues,
   rhValues, outputTemperature, outputRH, i, tValues, hValues, vapourValues,
   temperature, vapour, rh},
  indices = Lookup[match, "SeriesIndices"];
  weights = Lookup[match, "Weights"];
  temperatureSeries = Lookup[Lookup[caseData, "TemperaturePairsBySensorIndex"], #] & /@ indices;
  rhSeries = Lookup[Lookup[caseData, "RelativeHumidityPairsBySensorIndex"], #] & /@ indices;
  dates = First /@ First@temperatureSeries;
  temperatureValues = Last /@ # & /@ temperatureSeries;
  rhValues = Last /@ # & /@ rhSeries;
  outputTemperature = {};
  outputRH = {};
  Do[
    tValues = temperatureValues[[All, i]];
    hValues = rhValues[[All, i]];
    temperature = weightedNumeric[tValues, weights];
    If[NumericQ[temperature] && And @@ (NumericQ /@ hValues),
      vapourValues = MapThread[(#2/100.) * SaturationPressureFactorC[#1] &, {tValues, hValues}];
      vapour = weightedNumeric[vapourValues, weights];
      rh = If[NumericQ[vapour], 100. * vapour/SaturationPressureFactorC[temperature], Missing["MissingSpatialInput"]],
      rh = Missing["MissingSpatialInput"]
    ];
    AppendTo[outputTemperature, temperature];
    AppendTo[outputRH, rh],
    {i, Length@dates}
  ];
  <|
    "Match" -> match,
    "TargetDatesUTC" -> dates,
    "TemperatureValues" -> outputTemperature,
    "RelativeHumidityValues" -> outputRH,
    "TemperatureSeries" -> makeTimeSeries[dates, outputTemperature],
    "RelativeHumiditySeries" -> makeTimeSeries[dates, outputRH]
  |>
];

EvaluateSpatialMatch[caseData_Association, match_Association] := evaluateMatchedValues[caseData, match];

utcDateObject[value_] := Which[
  Head[value] === DateObject, TimeZoneConvert[value, 0],
  NumericQ[value], Missing["AmbiguousNumericTemporalCoordinate"],
  True, Missing["InvalidDate"]
];

utcDateString[value_] := Module[{date = utcDateObject@value},
  If[
    Head[date] === DateObject,
    DateString[date, {"ISODate", "T", "Time", "Z"}],
    ""
  ]
];

utcMillisecondKey[value_] := Module[{date = utcDateObject@value},
  If[
    Head[date] === DateObject,
    Round[1000. * N@UnixTime@date],
    Missing["InvalidDate"]
  ]
];

temporalPathDateToUTC[
  value_,
  pathTimeZone_?NumericQ
] := Which[
  Head[value] === DateObject,
    TimeZoneConvert[value, 0],
  NumericQ[value],
    TimeZoneConvert[
      FromAbsoluteTime[N@value, TimeZone -> pathTimeZone],
      0
    ],
  True,
    Missing["InvalidTemporalCoordinate"]
];

temporalPathMillisecondKey[
  value_,
  pathTimeZone_?NumericQ
] := Module[{date},
  date = temporalPathDateToUTC[value, pathTimeZone];
  If[
    Head[date] === DateObject,
    Round[1000. * N@UnixTime@date],
    Missing["InvalidTemporalCoordinate"]
  ]
];

absoluteDateKey[date_] := utcMillisecondKey@date;

dateValueAssociation[series_] := Association@Map[
  absoluteDateKey[First[#]] -> {First[#], Last[#]} &,
  SeriesPairs@series
];

pairedRowsFromAssociations[sensorAssociation_Association, modelAssociation_Association] := Module[{keys},
  keys = Sort@Intersection[Keys@sensorAssociation, Keys@modelAssociation];
  Cases[
    Map[
      Function[key,
        Module[{sensor, model},
          sensor = Lookup[sensorAssociation, key];
          model = Lookup[modelAssociation, key];
          {First@sensor, Last@sensor, Last@model, Last@model - Last@sensor}
        ]
      ],
      keys
    ],
    {_, _?NumericQ, _?NumericQ, _?NumericQ}
  ]
];

PairSensorModelSeries[sensorSeries_, modelSeries_] := pairedRowsFromAssociations[
  dateValueAssociation@sensorSeries,
  dateValueAssociation@modelSeries
];

pairExplicitUTCSeries[
  sensorDates_List,
  sensorValues_List,
  modelDates_List,
  modelValues_List
] := Module[
  {sensorAssociation, modelAssociation, keys},
  sensorAssociation = Association@MapThread[
    utcMillisecondKey[#1] -> {utcDateObject@#1, #2} &,
    {sensorDates, sensorValues}
  ];
  modelAssociation = Association@MapThread[
    utcMillisecondKey[#1] -> {utcDateObject@#1, #2} &,
    {modelDates, modelValues}
  ];
  sensorAssociation = Select[
    sensorAssociation,
    NumericQ@Last[#] &
  ];
  modelAssociation = Select[
    modelAssociation,
    NumericQ@Last[#] &
  ];
  keys = Sort@Intersection[Keys@sensorAssociation, Keys@modelAssociation];
  Cases[
    Map[
      Function[key,
        Module[{sensor, model},
          sensor = Lookup[sensorAssociation, key];
          model = Lookup[modelAssociation, key];
          {
            First@model,
            Last@sensor,
            Last@model,
            Last@model - Last@sensor
          }
        ]
      ],
      keys
    ],
    {_DateObject, _?NumericQ, _?NumericQ, _?NumericQ}
  ]
];

pairSensorModelData[
  sensorGroup_Association,
  modelAtDepth_Association,
  variable_String
] := Module[
  {sensorDates, sensorValues, modelDates, modelValues},
  sensorDates = Lookup[sensorGroup, "TargetDatesUTC", {}];
  sensorValues = Lookup[sensorGroup, "Values", {}];
  modelDates = Lookup[modelAtDepth, "TargetDatesUTC", {}];
  modelValues = If[
    variable === "Temperature",
    Lookup[modelAtDepth, "TemperatureValues", {}],
    Lookup[modelAtDepth, "RelativeHumidityValues", {}]
  ];
  If[
    !SameQ[
      Length@sensorDates,
      Length@sensorValues
    ] ||
      !SameQ[
        Length@modelDates,
        Length@modelValues
      ],
    Return@Failure[
      "ExplicitUTCSeriesLengthMismatch",
      <|
        "SensorDateCount" -> Length@sensorDates,
        "SensorValueCount" -> Length@sensorValues,
        "ModelDateCount" -> Length@modelDates,
        "ModelValueCount" -> Length@modelValues
      |>
    ]
  ];
  pairExplicitUTCSeries[
    sensorDates,
    sensorValues,
    modelDates,
    modelValues
  ]
];

correlationSafe[x_List, y_List] := If[
  Length@x >= 3 && StandardDeviation@x > 0 && StandardDeviation@y > 0,
  Correlation[x, y],
  Missing["Undefined"]
];

regressionSafe[measured_List, modelled_List] := Module[{variance, slope, intercept},
  variance = If[Length@measured >= 2, Variance@measured, 0.];
  If[variance <= 0, Return[<|"Slope" -> Missing["Undefined"], "Intercept" -> Missing["Undefined"]|>]];
  slope = Covariance[measured, modelled]/variance;
  intercept = Mean@modelled - slope * Mean@measured;
  <|"Slope" -> slope, "Intercept" -> intercept|>
];

bestLagMetric[pairedRows_List, lagHours_List] := Module[
  {
    sensor, model, results, lag, shiftedKeys, pairs, corr,
    validResults, minimumLag, maximumLag
  },
  sensor = Association@Map[
    absoluteDateKey[#[[1]]] -> #[[2]] &,
    pairedRows
  ];
  model = Association@Map[
    absoluteDateKey[#[[1]]] -> #[[3]] &,
    pairedRows
  ];
  minimumLag = If[lagHours === {}, Missing["Undefined"], Min@lagHours];
  maximumLag = If[lagHours === {}, Missing["Undefined"], Max@lagHours];
  results = Table[
    shiftedKeys = Select[
      Keys@sensor,
      KeyExistsQ[
        model,
        # + lag * 3600 * 1000
      ] &
    ];
    pairs = Cases[
      (
        {
          Lookup[sensor, #],
          Lookup[
            model,
            # + lag * 3600 * 1000
          ]
        } &
      ) /@ shiftedKeys,
      {_?NumericQ, _?NumericQ}
    ];
    corr = If[
      Length@pairs >= 3,
      correlationSafe[
        pairs[[All, 1]],
        pairs[[All, 2]]
      ],
      Missing["Undefined"]
    ];
    <|
      "LagHours" -> lag,
      "Correlation" -> corr,
      "PairCount" -> Length@pairs
    |>,
    {lag, lagHours}
  ];
  validResults = Select[
    results,
    NumericQ@Lookup[#, "Correlation"] &
  ];
  If[
    validResults === {},
    <|
      "BestLagHours" -> Missing["Undefined"],
      "BestLagCorrelation" -> Missing["Undefined"],
      "BestLagAtSearchBoundaryQ" -> Missing["Undefined"],
      "LagSearchMinimumHours" -> minimumLag,
      "LagSearchMaximumHours" -> maximumLag,
      "LagTable" -> results
    |>,
    With[
      {
        best = First@SortBy[
          validResults,
          -Lookup[#, "Correlation"] &
        ]
      },
      <|
        "BestLagHours" -> Lookup[best, "LagHours"],
        "BestLagCorrelation" ->
          Lookup[best, "Correlation"],
        "BestLagAtSearchBoundaryQ" ->
          MemberQ[
            {minimumLag, maximumLag},
            Lookup[best, "LagHours"]
          ],
        "LagSearchMinimumHours" -> minimumLag,
        "LagSearchMaximumHours" -> maximumLag,
        "LagTable" -> results,
        "LagConvention" ->
          "Positive lag compares sensor(t) with WUFI(t+lag)."
      |>
    ]
  ]
];

thresholdMetrics[measured_List, modelled_List, thresholds_List] := Association@Map[
  Function[threshold,
    ToString[threshold] -> <|
      "MeasuredHoursAbove" -> Count[measured, x_ /; x > threshold],
      "ModelledHoursAbove" -> Count[modelled, x_ /; x > threshold],
      "ModelMinusMeasuredHoursAbove" -> Count[modelled, x_ /; x > threshold] - Count[measured, x_ /; x > threshold],
      "MeasuredIntegratedExceedance_pph" -> Total[Clip[measured - threshold, {0., Infinity}]],
      "ModelledIntegratedExceedance_pph" -> Total[Clip[modelled - threshold, {0., Infinity}]]
    |>
  ],
  thresholds
];

metricsCore[pairedRows_List, variable_String, settings_Association] := Module[
  {measured, modelled, residual, regression, standardDeviationRatio, lag,
   result, thresholds, pathTimeZone},
  If[pairedRows === {}, Return[<|"PairCount" -> 0|>]];
  pathTimeZone = Lookup[
    settings,
    "TemporalPathTimeZoneHours",
    $TimeZone
  ];
  measured = N@pairedRows[[All, 2]];
  modelled = N@pairedRows[[All, 3]];
  residual = modelled - measured;
  regression = regressionSafe[measured, modelled];
  standardDeviationRatio = If[StandardDeviation@measured > 0, StandardDeviation@modelled/StandardDeviation@measured, Missing["Undefined"]];
  lag = bestLagMetric[pairedRows, Lookup[settings, "CrossCorrelationLagHours", Range[-24, 24]]];
  result = <|
    "PairCount" -> Length@pairedRows,
    "StartUTC" -> temporalPathDateToUTC[
      First@First@pairedRows,
      pathTimeZone
    ],
    "EndUTC" -> temporalPathDateToUTC[
      First@Last@pairedRows,
      pathTimeZone
    ],
    "MeanBias_WUFI_minus_sensor" -> Mean@residual,
    "MAE" -> Mean@Abs@residual,
    "RMSE" -> Sqrt@Mean[residual^2],
    "CenteredRMSE" -> Sqrt@Mean[(residual - Mean@residual)^2],
    "PearsonCorrelation" -> correlationSafe[measured, modelled],
    "RegressionSlope" -> Lookup[regression, "Slope"],
    "RegressionIntercept" -> Lookup[regression, "Intercept"],
    "StandardDeviationRatio" -> standardDeviationRatio,
    "ResidualP05" -> Quantile[residual, 0.05],
    "ResidualMedian" -> Median@residual,
    "ResidualP95" -> Quantile[residual, 0.95],
    "MaximumAbsoluteError" -> Max@Abs@residual,
    "BestLagHours" -> Lookup[lag, "BestLagHours"],
    "BestLagCorrelation" -> Lookup[lag, "BestLagCorrelation"],
    "BestLagAtSearchBoundaryQ" ->
      Lookup[lag, "BestLagAtSearchBoundaryQ"],
    "LagSearchMinimumHours" ->
      Lookup[lag, "LagSearchMinimumHours"],
    "LagSearchMaximumHours" ->
      Lookup[lag, "LagSearchMaximumHours"],
    "LagConvention" -> Lookup[lag, "LagConvention", ""]
  |>;
  If[variable === "RelativeHumidity",
    thresholds = thresholdMetrics[measured, modelled, Lookup[settings, "RelativeHumidityThresholds", {80., 85., 90., 95.}]];
    AssociateTo[result, "ThresholdMetrics" -> thresholds]
  ];
  result
];

dropInitialHours[
  pairedRows_List,
  hours_?NumericQ,
  anchor_:Automatic,
  pathTimeZone_:Automatic
] := Module[{zone, startUnix},
  If[pairedRows === {}, Return[{}]];
  zone = If[NumericQ[pathTimeZone], pathTimeZone, $TimeZone];
  startUnix = Which[
    dateQ[anchor],
      N@UnixTime@utcDateObject@anchor + hours * 3600.,
    NumericQ[anchor],
      N@UnixTime@temporalPathDateToUTC[anchor, zone] +
        hours * 3600.,
    True,
      N@UnixTime@temporalPathDateToUTC[
        First@First@pairedRows,
        zone
      ] + hours * 3600.
  ];
  Select[
    pairedRows,
    N@UnixTime@temporalPathDateToUTC[First[#], zone] >=
      startUnix &
  ]
];

ComparisonMetrics[pairedRows_List, variable_String, settings_Association] := <|
  "FullPeriod" -> metricsCore[pairedRows, variable, settings],
  "AfterInitialExclusion" -> metricsCore[
    dropInitialHours[
      pairedRows,
      Lookup[settings, "ExcludeInitialHoursForSecondaryMetrics", 24.],
      Lookup[settings, "ComparisonStartUTC", Automatic],
      Lookup[settings, "TemporalPathTimeZoneHours", $TimeZone]
    ],
    variable,
    settings
  ],
  "InitialExclusionHours" -> Lookup[settings, "ExcludeInitialHoursForSecondaryMetrics", 24.]
|>;

ensureDirectory[path_String] := Quiet@CreateDirectory[ExpandFileName@path, CreateIntermediateDirectories -> True];

csvScalar[value_] := Which[
  MissingQ[value], "",
  Head[value] === DateObject, utcDateString@value,
  AssociationQ[value] || ListQ[value], ExportString[jsonSafe@value, "RawJSON", "Compact" -> True],
  True, value
];

exportRowsCSV[path_String, rows_List] := Module[{keys, matrix},
  ensureDirectory@DirectoryName@path;
  If[rows === {}, Return@Export[path, {{"NoRows"}}, "CSV"]];
  keys = DeleteDuplicates@Flatten[Keys /@ Select[rows, AssociationQ]];
  matrix = Prepend[
    Map[(csvScalar /@ Lookup[#, keys, Missing["NotAvailable"]]) &, rows],
    keys
  ];
  Export[path, matrix, "CSV"]
];

jsonSafe[value_] := Which[
  AssociationQ[value], Association@KeyValueMap[ToString[#1] -> jsonSafe[#2] &, value],
  ListQ[value], jsonSafe /@ value,
  Head[value] === DateObject, utcDateString@value,
  MissingQ[value], Null,
  FailureQ[value], <|"FailureTag" -> ToString@First@value, "FailureData" -> jsonSafe@Last@value|>,
  Head[value] === TimeSeries || Head[value] === TemporalData, "[TimeSeries omitted from JSON manifest]",
  NumericQ[value] || StringQ[value] || TrueQ[value] || value === False || value === Null, value,
  True, ToString[value, InputForm]
];

exportWLAndJSON[basePath_String, expression_, writeJSON_:True] := Module[{wlPath, jsonPath, wlResult, jsonResult},
  ensureDirectory@DirectoryName@basePath;
  wlPath = basePath <> ".wl";
  jsonPath = basePath <> ".json";
  Put[expression, wlPath];
  wlResult = <|"Path" -> wlPath, "ByteCount" -> FileByteCount@wlPath|>;
  jsonResult = If[TrueQ@writeJSON,
    Quiet@Check[Export[jsonPath, jsonSafe@expression, "RawJSON", "Compact" -> False], $Failed],
    Missing["Disabled"]
  ];
  <|"WL" -> wlResult, "JSON" -> jsonResult|>
];


fixedWallClockStringToUTC[value_String, fixedTimeZone_?NumericQ] := Module[
  {parts, localDate},
  parts = Quiet@Check[Take[DateList[value], 6], $Failed];
  If[parts === $Failed, Return[Missing["InvalidWallClock"]]];
  localDate = DateObject[parts, TimeZone -> fixedTimeZone];
  TimeZoneConvert[localDate, 0]
];
fixedWallClockStringToUTC[_, _] := Missing["InvalidWallClock"];

hourlyUTCGridQ[dates_List] := Module[{times, differences},
  If[Length@dates < 2, Return[True]];
  times = N@UnixTime /@ (utcDateObject /@ dates);
  If[AnyTrue[times, !NumericQ[#] &], Return[False]];
  differences = Differences@times;
  Max[Abs[differences - 3600.]] < 0.5
];

hourlyTemporalGridQ[
  dates_List,
  pathTimeZone_?NumericQ
] := Module[{times, differences},
  If[Length@dates < 2, Return[True]];
  times = N@UnixTime /@
    (temporalPathDateToUTC[#, pathTimeZone] & /@ dates);
  If[AnyTrue[times, !NumericQ[#] &], Return[False]];
  differences = Differences@times;
  Max[Abs[differences - 3600.]] < 0.5
];

comparisonWXFFiles[outputRoot_String, settings_Association] := FileNames[
  "*.wxf",
  FileNameJoin[{outputRoot, comparisonOutputDirectoryName@settings}],
  Infinity
];

auditOneComparisonWXF[
  path_String,
  expectedCaseRecords_Association,
  settings_Association,
  runTimeZone_?NumericQ
] := Module[
  {
    payload, modelPath, sensorPath, pairedRows, modelDates, sensorDates,
    pairedDates, modelKeys, sensorKeys, pairedKeys, caseFolder,
    caseRecord, fixedZone, expectedStart, expectedEnd, expectedCount,
    modelStart, modelEnd, sensorStart, sensorEnd, pairedStart, pairedEnd,
    missingFromModel, missingFromSensor, maxOffset, pass,
    pathTimeZone
  },
  payload = Quiet@Check[Import[path, "WXF"], $Failed];
  If[!AssociationQ[payload],
    Return@<|"File" -> path, "PassQ" -> False,
      "Failure" -> "WXFImportOrSchemaFailure"|>
  ];

  pairedRows = Lookup[payload, "PairedRows", {}];
  pathTimeZone = Lookup[
    payload,
    "TemporalPathTimeZoneHours",
    runTimeZone
  ];

  If[
    Lookup[
      payload,
      "TemporalCoordinateSchema",
      "LegacyTimeSeriesPath"
    ] === "ExplicitUTCDateObjectsV2",
    modelDates = Lookup[payload, "WUFITargetDatesUTC", {}];
    sensorDates = Lookup[payload, "SensorTargetDatesUTC", {}];
    pairedDates = If[
      pairedRows === {},
      {},
      pairedRows[[All, 1]]
    ];
    modelKeys = DeleteMissing[
      utcMillisecondKey /@ modelDates
    ];
    sensorKeys = DeleteMissing[
      utcMillisecondKey /@ sensorDates
    ];
    pairedKeys = DeleteMissing[
      utcMillisecondKey /@ pairedDates
    ];
    pathTimeZone = 0,
    modelPath = timeSeriesPath@Lookup[
      payload, "WUFISeriesAtSensorDepth", Missing["NoModelSeries"]
    ];
    sensorPath = timeSeriesPath@Lookup[
      payload, "SensorSeries", Missing["NoSensorSeries"]
    ];
    If[
      !ListQ[modelPath] ||
        !ListQ[sensorPath] ||
        !ListQ[pairedRows],
      Return@<|
        "File" -> path,
        "PassQ" -> False,
        "Failure" -> "ComparisonPayloadInvalid"
      |>
    ];
    modelDates = First /@ modelPath;
    sensorDates = First /@ sensorPath;
    pairedDates = If[
      pairedRows === {},
      {},
      pairedRows[[All, 1]]
    ];
    modelKeys = DeleteMissing[
      temporalPathMillisecondKey[
        #,
        pathTimeZone
      ] & /@ modelDates
    ];
    sensorKeys = DeleteMissing[
      temporalPathMillisecondKey[
        #,
        pathTimeZone
      ] & /@ sensorDates
    ];
    pairedKeys = DeleteMissing[
      temporalPathMillisecondKey[
        #,
        pathTimeZone
      ] & /@ pairedDates
    ]
  ];

  caseFolder = SelectFirst[
    Keys@expectedCaseRecords,
    StringContainsQ[path, #] &,
    Missing["CaseNotResolved"]
  ];
  caseRecord = Lookup[expectedCaseRecords, caseFolder, <||>];

  fixedZone = Lookup[settings, "WUFIFixedTimeZone", 2];
  expectedStart = fixedWallClockStringToUTC[
    Lookup[caseRecord, "CalculationStart", ""], fixedZone
  ];
  expectedEnd = fixedWallClockStringToUTC[
    Lookup[caseRecord, "CalculationEnd", ""], fixedZone
  ];
  expectedCount = If[
    Head[expectedStart] === DateObject &&
      Head[expectedEnd] === DateObject,
    Round[(UnixTime@expectedEnd - UnixTime@expectedStart)/3600.] + 1,
    Missing["Unavailable"]
  ];

  modelStart = If[
    modelDates === {},
    Missing["Unavailable"],
    If[
      pathTimeZone == 0 && Head[First@modelDates] === DateObject,
      utcDateObject@First@modelDates,
      temporalPathDateToUTC[First@modelDates, pathTimeZone]
    ]
  ];
  modelEnd = If[
    modelDates === {},
    Missing["Unavailable"],
    If[
      pathTimeZone == 0 && Head[Last@modelDates] === DateObject,
      utcDateObject@Last@modelDates,
      temporalPathDateToUTC[Last@modelDates, pathTimeZone]
    ]
  ];
  sensorStart = If[
    sensorDates === {},
    Missing["Unavailable"],
    If[
      pathTimeZone == 0 && Head[First@sensorDates] === DateObject,
      utcDateObject@First@sensorDates,
      temporalPathDateToUTC[First@sensorDates, pathTimeZone]
    ]
  ];
  sensorEnd = If[
    sensorDates === {},
    Missing["Unavailable"],
    If[
      pathTimeZone == 0 && Head[Last@sensorDates] === DateObject,
      utcDateObject@Last@sensorDates,
      temporalPathDateToUTC[Last@sensorDates, pathTimeZone]
    ]
  ];
  pairedStart = If[
    pairedDates === {},
    Missing["Unavailable"],
    If[
      pathTimeZone == 0 && Head[First@pairedDates] === DateObject,
      utcDateObject@First@pairedDates,
      temporalPathDateToUTC[First@pairedDates, pathTimeZone]
    ]
  ];
  pairedEnd = If[
    pairedDates === {},
    Missing["Unavailable"],
    If[
      pathTimeZone == 0 && Head[Last@pairedDates] === DateObject,
      utcDateObject@Last@pairedDates,
      temporalPathDateToUTC[Last@pairedDates, pathTimeZone]
    ]
  ];

  missingFromModel = Complement[pairedKeys, modelKeys];
  missingFromSensor = Complement[pairedKeys, sensorKeys];
  maxOffset = If[
    pairedKeys === {} || modelKeys === {},
    Missing["Unavailable"],
    Max[Min[Abs[# - modelKeys]] & /@ pairedKeys]/1000.
  ];

  pass =
    modelDates =!= {} &&
    If[
      pathTimeZone == 0 &&
        AllTrue[modelDates, Head[#] === DateObject &],
      hourlyUTCGridQ[modelDates],
      hourlyTemporalGridQ[modelDates, pathTimeZone]
    ] &&
    If[
      pathTimeZone == 0 &&
        AllTrue[sensorDates, Head[#] === DateObject &],
      hourlyUTCGridQ[sensorDates],
      hourlyTemporalGridQ[sensorDates, pathTimeZone]
    ] &&
    missingFromModel === {} &&
    missingFromSensor === {} &&
    NumericQ[maxOffset] && maxOffset < 0.001 &&
    (Head[expectedStart] =!= DateObject ||
      Abs[UnixTime@modelStart - UnixTime@expectedStart] < 0.5) &&
    (Head[expectedEnd] =!= DateObject ||
      Abs[UnixTime@modelEnd - UnixTime@expectedEnd] < 0.5) &&
    (!IntegerQ[expectedCount] || Length@modelDates === expectedCount);

  <|
    "File" -> path,
    "CaseFolderName" -> caseFolder,
    "Variable" -> Lookup[payload, "Variable", Missing["Unavailable"]],
    "GroupFolderName" -> Lookup[
      payload, "GroupFolderName", Missing["Unavailable"]
    ],
    "WUFIFixedTimeZoneHours" -> fixedZone,
    "TemporalPathTimeZoneHoursUsed" -> pathTimeZone,
    "ExpectedWUFIStartUTC" -> expectedStart,
    "ExpectedWUFIEndUTC" -> expectedEnd,
    "ExpectedWUFIGridPointCount" -> expectedCount,
    "ModelStartUTC" -> modelStart,
    "ModelEndUTC" -> modelEnd,
    "ModelPointCount" -> Length@modelDates,
    "ModelHourlyGridQ" -> If[
      pathTimeZone == 0 &&
        AllTrue[modelDates, Head[#] === DateObject &],
      hourlyUTCGridQ[modelDates],
      hourlyTemporalGridQ[modelDates, pathTimeZone]
    ],
    "SensorGridStartUTC" -> sensorStart,
    "SensorGridEndUTC" -> sensorEnd,
    "SensorGridPointCount" -> Length@sensorDates,
    "SensorGridHourlyQ" -> If[
      pathTimeZone == 0 &&
        AllTrue[sensorDates, Head[#] === DateObject &],
      hourlyUTCGridQ[sensorDates],
      hourlyTemporalGridQ[sensorDates, pathTimeZone]
    ],
    "PairedStartUTC" -> pairedStart,
    "PairedEndUTC" -> pairedEnd,
    "PairedPointCount" -> Length@pairedDates,
    "PairedTimestampsMissingFromModelCount" -> Length@missingFromModel,
    "PairedTimestampsMissingFromSensorGridCount" -> Length@missingFromSensor,
    "MaximumPairToModelOffsetSeconds" -> maxOffset,
    "PassQ" -> TrueQ@pass
  |>
];

alignmentAuditRunTimeZone[manifest_] := Module[{zone},
  zone = If[
    AssociationQ[manifest],
    Lookup[manifest, "GeneratedTimeZoneHours", $TimeZone],
    $TimeZone
  ];
  If[NumericQ[zone], N@zone, N@$TimeZone]
];

AuditExistingComparisonOutput[
  outputRoot_String,
  inputSettings_:Automatic
] := Module[
  {
    manifestPath, comparisonManifest, settings, wufiManifest,
    allSelections, caseRecords, files, rows, summary, base,
    runTimeZone
  },
  manifestPath = FileNameJoin[{outputRoot, "comparison_manifest.wl"}];
  comparisonManifest = If[
    FileExistsQ[manifestPath],
    Quiet@Check[Get[manifestPath], $Failed],
    $Failed
  ];

  settings = Which[
    AssociationQ[inputSettings],
      resolveAutomaticInputPaths@Join[
        DefaultSensorComparisonSettings[], inputSettings
      ],
    AssociationQ[comparisonManifest] &&
      AssociationQ@Lookup[
        comparisonManifest, "Settings", Missing["NoSettings"]
      ],
      resolveAutomaticInputPaths@Join[
        DefaultSensorComparisonSettings[],
        Lookup[comparisonManifest, "Settings"]
      ],
    True,
      Return@Failure[
        "AlignmentAuditSettingsUnavailable",
        <|"OutputRoot" -> outputRoot|>
      ]
  ];

  runTimeZone = alignmentAuditRunTimeZone[comparisonManifest];

  wufiManifest = LoadWUFIManifestAny@Lookup[
    settings, "WUFIManifestPath"
  ];
  If[FailureQ[wufiManifest], Return@wufiManifest];

  allSelections = allCaseSelections@wufiManifest;
  caseRecords = Association@Map[
    Lookup[Lookup[#, "Case"], "CaseFolderName"] ->
      Lookup[#, "Case"] &,
    allSelections
  ];

  files = comparisonWXFFiles[outputRoot, settings];
  If[files === {},
    Return@Failure[
      "NoComparisonWXFFiles",
      <|"OutputRoot" -> outputRoot|>
    ]
  ];

  rows = auditOneComparisonWXF[
      #,
      caseRecords,
      settings,
      runTimeZone
    ] & /@ files;

  summary = <|
    "AuditVersion" -> 1,
    "GeneratedAtUTC" -> utcDateString@TimeZoneConvert[Now, 0],
    "OutputRoot" -> ExpandFileName@outputRoot,
    "GeneratedTimeZoneHoursFromRunManifest" -> runTimeZone,
    "RunTimeZoneSource" -> If[
      AssociationQ[comparisonManifest],
      "ComparisonManifest",
      "CurrentKernelFallbackBeforeManifestFinalization"
    ],
    "ComparisonWXFCount" -> Length@files,
    "PassedCount" -> Count[
      rows, row_ /; TrueQ@Lookup[row, "PassQ", False]
    ],
    "FailedCount" -> Count[
      rows, row_ /; !TrueQ@Lookup[row, "PassQ", False]
    ],
    "OverallStatus" -> If[
      AllTrue[rows, TrueQ@Lookup[#, "PassQ", False] &],
      "Passed", "Failed"
    ],
    "Rows" -> rows
  |>;

  base = FileNameJoin[{outputRoot, "time_alignment_audit"}];
  exportRowsCSV[base <> ".csv", rows];
  exportWLAndJSON[base, summary, True];
  summary
];


AuditExistingGraphicsOutput[
  outputRoot_String
] := AuditExistingGraphicsOutput[
  outputRoot,
  Automatic,
  Automatic
];

AuditExistingGraphicsOutput[
  outputRoot_String,
  inputSettings_
] := AuditExistingGraphicsOutput[
  outputRoot,
  inputSettings,
  Automatic
];

AuditExistingGraphicsOutput[
  outputRoot_String,
  inputSettings_,
  expectedPaths_
] := Module[
  {
    settings, actualFiles, expectedFiles, files, rows, summary, base,
    validCount, invalidCount, missingCount, unexpectedCount,
    failOnUnexpectedQ
  },
  settings = If[
    AssociationQ@inputSettings,
    resolveAutomaticInputPaths@Join[
      DefaultSensorComparisonSettings[],
      inputSettings
    ],
    resolveAutomaticInputPaths@DefaultSensorComparisonSettings[]
  ];
  actualFiles = Sort@DeleteDuplicates@Join[
    FileNames["*.jpg", outputRoot, Infinity],
    FileNames["*.jpeg", outputRoot, Infinity],
    FileNames["*.JPG", outputRoot, Infinity],
    FileNames["*.JPEG", outputRoot, Infinity]
  ];
  expectedFiles = If[
    ListQ@expectedPaths,
    Sort@DeleteDuplicates@Select[
      ExpandFileName /@ expectedPaths,
      graphicPathQ
    ],
    actualFiles
  ];
  files = Sort@Union[actualFiles, expectedFiles];
  rows = Map[
    Function[path,
      Join[
        GraphicFileAudit[path, settings],
        <|
          "ExpectedQ" -> MemberQ[expectedFiles, path],
          "UnexpectedQ" ->
            MemberQ[actualFiles, path] &&
              !MemberQ[expectedFiles, path]
        |>
      ]
    ],
    files
  ];
  validCount = Count[
    rows,
    row_ /; TrueQ@Lookup[row, "ValidQ", False]
  ];
  invalidCount = Length@rows - validCount;
  missingCount = Count[
    rows,
    row_ /;
      TrueQ@Lookup[row, "ExpectedQ", False] &&
      !TrueQ@Lookup[row, "ExistsQ", False]
  ];
  unexpectedCount = Count[
    rows,
    row_ /; TrueQ@Lookup[row, "UnexpectedQ", False]
  ];
  failOnUnexpectedQ = TrueQ@Lookup[
    settings,
    "GraphicsAuditFailOnUnexpectedFiles",
    True
  ];
  summary = <|
    "AuditVersion" -> 2,
    "GeneratedAtUTC" -> utcDateString@TimeZoneConvert[Now, 0],
    "OutputRoot" -> ExpandFileName@outputRoot,
    "GraphicFileCount" -> Length@actualFiles,
    "ActualGraphicFileCount" -> Length@actualFiles,
    "ExpectedGraphicFileCount" -> Length@expectedFiles,
    "AuditedPathCount" -> Length@files,
    "ValidCount" -> validCount,
    "InvalidCount" -> invalidCount,
    "MissingCount" -> missingCount,
    "UnexpectedCount" -> unexpectedCount,
    "FailOnUnexpectedFilesQ" -> failOnUnexpectedQ,
    "OverallStatus" -> If[
      expectedFiles =!= {} &&
        invalidCount == 0 &&
        missingCount == 0 &&
        (!failOnUnexpectedQ || unexpectedCount == 0),
      "Passed",
      "Failed"
    ],
    "Rows" -> rows
  |>;
  base = FileNameJoin[{outputRoot, "graphics_integrity_audit"}];
  exportRowsCSV[base <> ".csv", rows];
  exportWLAndJSON[
    base,
    summary,
    TrueQ@Lookup[settings, "WriteJSONManifest", True]
  ];
  summary
];


$parallelInitializationSignature = None;
$parallelInitializationReady = False;

ensureKernelCount[
  settings_Association,
  itemCount_:Infinity
] := Module[
  {configured, useful, desired, current},
  If[
    !TrueQ@Lookup[settings, "UseParallel", False],
    Return[0]
  ];
  configured = Lookup[
    settings,
    "MaximumKernels",
    Automatic
  ];
  useful = If[
    IntegerQ[itemCount],
    Max[1, itemCount],
    $ProcessorCount
  ];
  desired = Which[
    configured === Automatic,
      Min[useful, $ProcessorCount],
    IntegerQ[configured],
      Max[
        1,
        Min[configured, useful, $ProcessorCount]
      ],
    True,
      Min[useful, $ProcessorCount]
  ];
  current = Length@Kernels[];
  If[
    current < desired,
    Quiet@Check[
      LaunchKernels[desired - current],
      Null
    ]
  ];
  Length@Kernels[]
];

initializeParallelPackages[
  settings_:<||>,
  itemCount_:Infinity
] := Module[
  {
    sensorSource, plottingSource, expectedSensorVersion,
    expectedPlottingVersion, checks, kernelCount, signature
  },
  kernelCount = ensureKernelCount[settings, itemCount];
  If[kernelCount <= 1, Return[False]];
  sensorSource = $sensorDataUtilitiesSourceFile;
  If[
    !StringQ[sensorSource] ||
      !FileExistsQ[sensorSource],
    Return[False]
  ];
  plottingSource = FileNameJoin[
    {
      DirectoryName@sensorSource,
      "HygrothermalPlottingUtilities_v1_2.wl"
    }
  ];
  If[
    !FileExistsQ[plottingSource],
    Return[False]
  ];
  expectedSensorVersion = $SensorDataUtilitiesVersion;
  expectedPlottingVersion =
    HygrothermalPlottingUtilities`$HygrothermalPlottingUtilitiesVersion;
  signature = {
    Sort@Kernels[],
    sensorSource,
    plottingSource,
    expectedSensorVersion,
    expectedPlottingVersion
  };
  If[
    TrueQ[$parallelInitializationReady] &&
      SameQ[
        signature,
        $parallelInitializationSignature
      ],
    Return[True]
  ];
  checks = With[
    {
      sensorFile = sensorSource,
      plottingFile = plottingSource,
      sensorVersion = expectedSensorVersion,
      plottingVersion = expectedPlottingVersion
    },
    Quiet@Check[
      ParallelEvaluate[
        Quiet@Check[
          If[
            !TrueQ@ValueQ[
              HygrothermalPlottingUtilities`$HygrothermalPlottingUtilitiesVersion
            ] ||
              HygrothermalPlottingUtilities`$HygrothermalPlottingUtilitiesVersion =!=
                plottingVersion,
            Get[plottingFile]
          ];
          If[
            !TrueQ@ValueQ[
              SensorDataUtilities`$SensorDataUtilitiesVersion
            ] ||
              SensorDataUtilities`$SensorDataUtilitiesVersion =!=
                sensorVersion,
            Get[sensorFile]
          ];
          Length@DownValues[
            SensorDataUtilities`NormalizeSensorRows
          ] > 0 &&
          Length@DownValues[
            SensorDataUtilities`AggregateSensorChannel
          ] > 0 &&
          Length@DownValues[
            SensorDataUtilities`Private`collapseNearDuplicateRows
          ] > 0 &&
          Length@DownValues[
            SensorDataUtilities`Private`renderPlotTask
          ] > 0,
          False
        ]
      ],
      {}
    ]
  ];
  $parallelInitializationReady =
    ListQ[checks] &&
    checks =!= {} &&
    And @@ checks;
  $parallelInitializationSignature = If[
    TrueQ[$parallelInitializationReady],
    signature,
    None
  ];
  TrueQ[$parallelInitializationReady]
];

parallelDefinitionsReadyQ[] := Module[{checks},
  checks = Quiet@Check[
    ParallelEvaluate[
      Length@DownValues[
        SensorDataUtilities`NormalizeSensorRows
      ] > 0 &&
      Length@DownValues[
        SensorDataUtilities`AggregateSensorChannel
      ] > 0 &&
      Length@DownValues[
        SensorDataUtilities`Private`collapseNearDuplicateRows
      ] > 0 &&
      Length@DownValues[
        SensorDataUtilities`Private`renderPlotTask
      ] > 0
    ],
    {}
  ];
  ListQ[checks] && checks =!= {} && And @@ checks
];

controlledMap::pdefs =
  "Parallel package definitions or function closures could not be initialized on every subkernel; serial evaluation will be used.";

controlledMap[
  function_,
  items_List,
  settings_Association
] := Module[
  {kernelCount, distributed, ready},
  kernelCount = ensureKernelCount[
    settings,
    Length@items
  ];
  If[
    TrueQ@Lookup[settings, "UseParallel", False] &&
      kernelCount > 1 &&
      Length@items > 1,
    ready = initializeParallelPackages[
      settings,
      Length@items
    ];
    distributed = If[
      TrueQ@ready,
      Quiet@Check[
        DistributeDefinitions[function];
        True,
        False
      ],
      False
    ];
    ready =
      TrueQ[ready] &&
      TrueQ[distributed] &&
      parallelDefinitionsReadyQ[];
    If[
      ready,
      Quiet@Check[
        ParallelMap[
          function,
          items,
          Method -> "CoarsestGrained"
        ],
        Message[controlledMap::pdefs];
        Map[function, items]
      ],
      Message[controlledMap::pdefs];
      Map[function, items]
    ],
    Map[function, items]
  ]
];


resetParallelInitializationState[] := (
  $parallelInitializationSignature = None;
  $parallelInitializationReady = False;
  Null
);

closeParallelKernels[] := Module[{before},
  before = Length@Kernels[];
  Quiet@Check[CloseKernels[], Null];
  resetParallelInitializationState[];
  <|
    "ClosedKernelCount" -> before,
    "ActiveKernelCount" -> Length@Kernels[]
  |>
];

recyclePlotKernels[
  settings_Association,
  itemCount_:Infinity
] := Module[{closeAudit, ready},
  closeAudit = closeParallelKernels[];
  ready = If[
    TrueQ@Lookup[settings, "UseParallel", False] &&
      TrueQ@Lookup[settings, "ParallelPlotGeneration", True] &&
      IntegerQ[itemCount] && itemCount > 1,
    initializeParallelPackages[settings, itemCount],
    False
  ];
  Join[
    closeAudit,
    <|
      "ParallelPlotGenerationRequestedQ" ->
        TrueQ@Lookup[settings, "ParallelPlotGeneration", True],
      "ParallelReadyQ" -> ready,
      "ActiveKernelCountAfterLaunch" -> Length@Kernels[]
    |>
  ]
];

renderPlotTask[task_Association] := Module[
  {kind, payload, graphic},
  kind = Lookup[task, "PlotKind", Missing["PlotKind"]];
  payload = Lookup[task, "Payload", <||>];
  graphic = Quiet@Check[
    Switch[
      kind,
      "SensorTemperature",
        MakeTemperaturePlot[
          <|
            "Sensor group median" ->
              Lookup[payload, "TemperatureSeries"]
          |>
        ],
      "SensorHumidity",
        MakeHumidityPlot[
          <|
            "Sensor group median" ->
              Lookup[payload, "RelativeHumiditySeries"]
          |>
        ],
      "SensorDewPoint",
        MakeDewPointPlot[
          Lookup[payload, "TemperatureSeries"],
          Lookup[payload, "RelativeHumiditySeries"]
        ],
      "SensorMouldHistory",
        MakeMouldHistoryPlot[
          Lookup[payload, "TemperatureSeries"],
          Lookup[payload, "RelativeHumiditySeries"],
          Lookup[payload, "LIMCurves"]
        ],
      "SensorMouldRisk",
        MakeMouldRiskPlot[
          Lookup[payload, "TemperatureSeries"],
          Lookup[payload, "RelativeHumiditySeries"],
          Lookup[payload, "LIMCurves"]
        ],
      "ComparisonOverlay",
        MakeComparisonOverlayPlot[
          Lookup[payload, "SensorSeries"],
          Lookup[payload, "ModelSeries"],
          Lookup[payload, "MinimumSeries", None],
          Lookup[payload, "MaximumSeries", None],
          FrameLabel -> Lookup[payload, "FrameLabel"]
        ],
      "ComparisonResidual",
        MakeResidualPlot[
          Lookup[payload, "ResidualSeries"],
          FrameLabel -> Lookup[payload, "FrameLabel"]
        ],
      "ComparisonScatter",
        MakeMeasuredVsModelledPlot[
          Lookup[payload, "MeasuredValues"],
          Lookup[payload, "ModelledValues"],
          FrameLabel -> Lookup[payload, "FrameLabel"]
        ],
      _,
        $Failed
    ],
    $Failed
  ];
  If[
    graphic === $Failed,
    Failure[
      "PlotRenderingFailed",
      <|
        "TaskID" -> Lookup[task, "TaskID", Missing["TaskID"]],
        "PlotKind" -> kind,
        "Path" -> Lookup[task, "Path", Missing["Path"]]
      |>
    ],
    Join[
      KeyDrop[task, {"Payload"}],
      <|"Graphic" -> graphic|>
    ]
  ]
];

renderAndExportPlotTask[
  task_Association,
  settings_Association
] := Module[{rendered, exportResult},
  rendered = renderPlotTask@task;
  If[FailureQ@rendered, Return@rendered];
  exportResult = ExportGraphicChecked[
    Lookup[task, "Path"],
    Lookup[rendered, "Graphic"],
    Lookup[settings, "ExportResolution", 500],
    settings
  ];
  If[
    FailureQ@exportResult,
    Failure[
      "PlotExportFailed",
      <|
        "TaskID" -> Lookup[task, "TaskID", Missing["TaskID"]],
        "PlotKind" -> Lookup[task, "PlotKind", Missing["PlotKind"]],
        "Path" -> Lookup[task, "Path", Missing["Path"]],
        "Cause" -> exportResult
      |>
    ],
    Join[
      plotTaskMetadata@task,
      <|
        "RetryUsedQ" -> False,
        "Export" -> exportResult
      |>
    ]
  ]
];

plotTaskMetadata[task_Association] := KeyTake[
  task,
  {
    "TaskID", "RecordKey", "GroupID", "Variable",
    "GroupFolder", "Folder", "PlotKind", "Path"
  }
];

retryPlotTaskOnController[
  task_Association,
  settings_Association
] := Module[{retryResult, finalAudit},
  closeParallelKernels[];
  If[
    TrueQ@Lookup[
      settings,
      "ClearSystemCacheAfterPlotBatch",
      True
    ],
    Quiet@Check[ClearSystemCache[], Null]
  ];
  retryResult = Quiet@Check[
    renderAndExportPlotTask[task, settings],
    $Failed
  ];
  finalAudit = GraphicFileAudit[
    Lookup[task, "Path"],
    settings
  ];
  If[
    retryResult === $Failed || FailureQ@retryResult ||
      !TrueQ@Lookup[finalAudit, "ValidQ", False],
    Failure[
      "ControllerRetryFailed",
      <|
        "TaskID" -> Lookup[task, "TaskID", Missing["TaskID"]],
        "Path" -> Lookup[task, "Path", Missing["Path"]],
        "ControllerResult" -> retryResult,
        "FinalAudit" -> finalAudit
      |>
    ],
    Join[
      plotTaskMetadata@task,
      <|
        "RetryUsedQ" -> True,
        "Export" -> Lookup[retryResult, "Export", retryResult],
        "FinalAudit" -> finalAudit
      |>
    ]
  ]
];

plotTaskResultValue[
  result_Association,
  key_,
  default_
] := Lookup[result, key, default];

plotTaskResultValue[
  Failure[_, data_Association],
  key_,
  default_
] := Lookup[data, key, default];

plotTaskResultValue[_, _, default_] := default;

plotTaskExportSuccessQ[result_] := AssociationQ@result &&
  TrueQ@Lookup[result, "SucceededQ", False] &&
  StringQ@Lookup[result, "Path", Missing["Path"]] &&
  AssociationQ@Lookup[result, "FinalAudit", <||>] &&
  TrueQ@Lookup[
    Lookup[result, "FinalAudit", <||>],
    "ValidQ",
    False
  ];

normalizePlotTaskExportResult[
  task_Association,
  result_,
  settings_Association
] := Module[
  {metadata, path, finalAudit, exportRecord, structuredQ, recoveredQ},
  metadata = plotTaskMetadata@task;
  path = Lookup[task, "Path", Missing["Path"]];
  finalAudit = If[
    StringQ@path,
    GraphicFileAudit[path, settings],
    <|
      "Path" -> path,
      "ExistsQ" -> False,
      "ValidQ" -> False
    |>
  ];
  Which[
    FailureQ@result,
      Failure[
        "PlotTaskExportFailed",
        Join[
          metadata,
          <|
            "Cause" -> result,
            "FinalAudit" -> finalAudit
          |>
        ]
      ],
    TrueQ@Lookup[finalAudit, "ValidQ", False],
      structuredQ = AssociationQ@result && (
        AssociationQ@Lookup[result, "Export", Missing["Export"]] ||
        Lookup[result, "Status", Missing["Status"]] === "Exported"
      );
      recoveredQ = !structuredQ;
      exportRecord = Which[
        AssociationQ@result &&
          AssociationQ@Lookup[result, "Export", Missing["Export"]],
            Lookup[result, "Export"],
        AssociationQ@result &&
          Lookup[result, "Status", Missing["Status"]] === "Exported",
            result,
        True,
          <|
            "Status" -> "Exported",
            "Path" -> path,
            "ByteCount" -> Lookup[finalAudit, "ByteCount", 0],
            "ImageDimensionsPixels" -> Lookup[
              finalAudit,
              "ImageDimensionsPixels",
              {0, 0}
            ],
            "Validation" -> finalAudit
          |>
      ];
      Join[
        metadata,
        If[
          AssociationQ@result,
          KeyTake[
            result,
            {"RetryUsedQ", "RetryAttemptCount"}
          ],
          <||>
        ],
        <|
          "SucceededQ" -> True,
          "Path" -> path,
          "Export" -> exportRecord,
          "FinalAudit" -> finalAudit,
          "RecoveredFromUnstructuredResultQ" -> recoveredQ,
          "RawResultHead" -> ToString[Head@result, InputForm]
        |>
      ],
    True,
      Failure[
        "PlotTaskExportResultInvalid",
        Join[
          metadata,
          <|
            "RawResultHead" -> ToString[Head@result, InputForm],
            "FinalAudit" -> finalAudit
          |>
        ]
      ]
  ]
];

plotBatchInvariantAudit[
  tasks_List,
  exports_List
] := Module[
  {
    taskCount, resultCount, successful, failed, unclassified,
    taskIDs, resultTaskIDs, taskPaths, resultPaths,
    accountedForQ, allClassifiedQ, taskIDCoverageQ,
    pathCoverageQ, passedQ
  },
  taskCount = Length@tasks;
  resultCount = Length@exports;
  successful = Select[exports, plotTaskExportSuccessQ];
  failed = Select[exports, FailureQ];
  unclassified = Select[
    exports,
    !plotTaskExportSuccessQ[#] && !FailureQ[#] &
  ];
  taskIDs = Lookup[tasks, "TaskID", Missing["TaskID"]];
  resultTaskIDs = Map[
    plotTaskResultValue[#, "TaskID", Missing["TaskID"]] &,
    exports
  ];
  taskPaths = Lookup[tasks, "Path", Missing["Path"]];
  resultPaths = Map[
    plotTaskResultValue[#, "Path", Missing["Path"]] &,
    exports
  ];
  accountedForQ = resultCount == taskCount &&
    Length@successful + Length@failed + Length@unclassified == taskCount;
  allClassifiedQ = unclassified === {};
  taskIDCoverageQ = Sort@taskIDs === Sort@resultTaskIDs;
  pathCoverageQ = Sort@taskPaths === Sort@resultPaths;
  passedQ = accountedForQ && allClassifiedQ &&
    taskIDCoverageQ && pathCoverageQ;
  <|
    "TaskCount" -> taskCount,
    "ResultCount" -> resultCount,
    "SuccessfulExportCount" -> Length@successful,
    "FailedExportCount" -> Length@failed,
    "UnclassifiedResultCount" -> Length@unclassified,
    "AccountedForQ" -> accountedForQ,
    "AllResultsClassifiedQ" -> allClassifiedQ,
    "TaskIDCoverageQ" -> taskIDCoverageQ,
    "PathCoverageQ" -> pathCoverageQ,
    "PassedQ" -> passedQ,
    "SuccessfulTaskIDs" -> Map[
      Lookup[#, "TaskID", Missing["TaskID"]] &,
      successful
    ],
    "FailedTaskIDs" -> Map[
      plotTaskResultValue[#, "TaskID", Missing["TaskID"]] &,
      failed
    ],
    "UnclassifiedResultHeads" -> Map[
      ToString[Head@#, InputForm] &,
      unclassified
    ]
  |>
];

renderExportPlotBatch[
  tasks_List,
  settings_Association,
  batchLabel_String
] := Module[
  {
    startTime, recycleAtStartQ, parallelSettings,
    startKernelAudit, rendered, rawExports, exports, retryCount,
    retryTask, exportOne, endKernelAudit, taskFailures,
    invariantAudit, invariantFailure, batchFailures,
    failureList, elapsed
  },
  startTime = AbsoluteTime[];
  If[tasks === {},
    invariantAudit = plotBatchInvariantAudit[{}, {}];
    Return@<|
      "BatchLabel" -> batchLabel,
      "BatchStatus" -> "Passed",
      "TaskCount" -> 0,
      "ResultCount" -> 0,
      "SuccessfulExportCount" -> 0,
      "FailedExportCount" -> 0,
      "UnclassifiedResultCount" -> 0,
      "Exports" -> {},
      "Failures" -> {},
      "NestedFailureCount" -> 0,
      "BatchInvariantPassedQ" -> True,
      "BatchInvariantAudit" -> invariantAudit,
      "ElapsedSeconds" -> 0.,
      "KernelLifecycle" -> <||>
    |>
  ];
  recycleAtStartQ = TrueQ@Lookup[
    settings,
    "RecyclePlotKernelsPerBatch",
    True
  ];
  startKernelAudit = If[
    recycleAtStartQ,
    recyclePlotKernels[settings, Length@tasks],
    <|
      "ClosedKernelCount" -> 0,
      "ActiveKernelCount" -> Length@Kernels[],
      "ParallelReadyQ" -> initializeParallelPackages[
        settings,
        Length@tasks
      ]
    |>
  ];
  parallelSettings = Join[
    settings,
    <|
      "UseParallel" -> (
        TrueQ@Lookup[settings, "UseParallel", False] &&
        TrueQ@Lookup[
          settings,
          "ParallelPlotGeneration",
          True
        ]
      )
    |>
  ];
  rendered = controlledMap[
    renderPlotTask,
    tasks,
    parallelSettings
  ];
  retryCount = Max[
    0,
    Round@Lookup[settings, "GraphicExportRetryCount", 1]
  ];
  retryTask = Function[
    {task, firstFailure},
    Module[{attempt, retryResult},
      attempt = 0;
      retryResult = firstFailure;
      While[
        attempt < retryCount && FailureQ@retryResult &&
          TrueQ@Lookup[
            settings,
            "GraphicRetryOnController",
            True
          ],
        attempt++;
        retryResult = retryPlotTaskOnController[
          task,
          settings
        ]
      ];
      If[
        FailureQ@retryResult,
        Failure[
          "PlotTaskFailedAfterRetry",
          <|
            "TaskID" -> Lookup[task, "TaskID", Missing["TaskID"]],
            "RecordKey" -> Lookup[
              task,
              "RecordKey",
              Missing["RecordKey"]
            ],
            "Path" -> Lookup[task, "Path", Missing["Path"]],
            "FirstFailure" -> firstFailure,
            "RetryAttemptCount" -> attempt,
            "FinalRetryResult" -> retryResult
          |>
        ],
        Join[
          retryResult,
          <|"RetryAttemptCount" -> attempt|>
        ]
      ]
    ]
  ];
  exportOne = Function[
    {task, renderedItem},
    Module[{firstResult},
      Which[
        FailureQ@renderedItem,
          retryTask[task, renderedItem],
        True,
          firstResult = ExportGraphicChecked[
            Lookup[task, "Path"],
            Lookup[renderedItem, "Graphic"],
            Lookup[settings, "ExportResolution", 500],
            settings
          ];
          If[
            FailureQ@firstResult,
            retryTask[task, firstResult],
            Join[
              plotTaskMetadata@task,
              <|
                "RetryUsedQ" -> False,
                "RetryAttemptCount" -> 0,
                "Export" -> firstResult
              |>
            ]
          ]
      ]
    ]
  ];
  rawExports = MapThread[
    exportOne,
    {tasks, rendered}
  ];
  exports = MapThread[
    normalizePlotTaskExportResult[#1, #2, settings] &,
    {tasks, rawExports}
  ];
  Clear[rendered, rawExports];
  If[
    TrueQ@Lookup[
      settings,
      "ClearSystemCacheAfterPlotBatch",
      True
    ],
    Quiet@Check[ClearSystemCache[], Null]
  ];
  endKernelAudit = If[
    TrueQ@Lookup[
      settings,
      "ClosePlotKernelsAfterBatch",
      True
    ],
    closeParallelKernels[],
    <|
      "ClosedKernelCount" -> 0,
      "ActiveKernelCount" -> Length@Kernels[]
    |>
  ];
  taskFailures = Select[exports, FailureQ];
  invariantAudit = plotBatchInvariantAudit[tasks, exports];
  invariantFailure = If[
    TrueQ@Lookup[invariantAudit, "PassedQ", False],
    None,
    Failure[
      "GraphicsBatchInvariantFailed",
      Join[
        <|"BatchLabel" -> batchLabel|>,
        invariantAudit
      ]
    ]
  ];
  batchFailures = Join[
    taskFailures,
    If[invariantFailure === None, {}, {invariantFailure}]
  ];
  failureList = nestedFailures@batchFailures;
  elapsed = N[AbsoluteTime[] - startTime];
  <|
    "BatchLabel" -> batchLabel,
    "BatchStatus" -> If[batchFailures === {}, "Passed", "Failed"],
    "TaskCount" -> Length@tasks,
    "ResultCount" -> Length@exports,
    "SuccessfulExportCount" -> Count[exports, _?plotTaskExportSuccessQ],
    "FailedExportCount" -> Length@taskFailures,
    "UnclassifiedResultCount" -> Lookup[
      invariantAudit,
      "UnclassifiedResultCount",
      0
    ],
    "Exports" -> Select[exports, plotTaskExportSuccessQ],
    "Failures" -> batchFailures,
    "NestedFailureCount" -> Length@failureList,
    "BatchInvariantPassedQ" -> TrueQ@Lookup[
      invariantAudit,
      "PassedQ",
      False
    ],
    "BatchInvariantAudit" -> invariantAudit,
    "ElapsedSeconds" -> elapsed,
    "KernelLifecycle" -> <|
      "Start" -> startKernelAudit,
      "End" -> endKernelAudit
    |>
  |>
];

plotBatchExportsForKey[
  batch_Association,
  key_
] := Select[
  Lookup[batch, "Exports", {}],
  plotTaskExportSuccessQ[#] &&
    Lookup[#, "RecordKey", Missing["RecordKey"]] === key &
];

sensorPreparationSettingsKey[settings_Association] := Hash[
  KeyTake[
    settings,
    {
      "AggregationMethod",
      "CenteredWindowHalfWidthSeconds",
      "PointInterpolationMaxBracketSeconds",
      "WinsorizationFraction",
      "MinimumSamplesPerHour",
      "MinimumCoverageFraction",
      "MinimumGroupContributors",
      "NearDuplicateToleranceSeconds",
      "TemperatureRangeC",
      "RelativeHumidityRangePercent",
      "TemperatureJumpFlagC",
      "RelativeHumidityJumpFlagPercent",
      "FlatlineToleranceTemperatureC",
      "FlatlineToleranceRHPercent",
      "FlatlineMinimumDurationHours",
      "CeilingThresholdRHPercent",
      "CeilingFractionWarning",
      "IncludeSecondaryTemperature",
      "IncludeSecondaryRH",
      "SensorTimeZone"
    }
  ]
];

sensorBundleCacheKey[
  wallSystem_String,
  targetDates_List,
  settings_Association
] := StringJoin[
  wallSystem,
  "::",
  ToString@Hash[
    {
      Round[
        1000. *
          (dateUnixSeconds /@ targetDates)
      ],
      sensorPreparationSettingsKey@settings
    }
  ]
];

prepareSensorsForGrid[
  loadedSensors_Association,
  registry_Association,
  wallSystem_String,
  targetDates_List,
  settings_Association
] := Module[
  {
    records, method, tasks, preparedRules,
    targetTimes
  },
  records = Select[
    registrySensorRows@registry,
    Lookup[#, "WallSystem"] === wallSystem &
  ];
  method = Lookup[
    settings,
    "AggregationMethod",
    "CenteredWindowMedian"
  ];
  targetTimes = dateUnixSeconds /@ targetDates;
  If[
    !regularHourlyGridTimesQ[targetTimes],
    Return@Failure[
      "TargetGridNotHourly",
      <|"TargetCount" -> Length@targetDates|>
    ]
  ];
  tasks = Map[
    Function[record,
      <|
        "Record" -> record,
        "Loaded" -> Lookup[
          loadedSensors,
          Lookup[record, "SensorID"],
          Missing["NotLoaded"]
        ]
      |>
    ],
    records
  ];
  preparedRules = controlledMap[
    Function[task,
      Module[
        {
          record, id, loaded, raw, normalized,
          temperatureHourly, rhHourly
        },
        record = Lookup[task, "Record"];
        id = Lookup[record, "SensorID"];
        loaded = Lookup[task, "Loaded"];
        raw = If[
          AssociationQ[loaded],
          Lookup[loaded, "Data", $Failed],
          $Failed
        ];
        If[
          !ListQ[raw],
          id -> <|
            "Registry" -> record,
            "Status" -> "MissingOrInvalidWXF"
          |>,
          normalized = NormalizeSensorRows[
            raw,
            record,
            settings
          ];
          temperatureHourly =
            aggregateSensorChannelUnix[
              Lookup[
                normalized,
                "TemperatureUnixValuePairs",
                {}
              ],
              targetDates,
              targetTimes,
              method,
              settings
            ];
          rhHourly = aggregateSensorChannelUnix[
            Lookup[
              normalized,
              "RelativeHumidityUnixValuePairs",
              {}
            ],
            targetDates,
            targetTimes,
            method,
            settings
          ];
          id -> <|
            "Registry" -> record,
            "Status" -> "Prepared",
            "Normalized" -> normalized,
            "TemperatureHourly" ->
              temperatureHourly,
            "RelativeHumidityHourly" -> rhHourly
          |>
        ]
      ]
    ],
    tasks,
    settings
  ];
  If[
    AnyTrue[preparedRules, FailureQ],
    Return@First@Select[preparedRules, FailureQ]
  ];
  Association@preparedRules
];

sensorWallCaseFolderName["REF"] := "C01_REF_Sensors";
sensorWallCaseFolderName["HEMP"] := "C02_HEMP_Sensors";
sensorWallCaseFolderName[wallSystem_String] :=
  "C99_" <> SanitizeFileComponent[wallSystem] <> "_Sensors";

depthMillimetreString[depth_?NumericQ] := StringTrim@ToString@NumberForm[
  1000. * N@depth,
  {10, 3},
  NumberPadding -> {"", "0"},
  NumberPoint -> "."
];
depthMillimetreString[_] := "Unknown";

sensorGroupFolderNames[
  groupIDs_List,
  temperatureGroups_Association,
  rhGroups_Association
] := AssociationThread[
  groupIDs,
  MapIndexed[
    Function[{groupID, index},
      Module[{record, depth, number},
        record = Which[
          KeyExistsQ[temperatureGroups, groupID],
            Lookup[temperatureGroups, groupID],
          KeyExistsQ[rhGroups, groupID],
            Lookup[rhGroups, groupID],
          True,
            <||>
        ];
        depth = Lookup[record, "TargetDepthMetres", Missing["UnknownDepth"]];
        number = IntegerString[First@index, 10, 2];
        "S" <> number <>
          "_" <> SanitizeFileComponent[groupID] <>
          "_x" <> depthMillimetreString[depth] <> "mm"
      ]
    ],
    groupIDs
  ]
];

compactGroupFileStem[groupFolder_String] := Module[{parts},
  parts = StringSplit[groupFolder, "_"];
  If[parts === {}, "S00", First@parts]
];

comparisonOutputDirectoryName[settings_Association] := SanitizeFileComponent[
  Lookup[settings, "ComparisonOutputDirectoryName", "WUFI_vs_Sensors"]
];

dewPointGroupSeries[temperatureGroup_Association, rhGroup_Association] := Module[
  {rows, dates, values},
  rows = AlignTemperatureRH[
    Lookup[temperatureGroup, "TimeSeries"],
    Lookup[rhGroup, "TimeSeries"]
  ];
  If[rows === {}, Return[None]];
  dates = rows[[All, 1]];
  values = DewPointC[#[[2]], #[[3]]] & /@ rows;
  makeTimeSeries[dates, values]
];
dewPointGroupSeries[_, _] := None;

sensorGroupPlotTasks[
  folder_String,
  recordKey_,
  groupID_String,
  groupFolder_String,
  temperatureGroup_,
  rhGroup_,
  limCurves_Association
] := Module[
  {tasks, temperatureSeries, rhSeries, baseMetadata},
  ensureDirectory@folder;
  tasks = {};
  temperatureSeries = If[
    AssociationQ[temperatureGroup],
    Lookup[temperatureGroup, "TimeSeries", None],
    None
  ];
  rhSeries = If[
    AssociationQ[rhGroup],
    Lookup[rhGroup, "TimeSeries", None],
    None
  ];
  baseMetadata = <|
    "RecordKey" -> recordKey,
    "GroupID" -> groupID,
    "GroupFolder" -> groupFolder,
    "Folder" -> folder
  |>;
  If[temperatureSeries =!= None,
    AppendTo[
      tasks,
      Join[
        baseMetadata,
        <|
          "TaskID" -> groupID <> "::sensor-temperature",
          "PlotKind" -> "SensorTemperature",
          "Path" -> FileNameJoin[{folder, "temperature.jpg"}],
          "Payload" -> <|
            "TemperatureSeries" -> temperatureSeries
          |>
        |>
      ]
    ]
  ];
  If[rhSeries =!= None,
    AppendTo[
      tasks,
      Join[
        baseMetadata,
        <|
          "TaskID" -> groupID <> "::sensor-humidity",
          "PlotKind" -> "SensorHumidity",
          "Path" -> FileNameJoin[{folder, "humidity.jpg"}],
          "Payload" -> <|
            "RelativeHumiditySeries" -> rhSeries
          |>
        |>
      ]
    ]
  ];
  If[temperatureSeries =!= None && rhSeries =!= None,
    tasks = Join[
      tasks,
      {
        Join[
          baseMetadata,
          <|
            "TaskID" -> groupID <> "::sensor-dew-point",
            "PlotKind" -> "SensorDewPoint",
            "Path" -> FileNameJoin[{folder, "dew_point.jpg"}],
            "Payload" -> <|
              "TemperatureSeries" -> temperatureSeries,
              "RelativeHumiditySeries" -> rhSeries
            |>
          |>
        ],
        Join[
          baseMetadata,
          <|
            "TaskID" -> groupID <> "::sensor-mould-history",
            "PlotKind" -> "SensorMouldHistory",
            "Path" -> FileNameJoin[{folder, "mould_history.jpg"}],
            "Payload" -> <|
              "TemperatureSeries" -> temperatureSeries,
              "RelativeHumiditySeries" -> rhSeries,
              "LIMCurves" -> limCurves
            |>
          |>
        ],
        Join[
          baseMetadata,
          <|
            "TaskID" -> groupID <> "::sensor-mould-risk",
            "PlotKind" -> "SensorMouldRisk",
            "Path" -> FileNameJoin[{folder, "mould_risk.jpg"}],
            "Payload" -> <|
              "TemperatureSeries" -> temperatureSeries,
              "RelativeHumiditySeries" -> rhSeries,
              "LIMCurves" -> limCurves
            |>
          |>
        ]
      }
    ]
  ];
  tasks
];

exportSensorGroupPlots[
  outputRoot_String,
  sensorCaseFolder_String,
  groupFolder_String,
  temperatureGroup_,
  rhGroup_,
  limCurves_Association,
  settings_Association
] := Module[
  {folder, tasks, batch},
  folder = FileNameJoin[{
    outputRoot,
    "Sensor_Analysis",
    sensorCaseFolder,
    groupFolder
  }];
  tasks = sensorGroupPlotTasks[
    folder,
    groupFolder,
    groupFolder,
    groupFolder,
    temperatureGroup,
    rhGroup,
    limCurves
  ];
  batch = renderExportPlotBatch[
    tasks,
    settings,
    "Sensor group " <> groupFolder
  ];
  <|
    "Folder" -> folder,
    "Exports" -> Lookup[batch, "Exports", {}],
    "GraphicsBatchAudit" -> KeyDrop[batch, {"Exports"}]
  |>
];

exportSensorWallPlots[
  outputRoot_String,
  sensorCaseFolder_String,
  groupIDs_List,
  folders_Association,
  sensorGroupData_Association,
  limCurves_Association,
  settings_Association
] := Module[
  {tasks, groupID, groupFolder, folder, groupAssoc, batch, groups},
  tasks = Flatten[
    Table[
      groupFolder = Lookup[folders, groupID];
      folder = FileNameJoin[{
        outputRoot,
        "Sensor_Analysis",
        sensorCaseFolder,
        groupFolder
      }];
      groupAssoc = Lookup[sensorGroupData, groupID, <||>];
      sensorGroupPlotTasks[
        folder,
        groupID,
        groupID,
        groupFolder,
        Lookup[
          groupAssoc,
          "Temperature",
          Missing["NoTemperatureGroup"]
        ],
        Lookup[
          groupAssoc,
          "RelativeHumidity",
          Missing["NoRHGroup"]
        ],
        limCurves
      ],
      {groupID, groupIDs}
    ],
    1
  ];
  batch = renderExportPlotBatch[
    tasks,
    settings,
    "Sensor wall " <> sensorCaseFolder
  ];
  groups = Map[
    Function[currentGroupID,
      groupFolder = Lookup[folders, currentGroupID];
      Module[{groupOutputFolder, groupPlotExports},
        groupOutputFolder = FileNameJoin[{
          outputRoot,
          "Sensor_Analysis",
          sensorCaseFolder,
          groupFolder
        }];
        groupPlotExports = plotBatchExportsForKey[
          batch,
          currentGroupID
        ];
        <|
          "GroupID" -> currentGroupID,
          "Folder" -> groupOutputFolder,
          "Exports" -> groupPlotExports,
          "PlotExports" -> <|
            "Folder" -> groupOutputFolder,
            "Exports" -> groupPlotExports
          |>
        |>
      ]
    ],
    groupIDs
  ];
  <|
    "Groups" -> groups,
    "BatchAudit" -> KeyDrop[batch, {"Exports"}]
  |>
];

exportSensorWallTimeSeries[
  outputRoot_String,
  sensorCaseFolder_String,
  groupIDs_List,
  folders_Association,
  sensorGroupData_Association,
  settings_Association
] := Module[
  {
    base, timeSeriesFolder, temperatureSeries, rhSeries, dewSeries,
    temperatureMetadata, rhMetadata, dewMetadata, exports,
    tempGroup, rhGroup, dew, groupID, manifest
  },
  base = FileNameJoin[{outputRoot, "Sensor_Analysis", sensorCaseFolder}];
  timeSeriesFolder = FileNameJoin[{base, "time_series"}];
  ensureDirectory@timeSeriesFolder;
  temperatureSeries = {};
  rhSeries = {};
  dewSeries = {};
  temperatureMetadata = {};
  rhMetadata = {};
  dewMetadata = {};
  Do[
    tempGroup = Lookup[
      Lookup[sensorGroupData, groupID, <||>],
      "Temperature",
      Missing["NoTemperatureGroup"]
    ];
    rhGroup = Lookup[
      Lookup[sensorGroupData, groupID, <||>],
      "RelativeHumidity",
      Missing["NoRHGroup"]
    ];
    If[AssociationQ[tempGroup],
      AppendTo[temperatureSeries, Lookup[tempGroup, "TimeSeries"]];
      AppendTo[
        temperatureMetadata,
        <|
          "GroupID" -> groupID,
          "FolderName" -> Lookup[folders, groupID],
          "TargetDepthMetres" -> Lookup[
            Lookup[tempGroup, "GroupRecord"],
            "TargetDepthMetres"
          ],
          "SensorIDs" -> Lookup[
            Lookup[tempGroup, "GroupRecord"],
            "SensorIDs"
          ]
        |>
      ]
    ];
    If[AssociationQ[rhGroup],
      AppendTo[rhSeries, Lookup[rhGroup, "TimeSeries"]];
      AppendTo[
        rhMetadata,
        <|
          "GroupID" -> groupID,
          "FolderName" -> Lookup[folders, groupID],
          "TargetDepthMetres" -> Lookup[
            Lookup[rhGroup, "GroupRecord"],
            "TargetDepthMetres"
          ],
          "SensorIDs" -> Lookup[
            Lookup[rhGroup, "GroupRecord"],
            "SensorIDs"
          ]
        |>
      ]
    ];
    If[AssociationQ[tempGroup] && AssociationQ[rhGroup],
      dew = dewPointGroupSeries[tempGroup, rhGroup];
      If[dew =!= None,
        AppendTo[dewSeries, dew];
        AppendTo[
          dewMetadata,
          <|
            "GroupID" -> groupID,
            "FolderName" -> Lookup[folders, groupID],
            "TargetDepthMetres" -> Lookup[
              Lookup[tempGroup, "GroupRecord"],
              "TargetDepthMetres"
            ]
          |>
        ]
      ]
    ],
    {groupID, groupIDs}
  ];
  exports = {};
  If[TrueQ@Lookup[settings, "WriteWXF", True],
    AppendTo[
      exports,
      ExportWXFChecked[
        FileNameJoin[{timeSeriesFolder, "temperature.wxf"}],
        temperatureSeries
      ]
    ];
    AppendTo[
      exports,
      ExportWXFChecked[
        FileNameJoin[{timeSeriesFolder, "relative_humidity.wxf"}],
        rhSeries
      ]
    ];
    AppendTo[
      exports,
      ExportWXFChecked[
        FileNameJoin[{timeSeriesFolder, "dew_point.wxf"}],
        dewSeries
      ]
    ]
  ];
  manifest = <|
    "SensorCaseFolder" -> sensorCaseFolder,
    "TemperatureSeries" -> temperatureMetadata,
    "RelativeHumiditySeries" -> rhMetadata,
    "DewPointSeries" -> dewMetadata
  |>;
  AppendTo[
    exports,
    exportWLAndJSON[
      FileNameJoin[{base, "sensor_group_manifest"}],
      manifest,
      TrueQ@Lookup[settings, "WriteJSONManifest", True]
    ]
  ];
  <|
    "Folder" -> timeSeriesFolder,
    "Exports" -> exports,
    "Manifest" -> manifest
  |>
];

variableFileStem["Temperature"] := "temperature";
variableFileStem["RelativeHumidity"] := "relative_humidity";
variableFileStem[variable_] := ToLowerCase@SanitizeFileComponent[variable];

comparisonPlotTasks[
  folder_String,
  recordKey_,
  groupID_String,
  groupFolder_String,
  variable_String,
  sensorGroup_Association,
  modelSeries_,
  pairedRows_List
] := Module[
  {
    sensorSeries, lower, upper, residualSeries, unitLabel,
    measured, modelled, stem, degreeSymbol, baseMetadata, tasks
  },
  ensureDirectory@folder;
  sensorSeries = Lookup[sensorGroup, "TimeSeries"];
  lower = Lookup[sensorGroup, "MinimumSeries", None];
  upper = Lookup[sensorGroup, "MaximumSeries", None];
  residualSeries = If[
    pairedRows === {},
    {},
    makeTimeSeries[pairedRows[[All, 1]], pairedRows[[All, 4]]]
  ];
  degreeSymbol = FromCharacterCode@176;
  unitLabel = If[
    variable === "Temperature",
    Row@{"T, ", degreeSymbol, "C"},
    "RH, %"
  ];
  stem = variableFileStem@variable;
  baseMetadata = <|
    "RecordKey" -> recordKey,
    "GroupID" -> groupID,
    "Variable" -> variable,
    "GroupFolder" -> groupFolder,
    "Folder" -> folder
  |>;
  tasks = {
    Join[
      baseMetadata,
      <|
        "TaskID" -> recordKey <> "::overlay",
        "PlotKind" -> "ComparisonOverlay",
        "Path" -> FileNameJoin[{folder, stem <> "_overlay.jpg"}],
        "Payload" -> <|
          "SensorSeries" -> sensorSeries,
          "ModelSeries" -> modelSeries,
          "MinimumSeries" -> lower,
          "MaximumSeries" -> upper,
          "FrameLabel" -> {"Date", unitLabel}
        |>
      |>
    ]
  };
  If[pairedRows =!= {},
    measured = pairedRows[[All, 2]];
    modelled = pairedRows[[All, 3]];
    tasks = Join[
      tasks,
      {
        Join[
          baseMetadata,
          <|
            "TaskID" -> recordKey <> "::residual",
            "PlotKind" -> "ComparisonResidual",
            "Path" -> FileNameJoin[{folder, stem <> "_residual.jpg"}],
            "Payload" -> <|
              "ResidualSeries" -> residualSeries,
              "FrameLabel" -> {
                "Date",
                Row@{"WUFI - sensor, ", unitLabel}
              }
            |>
          |>
        ],
        Join[
          baseMetadata,
          <|
            "TaskID" -> recordKey <> "::scatter",
            "PlotKind" -> "ComparisonScatter",
            "Path" -> FileNameJoin[{folder, stem <> "_scatter.jpg"}],
            "Payload" -> <|
              "MeasuredValues" -> measured,
              "ModelledValues" -> modelled,
              "FrameLabel" -> {
                Row@{"Measured ", unitLabel},
                Row@{"WUFI ", unitLabel}
              }
            |>
          |>
        ]
      }
    ]
  ];
  tasks
];

exportComparisonPlots[
  folder_String,
  variable_String,
  sensorGroup_Association,
  modelSeries_,
  pairedRows_List,
  settings_Association
] := Module[{recordKey, tasks, batch},
  recordKey = FileBaseName@folder <> "::" <> variable;
  tasks = comparisonPlotTasks[
    folder,
    recordKey,
    FileBaseName@folder,
    FileBaseName@folder,
    variable,
    sensorGroup,
    modelSeries,
    pairedRows
  ];
  batch = renderExportPlotBatch[
    tasks,
    settings,
    "Comparison " <> recordKey
  ];
  <|
    "Folder" -> folder,
    "Exports" -> Lookup[batch, "Exports", {}],
    "GraphicsBatchAudit" -> KeyDrop[batch, {"Exports"}]
  |>
];

exportComparisonTimeSeries[
  caseBaseFolder_String,
  groupFolder_String,
  variable_String,
  sensorGroup_Association,
  modelAtDepth_Association,
  modelSeries_,
  pairedRows_List,
  settings_Association
] := Module[
  {folder, stem, residualSeries, payload, modelValues},
  If[!TrueQ@Lookup[settings, "WriteWXF", True],
    Return[Missing["Disabled"]]
  ];
  folder = FileNameJoin[{caseBaseFolder, "time_series"}];
  ensureDirectory@folder;
  stem = variableFileStem@variable;
  residualSeries = If[
    pairedRows === {},
    {},
    makeTimeSeries[pairedRows[[All, 1]], pairedRows[[All, 4]]]
  ];
  modelValues = If[
    variable === "Temperature",
    Lookup[modelAtDepth, "TemperatureValues", {}],
    Lookup[modelAtDepth, "RelativeHumidityValues", {}]
  ];
  payload = <|
    "TemporalCoordinateSchema" -> "ExplicitUTCDateObjectsV2",
    "Variable" -> variable,
    "GroupFolderName" -> groupFolder,
    "TemporalPathTimeZoneHours" -> 0,
    "SensorGroupRecord" -> Lookup[sensorGroup, "GroupRecord"],
    "SensorTargetDatesUTC" -> Lookup[
      sensorGroup,
      "TargetDatesUTC",
      {}
    ],
    "SensorValues" -> Lookup[sensorGroup, "Values", {}],
    "SensorSeries" -> Lookup[sensorGroup, "TimeSeries"],
    "SensorMinimumSeries" -> Lookup[
      sensorGroup,
      "MinimumSeries",
      Missing["Unavailable"]
    ],
    "SensorMaximumSeries" -> Lookup[
      sensorGroup,
      "MaximumSeries",
      Missing["Unavailable"]
    ],
    "WUFITargetDatesUTC" -> Lookup[
      modelAtDepth,
      "TargetDatesUTC",
      {}
    ],
    "WUFIValuesAtSensorDepth" -> modelValues,
    "WUFISeriesAtSensorDepth" -> modelSeries,
    "ResidualSeries" -> residualSeries,
    "PairedRows" -> pairedRows
  |>;
  ExportWXFChecked[
    FileNameJoin[{
      folder,
      compactGroupFileStem[groupFolder] <> "_" <> stem <> ".wxf"
    }],
    payload
  ]
];


logMessage[settings_Association, message_] := If[
  TrueQ@Lookup[settings, "PrintProgressLog", True],
  Print[
    "[",
    DateString[Now, {"Hour24", ":", "Minute", ":", "Second"}],
    "] ",
    message
  ]
];

progressView[label_, current_, total_] := Column@{
  Style[label, Bold],
  ProgressIndicator[current, {0, Max[1, total]}],
  Row@{current, " / ", total}
};

nestedFailures[expression_] := Cases[expression, _Failure, Infinity];

plannedOutputPaths[
  settings_Association,
  registry_Association,
  selections_List
] := Module[
  {
    outputRoot, paths, seenWallSystems, selection, caseRecord, wallSystem,
    temperatureGroups, rhGroups, groupIDs, folders, sensorCaseFolder,
    groupID, tempAvailable, rhAvailable, comparisonBase, caseFolder,
    projectName, groupFolder, stem
  },
  outputRoot = Lookup[settings, "OutputRoot"];
  paths = {
    FileNameJoin[{outputRoot, "qc_summary.csv"}],
    FileNameJoin[{outputRoot, "comparison_summary.csv"}],
    FileNameJoin[{outputRoot, "comparison_manifest.wl"}],
    FileNameJoin[{outputRoot, "comparison_manifest.json"}],
    FileNameJoin[{outputRoot, "time_alignment_audit.csv"}],
    FileNameJoin[{outputRoot, "time_alignment_audit.wl"}],
    FileNameJoin[{outputRoot, "time_alignment_audit.json"}],
    FileNameJoin[{outputRoot, "graphics_integrity_audit.csv"}],
    FileNameJoin[{outputRoot, "graphics_integrity_audit.wl"}],
    FileNameJoin[{outputRoot, "graphics_integrity_audit.json"}]
  };
  seenWallSystems = <||>;
  Do[
    caseRecord = Lookup[selection, "Case"];
    wallSystem = caseWallSystem[caseRecord, settings];
    temperatureGroups = buildSensorGroups[registry, wallSystem, "Temperature", settings];
    rhGroups = buildSensorGroups[registry, wallSystem, "RelativeHumidity", settings];
    groupIDs = Sort@Union[Keys@temperatureGroups, Keys@rhGroups];
    folders = sensorGroupFolderNames[groupIDs, temperatureGroups, rhGroups];
    sensorCaseFolder = sensorWallCaseFolderName@wallSystem;
    If[!KeyExistsQ[seenWallSystems, wallSystem],
      AssociateTo[seenWallSystems, wallSystem -> True];
      Do[
        groupFolder = Lookup[folders, groupID];
        tempAvailable = KeyExistsQ[temperatureGroups, groupID];
        rhAvailable = KeyExistsQ[rhGroups, groupID];
        If[tempAvailable,
          AppendTo[paths, FileNameJoin[{outputRoot, "Sensor_Analysis", sensorCaseFolder, groupFolder, "temperature.jpg"}]]
        ];
        If[rhAvailable,
          AppendTo[paths, FileNameJoin[{outputRoot, "Sensor_Analysis", sensorCaseFolder, groupFolder, "humidity.jpg"}]]
        ];
        If[tempAvailable && rhAvailable,
          paths = Join[
            paths,
            FileNameJoin[{outputRoot, "Sensor_Analysis", sensorCaseFolder, groupFolder, #}] & /@
              {"dew_point.jpg", "mould_history.jpg", "mould_risk.jpg"}
          ]
        ],
        {groupID, groupIDs}
      ];
      paths = Join[
        paths,
        FileNameJoin[{outputRoot, "Sensor_Analysis", sensorCaseFolder, "time_series", #}] & /@
          {"temperature.wxf", "relative_humidity.wxf", "dew_point.wxf"},
        {
          FileNameJoin[{outputRoot, "Sensor_Analysis", sensorCaseFolder, "sensor_group_manifest.wl"}],
          FileNameJoin[{outputRoot, "Sensor_Analysis", sensorCaseFolder, "sensor_group_manifest.json"}]
        }
      ]
    ];
    caseFolder = Lookup[caseRecord, "CaseFolderName"];
    projectName = Lookup[Lookup[selection, "Project"], "ProjectBaseName"];
    comparisonBase = FileNameJoin[{
      outputRoot,
      comparisonOutputDirectoryName@settings,
      projectName,
      caseFolder
    }];
    Do[
      groupFolder = Lookup[folders, groupID];
      If[KeyExistsQ[temperatureGroups, groupID],
        stem = "temperature";
        paths = Join[
          paths,
          FileNameJoin[{comparisonBase, groupFolder, stem <> #}] & /@
            {"_overlay.jpg", "_residual.jpg", "_scatter.jpg"},
          {FileNameJoin[{comparisonBase, "time_series", compactGroupFileStem[groupFolder] <> "_" <> stem <> ".wxf"}]}
        ]
      ];
      If[KeyExistsQ[rhGroups, groupID],
        stem = "relative_humidity";
        paths = Join[
          paths,
          FileNameJoin[{comparisonBase, groupFolder, stem <> #}] & /@
            {"_overlay.jpg", "_residual.jpg", "_scatter.jpg"},
          {FileNameJoin[{comparisonBase, "time_series", compactGroupFileStem[groupFolder] <> "_" <> stem <> ".wxf"}]}
        ]
      ],
      {groupID, groupIDs}
    ],
    {selection, selections}
  ];
  DeleteDuplicates[ExpandFileName /@ paths]
];

graphicPathQ[path_String] := MemberQ[
  {"jpg", "jpeg"},
  ToLowerCase@FileExtension@path
];
graphicPathQ[_] := False;

plannedGraphicPaths[
  settings_Association,
  registry_Association,
  selections_List
] := Module[
  {paths, comparisonDirectory, writeSensorQ, writeComparisonQ},
  paths = plannedOutputPaths[settings, registry, selections];
  comparisonDirectory = comparisonOutputDirectoryName@settings;
  writeSensorQ = TrueQ@Lookup[
    settings,
    "WriteSensorOnlyPlots",
    True
  ];
  writeComparisonQ = TrueQ@Lookup[
    settings,
    "WriteComparisonPlots",
    True
  ];
  Select[
    paths,
    graphicPathQ[#] &&
      (
        writeSensorQ &&
          MemberQ[FileNameSplit@#, "Sensor_Analysis"] ||
        writeComparisonQ &&
          MemberQ[FileNameSplit@#, comparisonDirectory]
      ) &
  ]
];

outputPathSummary[paths_List, settings_Association] := Module[
  {rows, warningLimit, hardLimit, overWarning, overHard, longest},
  warningLimit = Lookup[settings, "PathLengthWarningCharacters", 240];
  hardLimit = Lookup[
    settings,
    "PathLengthHardLimitCharacters",
    If[$OperatingSystem === "Windows", 259, 4095]
  ];
  rows = SortBy[
    (<|
      "Path" -> #,
      "PathLengthCharacters" -> StringLength@#
    |> &) /@ paths,
    Lookup[#, "PathLengthCharacters"] &
  ];
  overWarning = Select[rows, Lookup[#, "PathLengthCharacters"] > warningLimit &];
  overHard = Select[rows, Lookup[#, "PathLengthCharacters"] > hardLimit &];
  longest = If[rows === {}, Missing["NoPaths"], Last@rows];
  <|
    "PlannedPathCount" -> Length@rows,
    "WarningThresholdCharacters" -> warningLimit,
    "HardLimitCharacters" -> hardLimit,
    "MaximumPlannedPathLengthCharacters" -> If[AssociationQ[longest], Lookup[longest, "PathLengthCharacters"], Missing["Unavailable"]],
    "LongestPlannedPath" -> If[AssociationQ[longest], Lookup[longest, "Path"], Missing["Unavailable"]],
    "PathsAboveWarningCount" -> Length@overWarning,
    "PathsAboveHardLimitCount" -> Length@overHard,
    "PathsAboveWarning" -> overWarning,
    "PathsAboveHardLimit" -> overHard
  |>
];

OutputPathAudit[
  settings_Association,
  registry_Association,
  selections_List
] := outputPathSummary[
  plannedOutputPaths[settings, registry, selections],
  settings
];

serializableSelection[selection_Association] := <|
  "ProjectBaseName" -> Lookup[Lookup[selection, "Project"], "ProjectBaseName"],
  "CaseIndex" -> Lookup[Lookup[selection, "Case"], "CaseIndex"],
  "CaseName" -> Lookup[Lookup[selection, "Case"], "CaseName"],
  "CaseFolderName" -> Lookup[Lookup[selection, "Case"], "CaseFolderName"]
|>;

appendAudit[list_List, entry_] := Append[list, entry];

prepareSensorBundle[
  caseData_Association,
  loadedSensors_Association,
  registry_Association,
  limCurves_Association,
  outputRoot_String,
  settings_Association,
  writeSensorOutputsQ_:True
] := Module[
  {
    caseRecord, wallSystem, targetDates, prepared,
    temperatureGroups, rhGroups, groupIDs, folders,
    sensorCaseFolder, sensorGroupData, sensorExports,
    sensorPlotBatch, sensorWallTimeSeriesExport, tempGroup, rhGroup,
    groupID, preparationStart, preparationSeconds,
    groupStart, groupSeconds, exportStart, exportSeconds
  },
  caseRecord = Lookup[caseData, "CaseRecord"];
  wallSystem = caseWallSystem[caseRecord, settings];
  If[
    MissingQ[wallSystem],
    Return@Failure[
      "CaseWallSystemUnknown",
      <|"CaseName" -> Lookup[caseRecord, "CaseName"]|>
    ]
  ];
  targetDates = Lookup[caseData, "TargetDatesUTC"];
  preparationStart = AbsoluteTime[];
  logMessage[
    settings,
    "Preparing and aggregating sensor channels for wall system " <>
      wallSystem <> "."
  ];
  prepared = prepareSensorsForGrid[
    loadedSensors,
    registry,
    wallSystem,
    targetDates,
    settings
  ];
  If[FailureQ[prepared], Return@prepared];
  preparationSeconds = N[AbsoluteTime[] - preparationStart];

  groupStart = AbsoluteTime[];
  temperatureGroups = buildSensorGroups[
    registry,
    wallSystem,
    "Temperature",
    settings
  ];
  rhGroups = buildSensorGroups[
    registry,
    wallSystem,
    "RelativeHumidity",
    settings
  ];
  groupIDs = Sort@Union[
    Keys@temperatureGroups,
    Keys@rhGroups
  ];
  folders = sensorGroupFolderNames[
    groupIDs,
    temperatureGroups,
    rhGroups
  ];
  sensorCaseFolder = sensorWallCaseFolderName@wallSystem;
  sensorGroupData = <||>;
  Do[
    tempGroup = If[
      KeyExistsQ[temperatureGroups, groupID],
      AggregateSensorGroup[
        prepared,
        Lookup[temperatureGroups, groupID],
        "Temperature",
        settings
      ],
      Missing["NoTemperatureGroup"]
    ];
    rhGroup = If[
      KeyExistsQ[rhGroups, groupID],
      AggregateSensorGroup[
        prepared,
        Lookup[rhGroups, groupID],
        "RelativeHumidity",
        settings
      ],
      Missing["NoRHGroup"]
    ];
    AssociateTo[
      sensorGroupData,
      groupID -> <|
        "Temperature" -> tempGroup,
        "RelativeHumidity" -> rhGroup
      |>
    ],
    {groupID, groupIDs}
  ];
  groupSeconds = N[AbsoluteTime[] - groupStart];

  sensorExports = {};
  sensorPlotBatch = Missing["NotWritten"];
  exportSeconds = 0.;
  If[TrueQ[writeSensorOutputsQ],
    exportStart = AbsoluteTime[];
    logMessage[
      settings,
      "Generating sensor-only group outputs for " <>
        wallSystem <> "."
    ];
    sensorPlotBatch = If[
      TrueQ@Lookup[
        settings,
        "WriteSensorOnlyPlots",
        True
      ],
      exportSensorWallPlots[
        outputRoot,
        sensorCaseFolder,
        groupIDs,
        folders,
        sensorGroupData,
        limCurves,
        settings
      ],
      Missing["Disabled"]
    ];
    If[AssociationQ@sensorPlotBatch,
      sensorExports = Join[
        sensorExports,
        Lookup[sensorPlotBatch, "Groups", {}]
      ]
    ];
    sensorWallTimeSeriesExport =
      exportSensorWallTimeSeries[
        outputRoot,
        sensorCaseFolder,
        groupIDs,
        folders,
        sensorGroupData,
        settings
      ];
    AppendTo[
      sensorExports,
      sensorWallTimeSeriesExport
    ];
    exportSeconds = N[AbsoluteTime[] - exportStart]
  ];

  <|
    "WallSystem" -> wallSystem,
    "TargetDatesUTC" -> targetDates,
    "TargetGridHash" -> Hash[
      Round[
        1000. *
          (dateUnixSeconds /@ targetDates)
      ]
    ],
    "PreparedSensors" -> prepared,
    "TemperatureGroups" -> temperatureGroups,
    "RelativeHumidityGroups" -> rhGroups,
    "GroupIDs" -> groupIDs,
    "Folders" -> folders,
    "SensorCaseFolder" -> sensorCaseFolder,
    "SensorGroups" -> sensorGroupData,
    "SensorExports" -> sensorExports,
    "SensorGraphicsBatchAudit" -> If[
      AssociationQ@sensorPlotBatch,
      Lookup[sensorPlotBatch, "BatchAudit", <||>],
      sensorPlotBatch
    ],
    "SensorOutputsWrittenQ" ->
      TrueQ[writeSensorOutputsQ],
    "TimingSeconds" -> <|
      "SensorNormalizationAndHourlyAggregation" ->
        preparationSeconds,
      "SensorGroupAggregation" -> groupSeconds,
      "SensorOnlyExports" -> exportSeconds,
      "Total" ->
        preparationSeconds +
        groupSeconds +
        exportSeconds
    |>
  |>
];

runOneSelectionPrepared[
  selection_Association,
  caseData_Association,
  sensorBundle_Association,
  outputRoot_String,
  settings_Association
] := Module[
  {
    caseRecord, wallSystem, groupIDs, folders,
    sensorGroupData, comparisonRecords, metricsRows,
    groupID, groupRecord, spatialMatch, modelAtDepth,
    sensorGroup, modelSeries, paired, metrics, caseFolder,
    comparisonFolder, variable, groupAssoc,
    targetDates, comparisonCaseBase, timeSeriesExport,
    comparisonStart, comparisonSeconds, baseResult,
    plotTasks, plotTaskList, plotBatch, recordKey
  },
  comparisonStart = AbsoluteTime[];
  caseRecord = Lookup[caseData, "CaseRecord"];
  wallSystem = Lookup[sensorBundle, "WallSystem"];
  targetDates = Lookup[caseData, "TargetDatesUTC"];
  groupIDs = Lookup[sensorBundle, "GroupIDs"];
  folders = Lookup[sensorBundle, "Folders"];
  sensorGroupData = Lookup[
    sensorBundle,
    "SensorGroups"
  ];
  comparisonRecords = {};
  metricsRows = {};
  plotTasks = {};
  logMessage[
    settings,
    "Generating WUFI-versus-sensor comparisons for " <>
      Lookup[caseRecord, "CaseName"] <> "."
  ];
  caseFolder = Lookup[caseRecord, "CaseFolderName"];
  comparisonCaseBase = FileNameJoin[
    {
      outputRoot,
      comparisonOutputDirectoryName@settings,
      Lookup[
        Lookup[selection, "Project"],
        "ProjectBaseName"
      ],
      caseFolder
    }
  ];
  ensureDirectory@comparisonCaseBase;
  Do[
    groupAssoc = Lookup[sensorGroupData, groupID];
    Do[
      sensorGroup = Lookup[
        groupAssoc,
        variable,
        Missing["NoGroup"]
      ];
      If[
        AssociationQ[sensorGroup],
        groupRecord = Lookup[
          sensorGroup,
          "GroupRecord"
        ];
        spatialMatch = BuildSpatialMatch[
          groupRecord,
          caseRecord,
          Lookup[
            settings,
            "SpatialMethod",
            "Auto"
          ],
          settings
        ];
        If[
          !FailureQ[spatialMatch],
          modelAtDepth = EvaluateSpatialMatch[
            caseData,
            spatialMatch
          ];
          modelSeries = If[
            variable === "Temperature",
            Lookup[
              modelAtDepth,
              "TemperatureSeries"
            ],
            Lookup[
              modelAtDepth,
              "RelativeHumiditySeries"
            ]
          ];
          paired = pairSensorModelData[
            sensorGroup,
            modelAtDepth,
            variable
          ];
          If[FailureQ[paired], Return@paired];
          metrics = ComparisonMetrics[
            paired,
            variable,
            Join[
              settings,
              <|
                "ComparisonStartUTC" ->
                  First@targetDates,
                "TemporalPathTimeZoneHours" -> 0,
                "TemporalCoordinateSchema" ->
                  "ExplicitUTCDateObjectsV2"
              |>
            ]
          ];
          comparisonFolder = FileNameJoin[
            {
              comparisonCaseBase,
              Lookup[folders, groupID]
            }
          ];
          recordKey = groupID <> "::" <> variable;
          plotTaskList = If[
            TrueQ@Lookup[
              settings,
              "WriteComparisonPlots",
              True
            ],
            comparisonPlotTasks[
              comparisonFolder,
              recordKey,
              groupID,
              Lookup[folders, groupID],
              variable,
              sensorGroup,
              modelSeries,
              paired
            ],
            {}
          ];
          plotTasks = Join[plotTasks, plotTaskList];
          timeSeriesExport =
            exportComparisonTimeSeries[
              comparisonCaseBase,
              Lookup[folders, groupID],
              variable,
              sensorGroup,
              modelAtDepth,
              modelSeries,
              paired,
              settings
            ];
          AppendTo[
            comparisonRecords,
            <|
              "Selection" ->
                serializableSelection@selection,
              "WallSystem" -> wallSystem,
              "GroupID" -> groupID,
              "Variable" -> variable,
              "SensorGroup" -> groupRecord,
              "SpatialMatch" -> spatialMatch,
              "Metrics" -> metrics,
              "PairCount" -> Length@paired,
              "OutputFolder" ->
                comparisonFolder,
              "PlotRecordKey" -> recordKey,
              "PlotExports" -> Missing["PendingBatchExport"],
              "TimeSeriesExport" ->
                timeSeriesExport
            |>
          ];
          AppendTo[
            metricsRows,
            Join[
              serializableSelection@selection,
              <|
                "WallSystem" -> wallSystem,
                "GroupID" -> groupID,
                "Variable" -> variable,
                "SensorIDs" ->
                  Lookup[groupRecord, "SensorIDs"],
                "TargetDepthMetres" ->
                  Lookup[
                    groupRecord,
                    "TargetDepthMetres"
                  ],
                "SpatialMethod" ->
                  Lookup[spatialMatch, "Method"],
                "MonitorDepthsMetres" ->
                  Lookup[
                    spatialMatch,
                    "MonitorDepthsMetres"
                  ],
                "DepthOffsetMetres" ->
                  Lookup[
                    spatialMatch,
                    "DepthOffsetMetres"
                  ],
                "Extrapolation" ->
                  Lookup[
                    spatialMatch,
                    "Extrapolation"
                  ],
                "PairCount" -> Length@paired,
                "FullPeriod" ->
                  Lookup[metrics, "FullPeriod"],
                "AfterInitialExclusion" ->
                  Lookup[
                    metrics,
                    "AfterInitialExclusion"
                  ]
              |>
            ]
          ]
        ]
      ],
      {
        variable,
        {"Temperature", "RelativeHumidity"}
      }
    ],
    {groupID, groupIDs}
  ];
  plotBatch = If[
    TrueQ@Lookup[
      settings,
      "WriteComparisonPlots",
      True
    ],
    renderExportPlotBatch[
      plotTasks,
      settings,
      "Comparison case " <> Lookup[caseRecord, "CaseName"]
    ],
    Missing["Disabled"]
  ];
  comparisonRecords = Map[
    Function[record,
      Join[
        KeyDrop[record, {"PlotRecordKey"}],
        <|
          "PlotExports" -> If[
            AssociationQ@plotBatch,
            <|
              "Folder" -> Lookup[record, "OutputFolder"],
              "Exports" -> plotBatchExportsForKey[
                plotBatch,
                Lookup[record, "PlotRecordKey"]
              ]
            |>,
            plotBatch
          ]
        |>
      ]
    ],
    comparisonRecords
  ];
  comparisonSeconds =
    N[AbsoluteTime[] - comparisonStart];
  baseResult = <|
    "Selection" -> serializableSelection@selection,
    "WallSystem" -> wallSystem,
    "WUFIData" -> <|
      "PointCount" ->
        Lookup[caseData, "PointCount"],
      "TemperaturePath" ->
        Lookup[caseData, "TemperaturePath"],
      "RelativeHumidityPath" ->
        Lookup[caseData, "RelativeHumidityPath"],
      "SharedRawGridFastPathQ" ->
        Lookup[
          caseData,
          "SharedRawGridFastPathQ",
          False
        ]
    |>,
    "SensorCacheKey" ->
      sensorBundleCacheKey[
        wallSystem,
        targetDates,
        settings
      ],
    "SensorOutputsWrittenQ" ->
      Lookup[
        sensorBundle,
        "SensorOutputsWrittenQ",
        False
      ],
    "SensorExports" ->
      Lookup[
        sensorBundle,
        "SensorExports",
        {}
      ],
    "SensorGraphicsBatchAudit" ->
      Lookup[
        sensorBundle,
        "SensorGraphicsBatchAudit",
        Missing["Unavailable"]
      ],
    "Comparisons" -> comparisonRecords,
    "ComparisonGraphicsBatchAudit" -> If[
      AssociationQ@plotBatch,
      KeyDrop[plotBatch, {"Exports"}],
      plotBatch
    ],
    "MetricsRows" -> metricsRows,
    "TimingSeconds" -> <|
      "ComparisonAndExports" ->
        comparisonSeconds
    |>
  |>;
  If[
    TrueQ@Lookup[
      settings,
      "RetainPreparedSensorsInRunResults",
      False
    ],
    Join[
      baseResult,
      <|
        "PreparedSensors" ->
          Lookup[
            sensorBundle,
            "PreparedSensors"
          ],
        "SensorGroups" ->
          Lookup[
            sensorBundle,
            "SensorGroups"
          ]
      |>
    ],
    baseResult
  ]
];

runOneSelection[
  selection_Association,
  productionRoot_String,
  loadedSensors_Association,
  registry_Association,
  limCurves_Association,
  outputRoot_String,
  settings_Association
] := Module[
  {caseData, sensorBundle},
  logMessage[
    settings,
    "Loading WUFI data for " <>
      Lookup[
        Lookup[selection, "Case"],
        "CaseName",
        "unknown case"
      ] <> "."
  ];
  caseData = LoadWUFICaseSeries[
    productionRoot,
    selection,
    settings
  ];
  If[FailureQ[caseData], Return@caseData];
  sensorBundle = prepareSensorBundle[
    caseData,
    loadedSensors,
    registry,
    limCurves,
    outputRoot,
    settings,
    True
  ];
  If[FailureQ[sensorBundle], Return@sensorBundle];
  runOneSelectionPrepared[
    selection,
    caseData,
    sensorBundle,
    outputRoot,
    settings
  ]
];

SensorComparisonPreflight[inputSettings_Association] := Module[
  {
    settings, mode, audits, registry, lim, manifest, selections, errors,
    warnings, pathAudit
  },
  settings = applyExecutionProfile@resolveAutomaticInputPaths@Join[DefaultSensorComparisonSettings[], inputSettings];
  mode = Lookup[settings, "InputMode", "SelectedWXF"];
  audits = {
    fileAudit[Lookup[settings, "CanonicalRegistryPath"], "File", True],
    fileAudit[Lookup[settings, "LIMCurveDirectory"], "Directory", True],
    fileAudit[Lookup[settings, "ProductionRunRoot"], "Directory", True],
    fileAudit[Lookup[settings, "WUFIManifestPath"], "File", True],
    fileAudit[Lookup[settings, "SelectedSensorDirectory"], "Directory", mode === "SelectedWXF"],
    fileAudit[Lookup[settings, "MXCachePath"], "File", mode === "MX"],
    fileAudit[Lookup[settings, "RawJSONPath"], "File", mode === "JSON"]
  };
  errors = Select[audits, Lookup[#, "Status"] === "Missing" &];
  warnings = {};
  registry = If[errors === {}, LoadCanonicalSensorRegistry@Lookup[settings, "CanonicalRegistryPath"], Missing["Skipped"]];
  If[FailureQ[registry], AppendTo[errors, <|"Status" -> "InvalidRegistry", "Failure" -> registry|>]];
  lim = If[errors === {}, LoadLIMCurves@Lookup[settings, "LIMCurveDirectory"], Missing["Skipped"]];
  If[FailureQ[lim], AppendTo[errors, <|"Status" -> "InvalidLIMCurves", "Failure" -> lim|>]];
  manifest = If[errors === {}, LoadWUFIManifestAny@Lookup[settings, "WUFIManifestPath"], Missing["Skipped"]];
  If[FailureQ[manifest], AppendTo[errors, <|"Status" -> "InvalidManifest", "Failure" -> manifest|>]];
  selections = If[AssociationQ[manifest], ResolveWUFISelections[manifest, Lookup[settings, "SelectedCases", All]], Missing["Skipped"]];
  If[FailureQ[selections], AppendTo[errors, <|"Status" -> "InvalidCaseSelection", "Failure" -> selections|>]];
  pathAudit = If[
    AssociationQ[registry] && ListQ[selections],
    OutputPathAudit[settings, registry, selections],
    Missing["Skipped"]
  ];
  If[
    AssociationQ[pathAudit] && Lookup[pathAudit, "PathsAboveHardLimitCount", 0] > 0,
    AppendTo[
      errors,
      <|
        "Status" -> "OutputPathTooLong",
        "Message" -> "At least one planned output path exceeds the configured hard limit.",
        "PathAudit" -> pathAudit
      |>
    ]
  ];
  If[
    AssociationQ[pathAudit] &&
      Lookup[pathAudit, "PathsAboveWarningCount", 0] > 0 &&
      Lookup[pathAudit, "PathsAboveHardLimitCount", 0] == 0,
    AppendTo[
      warnings,
      "Some planned output paths are close to the Windows path-length limit; a shorter OutputRoot is recommended."
    ]
  ];
  If[Lookup[settings, "InputMode"] =!= "SelectedWXF",
    AppendTo[warnings, "The comparison runner consumes selected sensor WXFs; JSON/MX modes are used to regenerate those caches first."]
  ];
  <|
    "Status" -> If[errors === {}, "Ready", "Blocked"],
    "Settings" -> settings,
    "FileAudits" -> audits,
    "RegistrySensorCount" -> If[AssociationQ[registry], Length@registrySensorRows@registry, Missing["Unavailable"]],
    "LIMCurveNames" -> If[AssociationQ[lim], Keys@lim, Missing["Unavailable"]],
    "ResolvedSelections" -> If[ListQ[selections], serializableSelection /@ selections, selections],
    "OutputPathAudit" -> pathAudit,
    "Warnings" -> warnings,
    "Errors" -> errors
  |>
];

renderSensorOnlyPlotsFromOutput[
  outputRoot_String,
  limCurves_Association,
  settings_Association
] := Module[
  {manifests, rendered},
  manifests = FileNames[
    "sensor_group_manifest.wl",
    FileNameJoin[{outputRoot, "Sensor_Analysis"}],
    Infinity
  ];
  rendered = Map[
    Function[manifestPath,
      Module[
        {
          manifest, base, timeSeriesFolder,
          temperatureSeries, rhSeries,
          temperatureMetadata, rhMetadata,
          temperatureByGroup, rhByGroup,
          folderByGroup, groupIDs, sensorCaseFolder,
          sensorGroupData
        },
        manifest = Quiet@Check[Get[manifestPath], $Failed];
        If[
          !AssociationQ[manifest],
          Return@Failure[
            "SensorGroupManifestInvalid",
            <|"Path" -> manifestPath|>
          ]
        ];
        base = DirectoryName@manifestPath;
        timeSeriesFolder = FileNameJoin[{base, "time_series"}];
        temperatureSeries = Quiet@Check[
          Import[
            FileNameJoin[{timeSeriesFolder, "temperature.wxf"}],
            "WXF"
          ],
          {}
        ];
        rhSeries = Quiet@Check[
          Import[
            FileNameJoin[
              {timeSeriesFolder, "relative_humidity.wxf"}
            ],
            "WXF"
          ],
          {}
        ];
        temperatureMetadata = Lookup[
          manifest,
          "TemperatureSeries",
          {}
        ];
        rhMetadata = Lookup[
          manifest,
          "RelativeHumiditySeries",
          {}
        ];
        If[!ListQ[temperatureSeries], temperatureSeries = {}];
        If[!ListQ[rhSeries], rhSeries = {}];
        If[
          Length@temperatureSeries =!= Length@temperatureMetadata,
          Return@Failure[
            "SensorTemperatureSeriesMismatch",
            <|
              "ManifestPath" -> manifestPath,
              "ExpectedSeriesCount" -> Length@temperatureMetadata,
              "ImportedSeriesCount" -> Length@temperatureSeries
            |>
          ]
        ];
        If[
          Length@rhSeries =!= Length@rhMetadata,
          Return@Failure[
            "SensorRelativeHumiditySeriesMismatch",
            <|
              "ManifestPath" -> manifestPath,
              "ExpectedSeriesCount" -> Length@rhMetadata,
              "ImportedSeriesCount" -> Length@rhSeries
            |>
          ]
        ];
        temperatureByGroup = AssociationThread[
          Lookup[temperatureMetadata, "GroupID", {}],
          temperatureSeries
        ];
        rhByGroup = AssociationThread[
          Lookup[rhMetadata, "GroupID", {}],
          rhSeries
        ];
        folderByGroup = Association@Map[
          Function[metadataRow,
            Lookup[metadataRow, "GroupID"] ->
              Lookup[metadataRow, "FolderName"]
          ],
          DeleteDuplicatesBy[
            Join[temperatureMetadata, rhMetadata],
            Lookup[#, "GroupID"] &
          ]
        ];
        groupIDs = Sort@Union[
          Keys@temperatureByGroup,
          Keys@rhByGroup
        ];
        sensorCaseFolder = Last@FileNameSplit@base;
        sensorGroupData = Association@Table[
          groupID -> <|
            "Temperature" -> If[
              KeyExistsQ[temperatureByGroup, groupID],
              <|
                "TimeSeries" ->
                  Lookup[temperatureByGroup, groupID]
              |>,
              Missing["NoTemperatureGroup"]
            ],
            "RelativeHumidity" -> If[
              KeyExistsQ[rhByGroup, groupID],
              <|
                "TimeSeries" -> Lookup[rhByGroup, groupID]
              |>,
              Missing["NoRHGroup"]
            ]
          |>,
          {groupID, groupIDs}
        ];
        exportSensorWallPlots[
          outputRoot,
          sensorCaseFolder,
          groupIDs,
          folderByGroup,
          sensorGroupData,
          limCurves,
          settings
        ]
      ]
    ],
    manifests
  ];
  <|
    "ManifestCount" -> Length@manifests,
    "Rendered" -> rendered,
    "Failures" -> nestedFailures@rendered
  |>
];

renderComparisonPlotsFromOutput[
  outputRoot_String,
  settings_Association
] := Module[
  {
    comparisonRoot, files, records, validRecords,
    loadFailures, grouped, rendered
  },
  comparisonRoot = FileNameJoin[
    {
      outputRoot,
      comparisonOutputDirectoryName@settings
    }
  ];
  files = FileNames["*.wxf", comparisonRoot, Infinity];
  records = Map[
    Function[path,
      Module[
        {
          payload, variable, groupFolder, caseBase,
          outputFolder, sensorGroup, modelSeries,
          pairedRows, groupRecord, groupID, recordKey
        },
        payload = Quiet@Check[Import[path, "WXF"], $Failed];
        If[
          !AssociationQ[payload],
          Return@Failure[
            "ComparisonWXFInvalid",
            <|"Path" -> path|>
          ]
        ];
        variable = Lookup[payload, "Variable"];
        groupFolder = Lookup[payload, "GroupFolderName"];
        caseBase = DirectoryName@DirectoryName@path;
        outputFolder = FileNameJoin[{caseBase, groupFolder}];
        sensorGroup = <|
          "TimeSeries" -> Lookup[payload, "SensorSeries"],
          "MinimumSeries" -> Lookup[
            payload,
            "SensorMinimumSeries",
            None
          ],
          "MaximumSeries" -> Lookup[
            payload,
            "SensorMaximumSeries",
            None
          ]
        |>;
        modelSeries = Lookup[payload, "WUFISeriesAtSensorDepth"];
        pairedRows = Lookup[payload, "PairedRows", {}];
        groupRecord = Lookup[payload, "SensorGroupRecord", <||>];
        groupID = Lookup[groupRecord, "GroupID", groupFolder];
        recordKey = groupID <> "::" <> variable;
        <|
          "Path" -> path,
          "CaseBase" -> caseBase,
          "CaseLabel" -> Last@FileNameSplit@caseBase,
          "Tasks" -> comparisonPlotTasks[
            outputFolder,
            recordKey,
            groupID,
            groupFolder,
            variable,
            sensorGroup,
            modelSeries,
            pairedRows
          ]
        |>
      ]
    ],
    files
  ];
  loadFailures = Select[records, FailureQ];
  validRecords = Select[records, AssociationQ];
  grouped = GatherBy[
    validRecords,
    Lookup[#, "CaseBase"] &
  ];
  rendered = Map[
    Function[caseRecords,
      renderExportPlotBatch[
        Flatten[Lookup[caseRecords, "Tasks", {}], 1],
        settings,
        "Deferred comparison case " <>
          Lookup[First@caseRecords, "CaseLabel", "unknown"]
      ]
    ],
    grouped
  ];
  <|
    "WXFCount" -> Length@files,
    "CaseBatchCount" -> Length@grouped,
    "LoadFailures" -> loadFailures,
    "Rendered" -> rendered,
    "Failures" -> nestedFailures@{loadFailures, rendered}
  |>
];

RenderExistingComparisonOutput[
  outputRoot_String,
  inputSettings_Association:<||>
] := Module[
  {
    settings, limCurves, startTime,
    sensorResult, comparisonResult, graphicsAudit, result,
    expectedGraphicPaths
  },
  startTime = AbsoluteTime[];
  settings = resolveAutomaticInputPaths@Join[
    DefaultSensorComparisonSettings[],
    inputSettings,
    <|
      "OutputRoot" -> outputRoot,
      "WriteSensorOnlyPlots" -> True,
      "WriteComparisonPlots" -> True
    |>
  ];
  limCurves = LoadLIMCurves[
    Lookup[settings, "LIMCurveDirectory"]
  ];
  If[FailureQ[limCurves], Return@limCurves];
  sensorResult = renderSensorOnlyPlotsFromOutput[
    outputRoot,
    limCurves,
    settings
  ];
  comparisonResult =
    renderComparisonPlotsFromOutput[
      outputRoot,
      settings
    ];
  expectedGraphicPaths = Sort@DeleteDuplicates@Cases[
    {sensorResult, comparisonResult},
    (record_Association /;
      KeyExistsQ[record, "Path"] &&
      graphicPathQ@Lookup[record, "Path", ""]) :>
        ExpandFileName@Lookup[record, "Path"],
    Infinity
  ];
  graphicsAudit = If[
    TrueQ@Lookup[settings, "RunGraphicsAudit", True],
    AuditExistingGraphicsOutput[
      outputRoot,
      settings,
      expectedGraphicPaths
    ],
    Missing["Disabled"]
  ];
  closeParallelKernels[];
  result = <|
    "Status" -> Which[
      nestedFailures[{sensorResult, comparisonResult}] =!= {},
        "CompletedWithFailures",
      FailureQ@graphicsAudit,
        "CompletedWithGraphicsAuditFailure",
      AssociationQ@graphicsAudit &&
        Lookup[graphicsAudit, "OverallStatus", "Failed"] =!= "Passed",
        "CompletedWithGraphicsFailures",
      True,
        "Completed"
    ],
    "OutputRoot" -> outputRoot,
    "ElapsedSeconds" ->
      N[AbsoluteTime[] - startTime],
    "SensorOnlyPlots" -> sensorResult,
    "ComparisonPlots" -> comparisonResult,
    "GraphicsAudit" -> graphicsAudit
  |>;
  result
];

RunSensorComparison[
  inputSettings_Association
] := Module[
  {
    preflight, settings, registry, limCurves, manifest,
    selections, loadedSensors, outputRoot, runResults,
    failures, qcRows, metricsRows, comparisonManifest,
    exportAudit, writeJSON, result, startTime,
    elapsedSeconds, caseCounter, caseLabel, nestedRunFailures,
    pathAudit, alignmentAudit, graphicsAudit, sensorBundleCache,
    sensorOutputWallKeys, cacheKey, cacheHitQ, writeSensorOutputsQ,
    sensorBundle, caseBundle, caseData, selection, caseRecord,
    wallSystem, caseResult, stageStart, preflightSeconds,
    inputLoadSeconds, parallelInitializationSeconds,
    wufiLoadSeconds, caseProcessingSeconds, summaryExportSeconds,
    alignmentAuditSeconds, graphicsAuditSeconds, manifestSeconds, cacheHits,
    caseTimingRows, sensorCacheSummary, maximumWallSensorCount,
    parallelReady, processSelection, expectedGraphicPaths
  },
  startTime = AbsoluteTime[];
  Print[
    "Starting optimized sensor/WUFI comparison preflight..."
  ];
  stageStart = AbsoluteTime[];
  preflight = SensorComparisonPreflight@inputSettings;
  preflightSeconds =
    N[AbsoluteTime[] - stageStart];
  If[
    Lookup[preflight, "Status"] =!= "Ready",
    Print[
      "Preflight blocked the run. Inspect the returned Failure for details."
    ];
    Return@Failure[
      "PreflightBlocked",
      preflight
    ]
  ];

  settings = Lookup[preflight, "Settings"];
  stageStart = AbsoluteTime[];
  registry = LoadCanonicalSensorRegistry[
    Lookup[settings, "CanonicalRegistryPath"]
  ];
  limCurves = LoadLIMCurves[
    Lookup[settings, "LIMCurveDirectory"]
  ];
  manifest = LoadWUFIManifestAny[
    Lookup[settings, "WUFIManifestPath"]
  ];
  selections = ResolveWUFISelections[
    manifest,
    Lookup[settings, "SelectedCases", All]
  ];
  pathAudit = Lookup[
    preflight,
    "OutputPathAudit",
    <||>
  ];
  logMessage[
    settings,
    "Resolved " <>
      ToString@Length@selections <>
      " case(s). Maximum planned output path length: " <>
      ToString@Lookup[
        pathAudit,
        "MaximumPlannedPathLengthCharacters",
        Missing["Unavailable"]
      ] <>
      " characters."
  ];
  logMessage[
    settings,
    "Loading selected sensor WXF files."
  ];
  loadedSensors = LoadSelectedSensorWXFs[
    Lookup[settings, "SelectedSensorDirectory"],
    registry
  ];
  If[FailureQ[loadedSensors], Return@loadedSensors];
  outputRoot = Lookup[settings, "OutputRoot"];
  ensureDirectory@outputRoot;
  inputLoadSeconds =
    N[AbsoluteTime[] - stageStart];

  maximumWallSensorCount = Max[
    1,
    Sequence @@ (
      Count[
        registrySensorRows@registry,
        record_ /;
          Lookup[record, "WallSystem"] === #
      ] & /@
        DeleteDuplicates@Lookup[
          registrySensorRows@registry,
          "WallSystem"
        ]
    )
  ];
  stageStart = AbsoluteTime[];
  parallelReady = If[
    TrueQ@Lookup[
      settings,
      "UseParallel",
      False
    ],
    initializeParallelPackages[
      settings,
      maximumWallSensorCount
    ],
    False
  ];
  parallelInitializationSeconds =
    N[AbsoluteTime[] - stageStart];
  logMessage[
    settings,
    "Parallel preparation initialized: " <>
      ToString@parallelReady <>
      "; active kernels: " <>
      ToString@Length@Kernels[] <> "."
  ];

  sensorBundleCache = <||>;
  sensorOutputWallKeys = <||>;
  caseTimingRows = {};
  caseCounter = 0;
  caseLabel = "Initializing selected cases";

  processSelection = Function[
    {currentSelection, currentIndex},
    Module[
      {
        currentCaseRecord, currentWallSystem,
        currentCacheKey, currentCacheHitQ,
        currentWriteSensorOutputsQ,
        currentSensorBundle, currentCaseBundle,
        currentCaseData, currentResult,
        currentWUFILoadSeconds,
        currentComparisonSeconds,
        currentSensorPreparationSeconds,
        currentStageStart
      },
      currentCaseRecord = Lookup[
        currentSelection,
        "Case"
      ];
      currentWallSystem = Missing["Unavailable"];
      currentCacheHitQ = False;
      currentComparisonSeconds =
        Missing["Unavailable"];
      currentSensorPreparationSeconds =
        Missing["Unavailable"];
      caseLabel = "Processing " <>
        Lookup[
          currentCaseRecord,
          "CaseName",
          "unknown case"
        ];
      logMessage[
        settings,
        "Case " <> ToString@currentIndex <> "/" <>
          ToString@Length@selections <> ": " <>
          Lookup[
            currentCaseRecord,
            "CaseName",
            "unknown case"
          ] <> "."
      ];

      currentStageStart = AbsoluteTime[];
      logMessage[
        settings,
        "Loading WUFI data for " <>
          Lookup[
            currentCaseRecord,
            "CaseName",
            "unknown case"
          ] <> "."
      ];
      currentCaseData = LoadWUFICaseSeries[
        Lookup[settings, "ProductionRunRoot"],
        currentSelection,
        settings
      ];
      currentWUFILoadSeconds =
        N[AbsoluteTime[] - currentStageStart];

      currentResult = If[
        FailureQ[currentCaseData],
        currentCaseData,
        currentWallSystem = caseWallSystem[
          Lookup[currentCaseData, "CaseRecord"],
          settings
        ];
        currentCacheKey = sensorBundleCacheKey[
          currentWallSystem,
          Lookup[
            currentCaseData,
            "TargetDatesUTC"
          ],
          settings
        ];
        currentCacheHitQ =
          TrueQ@Lookup[
            settings,
            "ReuseSensorPreparationByWallAndGrid",
            True
          ] &&
          KeyExistsQ[
            sensorBundleCache,
            currentCacheKey
          ];

        If[
          currentCacheHitQ,
          currentSensorBundle = Lookup[
            sensorBundleCache,
            currentCacheKey
          ];
          currentCaseBundle = Join[
            currentSensorBundle,
            <|
              "SensorOutputsWrittenQ" -> False,
              "SensorExports" -> {}
            |>
          ];
          currentSensorPreparationSeconds = 0.;
          logMessage[
            settings,
            "Reusing cached sensor preparation for " <>
              currentWallSystem <> "."
          ],
          currentWriteSensorOutputsQ = If[
            TrueQ@Lookup[
              settings,
              "WriteSensorOnlyOutputsOncePerWallSystem",
              True
            ],
            !KeyExistsQ[
              sensorOutputWallKeys,
              currentWallSystem
            ],
            True
          ];
          currentSensorBundle = prepareSensorBundle[
            currentCaseData,
            loadedSensors,
            registry,
            limCurves,
            outputRoot,
            settings,
            currentWriteSensorOutputsQ
          ];
          If[
            !FailureQ[currentSensorBundle],
            currentSensorPreparationSeconds = Lookup[
              Lookup[
                currentSensorBundle,
                "TimingSeconds",
                <||>
              ],
              "Total",
              Missing["Unavailable"]
            ];
            AssociateTo[
              sensorBundleCache,
              currentCacheKey -> currentSensorBundle
            ];
            If[
              currentWriteSensorOutputsQ,
              AssociateTo[
                sensorOutputWallKeys,
                currentWallSystem -> currentCacheKey
              ]
            ]
          ];
          currentCaseBundle = currentSensorBundle
        ];

        currentStageStart = AbsoluteTime[];
        currentResult = If[
          FailureQ[currentCaseBundle],
          currentCaseBundle,
          runOneSelectionPrepared[
            currentSelection,
            currentCaseData,
            currentCaseBundle,
            outputRoot,
            settings
          ]
        ];
        currentComparisonSeconds =
          N[AbsoluteTime[] - currentStageStart];

        If[
          AssociationQ[currentResult],
          Join[
            currentResult,
            <|
              "SensorCacheHit" ->
                currentCacheHitQ,
              "TimingSeconds" -> Join[
                Lookup[
                  currentResult,
                  "TimingSeconds",
                  <||>
                ],
                <|
                  "WUFILoad" ->
                    currentWUFILoadSeconds,
                  "SensorBundlePreparation" ->
                    currentSensorPreparationSeconds,
                  "CaseComparison" ->
                    currentComparisonSeconds
                |>
              ]
            |>
          ],
          currentResult
        ]
      ];

      AppendTo[
        caseTimingRows,
        <|
          "CaseIndex" -> currentIndex,
          "CaseName" -> Lookup[
            currentCaseRecord,
            "CaseName",
            "unknown case"
          ],
          "WallSystem" -> currentWallSystem,
          "SensorCacheHit" ->
            currentCacheHitQ,
          "WUFILoadSeconds" ->
            currentWUFILoadSeconds,
          "SensorBundlePreparationSeconds" ->
            currentSensorPreparationSeconds,
          "CaseProcessingSeconds" ->
            currentComparisonSeconds
        |>
      ];
      caseCounter = currentIndex;
      logMessage[
        settings,
        "Finished case " <>
          ToString@caseCounter <> "/" <>
          ToString@Length@selections <> "."
      ];
      currentResult
    ]
  ];

  runResults = If[
    TrueQ@Lookup[
      settings,
      "ShowProgressIndicator",
      True
    ],
    Monitor[
      MapIndexed[
        processSelection[#1, First@#2] &,
        selections
      ],
      progressView[
        caseLabel,
        caseCounter,
        Length@selections
      ]
    ],
    MapIndexed[
      processSelection[#1, First@#2] &,
      selections
    ]
  ];
  failures = Select[runResults, FailureQ];
  qcRows = Flatten@Map[
    Function[bundle,
      KeyValueMap[
        Function[{id, prepared},
          If[
            !AssociationQ[prepared] ||
              !AssociationQ@Lookup[
                prepared,
                "Normalized",
                Missing["NotAvailable"]
              ],
            {},
            With[
              {
                normalized = Lookup[
                  prepared,
                  "Normalized"
                ],
                record = Lookup[
                  prepared,
                  "Registry"
                ]
              },
              {
                Join[
                  <|
                    "WallSystem" ->
                      Lookup[record, "WallSystem"],
                    "SensorID" -> id,
                    "ComparisonGroup" ->
                      Lookup[
                        record,
                        "ComparisonGroup"
                      ],
                    "TemperatureStatus" ->
                      Lookup[
                        record,
                        "TemperatureStatus"
                      ],
                    "RelativeHumidityStatus" ->
                      Lookup[
                        record,
                        "RelativeHumidityStatus"
                      ],
                    "RawRowCount" ->
                      Lookup[
                        normalized,
                        "RawRowCount"
                      ],
                    "SortedCollapsedRowCount" ->
                      Lookup[
                        normalized,
                        "SortedCollapsedRowCount"
                      ],
                    "NearDuplicateRowsCollapsed" ->
                      Lookup[
                        normalized,
                        "NearDuplicateRowsCollapsed"
                      ],
                    "OutOfRangeTemperatureCount" ->
                      Lookup[
                        normalized,
                        "OutOfRangeTemperatureCount"
                      ],
                    "OutOfRangeRHCount" ->
                      Lookup[
                        normalized,
                        "OutOfRangeRHCount"
                      ]
                  |>,
                  Association@KeyValueMap[
                    ("Temperature_" <> #1) -> #2 &,
                    Lookup[
                      normalized,
                      "TemperatureQC"
                    ]
                  ],
                  Association@KeyValueMap[
                    ("RH_" <> #1) -> #2 &,
                    Lookup[
                      normalized,
                      "RelativeHumidityQC"
                    ]
                  ]
                ]
              }
            ]
          ]
        ],
        Lookup[
          bundle,
          "PreparedSensors",
          <||>
        ]
      ]
    ],
    Values@sensorBundleCache
  ];
  qcRows = DeleteDuplicatesBy[
    qcRows,
    {
      Lookup[#, "WallSystem"],
      Lookup[#, "SensorID"]
    } &
  ];
  metricsRows = Flatten[
    Lookup[
      Select[runResults, AssociationQ],
      "MetricsRows",
      {}
    ],
    1
  ];
  nestedRunFailures = nestedFailures@runResults;

  stageStart = AbsoluteTime[];
  exportRowsCSV[
    FileNameJoin[
      {outputRoot, "qc_summary.csv"}
    ],
    qcRows
  ];
  exportRowsCSV[
    FileNameJoin[
      {outputRoot, "comparison_summary.csv"}
    ],
    metricsRows
  ];
  summaryExportSeconds =
    N[AbsoluteTime[] - stageStart];

  stageStart = AbsoluteTime[];
  alignmentAudit = If[
    TrueQ@Lookup[
      settings,
      "RunAlignmentAudit",
      True
    ],
    logMessage[
      settings,
      "Auditing UTC serialization and exact timestamp alignment."
    ];
    AuditExistingComparisonOutput[
      outputRoot,
      settings
    ],
    Missing["Disabled"]
  ];
  alignmentAuditSeconds =
    N[AbsoluteTime[] - stageStart];

  stageStart = AbsoluteTime[];
  expectedGraphicPaths = plannedGraphicPaths[
    settings,
    registry,
    selections
  ];
  graphicsAudit = If[
    TrueQ@Lookup[settings, "RunGraphicsAudit", True] &&
      (TrueQ@Lookup[settings, "WriteSensorOnlyPlots", True] ||
       TrueQ@Lookup[settings, "WriteComparisonPlots", True]),
    logMessage[
      settings,
      "Auditing all generated JPG/JPEG graphics."
    ];
    AuditExistingGraphicsOutput[
      outputRoot,
      settings,
      expectedGraphicPaths
    ],
    Missing["Disabled"]
  ];
  graphicsAuditSeconds =
    N[AbsoluteTime[] - stageStart];
  closeParallelKernels[];

  cacheHits = Count[
    Lookup[
      Select[runResults, AssociationQ],
      "SensorCacheHit",
      False
    ],
    True
  ];
  sensorCacheSummary = Association@KeyValueMap[
    Function[{key, bundle},
      key -> <|
        "WallSystem" ->
          Lookup[bundle, "WallSystem"],
        "TargetGridHash" ->
          Lookup[bundle, "TargetGridHash"],
        "SensorOutputsWrittenQ" ->
          Lookup[
            bundle,
            "SensorOutputsWrittenQ",
            False
          ],
        "TimingSeconds" ->
          Lookup[
            bundle,
            "TimingSeconds",
            <||>
          ]
      |>
    ],
    sensorBundleCache
  ];

  elapsedSeconds =
    N[AbsoluteTime[] - startTime];
  comparisonManifest = <|
    "ManifestVersion" -> 2,
    "GeneratedAt" ->
      DateString[Now, "ISODateTime"],
    "GeneratedAtLocal" ->
      DateString[Now, "ISODateTime"],
    "GeneratedAtUTC" ->
      DateString[
        TimeZoneConvert[Now, 0],
        {"ISODate", "T", "Time", "Z"}
      ],
    "GeneratedTimeZoneHours" -> $TimeZone,
    "WolframVersion" -> $Version,
    "SystemID" -> $SystemID,
    "SensorDataUtilitiesVersion" ->
      $SensorDataUtilitiesVersion,
    "HygrothermalPlottingUtilitiesVersion" ->
      $HygrothermalPlottingUtilitiesVersion,
    "Settings" -> settings,
    "Preflight" -> preflight,
    "CanonicalRegistryMetadata" ->
      KeyDrop[registry, {"Sensors"}],
    "SelectedCases" ->
      serializableSelection /@ selections,
    "CompletedSelectionCount" ->
      Count[runResults, _Association],
    "FailedSelectionCount" ->
      Length@failures,
    "Failures" -> failures,
    "NestedFailureCount" ->
      Length@nestedRunFailures,
    "NestedFailures" -> nestedRunFailures,
    "OutputPathAudit" -> pathAudit,
    "QCRowCount" -> Length@qcRows,
    "MetricRowCount" -> Length@metricsRows,
    "SensorPreparationCache" -> <|
      "Enabled" -> TrueQ@Lookup[
        settings,
        "ReuseSensorPreparationByWallAndGrid",
        True
      ],
      "UniqueBundleCount" ->
        Length@sensorBundleCache,
      "CacheHitCount" -> cacheHits,
      "Bundles" -> sensorCacheSummary
    |>,
    "StageTimingsSeconds" -> <|
      "Preflight" -> preflightSeconds,
      "InputLoading" -> inputLoadSeconds,
      "ParallelInitialization" ->
        parallelInitializationSeconds,
      "CaseRows" -> caseTimingRows,
      "SummaryExports" ->
        summaryExportSeconds,
      "AlignmentAudit" ->
        alignmentAuditSeconds,
      "GraphicsAudit" ->
        graphicsAuditSeconds,
      "ElapsedThroughFinalAudits" ->
        elapsedSeconds
    |>,
    "AlignmentAuditSummary" -> If[
      AssociationQ[alignmentAudit],
      KeyDrop[alignmentAudit, {"Rows"}],
      alignmentAudit
    ],
    "GraphicsIntegrityAuditSummary" -> If[
      AssociationQ[graphicsAudit],
      KeyDrop[graphicsAudit, {"Rows"}],
      graphicsAudit
    ],
    "ManifestFinalizedAfterAudits" -> True,
    "Results" -> Map[
      If[
        AssociationQ[#],
        KeyDrop[
          #,
          {
            "PreparedSensors",
            "SensorGroups"
          }
        ],
        #
      ] &,
      runResults
    ]
  |>;

  writeJSON = TrueQ@Lookup[
    settings,
    "WriteJSONManifest",
    True
  ];
  stageStart = AbsoluteTime[];
  exportAudit = exportWLAndJSON[
    FileNameJoin[
      {outputRoot, "comparison_manifest"}
    ],
    comparisonManifest,
    writeJSON
  ];
  manifestSeconds =
    N[AbsoluteTime[] - stageStart];
  elapsedSeconds =
    N[AbsoluteTime[] - startTime];

  result = <|
    "Status" -> Which[
      failures =!= {},
        "CompletedWithCaseFailures",
      nestedRunFailures =!= {},
        "CompletedWithExportFailures",
      AssociationQ[alignmentAudit] &&
        Lookup[
          alignmentAudit,
          "OverallStatus",
          "Failed"
        ] =!= "Passed",
        "CompletedWithAlignmentFailures",
      FailureQ[alignmentAudit],
        "CompletedWithAlignmentAuditFailure",
      AssociationQ[graphicsAudit] &&
        Lookup[
          graphicsAudit,
          "OverallStatus",
          "Failed"
        ] =!= "Passed",
        "CompletedWithGraphicsFailures",
      FailureQ[graphicsAudit],
        "CompletedWithGraphicsAuditFailure",
      True,
        "Completed"
    ],
    "OutputRoot" -> outputRoot,
    "ElapsedSeconds" -> elapsedSeconds,
    "CompletedSelectionCount" ->
      Count[runResults, _Association],
    "FailedSelectionCount" ->
      Length@failures,
    "NestedFailureCount" ->
      Length@nestedRunFailures,
    "NestedFailures" ->
      nestedRunFailures,
    "QCRowCount" -> Length@qcRows,
    "MetricRowCount" -> Length@metricsRows,
    "SensorCacheHitCount" -> cacheHits,
    "UniqueSensorBundleCount" ->
      Length@sensorBundleCache,
    "StageTimingsSeconds" -> Join[
      Lookup[
        comparisonManifest,
        "StageTimingsSeconds"
      ],
      <|"ManifestFinalization" -> manifestSeconds|>
    ],
    "ManifestExport" -> exportAudit,
    "AlignmentAudit" -> alignmentAudit,
    "GraphicsAudit" -> graphicsAudit,
    "RunResults" -> runResults
  |>;
  logMessage[
    settings,
    "Run finished in " <>
      ToString@NumberForm[
        elapsedSeconds,
        {10, 2}
      ] <>
      " seconds with " <>
      ToString@Length@nestedRunFailures <>
      " nested failure(s) and " <>
      ToString@cacheHits <>
      " sensor-cache hit(s)."
  ];
  Print["Run result summary:"];
  Print@Dataset@KeyDrop[
    result,
    {"NestedFailures", "RunResults"}
  ];
  result
];

RunSensorComparisonDraft[
  inputSettings_Association
] := RunSensorComparison[inputSettings];

End[];
EndPackage[];
