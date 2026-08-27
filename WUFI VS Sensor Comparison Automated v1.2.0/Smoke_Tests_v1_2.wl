(* ::Package:: *)

(* Production v1.2.0 smoke/regression suite. Run in Wolfram Mathematica 12.1. *)

smokeTestRoot = If[
  StringQ[$InputFileName] && StringLength[$InputFileName] > 0,
  DirectoryName@ExpandFileName@$InputFileName,
  NotebookDirectory[]
];

Get@FileNameJoin[{smokeTestRoot, "HygrothermalPlottingUtilities_v1_2.wl"}];
Get@FileNameJoin[{smokeTestRoot, "SensorDataUtilities_v1_2.wl"}];

smokeSettings = DefaultSensorComparisonSettings[];
smokeRegistry = LoadCanonicalSensorRegistry@FileNameJoin[{
  smokeTestRoot,
  "canonical_sensor_registry_2026-07-30.wl"
}];
smokeLIM = LoadLIMCurves@FileNameJoin[{smokeTestRoot, "TestAssets", "LIM Curves"}];
smokeManifest = LoadWUFIManifestAny@FileNameJoin[{
  smokeTestRoot,
  "TestAssets",
  "WUFI_export_manifest.wl"
}];

smokeStart = DateObject[{2026, 1, 1, 0, 0, 0}, TimeZone -> 0];
smokeTargets = Table[DatePlus[smokeStart, {i, "Hour"}], {i, 0, 3}];
smokePairs = {
  {DatePlus[smokeStart, {-20, "Minute"}], 1.},
  {DatePlus[smokeStart, {-10, "Minute"}], 2.},
  {DatePlus[smokeStart, {10, "Minute"}], 3.},
  {DatePlus[smokeStart, {100, "Minute"}], 20.},
  {DatePlus[smokeStart, {120, "Minute"}], 21.},
  {DatePlus[smokeStart, {140, "Minute"}], 22.},
  {DatePlus[smokeStart, {160, "Minute"}], 30.},
  {DatePlus[smokeStart, {180, "Minute"}], 31.},
  {DatePlus[smokeStart, {200, "Minute"}], 32.}
};

smokeAggregationSettings = Join[
  smokeSettings,
  <|
    "MinimumSamplesPerHour" -> 3,
    "MinimumCoverageFraction" -> 0.25
  |>
];

smokeAggregated = AggregateSensorChannel[
  smokePairs,
  smokeTargets,
  "CenteredWindowMedian",
  smokeAggregationSettings
];

smokeCase = First@Lookup[First@Lookup[smokeManifest, "Projects"], "Cases"];
smokeGroup = <|
  "GroupID" -> "REF_COLD_120",
  "TargetDepthMetres" -> 0.120
|>;
smokeSpatial = BuildSpatialMatch[smokeGroup, smokeCase, "Auto", smokeSettings];

smokePaired = Map[
  {#, 10., 10., 0.} &,
  smokeTargets
];
smokeMetrics = ComparisonMetrics[smokePaired, "Temperature", smokeSettings];

smokeRegistryRecord = First@Lookup[smokeRegistry, "Sensors"];
smokeRawRows = {
  {DatePlus[smokeStart, {0, "Second"}], 10., 80.},
  {DatePlus[smokeStart, {180, "Second"}], 10.1, 80.2},
  {DatePlus[smokeStart, {360, "Second"}], 10.2, 80.4}
};
smokeParallelSettings = Join[
  smokeSettings,
  <|
    "UseParallel" -> True,
    "MaximumKernels" -> Min[2, $ProcessorCount]
  |>
];
smokeParallelClosureToken = 73103;
smokeParallelNormalized =
  SensorDataUtilities`Private`controlledMap[
    Function[rowSet,
      <|
        "KernelID" -> $KernelID,
        "ClosureToken" -> smokeParallelClosureToken,
        "Normalized" -> NormalizeSensorRows[
          rowSet,
          smokeRegistryRecord,
          smokeParallelSettings
        ]
      |>
    ],
    {smokeRawRows, smokeRawRows},
    smokeParallelSettings
  ];

smokeHistoryPaletteColour = Quiet@Check[
  Blend["BlueGreenYellow", 0.5],
  $Failed
];
smokeRiskPaletteColour = Quiet@Check[
  ColorData["GrayYellowTones"][0.5],
  $Failed
];
smokeSanitizedFolder = SanitizeFileComponent["REF_COLD_120"];
smokeUTCDate = DateObject[{2025, 11, 26, 14, 0, 0}, TimeZone -> 0];
smokeLocalSameInstant =
  DateObject[{2025, 11, 26, 17, 0, 0}, TimeZone -> 3];
smokeWUFIFixedUTC =
  SensorDataUtilities`Private`forceWallClockToUTC[
    DateObject[{2025, 11, 26, 18, 0, 0}, TimeZone -> 3],
    2
  ];
smokeUTCTimeSeries =
  TimeSeries[{{smokeUTCDate, 1.}}];
smokeTemporalPathCoordinate =
  First@First@smokeUTCTimeSeries["Path"];
smokeTemporalPathUTC =
  SensorDataUtilities`Private`temporalPathDateToUTC[
    smokeTemporalPathCoordinate,
    $TimeZone
  ];

smokeDuplicateRowsUTC = {
  {
    DateObject[
      {2025, 11, 26, 14, 57, 35.0},
      TimeZone -> 0
    ],
    10.,
    80.
  },
  {
    DateObject[
      {2025, 11, 26, 14, 57, 35.4},
      TimeZone -> 0
    ],
    12.,
    82.
  }
};
smokeCollapsedUTC =
  SensorDataUtilities`Private`collapseNearDuplicateRows[
    smokeDuplicateRowsUTC,
    1.,
    0
  ];
smokeCollapsedDateUTC =
  First@First@Lookup[smokeCollapsedUTC, "Rows"];

smoke323InputPairs = Table[
  {
    DateObject[
      {2026, 3, 19, 19, minute, 0.},
      TimeZone -> 0
    ],
    N@minute
  },
  {minute, 30, 55, 5}
];
smoke323InputPairs = Join[
  smoke323InputPairs,
  Table[
    {
      DateObject[
        {2026, 3, 19, 20, minute, 0.},
        TimeZone -> 0
      ],
      N@(60 + minute)
    },
    {minute, 0, 10, 5}
  ],
  {
    {
      DateObject[
        {2026, 3, 19, 20, 14, 0.},
        TimeZone -> 0
      ],
      74.
    }
  }
];
smoke323TargetDates = Table[
  DateObject[
    {2026, 3, 19, hour, 0, 0.},
    TimeZone -> 0
  ],
  {hour, 18, 23}
];
smoke323Aggregation = AggregateSensorChannel[
  smoke323InputPairs,
  smoke323TargetDates,
  "CenteredWindowMedian",
  Join[
    smokeSettings,
    <|
      "MinimumSamplesPerHour" -> 3,
      "MinimumCoverageFraction" -> 0.5
    |>
  ]
];

smokeExplicitSensorGroup = <|
  "TargetDatesUTC" -> smoke323TargetDates,
  "Values" -> Lookup[smoke323Aggregation, "Values"]
|>;
smokeExplicitModel = <|
  "TargetDatesUTC" -> smoke323TargetDates,
  "TemperatureValues" -> Range[Length@smoke323TargetDates],
  "RelativeHumidityValues" -> Range[Length@smoke323TargetDates]
|>;
smokeExplicitPairs =
  SensorDataUtilities`Private`pairSensorModelData[
    smokeExplicitSensorGroup,
    smokeExplicitModel,
    "Temperature"
  ];
smokeCompactStem = SensorDataUtilities`Private`compactGroupFileStem[
  "S02_REF_WARM_BAND_390_x390.000mm"
];
smokePathAudit = HygrothermalPlottingUtilities`PathLengthAudit[
  FileNameJoin[{smokeTestRoot, "short", "test.jpg"}]
];
smokeOutputSettings = Join[
  smokeSettings,
  <|
    "OutputRoot" -> FileNameJoin[{smokeTestRoot, "Output_D1"}],
    "SelectedCases" -> {"Wall_REF_60-40_filling", "Wall_hempcrete"}
  |>
];
smokeSelections = ResolveWUFISelections[
  smokeManifest,
  Lookup[smokeOutputSettings, "SelectedCases"]
];
smokePlannedPaths = OutputPathAudit[
  smokeOutputSettings,
  smokeRegistry,
  smokeSelections
];

smokeNormalizedNumeric = NormalizeSensorRows[
  smokeRawRows,
  smokeRegistryRecord,
  smokeSettings
];
smokeNumericAggregated =
  SensorDataUtilities`Private`aggregateSensorChannelUnix[
    Lookup[
      smokeNormalizedNumeric,
      "TemperatureUnixValuePairs"
    ],
    smokeTargets,
    SensorDataUtilities`Private`dateUnixSeconds /@ smokeTargets,
    "CenteredWindowMedian",
    smokeAggregationSettings
  ];
smokeCacheKeyA =
  SensorDataUtilities`Private`sensorBundleCacheKey[
    "REF",
    smokeTargets,
    smokeSettings
  ];
smokeCacheKeyB =
  SensorDataUtilities`Private`sensorBundleCacheKey[
    "REF",
    smokeTargets,
    smokeSettings
  ];
smokeCacheKeyOtherWall =
  SensorDataUtilities`Private`sensorBundleCacheKey[
    "HEMP",
    smokeTargets,
    smokeSettings
  ];
smokeComputeOnlySettings =
  SensorDataUtilities`Private`applyExecutionProfile@Join[
    smokeSettings,
    <|"ExecutionProfile" -> "ComputeOnly"|>
  ];
smokeLagDates = Table[
  DatePlus[smokeStart, {i, "Hour"}],
  {i, 0, 5}
];
smokeLagSensor = {1., 4., 2., 8., 3., 7.};
smokeLagModel = {0., 1., 4., 2., 8., 3.};
smokeLagRows = MapThread[
  {#1, #2, #3, #3 - #2} &,
  {smokeLagDates, smokeLagSensor, smokeLagModel}
];
smokeLagMetrics = ComparisonMetrics[
  smokeLagRows,
  "Temperature",
  Join[
    smokeSettings,
    <|"CrossCorrelationLagHours" -> {-1, 0, 1}|>
  ]
];
smokeAuditFallbackTimeZone =
  SensorDataUtilities`Private`alignmentAuditRunTimeZone[$Failed];
smokeNumericTimestampRoundTripError = Max[Abs[
  Lookup[
    smokeNormalizedNumeric,
    "TemperatureUnixValuePairs"
  ][[All, 1]] -
    (SensorDataUtilities`Private`dateUnixSeconds /@
      (First /@ Lookup[
        smokeNormalizedNumeric,
        "TemperaturePairsUTC"
      ]))
]];

smokeGraphicSettings = Join[
  smokeSettings,
  <|
    "GraphicMinimumWidthPixels" -> 50,
    "GraphicMinimumHeightPixels" -> 50,
    "GraphicMinimumByteCount" -> 256
  |>
];
smokeGraphicsDirectory = CreateDirectory[
  FileNameJoin[{
    $TemporaryDirectory,
    "WUFIComparisonGraphicsSmoke-" <> CreateUUID[]
  }],
  CreateIntermediateDirectories -> True
];
smokeValidGraphicPath = FileNameJoin[{
  smokeGraphicsDirectory,
  "valid.jpg"
}];
smokeMalformedGraphicPath = FileNameJoin[{
  smokeGraphicsDirectory,
  "one_pixel_high.jpg"
}];
smokeGraphicExport = ExportGraphicChecked[
  smokeValidGraphicPath,
  Plot[x^2, {x, 0, 1}, ImageSize -> 300],
  100,
  smokeGraphicSettings
];
Export[
  smokeMalformedGraphicPath,
  Image[ConstantArray[0., {1, 300}]],
  "JPEG"
];
smokeValidGraphicAudit = GraphicFileAudit[
  smokeValidGraphicPath,
  smokeGraphicSettings
];
smokeMalformedGraphicAudit = GraphicFileAudit[
  smokeMalformedGraphicPath,
  smokeGraphicSettings
];
smokeLongGraphicDirectory = CreateDirectory[
  FileNameJoin[{
    smokeGraphicsDirectory,
    StringRepeat["long-segment-", 8]
  }],
  CreateIntermediateDirectories -> True
];
smokeLongGraphicPath = FileNameJoin[{
  smokeLongGraphicDirectory,
  "long_target_graphic.jpg"
}];
smokeLongGraphicExport = ExportGraphicChecked[
  smokeLongGraphicPath,
  Plot[Sin[x], {x, 0, 2 Pi}, ImageSize -> 300],
  100,
  smokeGraphicSettings
];
smokeMissingExpectedPath = FileNameJoin[{
  smokeGraphicsDirectory,
  "expected_but_missing.jpg"
}];
smokeExpectedInventoryAudit = AuditExistingGraphicsOutput[
  smokeGraphicsDirectory,
  smokeGraphicSettings,
  {
    smokeValidGraphicPath,
    smokeMalformedGraphicPath,
    smokeLongGraphicPath,
    smokeMissingExpectedPath
  }
];
smokeRenderedPlotTask = SensorDataUtilities`Private`renderPlotTask[
  <|
    "TaskID" -> "smoke::temperature",
    "RecordKey" -> "smoke",
    "PlotKind" -> "SensorTemperature",
    "Path" -> smokeValidGraphicPath,
    "Payload" -> <|
      "TemperatureSeries" -> smokeUTCTimeSeries
    |>
  |>
];
smokeBatchGraphicPaths = FileNameJoin[{
  smokeGraphicsDirectory,
  #
}] & /@ {"batch_a.jpg", "batch_b.jpg"};
smokeBatchTasks = {
  <|
    "TaskID" -> "smoke::batch-a",
    "RecordKey" -> "smoke-record-a",
    "GroupID" -> "SMOKE_A",
    "GroupFolder" -> "SMOKE_A",
    "PlotKind" -> "SensorTemperature",
    "Path" -> First@smokeBatchGraphicPaths,
    "Payload" -> <|
      "TemperatureSeries" -> smokeUTCTimeSeries
    |>
  |>,
  <|
    "TaskID" -> "smoke::batch-b",
    "RecordKey" -> "smoke-record-b",
    "GroupID" -> "SMOKE_B",
    "GroupFolder" -> "SMOKE_B",
    "PlotKind" -> "SensorTemperature",
    "Path" -> Last@smokeBatchGraphicPaths,
    "Payload" -> <|
      "TemperatureSeries" -> smokeUTCTimeSeries
    |>
  |>
};
smokePlotBatch = SensorDataUtilities`Private`renderExportPlotBatch[
  smokeBatchTasks,
  Join[
    smokeGraphicSettings,
    <|
      "UseParallel" -> False,
      "ParallelPlotGeneration" -> False,
      "RecyclePlotKernelsPerBatch" -> False,
      "ClosePlotKernelsAfterBatch" -> True,
      "ExportResolution" -> 100
    |>
  ],
  "Smoke graphics bookkeeping batch"
];
smokeRecordAExports =
  SensorDataUtilities`Private`plotBatchExportsForKey[
    smokePlotBatch,
    "smoke-record-a"
  ];
smokeControllerCacheBefore = <|
  "Token" -> CreateUUID[],
  "Values" -> Range[5]
|>;
smokeKernelRecycleAudit = SensorDataUtilities`Private`recyclePlotKernels[
  Join[
    smokeParallelSettings,
    <|"ParallelPlotGeneration" -> True|>
  ],
  2
];
smokeControllerCacheAfter = smokeControllerCacheBefore;
SensorDataUtilities`Private`closeParallelKernels[];

smokeTestReport = TestReport[{
  VerificationTest[
    AssociationQ@smokeRegistry && Length@Lookup[smokeRegistry, "Sensors"] == 17,
    True,
    TestID -> "Canonical registry loads with 17 selected sensors"
  ],
  VerificationTest[
    AssociationQ@smokeLIM && Sort@Keys@smokeLIM === Sort@{"LIM 0", "LIM I", "LIM II"},
    True,
    TestID -> "All three LIM curves load"
  ],
  VerificationTest[
    AssociationQ@smokeManifest && Lookup[smokeManifest, "ManifestVersion"] == 3,
    True,
    TestID -> "Production Run 1 manifest loads"
  ],
  VerificationTest[
    Length@ResolveWUFISelections[
      smokeManifest,
      {"Wall_REF_60-40_filling", "Wall_hempcrete"}
    ],
    2,
    TestID -> "Explicit selected-case resolution"
  ],
  VerificationTest[
    Lookup[smokeAggregated, "Values"][[1]],
    2.,
    SameTest -> (Abs[#1 - #2] < 10^-12 &),
    TestID -> "Centered-window median"
  ],
  VerificationTest[
    MissingQ@Lookup[smokeAggregated, "Values"][[2]],
    True,
    TestID -> "Missing hour remains missing"
  ],
  VerificationTest[
    Lookup[smokeSpatial, "Method"],
    "LinearWithinSameMaterial",
    TestID -> "REF 120 mm uses same-material interpolation"
  ],
  VerificationTest[
    Lookup[Lookup[smokeMetrics, "FullPeriod"], "RMSE"],
    0.,
    SameTest -> (Abs[#1 - #2] < 10^-12 &),
    TestID -> "Identity-series RMSE is zero"
  ],
  VerificationTest[
    Length@smokeParallelNormalized == 2 &&
      And @@ (AssociationQ /@ smokeParallelNormalized) &&
      And @@ (Lookup[#, "KernelID", 0] > 0 & /@ smokeParallelNormalized) &&
      And @@ (
        Lookup[#, "ClosureToken", Missing["Absent"]] ===
          smokeParallelClosureToken & /@ smokeParallelNormalized
      ) &&
      And @@ (
        AssociationQ@Lookup[#, "Normalized", Missing["Absent"]] & /@
          smokeParallelNormalized
      ) &&
      And @@ (
        KeyExistsQ[
          Lookup[#, "Normalized", <||>],
          "TemperaturePairsUTC"
        ] & /@ smokeParallelNormalized
      ),
    True,
    TestID ->
      "Parallel path executes on subkernels with package definitions and closure values"
  ],
  VerificationTest[
    smokeHistoryPaletteColour =!= $Failed,
    True,
    TestID -> "BlueGreenYellow history palette is available"
  ],
  VerificationTest[
    smokeRiskPaletteColour =!= $Failed,
    True,
    TestID -> "GrayYellowTones risk palette is available"
  ],
  VerificationTest[
    smokeSanitizedFolder,
    "REF_COLD_120",
    TestID -> "String folder components do not acquire quote underscores"
  ],
  VerificationTest[
    smokeCompactStem,
    "S02",
    TestID -> "Compact comparison WXF stem uses only sensor index"
  ],
  VerificationTest[
    TrueQ@Lookup[smokePathAudit, "WithinHardLimit"],
    True,
    TestID -> "Checked-export path audit recognizes a short path"
  ],
  VerificationTest[
    AssociationQ@smokePlannedPaths &&
      Lookup[smokePlannedPaths, "PathsAboveHardLimitCount", 1] == 0,
    True,
    TestID -> "Planned compact output tree remains below hard path limit"
  ],
  VerificationTest[
    SensorDataUtilities`Private`utcDateString@smokeUTCDate,
    "2025-11-26T14:00:00Z",
    TestID -> "UTC DateObject serializes without local-time shift"
  ],
  VerificationTest[
    SensorDataUtilities`Private`utcDateString@smokeLocalSameInstant,
    "2025-11-26T14:00:00Z",
    TestID -> "Local-zone DateObject converts to UTC before serialization"
  ],
  VerificationTest[
    SensorDataUtilities`Private`utcMillisecondKey@smokeUTCDate ===
      SensorDataUtilities`Private`utcMillisecondKey@smokeLocalSameInstant,
    True,
    TestID -> "UTC key is invariant for equivalent instants"
  ],
  VerificationTest[
    SensorDataUtilities`Private`utcDateString@smokeWUFIFixedUTC,
    "2025-11-26T16:00:00Z",
    TestID -> "WUFI 18:00 fixed UTC+2 converts to 16:00Z"
  ],
  VerificationTest[
    SensorDataUtilities`Private`utcDateString@smokeTemporalPathUTC,
    "2025-11-26T14:00:00Z",
    TestID ->
      "UTC DateObject survives TimeSeries Path round trip"
  ],
  VerificationTest[
    SensorDataUtilities`Private`temporalPathMillisecondKey[
      smokeTemporalPathCoordinate,
      $TimeZone
    ] ===
      SensorDataUtilities`Private`utcMillisecondKey@smokeUTCDate,
    True,
    TestID ->
      "TimeSeries Path coordinate maps to the original UTC key"
  ],
  VerificationTest[
    Abs[
      UnixTime@smokeCollapsedDateUTC -
        Mean[UnixTime /@ smokeDuplicateRowsUTC[[All, 1]]]
    ] < 10^-6,
    True,
    TestID ->
      "Near-duplicate collapse preserves the UTC instant"
  ],
  VerificationTest[
    DateValue[
      smokeCollapsedDateUTC,
      "TimeZoneOffset"
    ],
    0.,
    SameTest -> (
      Abs[N@#1 - N@#2] < 10^-12 &
    ),
    TestID ->
      "Collapsed sensor timestamp remains explicit UTC"
  ],
  VerificationTest[
    Lookup[smoke323Aggregation, "LastValidTargetUTC"],
    DateObject[{2026, 3, 19, 20, 0, 0.}, TimeZone -> 0],
    SameTest -> (
      Abs[UnixTime@#1 - UnixTime@#2] < 10^-6 &
    ),
    TestID ->
      "Sensor ending at 20:14Z cannot create a 23:00Z aggregate"
  ],
  VerificationTest[
    Length@smokeExplicitPairs == 1 &&
      Head[First@First@smokeExplicitPairs] === DateObject &&
      Abs[
        N@DateValue[
          First@First@smokeExplicitPairs,
          "TimeZoneOffset"
        ]
      ] < 10^-12,
    True,
    TestID ->
      "Comparison pairing uses explicit UTC DateObjects"
  ],
  VerificationTest[
    KeyExistsQ[
      smokeNormalizedNumeric,
      "TemperatureUnixValuePairs"
    ] &&
      Length@Lookup[
        smokeNormalizedNumeric,
        "TemperatureUnixValuePairs"
      ] ==
        Length@Lookup[
          smokeNormalizedNumeric,
          "TemperaturePairsUTC"
        ],
    True,
    TestID ->
      "Normalized sensors retain one-pass numeric UTC pairs"
  ],
  VerificationTest[
    Lookup[smokeNumericAggregated, "Values"] ===
      Lookup[
        AggregateSensorChannel[
          Lookup[
            smokeNormalizedNumeric,
            "TemperaturePairsUTC"
          ],
          smokeTargets,
          "CenteredWindowMedian",
          smokeAggregationSettings
        ],
        "Values"
      ],
    True,
    TestID ->
      "Numeric UTC aggregation matches public DateObject aggregation"
  ],
  VerificationTest[
    smokeCacheKeyA === smokeCacheKeyB &&
      smokeCacheKeyA =!= smokeCacheKeyOtherWall,
    True,
    TestID ->
      "Sensor preparation cache key is stable and wall-specific"
  ],
  VerificationTest[
    !TrueQ@Lookup[
      smokeComputeOnlySettings,
      "WriteSensorOnlyPlots"
    ] &&
      !TrueQ@Lookup[
        smokeComputeOnlySettings,
        "WriteComparisonPlots"
      ],
    True,
    TestID ->
      "ComputeOnly profile defers all JPG rendering"
  ],
  VerificationTest[
    Lookup[
      Lookup[smokeLagMetrics, "FullPeriod"],
      "BestLagHours"
    ] == 1 &&
      TrueQ@Lookup[
        Lookup[smokeLagMetrics, "FullPeriod"],
        "BestLagAtSearchBoundaryQ"
      ],
    True,
    TestID ->
      "Lag metrics flag a best lag at the configured search boundary"
  ],
  VerificationTest[
    NumericQ[smokeAuditFallbackTimeZone],
    True,
    TestID ->
      "Alignment audit has a numeric timezone before manifest finalization"
  ],
  VerificationTest[
    smokeNumericTimestampRoundTripError < 10^-9,
    True,
    TestID ->
      "Numeric UTC cache preserves legacy DateObject timestamp quantization"
  ],
  VerificationTest[
    Lookup[
      DefaultSensorComparisonSettings[],
      "MaximumKernels"
    ] === Automatic,
    True,
    TestID ->
      "Automatic kernel cap is the optimized default"
  ],
  VerificationTest[
    TrueQ@Lookup[
      DefaultSensorComparisonSettings[],
      "ParallelPlotGeneration"
    ] && TrueQ@Lookup[
      DefaultSensorComparisonSettings[],
      "RecyclePlotKernelsPerBatch"
    ],
    True,
    TestID ->
      "Parallel plot generation and per-batch kernel recycling are enabled"
  ],
  VerificationTest[
    AssociationQ@smokeGraphicExport &&
      TrueQ@Lookup[smokeValidGraphicAudit, "ValidQ", False],
    True,
    TestID ->
      "Checked graphic export commits a valid raster"
  ],
  VerificationTest[
    !TrueQ@Lookup[smokeMalformedGraphicAudit, "ValidQ", True] &&
      Lookup[smokeMalformedGraphicAudit, "HeightPixels", 2] == 1,
    True,
    TestID ->
      "One-pixel-high JPEG is rejected by graphics validation"
  ],
  VerificationTest[
    AssociationQ@smokeLongGraphicExport &&
      TrueQ@Lookup[
        Lookup[smokeLongGraphicExport, "Validation", <||>],
        "ValidQ",
        False
      ],
    True,
    TestID ->
      "Checked export stages long final paths outside destination folder"
  ],
  VerificationTest[
    Lookup[smokeExpectedInventoryAudit, "MissingCount", 0] == 1 &&
      Lookup[smokeExpectedInventoryAudit, "OverallStatus", "Passed"] ===
        "Failed",
    True,
    TestID ->
      "Graphics audit fails when an expected figure is missing"
  ],
  VerificationTest[
    Lookup[
      smokeExpectedInventoryAudit,
      "ExpectedGraphicFileCount",
      0
    ] == 4 &&
      Lookup[
        smokeExpectedInventoryAudit,
        "ActualGraphicFileCount",
        0
      ] == 3,
    True,
    TestID ->
      "Graphics audit reports expected and actual inventory counts"
  ],
  VerificationTest[
    AssociationQ@smokeRenderedPlotTask &&
      MatchQ[Lookup[smokeRenderedPlotTask, "Graphic"], _Graphics | _Legended],
    True,
    TestID ->
      "Plot-task renderer returns a graphic expression"
  ],
  VerificationTest[
    Lookup[smokePlotBatch, "TaskCount", -1] == 2 &&
      Lookup[smokePlotBatch, "ResultCount", -1] == 2 &&
      Lookup[smokePlotBatch, "SuccessfulExportCount", -1] == 2 &&
      Lookup[smokePlotBatch, "FailedExportCount", -1] == 0 &&
      Lookup[smokePlotBatch, "UnclassifiedResultCount", -1] == 0,
    True,
    TestID ->
      "Graphics batch counters account for every task"
  ],
  VerificationTest[
    TrueQ@Lookup[smokePlotBatch, "BatchInvariantPassedQ", False] &&
      Lookup[smokePlotBatch, "BatchStatus", "Failed"] === "Passed" &&
      TrueQ@Lookup[
        Lookup[smokePlotBatch, "BatchInvariantAudit", <||>],
        "AccountedForQ",
        False
      ],
    True,
    TestID ->
      "Graphics batch invariant passes for successful exports"
  ],
  VerificationTest[
    Length@Lookup[smokePlotBatch, "Exports", {}] == 2 &&
      AllTrue[
        Lookup[smokePlotBatch, "Exports", {}],
        SensorDataUtilities`Private`plotTaskExportSuccessQ
      ],
    True,
    TestID ->
      "Graphics batch retains validated per-task export records"
  ],
  VerificationTest[
    Length@smokeRecordAExports == 1 &&
      Lookup[
        First@smokeRecordAExports,
        "RecordKey",
        Missing["RecordKey"]
      ] === "smoke-record-a",
    True,
    TestID ->
      "Per-record PlotExports are restored from batch results"
  ],
  VerificationTest[
    smokeControllerCacheAfter === smokeControllerCacheBefore,
    True,
    TestID ->
      "Subkernel recycling preserves controller-kernel caches"
  ],
  VerificationTest[
    AssociationQ@smokeKernelRecycleAudit &&
      KeyExistsQ[smokeKernelRecycleAudit, "ClosedKernelCount"] &&
      KeyExistsQ[smokeKernelRecycleAudit, "ParallelReadyQ"],
    True,
    TestID ->
      "Kernel recycle operation returns lifecycle diagnostics"
  ]
}];

Quiet@Check[DeleteDirectory[smokeGraphicsDirectory, DeleteContents -> True], Null];
smokeTestReport
