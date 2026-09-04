(* ::Package:: *)

(*
  Production v1.2.0 driver for the automated sensor-only and WUFI-versus-sensor analysis.
  Target platform: Wolfram Mathematica 12.1.
*)

$HistoryLength = 0;

sensorComparisonCodeRoot = If[
  StringQ[$InputFileName] && StringLength[$InputFileName] > 0,
  DirectoryName@ExpandFileName@$InputFileName,
  Quiet@Check[NotebookDirectory[], Directory[]]
];

Get@FileNameJoin[{
  sensorComparisonCodeRoot,
  "HygrothermalPlottingUtilities_v1_2.wl"
}];

Get@FileNameJoin[{
  sensorComparisonCodeRoot,
  "SensorDataUtilities_v1_2.wl"
}];

Get@FileNameJoin[{
  sensorComparisonCodeRoot,
  "SensorComparisonConfig_v1_2.wl"
}];

sensorComparisonSettings = Join[
  DefaultSensorComparisonSettings[],
  sensorComparisonUserSettings
];

(*
  The driver intentionally does not launch kernels or start calculations.
  Evaluate the preflight and run cells explicitly from the companion notebook.
*)
