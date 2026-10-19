# Documentation site architecture, acceptance and rights record

**Status (2026-10-19): staged for PR; NOT YET MERGED, DEPLOYED OR VISUALLY ACCEPTED.**

## Protocol and architecture

Library → Tools → GitHub_Zensical_Documentation_Sites → GITHUB_ZENSICAL_DOCUMENTATION_SITES_PROTOCOL_v1.0.0.md is the governing reusable method.

The WUFI infrastructure source repository is **already public**. Unlike the private-code OOC example, it does not need a second public docs repository just to publish GitHub Pages. We use **Option A**: a reviewed Zensical site in this public source repository.

The maintained source worktrees remain **WUFI_mathematica_tools (default)** and **WUFI_python_tools**, which are intentionally not merged. The default branch owns curated unified documentation under site_docs; it links to exact authoritative source paths on each branch.

## Components

- site_docs/ — 12 specifically selected Markdown pages and one authored CSS file; no report graphics or private data.
- zensical.toml — curated navigation, full Pages subpath and presentation settings.
- scripts/validate_site_docs.py — fail-closed exact content manifest, symlink/type/private-path and simple credential checks.
- .github/workflows/documentation-site.yml — PR build/validation only; reviewed default-branch pushes deploy.
- Existing docs/ and README files on each tool branch — authoritative detailed source documentation and tests.

Future published destination **after verified merge and successful deploy**:
https://mihails-birjukovs.github.io/WUFI_infractructure_codebase/

Site source snapshot should be updated by PR when branch sources evolve. No automatic cross-branch checkout, merges or credentials are used.

## Acceptance gates (do not conflate)

1. SOURCE_GROUNDED — actual README, implementations, tests and authorized scientific audits reviewed.
2. RIGHTS_REVIEWED — owner approves public scientific scope, all assets and citations.
3. PUBLIC_ALLOWLIST_VALID — exact file enumeration and safety scan passes.
4. STRICT_BUILD_PASS — pinned Zensical build passes with no warnings.
5. PR_REVIEWED — owner/maintainer reviews proposed source/rights.
6. MERGED_DEFAULT_BRANCH — PR accepted into WUFI_mathematica_tools.
7. PAGES_DEPLOY_SUCCESS — Pages job reports actual successful deployment.
8. PUBLIC_SITE_VISUALLY_VERIFIED — inspect search/navigation, footer contrast, desktop/mobile and URLs.
9. RELEASE_ACCEPTED — owner records source SHA, workflow URL, site URL, exceptions and approval.

**A PR is not a live website; a build pass is not a rights or scientific proof.**

## Pages setup and constraints

Repository Settings → Pages → Build and deployment → GitHub Actions (verify account entitlement and repo policy). Actions must be enabled. After a reviewed merge, confirm the actual deployment action, site URL and served version; inspect in a browser. The workflow will not deploy PR heads or workflow-dispatch runs.

Site content is a public software/method summary: it never copies the raw MongoDB observations, licensed .w6p projects, WXF archives, external partner reports or unpublished scientific figures. No institutional logos are used. The text references a private report for provenance, but grants no rights to publish its content. Machine scanning cannot substitute human scientific/rights review.

## Maintenance/report-back

Use WUFI_mathematica_tools for Mathematica/tool docs and the site; WUFI_python_tools for Python sources. Avoid PRs that merge their distinct trees. Changes requested by Hygrothermal Modelling Copilot should be returned to the infrastructure maintenance chat with issue, branch and commit, input/test fixtures, expected vs actual behavior, numerical compatibility and regression results.

When ready, record both branch source commits, the site publishing commit, rights sign-off, PR, CI artifacts, Pages URL and browser QA in this record or a versioned release note.
