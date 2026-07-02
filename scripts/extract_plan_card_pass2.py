#!/usr/bin/env python3
"""Structure refactor pass 2 — plan card geometry/tokens/controls extraction."""
from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
CARD = ROOT / "lib" / "core" / "widgets" / "plan_time_task_card.dart"

GEOM_HEADER = """import 'package:counter/core/widgets/plan_card/plan_card_metrics.dart';

"""

CONTROLS_HEADER = """import 'dart:math' as math;

import 'package:counter/core/widgets/plan_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_card/plan_card_metrics.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""

RENAMES = {
    "_PlanCardGeom": "PlanCardGeom",
    "_PlanCardVerticalSpacing": "PlanCardVerticalSpacing",
    "_PlanCardTokens": "PlanCardTokens",
    "_PlanCardProgressSlot": "PlanCardProgressSlot",
    "_PlanCardInvariantBody": "PlanCardInvariantBody",
    "_PlanCardRailShell": "PlanCardRailShell",
    "_PlanCardProgressRow": "PlanCardProgressRow",
    "_PlanCardBodyTapShell": "PlanCardBodyTapShell",
    "_PlanCardControlRail": "PlanCardControlRail",
    "_PlanCardCheckbox": "PlanCardCheckbox",
    "_PlanCardCheckboxState": "PlanCardCheckboxState",
    "_PlanCardPlayButton": "PlanCardPlayButton",
    "_PlanCardPlayButtonState": "PlanCardPlayButtonState",
    "_PlanCardPlayIconPainter": "PlanCardPlayIconPainter",
    "_PlanCardMenuButton": "PlanCardMenuButton",
    "_PlanCardMenuButtonState": "PlanCardMenuButtonState",
    "_PlanCardMenuIconPainter": "PlanCardMenuIconPainter",
    "_PlanCardRecurringGlyph": "PlanCardRecurringGlyph",
    "_PlanCardTitleRow": "PlanCardTitleRow",
    "_PlanCardTagsRow": "PlanCardTagsRow",
    "_PlanCardTimeText": "PlanCardTimeText",
    "_PlanCardFooterRow": "PlanCardFooterRow",
    "_PlanCardWatermark": "PlanCardWatermark",
}


def apply_renames(text: str) -> str:
    for old, new in RENAMES.items():
        text = text.replace(old, new)
    return text


def main() -> None:
    lines = CARD.read_text(encoding="utf-8").splitlines(keepends=True)

    geom_chunk = apply_renames("".join(lines[433:561]))
    (ROOT / "lib/core/widgets/plan_card/plan_card_geometry.dart").write_text(
        GEOM_HEADER + geom_chunk,
        encoding="utf-8",
    )

    controls_chunk = apply_renames("".join(lines[2023:2437]))
    (ROOT / "lib/core/widgets/plan_card/plan_card_controls.dart").write_text(
        CONTROLS_HEADER + controls_chunk,
        encoding="utf-8",
    )

    sections_header = CONTROLS_HEADER.replace(
        "plan_card_controls.dart",
        "plan_card_sections.dart",
    ).replace("plan_card_controls", "plan_card_sections")
    sections_header = """import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/core/widgets/plan_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_card/plan_card_metrics.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""
    sections_chunk = apply_renames("".join(lines[2438:2624]))
    (ROOT / "lib/core/widgets/plan_card/plan_card_sections.dart").write_text(
        sections_header + sections_chunk,
        encoding="utf-8",
    )

    kept = lines[:433] + [
        "import 'package:counter/core/widgets/plan_card/plan_card_controls.dart';\n",
        "import 'package:counter/core/widgets/plan_card/plan_card_geometry.dart';\n",
        "import 'package:counter/core/widgets/plan_card/plan_card_sections.dart';\n",
        "\n",
    ] + lines[562:2023] + lines[2624:]

    text = apply_renames("".join(kept))
    CARD.write_text(text, encoding="utf-8")
    print(f"plan_time_task_card.dart -> {len(text.splitlines())} lines")


if __name__ == "__main__":
    main()
