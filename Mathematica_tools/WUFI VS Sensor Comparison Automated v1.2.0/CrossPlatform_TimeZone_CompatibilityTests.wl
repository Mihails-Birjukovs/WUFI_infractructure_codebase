(* Supplementary cross-platform regression, not part of historical v1.2.0 production test count. *)
(* Execute in a NEW kernel, from this folder, on both Mathematica 12.1/Windows
   and Wolfram 15/Linux. Do not promote a production patch from cloud alone. *)
testRoot = If[StringQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], NotebookDirectory[]];
Get[FileNameJoin[{testRoot, "HygrothermalPlottingUtilities_v1_2.wl"}]];
Get[FileNameJoin[{testRoot, "SensorDataUtilities_v1_2.wl"}]];

utcWallClockString[originTimeZone_] := Module[{d, converted},
  d = DateObject[{2025, 11, 26, 18, 0, 0}, TimeZone -> originTimeZone];
  converted = SensorDataUtilities`Private`forceWallClockToUTC[d, 2];
  DateString[converted, {"ISODate", "T", "Time", "Z"}]
];

tzCompatibilityReport = TestReport[{
  VerificationTest[utcWallClockString[3], "2025-11-26T16:00:00Z",
    TestID -> "Original +3 labelled wall-clock fields are not converted through host zone"],
  VerificationTest[utcWallClockString[0], "2025-11-26T16:00:00Z",
    TestID -> "Original UTC-labelled wall-clock fields are reinterpreted with fixed +2"],
  VerificationTest[utcWallClockString[-5], "2025-11-26T16:00:00Z",
    TestID -> "Original -5 labelled wall-clock fields remain 18:00 local before fixed +2"],
  VerificationTest[
    Block[{$TimeZone = -5.}, utcWallClockString[3]],
    "2025-11-26T16:00:00Z",
    TestID -> "Wolfram kernel host timezone -5 cannot alter source wall clock"],
  VerificationTest[
    Block[{$TimeZone = 3.}, utcWallClockString[3]],
    "2025-11-26T16:00:00Z",
    TestID -> "Wolfram kernel host timezone +3 cannot alter source wall clock"]
}];
tzCompatibilityReport
