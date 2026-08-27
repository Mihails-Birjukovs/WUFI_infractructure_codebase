(* ::Package:: *)

(* WUFI Data Post-Processor Automated Production v1.1.1 - graphics stress regression test
   Purpose:
     - exercise deterministic date/numeric tick rendering under validated high-throughput load;
     - compare imported pixel content, not raw JPEG bytes, so EXIF creation timestamps are non-semantic.
   Target: Wolfram Mathematica 12.1.
   This is intentionally heavier than the fast smoke suite. *)

stressTestBaseDirectoryV11 = If[
  StringQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName],
  NotebookDirectory[]
];

Get[
  FileNameJoin[
    {
      stressTestBaseDirectoryV11,
      "WUFIDataPostProcessor_v1_1_1.wl"
    }
  ]
];

stressRootV11 = ExpandFileName[
  FileNameJoin[
    {
      stressTestBaseDirectoryV11,
      "_graphics_stress_output"
    }
  ]
];

If[
  DirectoryQ[stressRootV11],
  Quiet@DeleteDirectory[stressRootV11, DeleteContents -> True]
];

CreateDirectory[
  stressRootV11,
  CreateIntermediateDirectories -> True
];

stressStartDateV11 = DateObject[{2025, 11, 26, 18, 0, 0}];

stressDatesV11 = Table[
  DatePlus[
    stressStartDateV11,
    {i, "Hour"}
  ],
  {i, 0, 3186}
];

stressTemperatureValuesV11 = Table[
  18. +
  8. Sin[2 Pi i/720.] +
  1.5 Sin[2 Pi i/168.],
  {i, 0, 3186}
];

stressDewPointValuesV11 = Table[
  stressTemperatureValuesV11[[i + 1]] -
  3.5 +
  0.8 Sin[2 Pi i/240.],
  {i, 0, 3186}
];

stressTemperatureSeriesV11 = {
  Transpose[
    {
      stressDatesV11,
      stressTemperatureValuesV11
    }
  ]
};

stressDewPointSeriesV11 = {
  Transpose[
    {
      stressDatesV11,
      stressDewPointValuesV11
    }
  ]
};

stressPayloadV11 = <|
  "TemperatureSeries" -> stressTemperatureSeriesV11,
  "HumiditySeries" -> {},
  "DewPointSeries" -> stressDewPointSeriesV11,
  "WaterSeries" -> {},
  "WaterTotalSeries" -> {},
  "StartDate" -> First[stressDatesV11],
  "EndDate" -> Last[stressDatesV11],
  "MonthSpan" -> 0,
  "ColorTable" -> {},
  "CurvesLIM" -> {}
|>;

stressBaseSettingsV11 = ResolveWUFIPostProcessorSettingsV11[
  <|
    "DataDirectory" -> stressRootV11,
    "OutputRoot" -> stressRootV11,
    "GraphicsMode" -> "Sweep",
    "FreshKernelRetries" -> 0,
    "ShowProgress" -> True,
    "VerboseLogging" -> True,
    "MinimumImageByteCount" -> 1,
    "MinimumImageWidth" -> 100,
    "MinimumImageHeight" -> 100,
    "ImageSizeSeries" -> 500,
    "ExportResolution" -> 500,
    "ExplicitTimeSeriesTicks" -> True
  |>
];

baselineDirectoryV11 = FileNameJoin[
  {
    stressRootV11,
    "baseline_1_kernel"
  }
];

parallelDirectoryV11 = FileNameJoin[
  {
    stressRootV11,
    "parallel_12_kernel"
  }
];

CreateDirectory[
  baselineDirectoryV11,
  CreateIntermediateDirectories -> True
];

CreateDirectory[
  parallelDirectoryV11,
  CreateIntermediateDirectories -> True
];

baselineTemperatureTargetV11 = FileNameJoin[
  {
    baselineDirectoryV11,
    "temperature.jpg"
  }
];

baselineDewPointTargetV11 = FileNameJoin[
  {
    baselineDirectoryV11,
    "dew_point.jpg"
  }
];

baselineJobsV11 = {
  <|
    "OutputType" -> "Image",
    "Kind" -> "Temperature",
    "Index" -> 1,
    "Target" -> baselineTemperatureTargetV11
  |>,
  <|
    "OutputType" -> "Image",
    "Kind" -> "DewPoint",
    "Index" -> 1,
    "Target" -> baselineDewPointTargetV11
  |>
};

baselinePassV11 = runGraphicsPassV11[
  baselineJobsV11,
  stressPayloadV11,
  Join[
    stressBaseSettingsV11,
    <|
      "UseParallelGraphics" -> False,
      "GraphicsKernelCount" -> 1,
      "ShowProgress" -> False
    |>
  ]
];

baselineResultsV11 = Lookup[
  baselinePassV11,
  "Results",
  {}
];

baselineValidV11 =
  Length[baselineResultsV11] === 2 &&
  And @@ (
    TrueQ[Lookup[#, "Status", ""] === "Valid"] & /@ baselineResultsV11
  );

imagePixelHashV11[path_String] := Module[{image},
  image = Quiet@Check[
    Import[path, "JPEG"],
    $Failed
  ];

  If[
    image === $Failed || Head[image] =!= Image,
    $Failed,
    Hash[
      ImageData[image, "Byte"],
      "SHA256"
    ]
  ]
];

baselineTemperatureHashV11 = imagePixelHashV11[
  baselineTemperatureTargetV11
];

baselineDewPointHashV11 = imagePixelHashV11[
  baselineDewPointTargetV11
];

baselineTemperatureDimensionsV11 = ImageDimensions[
  Import[
    baselineTemperatureTargetV11,
    "JPEG"
  ]
];

baselineDewPointDimensionsV11 = ImageDimensions[
  Import[
    baselineDewPointTargetV11,
    "JPEG"
  ]
];

stressJobsV11 = Flatten[
  Table[
    {
      <|
        "OutputType" -> "Image",
        "Kind" -> "Temperature",
        "Index" -> 1,
        "Target" -> FileNameJoin[
          {
            parallelDirectoryV11,
            "temperature_" <> IntegerString[i, 10, 2] <> ".jpg"
          }
        ]
      |>,
      <|
        "OutputType" -> "Image",
        "Kind" -> "DewPoint",
        "Index" -> 1,
        "Target" -> FileNameJoin[
          {
            parallelDirectoryV11,
            "dew_point_" <> IntegerString[i, 10, 2] <> ".jpg"
          }
        ]
      |>
    },
    {i, 1, 24}
  ],
  1
];

stressPassV11 = runGraphicsPassV11[
  stressJobsV11,
  stressPayloadV11,
  Join[
    stressBaseSettingsV11,
    <|
      "UseParallelGraphics" -> True,
      "GraphicsKernelCount" -> 12,
      "ShowProgress" -> True,
      "CurrentCaseOrdinal" -> 1,
      "TotalCaseCount" -> 1,
      "CurrentCaseName" -> "Graphics stress regression"
    |>
  ]
];

stressResultsV11 = Lookup[
  stressPassV11,
  "Results",
  {}
];

stressFileAssessmentsV11 = Map[
  Function[
    job,
    Module[
      {
        kind, target, image, dimensions, hash, expectedDimensions,
        expectedHash, valid
      },

      kind = Lookup[job, "Kind"];
      target = Lookup[job, "Target"];

      image = Quiet@Check[
        Import[target, "JPEG"],
        $Failed
      ];

      If[
        image === $Failed || Head[image] =!= Image,

        <|
          "Kind" -> kind,
          "Target" -> target,
          "Valid" -> False,
          "Issue" -> "Could not import rendered JPEG"
        |>,

        dimensions = ImageDimensions[image];
        hash = Hash[
          ImageData[image, "Byte"],
          "SHA256"
        ];

        expectedDimensions = If[
          kind === "Temperature",
          baselineTemperatureDimensionsV11,
          baselineDewPointDimensionsV11
        ];

        expectedHash = If[
          kind === "Temperature",
          baselineTemperatureHashV11,
          baselineDewPointHashV11
        ];

        valid =
          dimensions === expectedDimensions &&
          hash === expectedHash;

        <|
          "Kind" -> kind,
          "Target" -> target,
          "Valid" -> valid,
          "Dimensions" -> dimensions,
          "ExpectedDimensions" -> expectedDimensions,
          "PixelHash" -> hash,
          "ExpectedPixelHash" -> expectedHash
        |>
      ]
    ]
  ],
  stressJobsV11
];

graphicsStressReportV11 = <|
  "Version" -> $WUFIPostProcessorVersionV11,
  "BaselineValid" -> baselineValidV11,
  "StressJobCount" -> Length[stressJobsV11],
  "StressRenderValidCount" -> Count[
    Lookup[stressResultsV11, "Status", ""],
    "Valid"
  ],
  "StressRenderFailureCount" -> Count[
    Lookup[stressResultsV11, "Status", ""],
    "Failed"
  ],
  "GraphicsKernelCountRequested" -> Lookup[
    stressPassV11,
    "GraphicsKernelCountRequested",
    Missing["NotAvailable"]
  ],
  "GraphicsKernelCountLaunched" -> Lookup[
    stressPassV11,
    "GraphicsKernelCountLaunched",
    Missing["NotAvailable"]
  ],
  "PixelEquivalentCount" -> Count[
    Lookup[stressFileAssessmentsV11, "Valid", False],
    True
  ],
  "PixelMismatchCount" -> Count[
    Lookup[stressFileAssessmentsV11, "Valid", False],
    False
  ],
  "Mismatches" -> Select[
    stressFileAssessmentsV11,
    ! TrueQ[Lookup[#, "Valid", False]] &
  ],
  "Pass" ->
    TrueQ[baselineValidV11] &&
    Length[stressResultsV11] === Length[stressJobsV11] &&
    Count[Lookup[stressResultsV11, "Status", ""], "Valid"] === Length[stressJobsV11] &&
    Count[Lookup[stressFileAssessmentsV11, "Valid", False], True] === Length[stressJobsV11]
|>;

Dataset[
  KeyTake[
    graphicsStressReportV11,
    {
      "Version",
      "BaselineValid",
      "StressJobCount",
      "StressRenderValidCount",
      "StressRenderFailureCount",
      "GraphicsKernelCountRequested",
      "GraphicsKernelCountLaunched",
      "PixelEquivalentCount",
      "PixelMismatchCount",
      "Pass"
    }
  ]
]

graphicsStressReportV11
