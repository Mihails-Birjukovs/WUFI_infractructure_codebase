# Contributing and documentation governance

**Always set the pull-request base explicitly.** These two toolchain branches must never be merged together.

| Change type | Correct PR base |
| --- | --- |
| Mathematica launcher, ASC processing, sensor comparison | WUFI_mathematica_tools |
| Python climate, tests, multiscale, DMD, HODMD and DMDc | WUFI_python_tools |
| Curated public website and Zensical workflow | WUFI_mathematica_tools |

## Review checklist

1. Record affected branch, baseline SHA, changes and test impacts.
2. Keep executable code changes separately reviewable from public documentation.
3. Mark methods original, recovered, reconstructed or inferred.
4. Run branch-specific tests without editing frozen scientific archives.
5. Inspect proposed public files for rights, experimental privacy, internal paths and scientific accuracy.
6. Update the **explicit website allowlist** and navigation for each new page.
7. Verify the website content validator and strict build in a PR; **never deploy PR content**.
8. Merge after code and scientific/rights approval; then confirm actual Pages deployment, links, search, CSS, desktop/mobile and published revision.

## Public site safety model

This site has a fail-closed exact-file allowlist, symlink guard, blocked binary/data suffixes, path checks and simple credential heuristics. Automated scanning does not replace human privacy or rights review. No unpublished report graphics, raw MongoDB dumps, protected material-testing tables or institutional logos are copied.

The build uses read-only permissions and no retained checkout credentials. Deployment permissions are limited to the default-branch GitHub Pages job, not PR validation.

## Research-to-tools handoff

Scientific calibration, data analysis and article drafting occur in the **Hygrothermal Modelling Copilot** project. When new scientific work requires a code change, report back with the affected branch and SHA, an issue description, reproducible synthetic or redistribution-approved test, expected/observed outputs, test coverage and compatibility assessment. Review and merge the infrastructure change here.

The site is a curated **two-branch snapshot**. Python branch content can evolve without an automatic site rebuild containing those code changes. Update summaries by reviewed website PRs rather than cross-branch merges.

[Licensing and publication rights](licensing.md).
