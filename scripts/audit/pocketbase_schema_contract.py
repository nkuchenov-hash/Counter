#!/usr/bin/env python3
"""Fail when app-owned PocketBase collection constants drift from governing docs/migrations."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "lib/data/pb_config.dart"
MANIFEST = ROOT / "docs/POCKETBASE_MANIFEST.md"
PATH_REPOSITORY = ROOT / "lib/data/paths/path_repository.dart"
MIGRATIONS = ROOT / "pb_migrations"


def main() -> int:
    config = CONFIG.read_text(encoding="utf-8")
    manifest = MANIFEST.read_text(encoding="utf-8")
    repository = PATH_REPOSITORY.read_text(encoding="utf-8")
    violations: list[str] = []

    block_match = re.search(
        r"abstract class PbCollections\s*\{(?P<body>.*?)\n\}",
        config,
        flags=re.S,
    )
    if block_match is None:
        violations.append("PB_COLLECTIONS_BLOCK_MISSING")
        literal_collections: set[str] = set()
    else:
        literal_collections = set(
            re.findall(
                r"static const String \w+\s*=\s*['\"]([^'\"]+)['\"]",
                block_match.group("body"),
            )
        )

    for name in sorted(literal_collections):
        if f"`{name}`" not in manifest and f"**{name}**" not in manifest:
            violations.append(f"PB_COLLECTION_UNDOCUMENTED {name}")

    if "LIFEOS_PATH::" in repository:
        violations.append("PATH_REPOSITORY_LEGACY_MARKER")
    for token in ("category_link", "active_revision_link"):
        if token not in repository:
            violations.append(f"PATH_REPOSITORY_RELATION_MISSING {token}")

    path_migrations = sorted(MIGRATIONS.glob("*_durable_paths.js"))
    if len(path_migrations) != 1:
        violations.append(
            f"DURABLE_PATH_MIGRATION_COUNT expected=1 actual={len(path_migrations)}"
        )
    else:
        migration = path_migrations[0].read_text(encoding="utf-8")
        for token in (
            "paths",
            "path_revisions",
            'name: "category_link"',
            'name: "active_revision_link"',
        ):
            if token not in migration:
                violations.append(f"DURABLE_PATH_MIGRATION_MISSING {token}")

    required_manifest_tokens = (
        "`paths`",
        "`path_revisions`",
        "category_link",
        "active_revision_link",
        "pb_migrations/",
    )
    for token in required_manifest_tokens:
        if token not in manifest:
            violations.append(f"PATH_SCHEMA_MANIFEST_MISSING {token}")

    if violations:
        print("pocketbase_schema_contract: FAIL", file=sys.stderr)
        for violation in violations:
            print(f"  - {violation}", file=sys.stderr)
        return 1

    print(
        "pocketbase_schema_contract: OK "
        f"literal_collections={len(literal_collections)} path_migration={path_migrations[0].name}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
