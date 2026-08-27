(* ::Package:: *)

(* WUFI Data Post-Processor Automated Production v1.1.1 - fast smoke tests
   Target: Wolfram Mathematica 12.1.
   Run either interactively or via Get from the release folder. *)

smokeTestBaseDirectoryV11 = If[
  StringQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName],
  NotebookDirectory[]
];

Get[
  FileNameJoin[
    {
      smokeTestBaseDirectoryV11,
      "WUFIDataPostProcessor_v1_1_1.wl"
    }
  ]
];

syntheticCaseV11 = <|
  "ProjectBaseName" -> "Synthetic_Project",
  "CaseIndex" -> 1,
  "CaseName" -> "Synthetic_Case",
  "CaseFolderName" -> "C01_Synthetic_Case",
  "ExpectedASCFileName" -> "Synthetic_Project_0.asc",
  "Sensors" -> Table[
    <|
      "FolderName" -> ("P" <> ToString[i]),
      "TemperatureColumn" -> (2 i),
      "RelativeHumidityColumn" -> (2 i + 1)
    |>,
    {i, 3}
  ],
  "Layers" -> Table[
    <|
      "PlotFileBase" -> ("L" <> ToString[i]),
      "WaterContentColumn" -> (8 + i)
    |>,
    {i, 4}
  ],
  "TotalWaterContentColumn" -> 13
|>;

smokeRootV11 = ExpandFileName[
  FileNameJoin[
    {
      smokeTestBaseDirectoryV11,
      "_smoke_output"
    }
  ]
];

fullSettingsV11 = ResolveWUFIPostProcessorSettingsV11[
  <|
    "DataDirectory" -> smokeRootV11,
    "OutputRoot" -> smokeRootV11,
    "GraphicsMode" -> "Full",
    "ShowProgress" -> False,
    "VerboseLogging" -> False
  |>
];

sweepSettingsV11 = ResolveWUFIPostProcessorSettingsV11[
  <|
    "DataDirectory" -> smokeRootV11,
    "OutputRoot" -> smokeRootV11,
    "GraphicsMode" -> "Sweep",
    "ShowProgress" -> False,
    "VerboseLogging" -> False
  |>
];

v11SmokeReport = TestReport[
  {
    VerificationTest[
      Length[expectedWXFRecordsV11[syntheticCaseV11, fullSettingsV11]],
      5,
      TestID -> "Five WXF outputs are always planned"
    ],

    VerificationTest[
      Lookup[expectedWXFRecordsV11[syntheticCaseV11, fullSettingsV11], "Kind"],
      {"RelativeHumidity", "Temperature", "DewPoint", "LayerWaterContent", "TotalWaterContent"},
      TestID -> "WXF semantic inventory preserved"
    ],

    VerificationTest[
      FileNameTake /@ Lookup[expectedWXFRecordsV11[syntheticCaseV11, fullSettingsV11], "Target"],
      {"relative_humidity.wxf", "temperature.wxf", "dew_point.wxf", "layer_water_content.wxf", "total_water_content.wxf"},
      TestID -> "Downstream WXF filenames preserved"
    ],

    VerificationTest[
      Length[expectedImageJobsV11[syntheticCaseV11, fullSettingsV11]],
      20,
      TestID -> "Full mode image count = 5 sensors families + layers + total"
    ],

    VerificationTest[
      Length[expectedImageJobsV11[syntheticCaseV11, sweepSettingsV11]],
      11,
      TestID -> "Sweep mode image count = RH + T + layers + total"
    ],

    VerificationTest[
      Intersection[
        Lookup[expectedImageJobsV11[syntheticCaseV11, sweepSettingsV11], "Kind"],
        {"DewPoint", "MouldHistory", "MouldRisk"}
      ],
      {},
      TestID -> "Sweep mode omits dew-point and mould JPGs"
    ],

    VerificationTest[
      ValidateWUFIPostProcessorSettingsV11[
        Join[fullSettingsV11, <|"GraphicsMode" -> "Invalid"|>]
      ]["Valid"],
      False,
      TestID -> "Invalid GraphicsMode is rejected"
    ],

    VerificationTest[
      ValidateWUFIPostProcessorSettingsV11[
        Join[fullSettingsV11, <|"DataFileFormat" -> ".txt"|>]
      ]["Valid"],
      False,
      TestID -> "WXF filename extension contract is locked"
    ],

    VerificationTest[
      {
        Lookup[DefaultWUFIPostProcessorSettingsV11[], "GraphicsKernelCount"],
        Lookup[DefaultWUFIPostProcessorSettingsV11[], "ShowProgress"],
        Lookup[DefaultWUFIPostProcessorSettingsV11[], "VerboseLogging"],
        Lookup[DefaultWUFIPostProcessorSettingsV11[], "ExplicitTimeSeriesTicks"]
      },
      {8, True, True, True},
      TestID -> "Production v1.1.1 defaults are locked"
    ],

    VerificationTest[
      Lookup[
        ValidateWUFIPostProcessorSettingsV11[
          Join[
            fullSettingsV11,
            <|
              "UseParallelGraphics" -> True,
              "GraphicsKernelCount" -> 16
            |>
          ]
        ],
        "Warnings",
        {}
      ] =!= {},
      True,
      TestID -> "Kernel counts above validated threshold generate warning"
    ],

    VerificationTest[
      TrueQ[Lookup[fullSettingsV11, "RestartFailedCases"] === False],
      True,
      TestID -> "Restart is opt-in"
    ],

    VerificationTest[
      Module[
        {testDirectory, target, settings, result, ok},

        testDirectory = FileNameJoin[
          {
            smokeRootV11,
            "_atomic_jpeg_smoke"
          }
        ];

        If[
          DirectoryQ[testDirectory],
          Quiet@DeleteDirectory[testDirectory, DeleteContents -> True]
        ];

        CreateDirectory[
          testDirectory,
          CreateIntermediateDirectories -> True
        ];

        target = FileNameJoin[
          {
            testDirectory,
            "atomic_export.jpg"
          }
        ];

        settings = Join[
          fullSettingsV11,
          <|
            "MinimumImageByteCount" -> 1,
            "MinimumImageWidth" -> 10,
            "MinimumImageHeight" -> 10
          |>
        ];

        result = atomicExportImageV11[
          target,
          Plot[Sin[x], {x, 0, 2 Pi}, ImageSize -> 250],
          settings
        ];

        ok =
          TrueQ[Lookup[result, "Status", ""] === "Valid"] &&
          TrueQ[validImageFileQv11[target, settings]];

        If[
          DirectoryQ[testDirectory],
          Quiet@DeleteDirectory[testDirectory, DeleteContents -> True]
        ];

        ok
      ],
      True,
      TestID -> "Atomic JPEG export validates temporary and final image"
    ],

VerificationTest[
 Module[
  {dates, series, ticks, dateTicks},

  graphicsRuntimeSettingsV11 =
   <|
    "TimeFormat" -> {"MonthShort", "/", "YearShort"},
    "ExplicitTimeSeriesTicks" -> True
    |>;

  dates =
   DateObject /@
    {
     {2026, 1, 1, 0, 0, 0},
     {2026, 2, 1, 0, 0, 0},
     {2026, 3, 1, 0, 0, 0},
     {2026, 4, 1, 0, 0, 0}
     };

  series =
   Transpose[
    {
     dates,
     {20., 21., 20.5, 22.}
     }
    ];

  ticks =
   explicitDateFrameTicksV11[
    series
    ];

  dateTicks =
   ticks[[2, 1]];

  Clear[
   graphicsRuntimeSettingsV11
   ];

  And[
   MatchQ[
    ticks,
    {
     {_List, None},
     {_List, None}
     }
    ],

   FreeQ[
    ticks,
    Automatic
    ],

   dateTicks =!= {},

   AllTrue[
    dateTicks[[All, 1]],
    NumericQ
    ],

   AllTrue[
    dateTicks[[All, 2]],
    StringQ
    ]
   ]
  ],
 True,
 TestID ->
  "Time-series frame ticks resolve to numeric absolute-time positions"
 ],

    VerificationTest[
      Module[
        {
          testDirectory, target, settings, dates, temperatureSeries,
          payload, job, passData, result, ok
        },

        testDirectory = FileNameJoin[
          {
            smokeRootV11,
            "_fresh_kernel_graphics_smoke"
          }
        ];

        If[
          DirectoryQ[testDirectory],
          Quiet@DeleteDirectory[testDirectory, DeleteContents -> True]
        ];

        CreateDirectory[
          testDirectory,
          CreateIntermediateDirectories -> True
        ];

        target = FileNameJoin[
          {
            testDirectory,
            "temperature.jpg"
          }
        ];

        settings = Join[
          sweepSettingsV11,
          <|
            "UseParallelGraphics" -> True,
            "GraphicsKernelCount" -> 1,
            "FreshKernelRetries" -> 0,
            "MinimumImageByteCount" -> 1,
            "MinimumImageWidth" -> 10,
            "MinimumImageHeight" -> 10,
            "ImageSizeSeries" -> 250,
            "ExportResolution" -> 150,
            "ShowProgress" -> False,
            "VerboseLogging" -> False
          |>
        ];

        dates = DateObject /@ {
          {2026, 1, 1, 0, 0, 0},
          {2026, 2, 1, 0, 0, 0},
          {2026, 3, 1, 0, 0, 0},
          {2026, 4, 1, 0, 0, 0}
        };

        temperatureSeries = {
          Transpose[
            {
              dates,
              {20., 21., 20.5, 22.}
            }
          ]
        };

        payload = <|
          "TemperatureSeries" -> temperatureSeries,
          "HumiditySeries" -> {},
          "DewPointSeries" -> {},
          "WaterSeries" -> {},
          "WaterTotalSeries" -> {},
          "StartDate" -> First[dates],
          "EndDate" -> Last[dates],
          "MonthSpan" -> 0,
          "ColorTable" -> {},
          "CurvesLIM" -> {}
        |>;

        job = <|
          "OutputType" -> "Image",
          "Kind" -> "Temperature",
          "Index" -> 1,
          "Target" -> target
        |>;

        passData = runGraphicsPassV11[
          {job},
          payload,
          settings
        ];

        result = Lookup[passData, "Results", {}];

        ok =
          ListQ[result] &&
          Length[result] === 1 &&
          TrueQ[Lookup[First[result], "Status", ""] === "Valid"] &&
          TrueQ[validImageFileQv11[target, settings]] &&
          Lookup[passData, "GraphicsKernelCountLaunched", 0] === 1;

        If[
          DirectoryQ[testDirectory],
          Quiet@DeleteDirectory[testDirectory, DeleteContents -> True]
        ];

        ok
      ],
      True,
      TestID -> "Fresh-kernel graphics render and JPEG export succeeds"
    ]
  }
];

v11SmokeReport


v11SmokeReport//First
