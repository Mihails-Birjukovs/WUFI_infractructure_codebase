(* ::Package:: *)

BeginPackage["HygrothermalPlottingUtilities`"];

$HygrothermalPlottingUtilitiesVersion::usage =
  "$HygrothermalPlottingUtilitiesVersion gives the production package version.";
LoadLIMCurves::usage =
  "LoadLIMCurves[directory] imports LIM 0.csv, LIM I.csv, and LIM II.csv and returns an Association.";
SaturationPressureFactorC::usage =
  "SaturationPressureFactorC[t] gives the relative saturation-pressure factor used by the production post-processor dew-point formulation.";
DewPointC::usage =
  "DewPointC[t,rh] returns dew-point temperature in degrees Celsius for temperature t and RH in percent.";
SeriesPairs::usage =
  "SeriesPairs[series] returns valid {date,value} pairs from a TimeSeries or pair list.";
AlignTemperatureRH::usage =
  "AlignTemperatureRH[tempSeries,rhSeries] returns common {date,temperature,RH} rows without interpolation.";
MakeTemperaturePlot::usage =
  "MakeTemperaturePlot[seriesAssociation] creates a production-style date plot for temperature series.";
MakeHumidityPlot::usage =
  "MakeHumidityPlot[seriesAssociation] creates a production-style date plot for RH series.";
MakeDewPointPlot::usage =
  "MakeDewPointPlot[tempSeries,rhSeries] plots temperature and derived dew point using production styling.";
MakeMouldHistoryPlot::usage =
  "MakeMouldHistoryPlot[tempSeries,rhSeries,limCurves] creates a time-coloured T-RH history plot using the production BlueGreenYellow palette.";
MakeMouldRiskPlot::usage =
  "MakeMouldRiskPlot[tempSeries,rhSeries,limCurves] creates a production-style T-RH density plot using GrayYellowTones.";
MakeComparisonOverlayPlot::usage =
  "MakeComparisonOverlayPlot[sensorSeries,modelSeries] overlays experimental and WUFI series using production-compatible styling.";
MakeResidualPlot::usage =
  "MakeResidualPlot[residualSeries] plots WUFI minus sensor residuals using production-compatible styling.";
MakeMeasuredVsModelledPlot::usage =
  "MakeMeasuredVsModelledPlot[sensorValues,modelValues] creates a measured-versus-modelled scatter plot with a 1:1 line.";
GraphicFileAudit::usage =
  "GraphicFileAudit[path,settings] validates that a raster graphic can be imported and meets configured byte-count and dimension thresholds.";
ExportGraphicChecked::usage =
  "ExportGraphicChecked[path,graphic,resolution,settings] exports through a short staging path, validates dimensions and byte count, copies to the final path, and validates the committed graphic.";
ExportWXFChecked::usage =
  "ExportWXFChecked[path,expression] exports WXF and validates the result.";
SanitizeFileComponent::usage =
  "SanitizeFileComponent[text] creates a deterministic filesystem-safe component name.";
PathLengthAudit::usage =
  "PathLengthAudit[path] returns the expanded path length and platform limit used by checked exports.";

Begin["`Private`"];

$HygrothermalPlottingUtilitiesVersion = "Production-1.2.0-2026-08-05";

ClearAll[
  LoadLIMCurves, SaturationPressureFactorC, DewPointC, SeriesPairs,
  AlignTemperatureRH, MakeTemperaturePlot, MakeHumidityPlot,
  MakeDewPointPlot, MakeMouldHistoryPlot, MakeMouldRiskPlot,
  MakeComparisonOverlayPlot, MakeResidualPlot,
  MakeMeasuredVsModelledPlot, GraphicFileAudit, ExportGraphicChecked,
  ExportWXFChecked, SanitizeFileComponent, PathLengthAudit,
  graphicValidationThresholds, graphicTemporaryPath, graphicExportFormat,
  validNumericPairQ, dateKey, dateFormat,
  alignedRows, emptyGraphic, getFilteredSeries, productionDatePlot,
  historyPlotRange, riskPlotRange, productionDateOptions,
  temperatureLabel, historyColorPalette, riskColorPalette,
  plotLegendLIMHistory, plotLegendLIMRisk, dashStyle
];

fontSizeDateSeries = 16;
fontSizeMouldPlots = 16;
imageSizeSeries = 500;
imageSizeMould = 500;
imageSizeRisk = 500;
legendSizeMould = 0.6 * imageSizeMould;
legendSizeRisk = 0.85 * imageSizeRisk;
timeFormat = {"MonthShort", "/", "YearShort"};
windowSize = 0.0025;
pointCullingFactor = 1;
historyColorPalette = "BlueGreenYellow";
riskColorPalette = "GrayYellowTones";
degreeSymbol = FromCharacterCode@176;
temperatureLabel = Row@{"T, ", degreeSymbol, "C"};
plotStyleDefault = {Black, Orange};
plotStyleDew = {{Orange, Darker@Red}, {Gray, Black}};
plotLegendLIMHistory = SwatchLegend[
  {Gray, Blue, Red},
  {"LIM 0", "LIM I", "LIM II"}
];
plotLegendLIMRisk = SwatchLegend[
  {Green, Blue, Red},
  {"LIM 0", "LIM I", "LIM II"}
];
dashSpacing = 0.02;
dash = Dashing@{dashSpacing, dashSpacing};
dashStyle = {{Green, dash}, {Blue, dash}, {Red, dash}};

validNumericPairQ[pair_] := MatchQ[pair, {_, _?NumericQ}];

dateKey[date_] := Quiet@Check[N@AbsoluteTime[date], Missing["InvalidDate"]];

SeriesPairs[series_] := Module[{path},
  path = Quiet@Check[series["Path"], $Failed];
  If[!ListQ[path], path = series];
  If[!ListQ[path], Return[{}]];
  Select[path, validNumericPairQ]
];

alignedRows[tempSeries_, rhSeries_] := Module[
  {tempPairs, rhPairs, tempAssociation, rhAssociation, commonKeys},
  tempPairs = SeriesPairs@tempSeries;
  rhPairs = SeriesPairs@rhSeries;
  tempAssociation = Association@Map[
    (dateKey[First@#] -> {First@#, Last@#}) &,
    tempPairs
  ];
  rhAssociation = Association@Map[
    (dateKey[First@#] -> {First@#, Last@#}) &,
    rhPairs
  ];
  commonKeys = Sort@Intersection[Keys@tempAssociation, Keys@rhAssociation];
  Map[
    Function[key,
      {
        First@Lookup[tempAssociation, key],
        Last@Lookup[tempAssociation, key],
        Last@Lookup[rhAssociation, key]
      }
    ],
    commonKeys
  ]
];

AlignTemperatureRH[tempSeries_, rhSeries_] := alignedRows[tempSeries, rhSeries];

SaturationPressureFactorC[temperature_?NumericQ] :=
  Exp[(18.678 - temperature/234.5) * (temperature/(257.14 + temperature))];

DewPointC[temperature_?NumericQ, relativeHumidity_?NumericQ] := Module[{gamma},
  If[relativeHumidity <= 0, Return[Indeterminate]];
  gamma = Log[(relativeHumidity/100.) * SaturationPressureFactorC[temperature]];
  257.14 * gamma/(18.678 - gamma)
];

LoadLIMCurves[directory_String] := Module[
  {expanded, names, paths, imported, invalid},
  expanded = ExpandFileName@directory;
  If[!DirectoryQ[expanded],
    Return@Failure["LIMDirectoryMissing", <|"Directory" -> expanded|>]
  ];
  names = {"LIM 0", "LIM I", "LIM II"};
  paths = FileNameJoin[{expanded, # <> ".csv"}] & /@ names;
  invalid = Select[paths, !FileExistsQ[#] &];
  If[invalid =!= {},
    Return@Failure["LIMFilesMissing", <|"MissingFiles" -> invalid|>]
  ];
  imported = AssociationThread[
    names,
    (Cases[
      Quiet@Check[Import[#, "CSV"], {}],
      {_?NumericQ, _?NumericQ}
    ] &) /@ paths
  ];
  invalid = Select[names, Length@Lookup[imported, #, {}] < 2 &];
  If[invalid =!= {},
    Return@Failure["LIMCurveInvalid", <|"InvalidCurves" -> invalid|>]
  ];
  imported
];

SanitizeFileComponent[text_] := Module[{value},
  value = If[StringQ[text], text, ToString[text, InputForm]];
  value = StringReplace[
    value,
    {
      WhitespaceCharacter .. -> "_",
      ("\\" | "/" | ":" | "*" | "?" | "\"" | "<" | ">" | "|") -> "_",
      ";" -> "_",
      RegularExpression["_+"] -> "_"
    }
  ];
  StringTrim[value, "_."]
];

PathLengthAudit[path_String] := Module[{expanded, length, hardLimit},
  expanded = ExpandFileName@path;
  length = StringLength@expanded;
  hardLimit = If[$OperatingSystem === "Windows", 259, 4095];
  <|
    "Path" -> expanded,
    "PathLengthCharacters" -> length,
    "OperatingSystem" -> $OperatingSystem,
    "HardLimitCharacters" -> hardLimit,
    "WithinHardLimit" -> TrueQ[length <= hardLimit]
  |>
];

dateFormat[date_] := DateString[date, {"Day", "/", "Month", "/", "Year"}];

emptyGraphic[text_String] := Graphics[
  {Inset@Style[text, Black, Bold, fontSizeDateSeries]},
  Frame -> True,
  FrameStyle -> Directive[Black, Bold],
  FrameTicksStyle -> Directive[Black, Bold],
  PlotRange -> {{0, 1}, {0, 1}},
  ImageSize -> imageSizeSeries,
  Background -> White
];

getFilteredSeries[timeSeries_List] := Module[{radius, transposed},
  If[Length@timeSeries < 2, Return@timeSeries];
  radius = Max[1, Round[windowSize * Length@timeSeries]];
  transposed = Transpose@timeSeries;
  Transpose@{First@transposed, MeanFilter[Last@transposed, radius]}
];

productionDateOptions[label_, imageSize_] := Sequence[
  ImageSize -> imageSize,
  Background -> White,
  FrameLabel -> label,
  LabelStyle -> Directive[Black, Bold, fontSizeDateSeries],
  GridLines -> Automatic,
  Frame -> True,
  FrameStyle -> Directive[Black, Bold],
  FrameTicksStyle -> Directive[Black, Bold],
  DateTicksFormat -> timeFormat
];

productionDatePlot[timeSeries_List, label_, style_List, legends_:None,
  plotRange_:All] := Show[
  {
    DateListPlot[
      timeSeries,
      Joined -> False,
      PlotStyle -> First@style
    ],
    DateListPlot[
      getFilteredSeries@timeSeries,
      Joined -> True,
      PlotStyle -> Last@style,
      PlotLegends -> legends
    ]
  },
  productionDateOptions[label, imageSizeSeries],
  PlotRange -> plotRange
];

Options[MakeTemperaturePlot] = {
  PlotLabel -> None,
  ImageSize -> imageSizeSeries,
  PlotRange -> All
};

MakeTemperaturePlot[seriesAssociation_Association, OptionsPattern[]] := Module[
  {datasets, dataset, graphic},
  datasets = Select[SeriesPairs /@ Values@seriesAssociation, # =!= {} &];
  If[datasets === {}, Return@emptyGraphic["No valid temperature data"]];
  dataset = First@datasets;
  graphic = productionDatePlot[
    dataset,
    {"Date", temperatureLabel},
    plotStyleDefault,
    None,
    OptionValue[PlotRange]
  ];
  Show[
    graphic,
    ImageSize -> OptionValue[ImageSize],
    PlotLabel -> OptionValue[PlotLabel]
  ]
];

Options[MakeHumidityPlot] = Options[MakeTemperaturePlot];

MakeHumidityPlot[seriesAssociation_Association, OptionsPattern[]] := Module[
  {datasets, dataset, graphic},
  datasets = Select[SeriesPairs /@ Values@seriesAssociation, # =!= {} &];
  If[datasets === {}, Return@emptyGraphic["No valid RH data"]];
  dataset = First@datasets;
  graphic = productionDatePlot[
    dataset,
    {"Date", "RH, %"},
    plotStyleDefault,
    None,
    OptionValue[PlotRange]
  ];
  Show[
    graphic,
    ImageSize -> OptionValue[ImageSize],
    PlotLabel -> OptionValue[PlotLabel]
  ]
];

Options[MakeDewPointPlot] = Options[MakeTemperaturePlot];

MakeDewPointPlot[tempSeries_, rhSeries_, OptionsPattern[]] := Module[
  {rows, temperaturePairs, dewPairs, legend, graphic},
  rows = alignedRows[tempSeries, rhSeries];
  If[rows === {}, Return@emptyGraphic["No paired temperature/RH data"]];
  temperaturePairs = rows[[All, {1, 2}]];
  dewPairs = Cases[
    ({#[[1]], DewPointC[#[[2]], #[[3]]]} &) /@ rows,
    {_, _?NumericQ}
  ];
  legend = Placed[
    SwatchLegend[
      Flatten[Last /@ plotStyleDew],
      {"Temperature", "Dew Point"}
    ],
    Top
  ];
  graphic = Show[
    {
      productionDatePlot[
        temperaturePairs,
        {"Date", temperatureLabel},
        First@plotStyleDew,
        None,
        OptionValue[PlotRange]
      ],
      productionDatePlot[
        dewPairs,
        {"Date", temperatureLabel},
        Last@plotStyleDew,
        legend,
        OptionValue[PlotRange]
      ]
    },
    productionDateOptions[{"Date", temperatureLabel}, imageSizeSeries],
    PlotRange -> OptionValue[PlotRange]
  ];
  Show[
    graphic,
    ImageSize -> OptionValue[ImageSize],
    PlotLabel -> OptionValue[PlotLabel]
  ]
];

historyPlotRange[dataset_List] := Module[
  {transposed, temperatures, humidity},
  transposed = Transpose@dataset;
  temperatures = First@transposed;
  humidity = Last@transposed;
  {
    {
      If[Min@temperatures > 0, Min@temperatures, 0],
      If[Max@temperatures < 40, Max@temperatures, 40]
    },
    MinMax@humidity
  }
];

riskPlotRange[dataset_List] := Module[
  {transposed, temperatures, humidity},
  transposed = Transpose@dataset;
  temperatures = First@transposed;
  humidity = Last@transposed;
  {
    {
      If[Min@temperatures > 0, Min@temperatures, 0],
      If[Max@temperatures < 40, Max@temperatures, 40]
    },
    {
      If[Min@humidity > 40, Min@humidity, 40],
      Max@humidity
    }
  }
];

Options[MakeMouldHistoryPlot] = {
  PlotLabel -> Automatic,
  ImageSize -> imageSizeMould
};

MakeMouldHistoryPlot[tempSeries_, rhSeries_, limCurves_Association,
  OptionsPattern[]] := Module[
  {
    rows, mouldSeries, dates, startDate, endDate, monthSpan,
    colorGrading, colorTable, dateLegend, label, curves
  },
  rows = alignedRows[tempSeries, rhSeries];
  If[Length@rows < 2,
    Return@emptyGraphic["Insufficient paired data for mould history"]
  ];
  dates = rows[[All, 1]];
  mouldSeries = rows[[All, {2, 3}]];
  startDate = First@dates;
  endDate = Last@dates;
  monthSpan = Quiet@Check[
    QuantityMagnitude@DateDifference[startDate, endDate, "Month"],
    0
  ];
  colorGrading = If[
    Length@dates > 1,
    Subdivide[0., 1., Length@dates - 1],
    {0.}
  ];
  colorTable = (Blend[historyColorPalette, #] &) /@ colorGrading;
  dateLegend = BarLegend[
    {historyColorPalette, {0, monthSpan}},
    LegendMarkerSize -> legendSizeMould,
    LegendLabel -> "Months"
  ];
  label = Replace[
    OptionValue[PlotLabel],
    Automatic :> dateFormat@startDate <> " - " <> dateFormat@endDate
  ];
  curves = Values@limCurves;
  Show[
    {
      ListPlot[
        Table[
          Style[mouldSeries[[k]], colorTable[[k]]],
          {k, 1, Length@mouldSeries, Max[1, pointCullingFactor]}
        ],
        PlotLegends -> dateLegend,
        PlotStyle -> {PointSize@Medium, Opacity@0.8},
        LabelStyle -> Directive[Black, Bold, fontSizeMouldPlots],
        GridLines -> Automatic,
        Background -> None,
        ColorFunctionScaling -> True,
        Frame -> True,
        FrameStyle -> Directive[Black, Bold],
        FrameTicksStyle -> Directive[Black, Bold]
      ],
      ListLinePlot[
        curves,
        InterpolationOrder -> 2,
        PlotStyle -> {Gray, Blue, Red},
        PlotLegends -> plotLegendLIMHistory
      ]
    },
    PlotRange -> historyPlotRange@mouldSeries,
    PlotLabel -> label,
    FrameLabel -> {temperatureLabel, "RH, %"},
    LabelStyle -> Directive[Black, Bold, fontSizeMouldPlots],
    FrameStyle -> Directive[Black, Bold],
    FrameTicksStyle -> Directive[Black, Bold],
    GridLines -> Automatic,
    Background -> White,
    ImageSize -> OptionValue[ImageSize]
  ]
];

Options[MakeMouldRiskPlot] = {
  PlotLabel -> Automatic,
  ImageSize -> imageSizeRisk
};

MakeMouldRiskPlot[tempSeries_, rhSeries_, limCurves_Association,
  OptionsPattern[]] := Module[
  {rows, mouldSeries, startDate, endDate, label, curves},
  rows = alignedRows[tempSeries, rhSeries];
  If[Length@rows < 10,
    Return@emptyGraphic["Insufficient paired data for mould density"]
  ];
  mouldSeries = rows[[All, {2, 3}]];
  startDate = First@rows[[All, 1]];
  endDate = Last@rows[[All, 1]];
  label = Replace[
    OptionValue[PlotLabel],
    Automatic :> dateFormat@startDate <> " - " <> dateFormat@endDate
  ];
  curves = Values@limCurves;
  Show[
    {
      SmoothDensityHistogram[
        mouldSeries,
        PlotRange -> riskPlotRange@mouldSeries,
        PlotLegends -> BarLegend[
          riskColorPalette,
          LegendMarkerSize -> legendSizeRisk
        ],
        ColorFunction -> riskColorPalette,
        PlotLabel -> label,
        MeshStyle -> White,
        MaxRecursion -> 5,
        PerformanceGoal -> "Quality",
        Mesh -> 5,
        GridLines -> Automatic,
        LabelStyle -> Directive[Black, Bold, fontSizeMouldPlots],
        FrameLabel -> {temperatureLabel, "RH, %"},
        PlotPoints -> 150,
        Frame -> True,
        FrameStyle -> Directive[Black, Bold],
        FrameTicksStyle -> Directive[Black, Bold]
      ],
      ListLinePlot[
        curves,
        InterpolationOrder -> 1,
        PlotStyle -> dashStyle,
        PlotLegends -> plotLegendLIMRisk
      ]
    },
    ImageSize -> OptionValue[ImageSize],
    LabelStyle -> Directive[Black, Bold, fontSizeMouldPlots],
    FrameStyle -> Directive[Black, Bold],
    FrameTicksStyle -> Directive[Black, Bold],
    Background -> White
  ]
];

Options[MakeComparisonOverlayPlot] = {
  PlotLabel -> None,
  ImageSize -> imageSizeSeries,
  PlotRange -> All,
  FrameLabel -> {"Date", "Value"}
};

MakeComparisonOverlayPlot[
  sensorSeries_, modelSeries_, sensorLower_:None, sensorUpper_:None,
  OptionsPattern[]
] := Module[
  {sensorPairs, modelPairs, envelope, sensorPlot, modelPlot, legend},
  sensorPairs = SeriesPairs@sensorSeries;
  modelPairs = SeriesPairs@modelSeries;
  If[sensorPairs === {} || modelPairs === {},
    Return@emptyGraphic["No paired comparison data"]
  ];
  legend = Placed[
    SwatchLegend[{Black, Orange}, {"Sensor", "WUFI"}],
    Top
  ];
  envelope = If[
    sensorLower === None || sensorUpper === None,
    Graphics[{}],
    DateListPlot[
      {SeriesPairs@sensorUpper, SeriesPairs@sensorLower},
      PlotStyle -> {Directive[Opacity@0], Directive[Opacity@0]},
      Filling -> {1 -> {2}},
      FillingStyle -> Directive[Gray, Opacity@0.18],
      PlotRange -> OptionValue[PlotRange]
    ]
  ];
  sensorPlot = DateListPlot[
    sensorPairs,
    Joined -> False,
    PlotStyle -> Directive[Black, PointSize@Small, Opacity@0.8]
  ];
  modelPlot = DateListPlot[
    modelPairs,
    Joined -> True,
    PlotStyle -> Directive[Orange, Thick],
    PlotLegends -> legend
  ];
  Show[
    {envelope, sensorPlot, modelPlot},
    productionDateOptions[OptionValue[FrameLabel], OptionValue[ImageSize]],
    PlotLabel -> OptionValue[PlotLabel],
    PlotRange -> OptionValue[PlotRange]
  ]
];

Options[MakeResidualPlot] = Options[MakeComparisonOverlayPlot];

MakeResidualPlot[residualSeries_, OptionsPattern[]] := Module[
  {pairs, zeroLine},
  pairs = SeriesPairs@residualSeries;
  If[pairs === {}, Return@emptyGraphic["No valid residual data"]];
  zeroLine = DateListPlot[
    {{First@First@pairs, 0}, {First@Last@pairs, 0}},
    Joined -> True,
    PlotStyle -> Directive[Red, Dashed]
  ];
  Show[
    {
      DateListPlot[
        pairs,
        Joined -> False,
        PlotStyle -> Black
      ],
      DateListPlot[
        getFilteredSeries@pairs,
        Joined -> True,
        PlotStyle -> Orange
      ],
      zeroLine
    },
    productionDateOptions[OptionValue[FrameLabel], OptionValue[ImageSize]],
    PlotLabel -> OptionValue[PlotLabel],
    PlotRange -> OptionValue[PlotRange]
  ]
];

Options[MakeMeasuredVsModelledPlot] = {
  PlotLabel -> None,
  ImageSize -> imageSizeSeries,
  FrameLabel -> {"Measured", "Modelled"}
};

MakeMeasuredVsModelledPlot[sensorValues_List, modelValues_List,
  OptionsPattern[]] := Module[
  {pairs, bounds, scatter, oneToOne},
  pairs = Select[
    Transpose@{sensorValues, modelValues},
    MatchQ[#, {_?NumericQ, _?NumericQ}] &
  ];
  If[Length@pairs < 2,
    Return@emptyGraphic["Insufficient paired values"]
  ];
  bounds = MinMax@Flatten@pairs;
  scatter = ListPlot[
    pairs,
    Frame -> True,
    FrameStyle -> Directive[Black, Bold],
    FrameTicksStyle -> Directive[Black, Bold],
    FrameLabel -> OptionValue[FrameLabel],
    PlotStyle -> Directive[Black, PointSize@Small, Opacity@0.55],
    PlotLabel -> OptionValue[PlotLabel],
    PlotRange -> {bounds, bounds},
    ImageSize -> OptionValue[ImageSize],
    GridLines -> Automatic,
    LabelStyle -> Directive[Black, Bold, fontSizeDateSeries],
    Background -> White
  ];
  oneToOne = Plot[
    x,
    {x, First@bounds, Last@bounds},
    PlotStyle -> Directive[Orange, Thick]
  ];
  Show[scatter, oneToOne]
];

graphicValidationThresholds[settings_Association] := <|
  "MinimumWidthPixels" -> Max[
    1,
    Round@Lookup[settings, "GraphicMinimumWidthPixels", 200]
  ],
  "MinimumHeightPixels" -> Max[
    1,
    Round@Lookup[settings, "GraphicMinimumHeightPixels", 200]
  ],
  "MinimumByteCount" -> Max[
    1,
    Round@Lookup[settings, "GraphicMinimumByteCount", 4096]
  ]
|>;
graphicValidationThresholds[_] := graphicValidationThresholds@<||>;

graphicTemporaryPath[
  path_String,
  settings_Association:<||>
] := Module[
  {directory, configured, extension, token},
  configured = Lookup[
    settings,
    "GraphicStagingDirectory",
    Automatic
  ];
  directory = Which[
    StringQ@configured && StringLength@configured > 0,
      ExpandFileName@configured,
    True,
      FileNameJoin@{
        $TemporaryDirectory,
        "WUFIComparisonGraphics"
      }
  ];
  Quiet@CreateDirectory[
    directory,
    CreateIntermediateDirectories -> True
  ];
  extension = FileExtension@path;
  token = StringReplace[CreateUUID[], "-" -> ""];
  FileNameJoin@{
    directory,
    "wufi-graphic-" <> token <>
      If[StringLength@extension > 0, "." <> extension, ""]
  }
];

graphicExportFormat[path_String] := Switch[
  ToLowerCase@FileExtension@path,
  "jpg" | "jpeg", "JPEG",
  "png", "PNG",
  "tif" | "tiff", "TIFF",
  "bmp", "BMP",
  _, Automatic
];

GraphicFileAudit[
  path_String,
  settings_Association:<||>
] := Module[
  {
    expanded, thresholds, existsQ, bytes, image,
    dimensions, width, height, importQ, validQ
  },
  expanded = ExpandFileName@path;
  thresholds = graphicValidationThresholds@settings;
  existsQ = FileExistsQ@expanded;
  bytes = If[
    existsQ,
    Quiet@Check[FileByteCount@expanded, 0],
    0
  ];
  image = If[
    existsQ,
    Quiet@Check[Import@expanded, $Failed],
    $Failed
  ];
  importQ = ImageQ@image;
  dimensions = If[
    importQ,
    Quiet@Check[ImageDimensions@image, {0, 0}],
    {0, 0}
  ];
  {width, height} = If[
    MatchQ[dimensions, {_Integer, _Integer}],
    dimensions,
    {0, 0}
  ];
  validQ = TrueQ@existsQ &&
    TrueQ@importQ &&
    IntegerQ@bytes &&
    bytes >= Lookup[thresholds, "MinimumByteCount"] &&
    width >= Lookup[thresholds, "MinimumWidthPixels"] &&
    height >= Lookup[thresholds, "MinimumHeightPixels"];
  <|
    "Path" -> expanded,
    "ExistsQ" -> existsQ,
    "ImportSucceededQ" -> importQ,
    "ImageDimensionsPixels" -> {width, height},
    "WidthPixels" -> width,
    "HeightPixels" -> height,
    "ByteCount" -> bytes,
    "Thresholds" -> thresholds,
    "ValidQ" -> validQ
  |>
];

ExportGraphicChecked[
  path_String,
  graphic_,
  resolution_:500
] := ExportGraphicChecked[path, graphic, resolution, <||>];

ExportGraphicChecked[
  path_String,
  graphic_,
  resolution_,
  settings_Association
] := Module[
  {
    expanded, pathAudit, temporary, temporaryPathAudit, format, result,
    temporaryAudit, commitResult, finalAudit
  },
  expanded = ExpandFileName@path;
  pathAudit = PathLengthAudit@expanded;
  If[
    !TrueQ@Lookup[pathAudit, "WithinHardLimit", False],
    Return@Failure["PathTooLong", pathAudit]
  ];
  Quiet@CreateDirectory[
    DirectoryName@expanded,
    CreateIntermediateDirectories -> True
  ];
  temporary = graphicTemporaryPath[expanded, settings];
  temporaryPathAudit = PathLengthAudit@temporary;
  If[
    !TrueQ@Lookup[
      temporaryPathAudit,
      "WithinHardLimit",
      False
    ],
    Return@Failure[
      "GraphicStagingPathTooLong",
      <|
        "Path" -> expanded,
        "TemporaryPath" -> temporary,
        "TemporaryPathAudit" -> temporaryPathAudit
      |>
    ]
  ];
  format = graphicExportFormat@expanded;
  result = Quiet@Check[
    If[
      format === Automatic,
      Export[
        temporary,
        graphic,
        ImageResolution -> resolution
      ],
      Export[
        temporary,
        graphic,
        format,
        ImageResolution -> resolution
      ]
    ],
    $Failed
  ];
  If[result === $Failed || !FileExistsQ@temporary,
    Quiet@Check[
      If[FileExistsQ@temporary, DeleteFile@temporary],
      Null
    ];
    Return@Failure[
      "GraphicExportFailed",
      <|"Path" -> expanded, "TemporaryPath" -> temporary|>
    ]
  ];
  temporaryAudit = GraphicFileAudit[temporary, settings];
  If[!TrueQ@Lookup[temporaryAudit, "ValidQ", False],
    Quiet@Check[DeleteFile@temporary, Null];
    Return@Failure[
      "GraphicExportMalformed",
      <|
        "Path" -> expanded,
        "TemporaryPath" -> temporary,
        "Validation" -> temporaryAudit
      |>
    ]
  ];
  Quiet@Check[
    If[FileExistsQ@expanded, DeleteFile@expanded],
    Null
  ];
  commitResult = Quiet@Check[
    CopyFile[temporary, expanded],
    $Failed
  ];
  If[commitResult === $Failed || !FileExistsQ@expanded,
    Quiet@Check[
      If[FileExistsQ@temporary, DeleteFile@temporary],
      Null
    ];
    Quiet@Check[
      If[FileExistsQ@expanded, DeleteFile@expanded],
      Null
    ];
    Return@Failure[
      "GraphicCommitFailed",
      <|"Path" -> expanded, "TemporaryPath" -> temporary|>
    ]
  ];
  finalAudit = GraphicFileAudit[expanded, settings];
  Quiet@Check[
    If[FileExistsQ@temporary, DeleteFile@temporary],
    Null
  ];
  If[!TrueQ@Lookup[finalAudit, "ValidQ", False],
    Quiet@Check[
      If[FileExistsQ@expanded, DeleteFile@expanded],
      Null
    ];
    Return@Failure[
      "GraphicCommitValidationFailed",
      <|"Path" -> expanded, "Validation" -> finalAudit|>
    ]
  ];
  <|
    "Status" -> "Exported",
    "Path" -> expanded,
    "ByteCount" -> Lookup[finalAudit, "ByteCount"],
    "ImageDimensionsPixels" ->
      Lookup[finalAudit, "ImageDimensionsPixels"],
    "Validation" -> finalAudit
  |>
];

ExportWXFChecked[path_String, expression_] := Module[
  {expanded, pathAudit, result, bytes},
  expanded = ExpandFileName@path;
  pathAudit = PathLengthAudit@expanded;
  If[!TrueQ@Lookup[pathAudit, "WithinHardLimit", False],
    Return@Failure["PathTooLong", pathAudit]
  ];
  Quiet@CreateDirectory[
    DirectoryName@expanded,
    CreateIntermediateDirectories -> True
  ];
  result = Quiet@Check[Export[expanded, expression, "WXF"], $Failed];
  If[result === $Failed || !FileExistsQ[expanded],
    Return@Failure["WXFExportFailed", <|"Path" -> expanded|>]
  ];
  bytes = Quiet@Check[FileByteCount@expanded, 0];
  If[!IntegerQ[bytes] || bytes <= 0,
    Return@Failure[
      "WXFExportEmpty",
      <|"Path" -> expanded, "ByteCount" -> bytes|>
    ]
  ];
  <|"Status" -> "Exported", "Path" -> expanded, "ByteCount" -> bytes|>
];

End[];
EndPackage[];
