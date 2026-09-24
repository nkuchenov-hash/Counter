#!/usr/bin/env python3
"""Keep the canonical function registry and published encyclopedia in lock-step."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FUNCTIONS = ROOT / "docs" / "FUNCTIONS.md"
USER_GUIDE = ROOT / "docs" / "USER_GUIDE.md"
SITE = ROOT / "marketing" / "docs" / "index.html"

REGISTRY_ROW = re.compile(r"^\|\s*`([a-z0-9_.-]+)`\s*\|", re.M)
SITE_ID = re.compile(r"data-function-id=[\"']([a-z0-9_.-]+)[\"']")
CODE_REF = re.compile(r"`((?:lib|docs|browser_extension|server|pb_hooks|pb_migrations)/[^`]+)`")


def main() -> int:
    issues: list[str] = []
    for path in (FUNCTIONS, USER_GUIDE, SITE):
        if not path.exists():
            issues.append(f"MISSING {path.relative_to(ROOT).as_posix()}")
    if issues:
        return fail(issues)

    functions = FUNCTIONS.read_text(encoding="utf-8")
    guide = USER_GUIDE.read_text(encoding="utf-8")
    site = SITE.read_text(encoding="utf-8")

    ids = REGISTRY_ROW.findall(functions)
    if not ids:
        issues.append("FUNCTION_REGISTRY_EMPTY")
    if len(ids) != len(set(ids)):
        dupes = sorted({x for x in ids if ids.count(x) > 1})
        issues.append("FUNCTION_REGISTRY_DUPLICATES " + ",".join(dupes))

    site_ids = SITE_ID.findall(site)
    if len(site_ids) != len(set(site_ids)):
        dupes = sorted({x for x in site_ids if site_ids.count(x) > 1})
        issues.append("ENCYCLOPEDIA_DUPLICATE_IDS " + ",".join(dupes))

    missing_site = sorted(set(ids) - set(site_ids))
    stale_site = sorted(set(site_ids) - set(ids))
    if missing_site:
        issues.append("ENCYCLOPEDIA_MISSING_IDS " + ",".join(missing_site))
    if stale_site:
        issues.append("ENCYCLOPEDIA_STALE_IDS " + ",".join(stale_site))

    required_site_tokens = (
        'id="q"', 'type="search"', 'aria-label=', '@media(max-width:',
        'docs/FUNCTIONS.md', 'docs/USER_GUIDE.md', 'Production',
    )
    for token in required_site_tokens:
        if token not in site:
            issues.append(f"ENCYCLOPEDIA_UI_CONTRACT_MISSING {token}")

    # User guide must cover every user-facing top-level domain represented by IDs.
    user_domains = {
        "timeline": ("Timeline", "Запись времени"),
        "planning": ("Plans", "Планирование"),
        "lists": ("Lists",),
        "calendar": ("Calendar",),
        "categories": ("Categories",),
        "tags": ("тег", "Tags"),
        "profile": ("Profile",),
        "stats": ("Stats",),
        "notes": ("Notes",),
        "paths": ("Paths",),
        "voice": ("Голос",),
        "health": ("Health", "Сон"),
        "offline": ("Offline", "синхронизац"),
        "browser": ("Browser companion",),
        "auth": ("авторизац", "OAuth"),
        "shell": ("navigation", "навигац"),
        "wear": ("Wear",),
    }
    present_domains = {x.split(".", 1)[0] for x in ids}
    for domain, needles in user_domains.items():
        if domain in present_domains and not any(n.lower() in guide.lower() for n in needles):
            issues.append(f"USER_GUIDE_DOMAIN_MISSING {domain}")

    # Explicit full repository anchors in FUNCTIONS must resolve.
    for ref in CODE_REF.findall(functions):
        clean = ref.split("#", 1)[0]
        if not (ROOT / clean).exists():
            issues.append(f"FUNCTION_BROKEN_CODE_REF {clean}")

    if issues:
        return fail(issues)
    print(f"function_encyclopedia_contract: OK ({len(ids)} capabilities)")
    return 0


def fail(issues: list[str]) -> int:
    print("function_encyclopedia_contract: FAIL")
    for issue in issues:
        print(f"  - {issue}")
    print(f"ISSUES={len(issues)}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
