# Independent Wolfram cross-platform checks (17 October 2026)

This is a supplementary diagnostic on Wolfram Language 15.0.1/Linux, **not** the accepted Mathematica 12.1/Windows release-validation suite.

| Check | Result |
| --- | --- |
| WUFIModelMetadata package loaded, synthetic export mask, filename sanitization and ASC validation | Pass |
| HygrothermalPlottingUtilities and SensorDataUtilities loaded; comparison metrics evaluated | Pass |
| Full Data Post-Processor v1.1.1 smoke suite | **13/14 passed** |
| Sole failing TestID | Fresh-kernel graphics render and JPEG export succeeds |
| Standalone headless JPEG export | Pass, 16,593 bytes |
| LaunchKernels[1] in this cloud evaluator | No parallel kernels launched |

**Test count correction:** the Wolfram TestReportObject failures association has three *categories*, but two are empty; the actual number of unsuccessful tests is **one**, not three.

Because sequential JPEG export works but zero parallel kernels launch, the failing smoke test is consistent with **restricted subkernel availability in the cloud environment** rather than a generic rendering failure. The evidence is not sufficient to prove that subkernel availability is the sole internal cause of the failing production test.

The production v1.1.1 implementation must not be modified solely to satisfy an unsupported Wolfram 15/Linux evaluation. Target acceptance requires Mathematica 12.1/Windows, licensed subkernels and authorized REF/HEMP datasets; licensed WUFI Pro 6.5 execution/import remains a separate check. No validated executable Mathematica files are changed by this document.
