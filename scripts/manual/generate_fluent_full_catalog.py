#!/usr/bin/env python3
"""Generate every 24px Regular/Filled Fluent pair from the *installed* package.

The 24px intersection is resolved from pubspec.lock's actual package source,
not from upstream main: new upstream glyphs can be absent from pinned Flutter.
Stable "fluent__" keys prevent collisions with old category preferences.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from urllib.parse import urlparse, unquote

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / ".dart_tool/package_config.json"
OUTPUT = ROOT / "lib/core/fluent_full_catalog_generated.g.dart"


def installed_package() -> Path:
    data = json.loads(CONFIG.read_text(encoding="utf-8"))
    pkg = next((p for p in data["packages"]
                if p["name"] == "fluentui_system_icons"), None)
    if pkg is None:
        raise RuntimeError("fluentui_system_icons missing from package_config")
    uri = pkg["rootUri"]
    parsed = urlparse(uri)
    if parsed.scheme == "file":
        return Path(unquote(parsed.path))
    if parsed.scheme:
        raise RuntimeError(f"Unexpected Dart package URI: {uri}")
    return (CONFIG.parent / uri).resolve()


def main() -> None:
    package = installed_package()
    sources = list((package / "lib").rglob("*.dart"))
    if not sources:
        raise RuntimeError(f"No Fluent Dart files under {package}")

    appearances: dict[str, set[str]] = {}
    # Check the exported Dart API, not the SVG source, before adding a symbol.
    symbol = re.compile(
        r"\b(?:static\s+)?const\s+IconData\s+([a-z][a-z0-9_]*)_24_(regular|filled)\s*="
    )
    for source in sources:
        text = source.read_text(encoding="utf-8")
        for stem, style in symbol.findall(text):
            appearances.setdefault(stem, set()).add(style)

    paired = sorted(stem for stem, styles in appearances.items()
                    if {"regular", "filled"} <= styles)
    if len(paired) < 1000:
        raise RuntimeError(
            f"Only {len(paired)} valid 24px Regular/Filled pairs detected "
            f"in {package}; inspect the package API before accepting output"
        )

    lines = [
        "// GENERATED. Do not edit manually.",
        "// Complete 24px Fluent UI Regular/Filled catalog from installed package.",
        "// Regenerate: python scripts/manual/generate_fluent_full_catalog.py",
        "import 'package:counter/core/category_icon_catalog_generated.g.dart';",
        "import 'package:fluentui_system_icons/fluentui_system_icons.dart';",
        "",
        "const Map<String, MatchedCategoryIcon> kFullFluentCategoryIcons = {",
    ]
    for stem in paired:
        lines.append(
            f"  'fluent__{stem}': MatchedCategoryIcon("
            f"FluentIcons.{stem}_24_regular, "
            f"FluentIcons.{stem}_24_filled),"
        )
    lines += ["};", ""]
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {len(paired)} tested 24px icon pairs: {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
