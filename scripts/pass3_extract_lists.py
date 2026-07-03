#!/usr/bin/env python3
"""Pass 3 — split lists_view.dart card widgets + export helper."""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
LV = ROOT / "lib" / "features" / "lists" / "lists_view.dart"

CARD_HEADER = """import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""

EXPORT_HEADER = """import 'package:counter/core/app_snackbar.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

"""

RENAMES = {
    "_ListsQuadraticChip": "ListsQuadraticChip",
    "_BacklogPlanCard": "BacklogPlanCard",
    "_ListsSemicircleMenuOverlay": "ListsSemicircleMenuOverlay",
    "_ListsSemicircleMenuOverlayState": "ListsSemicircleMenuOverlayState",
}


def apply_renames(text: str) -> str:
    for old, new in RENAMES.items():
        text = text.replace(old, new)
    return text


def main() -> None:
    lines = LV.read_text(encoding="utf-8").splitlines(keepends=True)
    tail_start = next(
        i for i, l in enumerate(lines) if l.startswith("/// Fast filter chip")
    )
    export_start = next(
        i
        for i, l in enumerate(lines)
        if l.strip() == "Future<void> _exportVisibleListAsText(List<PlanningTask> visible) async {"
    )
    export_end = next(
        i
        for i in range(export_start + 1, len(lines))
        if lines[i].startswith("  /// Manual chip picker")
    )

    card_chunk = apply_renames("".join(lines[tail_start:]))
    (ROOT / "lib/features/lists/lists_card.dart").write_text(
        CARD_HEADER + card_chunk,
        encoding="utf-8",
    )

    export_lines = lines[export_start:export_end]
    export_text = "".join(export_lines)
    export_text = export_text.replace(
        "Future<void> _exportVisibleListAsText(List<PlanningTask> visible) async {",
        "Future<void> exportVisibleListAsText({\n"
        "  required BuildContext context,\n"
        "  required String locale,\n"
        "  required List<PlanningTask> visible,\n"
        "}) async {",
    )
    export_text = export_text.replace("final loc = currentLocale.value;", "")
    export_text = export_text.replace("t(loc,", "t(locale,")
    (ROOT / "lib/features/lists/lists_export.dart").write_text(
        EXPORT_HEADER + export_text,
        encoding="utf-8",
    )

    kept = lines[:export_start] + lines[export_end:tail_start]
    insert_idx = next(i for i, l in enumerate(kept) if l.startswith("import "))
    last_import = insert_idx
    for i, l in enumerate(kept):
        if l.startswith("import "):
            last_import = i
    new_imports = [
        "import 'package:counter/features/lists/lists_card.dart';\n",
        "import 'package:counter/features/lists/lists_export.dart';\n",
    ]
    for imp in reversed(new_imports):
        if imp not in "".join(kept):
            kept.insert(last_import + 1, imp)

    kept_text = apply_renames("".join(kept))
    kept_text = kept_text.replace(
        "await _exportVisibleListAsText(visible);",
        "await exportVisibleListAsText(context: context, locale: loc, visible: visible);",
    )
    kept_text = kept_text.replace(
        "await _exportVisibleListAsText(flatRows);",
        "await exportVisibleListAsText(context: context, locale: loc, visible: flatRows);",
    )
    kept_text = kept_text.replace(
        "_exportVisibleListAsText(flatRows)",
        "exportVisibleListAsText(context: context, locale: loc, visible: flatRows)",
    )
    LV.write_text(kept_text, encoding="utf-8")
    print("lists_view:", len(kept_text.splitlines()))


if __name__ == "__main__":
    main()
