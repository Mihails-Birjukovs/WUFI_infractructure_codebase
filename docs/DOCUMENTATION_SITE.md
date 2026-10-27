# Documentation site architecture, acceptance and rights record

**Published and visually accepted by the owner after PR #27 (2026-10-20), published commit `5d55fb3`. This file records historical acceptance gates and pending later documentation-only revisions.**

## Protocol and architecture

Library → Tools → GitHub_Zensical_Documentation_Sites → GITHUB_ZENSICAL_DOCUMENTATION_SITES_PROTOCOL_v1.0.0.md is the governing reusable method.

The WUFI infrastructure source repository is **already public**. Unlike the private-code OOC example, it does not need a second public docs repository just to publish GitHub Pages. We use **Option A**: a reviewed Zensical site in this public source repository.

The maintained source worktrees remain **WUFI_mathematica_tools (default)** and **WUFI_python_tools**, which are intentionally not merged. The default branch owns curated unified documentation under site_docs; it links to exact authoritative source paths on each branch.

## Components

- site_docs/ — 14 explicitly selected Markdown pages, one stylesheet, and three byte-pinned INM SVG assets reused from the OOC docs site; no report graphics or private data.
- zensical.toml — curated navigation, full Pages subpath and presentation settings.
- scripts/validate_site_docs.py — fail-closed exact content manifest, symlink/type/private-path and simple credential checks.
- .github/workflows/documentation-site.yml — PR build/validation only; reviewed default-branch pushes deploy.
- Existing docs/ and README files on each tool branch — authoritative detailed source documentation and tests.

Current published website:
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

Site content is a public software/method summary: it never copies the raw MongoDB observations, licensed .w6p projects, WXF archives, external partner reports or unpublished scientific figures. Only the three already-public, same-maintainer OOC INM identity logos are reused and pinned by their source Git blob hashes; their marks remain outside the MIT software license. The text references a private report for provenance, but grants no rights to publish its content. Machine scanning cannot substitute human scientific/rights review.

## Maintenance/report-back

Use WUFI_mathematica_tools for Mathematica/tool docs and the site; WUFI_python_tools for Python sources. Avoid PRs that merge their distinct trees. Changes requested by Hygrothermal Modelling Copilot should be returned to the infrastructure maintenance chat with issue, branch and commit, input/test fixtures, expected vs actual behavior, numerical compatibility and regression results.

When ready, record both branch source commits, the site publishing commit, rights sign-off, PR, CI artifacts, Pages URL and browser QA in this record or a versioned release note.

## INM visual identity and credits update (2026-10-20)

The style is harmonized with the maintainer's published OOC documentation site: white header with orange accent, navy navigation, dark hero, tab structure, highlighted identity/credit strip, table/blockquote treatments, and accessible footer/copyright contrast. The same three INM SVGs (header logo, favicon and square footer badge) were copied byte-for-byte from OOC and are individually verified against exact source Git blob hashes. A future update to either set requires independent rights and appearance review; no general SVG publishing permission was introduced.

Added contributor credits for software, MongoDB network/data management, sensor installation, and material lab measurement. Added paper-level references for pvlib (current recommended 2023 JOSS and 2018 historical), Erbs (1982), DMD (Schmid 2010/Tu et al. 2014), HODMD (Le Clainche & Vega 2017), and DMDc (Proctor et al. 2016). Citations distinguish actual library use from locally reconstructed/new source implementations.

## 2026-10-20: user-observed style delivery regression

User-provided side-by-side browser screenshots showed the WUFI home hero, identity panel, logo sizing and the footer copyright without the expected OOC-style CSS, while the OOC site was correctly styled. The original successful Pages deployment artifact contained both the CSS file and the correct link markup; applying that CSS in local browser computation yields the expected values. Thus **the screenshots establish missing CSS application in the live browser, not a defective stylesheet selector or failed build**. The precise HTTP-level browser failure could not be independently observed in the accessible environment.

Recovery: publish the same approved WUFI stylesheet under a **new uniquely versioned URL** (`stylesheets/inm-wufi-20261020.css`) to invalidate any cache of the former asset path, remove the old asset, and update `extra_css` in Zensical. Match the OOC footer's concise copyright while retaining legal rights detail on the Licensing page. Simplify the visible homepage contribution panel to two columns, preserving complete role credits on Credits & contributors.

Add `scripts/check_site_style.py` to CI to require the generated homepage, secondary pages, stylesheet relative URLs and core hero/INM/footer selectors to be present. This is **build-artifact QA, not remote browser HTTP/visual QA**; after merge, the actual live page must be inspected, CSS status must be 200, and computed background/width/text colors checked. OOC brand assets and Python/Mathematica code remain unchanged.

## 2026-10-28 Python tool inventory refresh (documentation proposal)

Source: `WUFI_python_tools` commit `c5ec8ce` (Valters Ribickis, 2026-10-20). New Python source contains a batch launcher, ASC post-processor, and parameter sweep/thickness optimisation scripts. Documentation now points to their original package READMEs, clarifies that only some scripts execute licensed WUFI, distinguishes CSV/JPG from Mathematica WXF outputs, and prominently preserves the execution/physical/test caveats. Three classes of follow-up are tracked as [Issues #28–#35](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/issues): safe execution / proper tests / interpolation with Mathematica; additional dependencies and physical/QC/governance review also remain open. **Those issues request Valters's assessment before any implementation**.

This release changes only documentation and root README on the Mathematica default branch. No executable tools, CI workflows, licenses, visual CSS, branding or public-site file allowlist are changed. PR build and human approval still required before publication; the Python source README update is separately proposed against the Python branch.
