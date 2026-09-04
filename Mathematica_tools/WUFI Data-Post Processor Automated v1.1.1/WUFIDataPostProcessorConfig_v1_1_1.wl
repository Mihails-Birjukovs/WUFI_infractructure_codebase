(* ::Package:: *)

(* WUFI Data Post-Processor Automated Production v1.1.1 - user configuration *)

postProcessorSettings = Join[
  DefaultWUFIPostProcessorSettingsV11[],
  <|
    "DataDirectory" ->
      "D:\\Science\\NMI\\WEED Project\\Fibrolite Materials RTU 2026\\WUFI\\WUFI_FINAL_Wall_Models_2026-08-25",

    (* "Full" = v1.0-compatible JPG inventory.
       "Sweep" = all five WXFs + RH/temperature JPGs + layer/total water JPGs. *)
    "GraphicsMode" -> "Full",

    (* Set True to audit the output tree and rerun only incomplete cases.
       Within those cases, already-valid WXF/JPG outputs are kept. *)
    "RestartFailedCases" -> False,

    (* Validated graphics policy for this workflow:
         8  = production default / recommended interactive throughput;
         12 = validated high-throughput option on the reference workstation;
         >12 triggers a warning.
       A 16-kernel reference run stalled in case 1 and failed to render some files.
       Do not use Automatic for production campaigns. *)
    "UseParallelGraphics" -> True,
    "GraphicsKernelCount" -> 8,
    "GraphicsKernelWarningThreshold" -> 12,
    "FreshKernelRetries" -> 1,

    (* Controller-only user feedback. Worker kernels never print progress. *)
    "ShowProgress" -> True,
    "VerboseLogging" -> True,

    (* Explicit time-series frame ticks mitigate the rare parallel-rendering
       defect observed with missing date/numeric tick labels. *)
    "ExplicitTimeSeriesTicks" -> True,

    "MissingASCPolicy" -> "AbortAll",
    "CaseFailurePolicy" -> "Continue"
  |>
];
