#!/usr/bin/env python3
"""Validate Zensical output paths, selected INM styling and footer contracts.

Build-time tests cannot confirm HTTP 200 on GitHub Pages or remote browser
computed styles; the published site still requires live visual inspection.
"""
from __future__ import annotations

from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import posixpath
import sys

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"
STYLE = "stylesheets/inm-wufi-20261020.css"
PAGES = [
    "index.html",
    "getting-started/index.html",
    "architecture/index.html",
    "mathematica/index.html",
    "python/index.html",
    "climate/index.html",
    "modal/index.html",
    "validation/index.html",
    "credits/index.html",
    "references/index.html",
    "licensing/index.html",
    "data-provenance/index.html",
]
ASSETS = [
    "assets/inm-horizontal.svg",
    "assets/inm-mark.svg",
    "assets/inm-square-footer.svg",
]


class Tags(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.stylesheets: list[str] = []
        self.classes: set[str] = set()
        self.images: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        data = dict(attrs)
        self.classes.update((data.get("class") or "").split())
        if tag == "link" and "stylesheet" in (data.get("rel") or "").split():
            self.stylesheets.append(data.get("href") or "")
        if tag == "img":
            self.images.append(data.get("src") or "")


def relative_asset(page: str, url: str) -> str:
    parsed = urlsplit(url)
    if parsed.scheme or parsed.netloc or parsed.query or parsed.fragment:
        raise ValueError(f"Unexpected non-local style URL: {page}: {url}")
    path = posixpath.normpath(posixpath.join(posixpath.dirname(page), unquote(parsed.path)))
    if path.startswith("../") or path.startswith("/"):
        raise ValueError(f"Escaping asset URL: {page}: {url}")
    return path


def validate() -> None:
    css_path = SITE / STYLE
    if not css_path.is_file():
        raise ValueError(f"Missing versioned stylesheet in built site: {STYLE}")
    css = css_path.read_text("utf-8")
    required = [
        ".wufi-hero", ".wufi-actions", ".wufi-link-primary",
        ".wufi-identity", ".wufi-brand-mark", ".wufi-credit-strip",
        ".md-header__button.md-logo img", ".md-footer-meta__inner::after",
        "footer.md-footer .md-footer-meta .md-copyright",
        "footer.md-footer .md-footer-meta .md-copyright a:visited",
        "#f47b20", "#1c3854", "inm-square-footer.svg",
    ]
    for fragment in required:
        if fragment not in css:
            raise ValueError(f"Expected OOC-style selector/brand missing: {fragment}")

    for asset in ASSETS:
        if not (SITE / asset).is_file():
            raise ValueError(f"Missing approved INM asset in site: {asset}")

    for page_path in PAGES:
        html_file = SITE / page_path
        if not html_file.is_file():
            raise ValueError(f"Missing generated page: {page_path}")
        html = html_file.read_text("utf-8")
        parser = Tags()
        parser.feed(html)
        stylesheet_paths = [
            relative_asset(page_path, href)
            for href in parser.stylesheets
            if "inm-wufi-" in href or "wufi.css" in href
        ]
        if stylesheet_paths != [STYLE]:
            raise ValueError(
                f"{page_path}: missing/stale/misresolved WUFI CSS: {stylesheet_paths}"
            )
        if "md-copyright__highlight" not in parser.classes:
            raise ValueError(f"{page_path}: footer copyright markup missing")

        if page_path == "index.html":
            for required_class in ("wufi-hero", "wufi-actions", "wufi-identity", "wufi-brand-mark"):
                if required_class not in parser.classes:
                    raise ValueError(f"Homepage missing styling class: {required_class}")
            if "assets/inm-horizontal.svg" not in [
                relative_asset(page_path, url) for url in parser.images if not url.startswith("data:")
            ]:
                raise ValueError("Homepage identity logo missing")
            if "Copyright © 2026 Mihails Birjukovs" not in html:
                raise ValueError("Footer copyright differs from approved concise wording")
            if "Institutional logos excluded from the MIT license" in html:
                raise ValueError("Long licensing disclaimer still in footer")

    print(
        f"PASS: {len(PAGES)} generated pages link to {STYLE}, "
        f"three approved SVGs and OOC-matched hero/footer selectors present"
    )


if __name__ == "__main__":
    try:
        validate()
    except (ValueError, OSError, UnicodeError) as e:
        print(f"STYLESHEET QA FAILED: {e}", file=sys.stderr)
        raise SystemExit(1) from e
