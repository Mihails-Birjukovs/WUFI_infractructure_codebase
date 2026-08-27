(* ::Package:: *)

(*
  Production v1.2.0 equivalence suite.
  Run after completing the candidate five-case run in Wolfram Mathematica 12.1.

  Edit only the two output roots below when necessary.
*)

baselineOutputRoot =
  "D:\\Science\\NMI\\WEED Project\\Fibrolite Materials RTU 2026\\Sensors VS WUFI\\Output_v1_Run1";

candidateOutputRoot =
  "D:\\Science\\NMI\\WEED Project\\Fibrolite Materials RTU 2026\\Sensors VS WUFI\\Output_v1_2_Run1";

equivalenceAbsoluteTolerance = 10.^-10;
equivalenceRelativeTolerance = 10.^-10;

ClearAll[
  equivalenceRelativePath,
  equivalenceNumericQ,
  equivalenceValueQ,
  equivalenceWXFFiles,
  equivalenceImportWXF,
  equivalenceComparisonMetricMap,
  equivalenceMetricKey,
  equivalenceFilePairs,
  equivalenceWXFMismatches
];

equivalenceRelativePath[root_String, path_String] := FileNameJoin[
  Drop[
    FileNameSplit@ExpandFileName@path,
    Length@FileNameSplit@ExpandFileName@root
  ]
];

equivalenceNumericQ[a_?NumericQ, b_?NumericQ] := Module[
  {scale},
  scale = Max[1., Abs@N@a, Abs@N@b];
  Abs[N@a - N@b] <=
    equivalenceAbsoluteTolerance +
      equivalenceRelativeTolerance * scale
];

equivalenceValueQ[old_, new_] := Which[
  NumericQ[old] && NumericQ[new],
    equivalenceNumericQ[old, new],

  Head[old] === DateObject && Head[new] === DateObject,
    Abs[N@UnixTime@old - N@UnixTime@new] < 10.^-6,

  MissingQ[old] && MissingQ[new],
    SameQ[old, new],

  Head[old] === TimeSeries || Head[old] === TemporalData,
    (Head[new] === TimeSeries || Head[new] === TemporalData) &&
      equivalenceValueQ[
        Quiet@Check[old["Path"], Normal@old],
        Quiet@Check[new["Path"], Normal@new]
      ],

  AssociationQ[old] && AssociationQ[new],
    And @@ (KeyExistsQ[new, #] & /@ Keys@old) &&
      And @@ KeyValueMap[
        Function[{key, value},
          KeyExistsQ[new, key] &&
            equivalenceValueQ[
              value,
              Lookup[new, key]
            ]
        ],
        old
      ],

  ListQ[old] && ListQ[new],
    Length@old == Length@new &&
      And @@ MapThread[
        equivalenceValueQ,
        {old, new}
      ],

  True,
    SameQ[old, new]
];

equivalenceWXFFiles[root_String] := Sort[
  equivalenceRelativePath[root, #] & /@
    FileNames["*.wxf", root, Infinity]
];

equivalenceImportWXF[root_String, relative_String] :=
  Quiet@Check[
    Import[
      FileNameJoin[{root, relative}],
      "WXF"
    ],
    $Failed
  ];

equivalenceMetricKey[record_Association] := StringRiffle[
  {
    Lookup[
      Lookup[record, "Selection", <||>],
      "CaseName",
      "UnknownCase"
    ],
    Lookup[record, "GroupID", "UnknownGroup"],
    Lookup[record, "Variable", "UnknownVariable"]
  },
  "::"
];

equivalenceComparisonMetricMap[root_String] := Module[
  {manifest, records},
  manifest = Quiet@Check[
    Get@FileNameJoin[
      {root, "comparison_manifest.wl"}
    ],
    $Failed
  ];
  If[!AssociationQ[manifest], Return[$Failed]];
  records = Flatten[
    Lookup[
      Select[
        Lookup[manifest, "Results", {}],
        AssociationQ
      ],
      "Comparisons",
      {}
    ],
    1
  ];
  Association@Map[
    Function[record,
      equivalenceMetricKey[record] ->
        Lookup[record, "Metrics", <||>]
    ],
    records
  ]
];

baselineManifest = Quiet@Check[
  Get@FileNameJoin[
    {baselineOutputRoot, "comparison_manifest.wl"}
  ],
  $Failed
];

candidateManifest = Quiet@Check[
  Get@FileNameJoin[
    {candidateOutputRoot, "comparison_manifest.wl"}
  ],
  $Failed
];

baselineAlignment = Quiet@Check[
  Get@FileNameJoin[
    {baselineOutputRoot, "time_alignment_audit.wl"}
  ],
  $Failed
];

candidateAlignment = Quiet@Check[
  Get@FileNameJoin[
    {candidateOutputRoot, "time_alignment_audit.wl"}
  ],
  $Failed
];

baselineWXFFiles = equivalenceWXFFiles[
  baselineOutputRoot
];
candidateWXFFiles = equivalenceWXFFiles[
  candidateOutputRoot
];

equivalenceFilePairs = Intersection[
  baselineWXFFiles,
  candidateWXFFiles
];

equivalenceWXFMismatches = Select[
  equivalenceFilePairs,
  Function[relative,
    !equivalenceValueQ[
      equivalenceImportWXF[
        baselineOutputRoot,
        relative
      ],
      equivalenceImportWXF[
        candidateOutputRoot,
        relative
      ]
    ]
  ]
];

baselineMetricMap =
  equivalenceComparisonMetricMap[
    baselineOutputRoot
  ];
candidateMetricMap =
  equivalenceComparisonMetricMap[
    candidateOutputRoot
  ];

metricKeysCommon = If[
  AssociationQ[baselineMetricMap] &&
    AssociationQ[candidateMetricMap],
  Intersection[
    Keys@baselineMetricMap,
    Keys@candidateMetricMap
  ],
  {}
];

metricMismatches = Select[
  metricKeysCommon,
  Function[key,
    !equivalenceValueQ[
      Lookup[baselineMetricMap, key],
      Lookup[candidateMetricMap, key]
    ]
  ]
];

baselineQC = Quiet@Check[
  Import[
    FileNameJoin[
      {baselineOutputRoot, "qc_summary.csv"}
    ],
    "CSV"
  ],
  $Failed
];

candidateQC = Quiet@Check[
  Import[
    FileNameJoin[
      {candidateOutputRoot, "qc_summary.csv"}
    ],
    "CSV"
  ],
  $Failed
];

baselineJPGFiles = Sort[
  equivalenceRelativePath[
    baselineOutputRoot,
    #
  ] & /@
    FileNames[
      "*.jpg",
      baselineOutputRoot,
      Infinity
    ]
];

candidateJPGFiles = Sort[
  equivalenceRelativePath[
    candidateOutputRoot,
    #
  ] & /@
    FileNames[
      "*.jpg",
      candidateOutputRoot,
      Infinity
    ]
];

equivalenceTestReport = TestReport[{
  VerificationTest[
    AssociationQ@baselineManifest &&
      AssociationQ@candidateManifest,
    True,
    TestID ->
      "Both comparison manifests load"
  ],

  VerificationTest[
    Lookup[
      candidateManifest,
      "SensorDataUtilitiesVersion",
      ""
    ],
    "Production-1.2.0-2026-08-05",
    TestID ->
      "Candidate sensor package version is Production v1.2.0"
  ],

  VerificationTest[
    Lookup[
      candidateManifest,
      "HygrothermalPlottingUtilitiesVersion",
      ""
    ],
    "Production-1.2.0-2026-08-05",
    TestID ->
      "Candidate plotting package version is Production v1.2.0"
  ],

  VerificationTest[
    Lookup[
      Lookup[
        candidateManifest,
        "SensorPreparationCache",
        <||>
      ],
      "UniqueBundleCount",
      Missing["Unavailable"]
    ] == 2 &&
      Lookup[
        Lookup[
          candidateManifest,
          "SensorPreparationCache",
          <||>
        ],
        "CacheHitCount",
        Missing["Unavailable"]
      ] == 3,
    True,
    TestID ->
      "Five-case run uses two unique sensor bundles and three cache hits"
  ],

  VerificationTest[
    Lookup[
      candidateManifest,
      "ManifestFinalizedAfterAudits",
      False
    ] &&
      Lookup[
        Lookup[
          candidateManifest,
          "AlignmentAuditSummary",
          <||>
        ],
        "OverallStatus",
        "Failed"
      ] === "Passed" &&
      Lookup[
        Lookup[
          candidateManifest,
          "GraphicsIntegrityAuditSummary",
          <||>
        ],
        "OverallStatus",
        "Failed"
      ] === "Passed",
    True,
    TestID ->
      "Final manifest contains passed alignment and graphics audits"
  ],

  VerificationTest[
    baselineWXFFiles,
    candidateWXFFiles,
    TestID ->
      "Candidate exports the same relative WXF file set"
  ],

  VerificationTest[
    equivalenceWXFMismatches,
    {},
    TestID ->
      "All WXF payloads are numerically and temporally equivalent"
  ],

  VerificationTest[
    AssociationQ[baselineMetricMap] &&
      AssociationQ[candidateMetricMap] &&
      Sort@Keys@baselineMetricMap ===
        Sort@Keys@candidateMetricMap &&
      metricMismatches === {},
    True,
    TestID ->
      "All pre-existing comparison metrics are equivalent"
  ],

  VerificationTest[
    baselineQC,
    candidateQC,
    TestID ->
      "QC summary is unchanged"
  ],

  VerificationTest[
    Lookup[
      candidateAlignment,
      "OverallStatus",
      "Failed"
    ] === "Passed" &&
      Lookup[
        candidateAlignment,
        "FailedCount",
        1
      ] == 0 &&
      Lookup[
        candidateAlignment,
        "PassedCount",
        0
      ] == 24,
    True,
    TestID ->
      "Candidate alignment audit passes 24 of 24 series"
  ],
  VerificationTest[
    NumericQ@Lookup[
      candidateAlignment,
      "GeneratedTimeZoneHoursFromRunManifest",
      Missing["Unavailable"]
    ],
    True,
    TestID ->
      "Alignment audit serializes a numeric run timezone"
  ],

  VerificationTest[
    baselineJPGFiles,
    candidateJPGFiles,
    TestID ->
      "Full-profile candidate exports the same JPG file set"
  ],

  VerificationTest[
    Lookup[
      candidateManifest,
      "CompletedSelectionCount",
      0
    ] == 5 &&
      Lookup[
        candidateManifest,
        "FailedSelectionCount",
        1
      ] == 0 &&
      Lookup[
        candidateManifest,
        "NestedFailureCount",
        1
      ] == 0 &&
      Lookup[
        candidateManifest,
        "MetricRowCount",
        0
      ] == 24 &&
      Lookup[
        candidateManifest,
        "QCRowCount",
        0
      ] == 17,
    True,
    TestID ->
      "Candidate run counts match the frozen baseline"
  ]
}];

equivalenceDetails = <|
  "BaselineOutputRoot" -> baselineOutputRoot,
  "CandidateOutputRoot" -> candidateOutputRoot,
  "BaselineWXFCount" -> Length@baselineWXFFiles,
  "CandidateWXFCount" -> Length@candidateWXFFiles,
  "WXFMismatches" -> equivalenceWXFMismatches,
  "BaselineMetricCount" -> If[
    AssociationQ[baselineMetricMap],
    Length@baselineMetricMap,
    Missing["Unavailable"]
  ],
  "CandidateMetricCount" -> If[
    AssociationQ[candidateMetricMap],
    Length@candidateMetricMap,
    Missing["Unavailable"]
  ],
  "MetricMismatches" -> metricMismatches,
  "BaselineJPGCount" -> Length@baselineJPGFiles,
  "CandidateJPGCount" -> Length@candidateJPGFiles,
  "CandidateElapsedSeconds" -> Lookup[
    Lookup[
      candidateManifest,
      "StageTimingsSeconds",
      <||>
    ],
    "ElapsedThroughAlignmentAudit",
    Missing["Unavailable"]
  ]
|>;

<|
  "TestReport" -> equivalenceTestReport,
  "Details" -> equivalenceDetails
|>
