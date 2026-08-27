(* ::Package:: *)

BeginPackage["WUFIModelMetadata`"];

BuildWUFIManifest::usage =
  "BuildWUFIManifest[directory] parses matching .w6p/.xml pairs and returns a project/case manifest.";
BuildExportMask::usage =
  "BuildExportMask[materialCount, totalSensorCount] builds the reversed WUFI -v mask for T, RH, layer water contents, and total water content.";
WriteWUFIManifest::usage =
  "WriteWUFIManifest[manifest, directory, baseName] writes .wl and .json copies of the manifest.";
LoadWUFIManifest::usage =
  "LoadWUFIManifest[path] loads a manifest written as a Wolfram Language expression.";
WriteWUFIBatchFile::usage =
  "WriteWUFIBatchFile[manifest, path] writes a Windows batch launcher for all valid projects.";
ValidateASCRows::usage =
  "ValidateASCRows[rows, caseRecord] validates an imported WUFI ASC table against the manifest.";
SanitizeFileName::usage =
  "SanitizeFileName[text] converts text to a Windows-safe file or folder token.";

Begin["`Private`"];

$ManifestVersion = 3;
$FixedSkippedSeriesCount = 19;
$BoundarySensorCount = 2;

Options[BuildWUFIManifest] = {
  "RequireGrafikaAgreement" -> False
};

Options[WriteWUFIBatchFile] = {
  "WUFICommand" -> "WUFI",
  "CalculationSwitches" -> "-C -s -v",
  "PauseAtEnd" -> True
};

ClearAll[
  xmlAttributes, xmlAttribute, xmlDirectChildren, xmlFirstDirectChild,
  xmlText, xmlChildText, parseNumber, parseInteger, scalarValue,
  fixedDecimalString, depthToken, indexToken, shortToken,
  parseGrafikaSensors, parseTimeProfileISO, parseCase, buildProjectRecord,
  missingProjectRecord, jsonSafe, batQuote, commandToken
];

xmlAttributes[XMLElement[_, attrs_, _]] := Association[attrs];
xmlAttributes[_] := <||>;

xmlAttribute[element_XMLElement, key_String, default_: Missing["NotAvailable"]] :=
  Lookup[xmlAttributes[element], key, default];
xmlAttribute[_, _, default_: Missing["NotAvailable"]] := default;

xmlDirectChildren[element_XMLElement, tag_String] :=
  Cases[element[[3]], child : XMLElement[tag, _, _] :> child, {1}];
xmlDirectChildren[_, _] := {};

xmlFirstDirectChild[element_, tag_String] :=
  FirstCase[xmlDirectChildren[element, tag], child_ :> child,
    Missing["NotFound", tag]];

xmlText[element_XMLElement] :=
  StringTrim[StringJoin[Cases[element[[3]], text_String :> text, Infinity]]];
xmlText[_] := "";

xmlChildText[element_, tag_String, default_: ""] := Module[{child},
  child = xmlFirstDirectChild[element, tag];
  If[MissingQ[child], default, xmlText[child]]
];

parseNumber[value_] := Module[{text, normalized},
  text = StringTrim[ToString[value]];
  normalized = StringReplace[text, "," -> "."];
  normalized = StringReplace[
    normalized,
    RegularExpression[
      "^([+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+))[eE]([+-]?[0-9]+)$"
    ] -> "$1*^$2"
  ];
  If[
    StringMatchQ[normalized, NumberString],
    Quiet@Check[N[ToExpression[normalized]], Missing["NotNumeric", text]],
    Missing["NotNumeric", text]
  ]
];

parseInteger[value_] := Module[{text},
  text = StringTrim[ToString[value]];
  If[StringMatchQ[text, DigitCharacter ..], ToExpression[text],
    Missing["NotInteger", text]]
];

scalarValue[element_, scalarName_String, default_: Missing["NotFound"]] :=
 Module[{scalars, scalar},
  scalars = xmlFirstDirectChild[element, "Scalars"];
  If[MissingQ[scalars], Return[default]];
  scalar = FirstCase[
    xmlDirectChildren[scalars, "Scalar"],
    item_XMLElement /;
      xmlAttribute[item, "name", ""] === scalarName :> item,
    Missing["NotFound", scalarName]
  ];
  If[MissingQ[scalar], default,
    parseNumber[xmlAttribute[scalar, "value", ""]]]
];

SanitizeFileName[text_] := Module[{value},
  value = StringTrim[ToString[text]];
  value = StringReplace[value, {
      RegularExpression["[<>:\"/\\\\|?*\\x00-\\x1F]"] -> "_",
      WhitespaceCharacter .. -> "_"
    }];
  value = StringReplace[value, RegularExpression["_+"] -> "_"];
  value = StringTrim[value, RegularExpression["[ ._]+"]];
  If[value === "", "unnamed", value]
];

shortToken[text_, maximum_: 48] := Module[{safe},
  safe = SanitizeFileName[text];
  If[StringLength[safe] <= maximum, safe,
    StringTrim[StringTake[safe, maximum], RegularExpression["[ ._]+"]]]
];

indexToken[prefix_String, index_Integer, count_Integer] :=
  prefix <> IntegerString[index, 10, Max[2, IntegerLength[Max[1, count]]]];

fixedDecimalString[value_?NumericQ, decimals_Integer : 3] := Module[
  {scale, scaledInteger, sign, absoluteInteger, wholePart, fractionalPart},

  (* Build decimal text from integers rather than NumberForm/StandardForm.
     This prevents formatted-box expressions from leaking into JSON and
     Windows folder names when evaluated in a notebook front end. *)
  scale = 10^decimals;
  scaledInteger = Round[N[value] scale];

  sign = If[scaledInteger < 0, "-", ""];
  absoluteInteger = Abs[scaledInteger];
  wholePart = Quotient[absoluteInteger, scale];
  fractionalPart = Mod[absoluteInteger, scale];

  sign <> ToString[wholePart] <>
    If[
      decimals > 0,
      "." <> IntegerString[fractionalPart, 10, decimals],
      ""
    ]
];

fixedDecimalString[_, _ : 3] := "NA";

depthToken[depthMetres_?NumericQ] := Module[{millimetres, fixed, pieces},
  millimetres = 1000. depthMetres;
  fixed = fixedDecimalString[millimetres, 3];
  pieces = StringSplit[fixed, "."];
  If[Length[pieces] == 1, pieces = {First[pieces], "000"}];
  StringPadLeft[pieces[[1]], 3, "0"] <> "." <> pieces[[2]] <> "mm"
];
depthToken[_] := "NAmm";

BuildExportMask[materialCount_Integer?NonNegative,
   totalSensorCount_Integer?NonNegative] :=
  StringJoin[
    StringRepeat["1", materialCount + 1],
    StringRepeat["011", totalSensorCount],
    StringRepeat["0", 4 (materialCount + 2) + $FixedSkippedSeriesCount]
  ];


parseTimeProfileISO[profile_XMLElement] := Module[{dateText, timeFraction, dateObject},
  dateText = xmlChildText[profile, "Date", ""];
  timeFraction = parseNumber[xmlChildText[profile, "Time", ""]];
  dateObject = Quiet@Check[DateObject[dateText], $Failed];
  If[dateObject === $Failed || ! NumericQ[timeFraction],
    Missing["NotAvailable"],
    DateString[
      DatePlus[dateObject, Quantity[24 timeFraction, "Hours"]],
      {"Year", "-", "Month", "-", "Day", "T", "Hour", ":",
        "Minute", ":", "Second"}
    ]
  ]
];
parseTimeProfileISO[_] := Missing["NotAvailable"];

parseGrafikaSensors[caseNode_] := Module[
  {grafika, curvesContainer, curveNodes, records, grouped, complete,
   positionRecords, exteriorPositions, interiorPositions, internalPositions},

  grafika = xmlFirstDirectChild[caseNode, "Grafika"];
  If[MissingQ[grafika],
    Return[<|"Available" -> False,
      "Status" -> "Unavailable",
      "CompletePositionCount" -> Missing["NotAvailable"],
      "InternalSensorCount" -> Missing["NotAvailable"],
      "Positions" -> {}|>]
  ];

  curvesContainer = xmlFirstDirectChild[grafika, "CoursesCurves"];
  If[MissingQ[curvesContainer],
    Return[<|"Available" -> False,
      "Status" -> "Unavailable",
      "CompletePositionCount" -> Missing["NotAvailable"],
      "InternalSensorCount" -> Missing["NotAvailable"],
      "Positions" -> {}|>]
  ];

  curveNodes = xmlDirectChildren[curvesContainer, "Curve"];
  records = Cases[
    curveNodes,
    curve_XMLElement :> Module[{type, position},
      type = parseInteger[xmlChildText[curve, "CurveTypeID", ""]];
      position = parseInteger[xmlChildText[curve, "CurvePositionIndex", ""]];
      If[MemberQ[{9, 10, 15}, type] && IntegerQ[position],
        <|"Type" -> type, "PositionIndex" -> position,
          "Name" -> xmlChildText[curve, "Name", ""]|>,
        Nothing
      ]
    ]
  ];

  If[records === {},
    Return[<|"Available" -> False,
      "Status" -> "Unavailable",
      "CompletePositionCount" -> Missing["NotAvailable"],
      "InternalSensorCount" -> Missing["NotAvailable"],
      "Positions" -> {}|>]
  ];

  grouped = KeySort@GroupBy[records, Lookup[#, "PositionIndex"] &];
  complete = Select[grouped,
    MemberQ[Lookup[#, "Type"], 9] && MemberQ[Lookup[#, "Type"], 10] &];

  positionRecords = KeyValueMap[
    Function[{position, group},
      Module[{names, joined, kind},
        names = Lookup[group, "Name", {}];
        joined = ToLowerCase[StringRiffle[names, " "]];
        kind = Which[
          StringContainsQ[joined, "exterior surface"], "ExteriorSurface",
          StringContainsQ[joined, "interior surface"], "InteriorSurface",
          True, "Internal"
        ];
        <|"PositionIndex" -> position, "Kind" -> kind,
          "CurveTypes" -> Sort@DeleteDuplicates@Lookup[group, "Type"],
          "Names" -> names|>
      ]
    ],
    complete
  ];

  exteriorPositions = Count[Lookup[positionRecords, "Kind", {}],
    "ExteriorSurface"];
  interiorPositions = Count[Lookup[positionRecords, "Kind", {}],
    "InteriorSurface"];
  internalPositions = Count[Lookup[positionRecords, "Kind", {}], "Internal"];

  <|
    "Available" -> True,
    "Status" -> If[exteriorPositions == 1 && interiorPositions == 1,
      "Complete", "SurfaceIdentificationWarning"],
    "CompletePositionCount" -> Length[positionRecords],
    "InternalSensorCount" -> internalPositions,
    "ExteriorSurfaceCount" -> exteriorPositions,
    "InteriorSurfaceCount" -> interiorPositions,
    "Positions" -> positionRecords
  |>
];

parseCase[caseNode_, ordinal_Integer, projectBase_String,
   projectCaseCount_Integer] := Module[
  {caseIndex, caseID, caseName, isActive, component, layersContainer,
   layerNodes, layersCountAttribute, layerCount, preliminaryLayers,
   thicknesses, layerStarts, layers, allMonitors, validMonitors,
   staleMonitors, grafikaCheck, validationStatus, totalSensorCount,
   sensors, expectedColumns, totalWaterColumn, calculationStart,
   calculationEnd, lastResultStart, lastResultEnd, controlParams,
   timeProfilesContainer, timeProfileNodes, resultStatistic, layerResults,
   resultLayerCount, caseFolderName, ascColumns, warnings, errors},

  caseIndex = Replace[parseInteger[xmlAttribute[caseNode, "Index", ""]],
    _Missing -> ordinal];
  caseID = parseInteger[xmlChildText[caseNode, "CaseID", ""]];
  caseName = xmlChildText[caseNode, "Name", "Case " <> ToString[caseIndex]];
  isActive = ToUpperCase[xmlChildText[caseNode, "IsActive", "FALSE"]] === "TRUE";

  component = xmlFirstDirectChild[caseNode, "Component"];
  layersContainer = xmlFirstDirectChild[component, "Layers"];
  layerNodes = If[MissingQ[layersContainer], {},
    xmlDirectChildren[layersContainer, "Layer"]];
  layerCount = Length[layerNodes];
  layersCountAttribute = If[MissingQ[layersContainer],
    Missing["NotAvailable"],
    parseInteger[xmlAttribute[layersContainer, "Count", ""]]
  ];

  preliminaryLayers = MapIndexed[
    Function[{layerNode, indexList},
      Module[{layerIndex, thickness, material, materialName,
        monitorsContainer, monitorNodes, monitorRecords},
        layerIndex = Replace[
          parseInteger[xmlAttribute[layerNode, "Index", ""]],
          _Missing -> First[indexList]
        ];
        thickness = scalarValue[layerNode, "Thickness"];
        material = xmlFirstDirectChild[layerNode, "Material"];
        materialName = If[MissingQ[material], "Unnamed material",
          xmlChildText[material, "Name", "Unnamed material"]];
        monitorsContainer = xmlFirstDirectChild[layerNode, "MonitorPositions"];
        monitorNodes = If[MissingQ[monitorsContainer], {},
          xmlDirectChildren[monitorsContainer, "MonitorPosition"]];
        monitorRecords = MapIndexed[
          Function[{monitorNode, monitorIndexList},
            Module[{monitorIndex, elementText, elementID, requestedDepth,
              realDepth, validElement, validDepth, withinLayer, valid},
              monitorIndex = Replace[
                parseInteger[xmlAttribute[monitorNode, "Index", ""]],
                _Missing -> First[monitorIndexList]
              ];
              elementText = xmlChildText[monitorNode, "ElementID", ""];
              elementID = parseInteger[elementText];
              requestedDepth = scalarValue[monitorNode, "DepthInLayer"];
              realDepth = scalarValue[monitorNode, "RealDepthInLayer"];
              validElement = IntegerQ[elementID];
              validDepth = NumericQ[realDepth];
              withinLayer = NumericQ[realDepth] && NumericQ[thickness] &&
                -10^-9 <= realDepth <= thickness + 10^-9;
              valid = validElement && validDepth && withinLayer;
              <|
                "MonitorIndex" -> monitorIndex,
                "LayerIndex" -> layerIndex,
                "MaterialName" -> materialName,
                "ElementIDText" -> elementText,
                "ElementID" -> elementID,
                "RequestedDepthInLayer" -> requestedDepth,
                "RealDepthInLayer" -> realDepth,
                "Valid" -> valid,
                "StaleReason" -> Which[
                  ! validElement, "ElementIDNotNumeric",
                  ! validDepth, "RealDepthNotNumeric",
                  ! withinLayer, "RealDepthOutsideLayer",
                  True, None
                ]
              |>
            ]
          ],
          monitorNodes
        ];
        <|
          "LayerIndex" -> layerIndex,
          "MaterialName" -> materialName,
          "ThicknessMetres" -> thickness,
          "RawMonitors" -> monitorRecords
        |>
      ]
    ],
    layerNodes
  ];

  thicknesses = Lookup[preliminaryLayers, "ThicknessMetres", {}];
  layerStarts = Most@FoldList[Plus, 0.,
    Replace[thicknesses, _Missing -> 0., {1}]];

  layers = MapThread[
    Function[{layer, start},
      Join[layer, <|
        "StartDepthMetres" -> start,
        "EndDepthMetres" -> If[NumericQ[Lookup[layer, "ThicknessMetres"]],
          start + Lookup[layer, "ThicknessMetres"], Missing["NotAvailable"]]
      |>]
    ],
    {preliminaryLayers, layerStarts}
  ];

  allMonitors = Flatten[Lookup[layers, "RawMonitors", {}], 1];
  allMonitors = Map[
    Function[monitor,
      Module[{layer, globalDepth},
        layer = FirstCase[layers,
          candidate_ /; Lookup[candidate, "LayerIndex"] ===
            Lookup[monitor, "LayerIndex"] :> candidate,
          Missing["NotFound"]];
        globalDepth = If[
          ! MissingQ[layer] && NumericQ[Lookup[monitor, "RealDepthInLayer"]],
          Lookup[layer, "StartDepthMetres"] +
            Lookup[monitor, "RealDepthInLayer"],
          Missing["NotAvailable"]
        ];
        Join[monitor, <|"GlobalDepthMetres" -> globalDepth|>]
      ]
    ],
    allMonitors
  ];

  validMonitors = SortBy[Select[allMonitors, TrueQ[Lookup[#, "Valid"]] &],
    Lookup[#, "GlobalDepthMetres", Infinity] &];
  staleMonitors = Select[allMonitors, ! TrueQ[Lookup[#, "Valid"]] &];

  grafikaCheck = parseGrafikaSensors[caseNode];
  validationStatus = Which[
    ! TrueQ[Lookup[grafikaCheck, "Available"]], "ComponentOnly",
    Lookup[grafikaCheck, "InternalSensorCount"] === Length[validMonitors],
      "ComponentAndGrafikaAgree",
    True, "ComponentGrafikaMismatch"
  ];

  totalSensorCount = Length[validMonitors] + $BoundarySensorCount;

  sensors = Join[
    {<|"Kind" -> "ExteriorSurface", "LayerIndex" -> Missing["Surface"],
       "MaterialName" -> "Exterior Surface", "GlobalDepthMetres" -> 0.|>},
    Map[Join[#, <|"Kind" -> "Internal"|>] &, validMonitors],
    {<|"Kind" -> "InteriorSurface", "LayerIndex" -> Missing["Surface"],
       "MaterialName" -> "Interior Surface",
       "GlobalDepthMetres" -> Total[Replace[thicknesses, _Missing -> 0., {1}]]|>}
  ];

  sensors = MapIndexed[
    Function[{sensor, indexList},
      Module[{sensorIndex, prefix, folderName},
        sensorIndex = First[indexList];
        prefix = indexToken["S", sensorIndex, Length[sensors]];
        folderName = Switch[Lookup[sensor, "Kind"],
          "ExteriorSurface", prefix <> "_Exterior_Surface",
          "InteriorSurface", prefix <> "_Interior_Surface",
          _, prefix <> "_" <>
            indexToken["L", Lookup[sensor, "LayerIndex"], Max[1, layerCount]] <>
            "_" <> shortToken[Lookup[sensor, "MaterialName"], 42] <>
            "_x" <> depthToken[Lookup[sensor, "GlobalDepthMetres"]]
        ];
        Join[sensor, <|
          "SensorIndex" -> sensorIndex,
          "FolderName" -> folderName,
          "TemperatureColumn" -> 2 + 2 (sensorIndex - 1),
          "RelativeHumidityColumn" -> 3 + 2 (sensorIndex - 1)
        |>]
      ]
    ],
    sensors
  ];

  layers = MapIndexed[
    Function[{layer, indexList},
      Module[{layerIndex, token},
        layerIndex = First[indexList];
        token = indexToken["L", layerIndex, Max[1, layerCount]] <> "_" <>
          shortToken[Lookup[layer, "MaterialName"], 64];
        Join[KeyDrop[layer, {"RawMonitors"}], <|
          "WaterContentColumn" -> 2 + 2 totalSensorCount + (layerIndex - 1),
          "PlotFileBase" -> token
        |>]
      ]
    ],
    layers
  ];

  totalWaterColumn = 2 + 2 totalSensorCount + layerCount;
  expectedColumns = totalWaterColumn;

  ascColumns = Join[
    {<|"Column" -> 1, "Type" -> "Timestamp"|>},
    Flatten[Map[
      {
        <|"Column" -> Lookup[#, "TemperatureColumn"],
          "Type" -> "Temperature", "SensorIndex" -> Lookup[#, "SensorIndex"]|>,
        <|"Column" -> Lookup[#, "RelativeHumidityColumn"],
          "Type" -> "RelativeHumidity", "SensorIndex" -> Lookup[#, "SensorIndex"]|>
      } &,
      sensors
    ], 1],
    Map[
      <|"Column" -> Lookup[#, "WaterContentColumn"],
        "Type" -> "LayerWaterContent", "LayerIndex" -> Lookup[#, "LayerIndex"]|> &,
      layers
    ],
    {<|"Column" -> totalWaterColumn, "Type" -> "TotalWaterContent"|>}
  ];

  resultStatistic = xmlFirstDirectChild[caseNode, "ResultStatistic"];
  layerResults = If[MissingQ[resultStatistic], Missing["NotAvailable"],
    xmlFirstDirectChild[resultStatistic, "LayerResults"]];
  resultLayerCount = If[MissingQ[layerResults], Missing["NotAvailable"],
    Length[xmlDirectChildren[layerResults, "LayerResult"]]];

  controlParams = xmlFirstDirectChild[caseNode, "ControlParams"];
  timeProfilesContainer = xmlFirstDirectChild[controlParams, "TimeProfiles"];
  timeProfileNodes = If[MissingQ[timeProfilesContainer], {},
    SortBy[xmlDirectChildren[timeProfilesContainer, "TimeProfile"],
      Replace[parseInteger[xmlAttribute[#, "Index", ""]],
        _Missing -> Infinity] &]
  ];
  calculationStart = If[Length[timeProfileNodes] >= 1,
    parseTimeProfileISO[First[timeProfileNodes]], Missing["NotAvailable"]];
  calculationEnd = If[Length[timeProfileNodes] >= 2,
    parseTimeProfileISO[Last[timeProfileNodes]], Missing["NotAvailable"]];

  lastResultStart = Module[{grafika},
    grafika = xmlFirstDirectChild[caseNode, "Grafika"];
    If[MissingQ[grafika], Missing["NotAvailable"],
      With[{value = xmlChildText[grafika, "StartDateCalc", ""]},
        If[value === "", Missing["NotAvailable"],
          StringReplace[value, " " -> "T"]]]]
  ];
  lastResultEnd = Module[{grafika},
    grafika = xmlFirstDirectChild[caseNode, "Grafika"];
    If[MissingQ[grafika], Missing["NotAvailable"],
      With[{value = xmlChildText[grafika, "EndDateCalc", ""]},
        If[value === "", Missing["NotAvailable"],
          StringReplace[value, " " -> "T"]]]]
  ];

  caseFolderName = indexToken["C", caseIndex, projectCaseCount] <> "_" <>
    shortToken[caseName, 80];

  warnings = DeleteCases[{
      If[IntegerQ[layersCountAttribute] && layersCountAttribute =!= layerCount,
        "Layers Count attribute does not match actual Layer node count.", Nothing],
      If[IntegerQ[resultLayerCount] && resultLayerCount =!= layerCount,
        "ResultStatistic layer count does not match the current Component layer count.", Nothing],
      If[validationStatus === "ComponentGrafikaMismatch",
        "Valid Component monitor count does not match Grafika T/RH position count.", Nothing],
      If[Length[staleMonitors] > 0,
        ToString[Length[staleMonitors]] <> " stale or unresolved monitor record(s) were ignored.", Nothing]
    }, Nothing];

  errors = DeleteCases[{
      If[layerCount <= 0, "No material layers were found.", Nothing],
      If[AnyTrue[thicknesses, MissingQ],
        "At least one layer thickness could not be parsed.", Nothing]
    }, Nothing];

  <|
    "ProjectBaseName" -> projectBase,
    "CaseIndex" -> caseIndex,
    "CaseZeroIndex" -> caseIndex - 1,
    "CaseID" -> caseID,
    "CaseName" -> caseName,
    "IsActive" -> isActive,
    "CaseFolderName" -> caseFolderName,
    "ExpectedASCFileName" -> projectBase <> "_" <> ToString[caseIndex - 1] <> ".asc",
    "LayerCount" -> layerCount,
    "LayersCountAttribute" -> layersCountAttribute,
    "ResultLayerCount" -> resultLayerCount,
    "Layers" -> layers,
    "RawMonitorCount" -> Length[allMonitors],
    "InternalSensorCount" -> Length[validMonitors],
    "StaleMonitorCount" -> Length[staleMonitors],
    "StaleMonitors" -> staleMonitors,
    "TotalSensorCount" -> totalSensorCount,
    "Sensors" -> sensors,
    "GrafikaSensorCheck" -> grafikaCheck,
    "SensorValidationStatus" -> validationStatus,
    "ExpectedASCColumnCount" -> expectedColumns,
    "TotalWaterContentColumn" -> totalWaterColumn,
    "ASCColumns" -> SortBy[ascColumns, Lookup[#, "Column"] &],
    "CalculationStart" -> calculationStart,
    "CalculationEnd" -> calculationEnd,
    "LastResultStart" -> lastResultStart,
    "LastResultEnd" -> lastResultEnd,
    "Warnings" -> warnings,
    "Errors" -> errors
  |>
];

missingProjectRecord[w6pPath_String, xmlPath_String] := Module[{base},
  base = FileBaseName[w6pPath];
  <|
    "ProjectFileName" -> FileNameTake[w6pPath],
    "XMLFileName" -> FileNameTake[xmlPath],
    "ProjectBaseName" -> base,
    "CaseCount" -> 0,
    "HomogeneousExportSchema" -> False,
    "ReadyForBatch" -> False,
    "Errors" -> {"Matching sidecar XML file was not found."},
    "Warnings" -> {},
    "Cases" -> {}
  |>
];

buildProjectRecord[w6pPath_String, xmlPath_String,
   requireGrafikaAgreement_] := Module[
  {xml, caseNodes, casesContainer, caseCountAttribute, projectBase,
   cases, schemaPairs, homogeneous, materialCount, internalSensorCount,
   totalSensorCount, mask, expectedColumns, projectErrors, projectWarnings,
   ready},

  projectBase = FileBaseName[w6pPath];
  xml = Quiet@Check[Import[xmlPath, "XMLObject"], $Failed];
  If[xml === $Failed,
    Return[<|
      "ProjectFileName" -> FileNameTake[w6pPath],
      "XMLFileName" -> FileNameTake[xmlPath],
      "ProjectBaseName" -> projectBase,
      "CaseCount" -> 0,
      "HomogeneousExportSchema" -> False,
      "ReadyForBatch" -> False,
      "Errors" -> {"The sidecar XML file could not be imported."},
      "Warnings" -> {}, "Cases" -> {}|>]
  ];

  caseNodes = Cases[xml, node : XMLElement["Case", _, _] :> node, Infinity];
  caseNodes = SortBy[caseNodes,
    Replace[parseInteger[xmlAttribute[#, "Index", ""]], _Missing -> Infinity] &];
  casesContainer = FirstCase[xml,
    node : XMLElement["Cases", _, _] :> node,
    Missing["NotFound"], Infinity];
  caseCountAttribute = If[MissingQ[casesContainer], Missing["NotAvailable"],
    parseInteger[xmlAttribute[casesContainer, "Count", ""]]];

  cases = MapIndexed[
    parseCase[#1, First[#2], projectBase, Length[caseNodes]] &,
    caseNodes
  ];

  schemaPairs = Lookup[#, {"LayerCount", "InternalSensorCount"}] & /@ cases;
  homogeneous = Length[schemaPairs] > 0 && Length[DeleteDuplicates[schemaPairs]] == 1;
  materialCount = If[homogeneous, Lookup[cases[[1]], "LayerCount"], Missing["Heterogeneous"]];
  internalSensorCount = If[homogeneous,
    Lookup[cases[[1]], "InternalSensorCount"], Missing["Heterogeneous"]];
  totalSensorCount = If[homogeneous,
    Lookup[cases[[1]], "TotalSensorCount"], Missing["Heterogeneous"]];
  mask = If[homogeneous,
    BuildExportMask[materialCount, totalSensorCount], Missing["Heterogeneous"]];
  expectedColumns = If[homogeneous,
    Lookup[cases[[1]], "ExpectedASCColumnCount"], Missing["Heterogeneous"]];

  projectErrors = Flatten@{
    If[caseNodes === {}, "No WUFI cases were found in the XML.", Nothing],
    If[IntegerQ[caseCountAttribute] && caseCountAttribute =!= Length[caseNodes],
      "Cases Count attribute does not match the actual Case node count.", Nothing],
    If[Length[caseNodes] > 0 && ! homogeneous,
      "Cases do not share identical material-domain and valid-sensor counts.", Nothing],
    Flatten[Lookup[cases, "Errors", {}]],
    If[TrueQ[requireGrafikaAgreement] &&
      AnyTrue[Lookup[cases, "SensorValidationStatus", {}],
        # === "ComponentGrafikaMismatch" &],
      "Grafika agreement is required, but at least one case has a sensor-count mismatch.",
      Nothing]
  };

  projectWarnings = Flatten@Lookup[cases, "Warnings", {}];
  ready = projectErrors === {};

  <|
    "ProjectFileName" -> FileNameTake[w6pPath],
    "XMLFileName" -> FileNameTake[xmlPath],
    "ProjectBaseName" -> projectBase,
    "CaseCount" -> Length[cases],
    "CasesCountAttribute" -> caseCountAttribute,
    "HomogeneousExportSchema" -> homogeneous,
    "MaterialCount" -> materialCount,
    "InternalSensorCount" -> internalSensorCount,
    "BoundarySensorCount" -> $BoundarySensorCount,
    "TotalSensorCount" -> totalSensorCount,
    "FixedSkippedSeriesCount" -> $FixedSkippedSeriesCount,
    "ExportMask" -> mask,
    "ExportMaskLength" -> If[StringQ[mask], StringLength[mask], Missing["NotAvailable"]],
    "SelectedSeriesCount" -> If[homogeneous,
      2 totalSensorCount + materialCount + 1, Missing["NotAvailable"]],
    "ExpectedASCColumnCount" -> expectedColumns,
    "ReadyForBatch" -> ready,
    "Warnings" -> DeleteDuplicates[projectWarnings],
    "Errors" -> DeleteDuplicates[projectErrors],
    "Cases" -> cases
  |>
];

BuildWUFIManifest[directory_String, OptionsPattern[]] := Module[
  {resolvedDirectory, w6pFiles, projects, requireGrafikaAgreement},
  resolvedDirectory = ExpandFileName[directory];
  requireGrafikaAgreement = TrueQ[OptionValue["RequireGrafikaAgreement"]];
  w6pFiles = Sort@FileNames["*.w6p", resolvedDirectory];
  projects = Map[
    Function[w6pPath,
      Module[{xmlPath},
        xmlPath = FileNameJoin[{resolvedDirectory,
          FileBaseName[w6pPath] <> ".xml"}];
        If[FileExistsQ[xmlPath],
          buildProjectRecord[w6pPath, xmlPath, requireGrafikaAgreement],
          missingProjectRecord[w6pPath, xmlPath]
        ]
      ]
    ],
    w6pFiles
  ];

  <|
    "ManifestVersion" -> $ManifestVersion,
    "GeneratedAt" -> DateString[Now, "ISODateTime"],
    "ManifestDirectory" -> resolvedDirectory,
    "SupportedProjectExtension" -> ".w6p",
    "ExportPolicy" -> <|
      "TemperatureAtAllValidSensors" -> True,
      "RelativeHumidityAtAllValidSensors" -> True,
      "VapourPressure" -> False,
      "LayerWaterContent" -> True,
      "TotalWaterContent" -> True,
      "FixedSkippedSeriesCount" -> $FixedSkippedSeriesCount,
      "BoundarySensorCount" -> $BoundarySensorCount
    |>,
    "ProjectCount" -> Length[projects],
    "ReadyProjectCount" -> Count[Lookup[projects, "ReadyForBatch", {}], True],
    "Projects" -> projects
  |>
];

jsonSafe[expression_] := expression /. {
  Missing[__] -> Null,
  None -> Null
};

WriteWUFIManifest[manifest_Association, directory_String,
   baseName_String : "WUFI_export_manifest"] := Module[
  {resolvedDirectory, wlPath, jsonPath},
  resolvedDirectory = ExpandFileName[directory];
  If[! DirectoryQ[resolvedDirectory],
    CreateDirectory[resolvedDirectory, CreateIntermediateDirectories -> True]];
  wlPath = FileNameJoin[{resolvedDirectory, baseName <> ".wl"}];
  jsonPath = FileNameJoin[{resolvedDirectory, baseName <> ".json"}];
  Put[manifest, wlPath];
  Export[jsonPath, jsonSafe[manifest], "RawJSON"];
  <|"WolframLanguage" -> wlPath, "JSON" -> jsonPath|>
];

LoadWUFIManifest[path_String] := Get[ExpandFileName[path]];

batQuote[text_String] := "\"" <>
  StringReplace[text, {"%" -> "%%", "\"" -> ""}] <> "\"";

commandToken[text_String] := If[StringContainsQ[text, Whitespace],
  batQuote[text], text];

WriteWUFIBatchFile[manifest_Association, path_String,
   OptionsPattern[]] := Module[
  {projects, readyProjects, command, switches, commandBlocks, lines,
   resolvedPath, pauseAtEnd, projectCount},
  projects = Lookup[manifest, "Projects", {}];
  readyProjects = Select[projects, TrueQ[Lookup[#, "ReadyForBatch"]] &];
  command = OptionValue["WUFICommand"];
  switches = OptionValue["CalculationSwitches"];
  pauseAtEnd = TrueQ[OptionValue["PauseAtEnd"]];
  projectCount = Length[readyProjects];

  commandBlocks = MapIndexed[
    Function[{project, position},
      Module[{projectName, commandLine, progress},
        projectName = Lookup[project, "ProjectFileName"];
        commandLine = commandToken[command] <> " " <> batQuote[projectName] <>
          " " <> switches <> Lookup[project, "ExportMask"];
        progress = "[" <> ToString[First[position]] <> "/" <>
          ToString[projectCount] <> "]";
        {
          "echo " <> progress <> " Running " <> projectName,
          commandLine,
          "if errorlevel 1 (",
          "  echo [ERROR] WUFI failed for " <> projectName,
          "  set \"WUFI_RC=1\"",
          ") else (",
          "  echo [OK]    Completed " <> projectName,
          ")",
          ""
        }
      ]
    ],
    readyProjects
  ];

  lines = Join[
    {
      "@echo off",
      "setlocal EnableExtensions",
      "pushd \"%~dp0\"",
      "if errorlevel 1 (",
      "  echo [ERROR] Could not change to the batch-file directory.",
      If[pauseAtEnd, "  pause", "  rem pause disabled"],
      "  exit /b 1",
      ")",
      "set \"WUFI_RC=0\"",
      ""
    },
    Flatten[commandBlocks, 1],
    {
      "popd",
      "",
      "if not \"%WUFI_RC%\"==\"0\" (",
      "  echo.",
      "  echo One or more WUFI runs failed."
    },
    If[pauseAtEnd, {"  pause"}, {}],
    {
      "  exit /b 1",
      ")",
      "",
      "echo.",
      "echo All WUFI runs completed successfully."
    },
    If[pauseAtEnd, {"pause"}, {}],
    {"exit /b 0"}
  ];

  resolvedPath = ExpandFileName[path];
  (* Join with LF only. On Windows, Export[..., "Text"] writes the native CRLF line ending without introducing a doubled carriage return. *)
  Export[resolvedPath, StringRiffle[lines, "\n"], "Text"];
  resolvedPath
];

ValidateASCRows[rows_List, caseRecord_Association] := Module[
  {rowWidths, consistentWidth, actualWidth, expectedWidth, numericData,
   numericColumnsQ, issues},
  rowWidths = Length /@ rows;
  consistentWidth = rowWidths =!= {} && SameQ @@ rowWidths;
  actualWidth = If[consistentWidth, First[rowWidths], Missing["Inconsistent"]];
  expectedWidth = Lookup[caseRecord, "ExpectedASCColumnCount",
    Missing["NotAvailable"]];
  numericData = If[consistentWidth && IntegerQ[actualWidth] && actualWidth >= 2,
    rows[[All, 2 ;;]], {}];
  numericColumnsQ = numericData =!= {} && MatrixQ[numericData, NumericQ];
  issues = DeleteCases[{
      If[rows === {}, "ASC import returned no rows.", Nothing],
      If[! consistentWidth, "ASC rows do not all have the same column count.", Nothing],
      If[consistentWidth && IntegerQ[expectedWidth] && actualWidth =!= expectedWidth,
        "ASC column count does not match the manifest.", Nothing],
      If[consistentWidth && ! numericColumnsQ,
        "At least one non-timestamp ASC value is not numeric.", Nothing]
    }, Nothing];
  <|
    "Valid" -> (issues === {}),
    "RowCount" -> Length[rows],
    "ActualColumnCount" -> actualWidth,
    "ExpectedColumnCount" -> expectedWidth,
    "Issues" -> issues
  |>
];

End[];
EndPackage[];
