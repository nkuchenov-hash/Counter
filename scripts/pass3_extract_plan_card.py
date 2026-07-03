#!/usr/bin/env python3
"""Pass 3 — normalize plan_time_task_card/ package and split layouts/density."""
from __future__ import annotations

import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[1]
WIDGETS = ROOT / "lib" / "core" / "widgets"
OLD_CARD_DIR = WIDGETS / "plan_card"
NEW_PKG = WIDGETS / "plan_time_task_card"
CARD = WIDGETS / "plan_time_task_card.dart"

DENSITY_HEADER = """import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_time_card_density.dart';
import 'package:counter/data/models.dart';

"""

LAYOUTS_HEADER = """import 'dart:math' as math;

import 'package:counter/core/plan_category_lookup.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_sections.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_time_card_density.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""

TAGS_HEADER = LAYOUTS_HEADER

PROGRESS_HEADER = """import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_sections.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';

"""

RENAMES = {
    "_TimeViewDensityBody": "TimeViewDensityBody",
    "_TimeViewCardCommon": "TimeViewCardCommon",
    "_TimeViewLeftControls": "TimeViewLeftControls",
    "_TimeViewResponsiveShell": "TimeViewResponsiveShell",
    "_TimeViewVerticalShell": "TimeViewVerticalShell",
    "_TimeViewTagsRow": "TimeViewTagsRow",
    "_TimeViewTagStack": "TimeViewTagStack",
    "_TimeViewCompactTagPill": "TimeViewCompactTagPill",
    "_TimeViewVerySmallLayout": "TimeViewVerySmallLayout",
    "_TimeViewSmallLayout": "TimeViewSmallLayout",
    "_TimeViewMoreCompactLayout": "TimeViewMoreCompactLayout",
    "_TimeViewTwoRowCenterLayout": "TimeViewTwoRowCenterLayout",
    "_TimeViewCompactLayout": "TimeViewCompactLayout",
    "_TimeViewMediumLayout": "TimeViewMediumLayout",
    "_TimelinePlanCardSmall": "TimelinePlanCardSmall",
    "_TimelinePlanCardMedium": "TimelinePlanCardMedium",
    "_TimelinePlanCardLarge": "TimelinePlanCardLarge",
    "_planCardWallTimeLabel": "planCardWallTimeLabel",
}


def apply_renames(text: str) -> str:
    for old, new in RENAMES.items():
        text = text.replace(old, new)
    return text


def move_plan_card_dir() -> None:
    NEW_PKG.mkdir(parents=True, exist_ok=True)
    mapping = {
        "plan_card_geometry.dart": "plan_card_geometry.dart",
        "plan_card_metrics.dart": "plan_card_metrics.dart",
        "plan_time_card_density.dart": "plan_card_density.dart",
        "plan_card_controls.dart": "plan_card_controls.dart",
        "plan_card_sections.dart": "plan_card_sections.dart",
    }
    for src_name, dst_name in mapping.items():
        src = OLD_CARD_DIR / src_name
        if not src.exists():
            continue
        text = src.read_text(encoding="utf-8")
        text = text.replace("plan_card/", "plan_time_task_card/")
        text = text.replace(
            "plan_time_card_density.dart",
            "plan_card_density.dart",
        )
        (NEW_PKG / dst_name).write_text(text, encoding="utf-8")


def main() -> None:
    move_plan_card_dir()
    lines = CARD.read_text(encoding="utf-8").splitlines(keepends=True)

    layouts_start = next(i for i, l in enumerate(lines) if "_TimeViewDensityBody" in l)
    layouts_end = next(i for i, l in enumerate(lines) if l.startswith("class PlanCardBodyTapShell"))
    tags_start = next(i for i, l in enumerate(lines) if "_TimeViewTagsRow" in l)
    tags_end = next(i for i, l in enumerate(lines) if "_TimeViewVerySmallLayout" in l)
    progress_start = next(i for i, l in enumerate(lines) if "class PlanCardProgressSlot" in l)
    progress_end = layouts_start
    density_start = next(i for i, l in enumerate(lines) if l.startswith("PlanTimeTaskCardDensity planTimeCardDensityForBlock"))
    density_end = len(lines)

    layouts = apply_renames("".join(lines[layouts_start:layouts_end]))
    tags = apply_renames("".join(lines[tags_start:tags_end]))
    progress = apply_renames("".join(lines[progress_start:progress_end]))
    density = apply_renames("".join(lines[density_start:density_end]))

    (NEW_PKG / "plan_card_layouts.dart").write_text(LAYOUTS_HEADER + layouts, encoding="utf-8")
    (NEW_PKG / "plan_card_tags.dart").write_text(TAGS_HEADER + tags, encoding="utf-8")
    (NEW_PKG / "plan_card_progress.dart").write_text(PROGRESS_HEADER + progress, encoding="utf-8")
    (NEW_PKG / "plan_card_density.dart").write_text(DENSITY_HEADER + density, encoding="utf-8")

    main_widget = apply_renames("".join(lines[:progress_start] + lines[layouts_end:layouts_start]))
    main_header = """// Plan card package entry — public widget + re-exports.
import 'dart:math' as math;

import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/plan_category_lookup.dart';
import 'package:counter/data/models.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

import 'plan_card_density.dart';
import 'plan_card_geometry.dart';
import 'plan_card_controls.dart';
import 'plan_card_sections.dart';
import 'plan_card_layouts.dart';
import 'plan_card_progress.dart';
import 'plan_card_tags.dart';
import 'plan_card_metrics.dart';

export 'plan_card_density.dart';
export 'plan_card_metrics.dart';
export 'plan_time_card_density.dart' show PlanTimeCardVisualDensity, planTimeCardVisualDensityForRenderedHeight, planTimeCardTaskDensityForVisual;

"""
    # fix density export name
    main_header = main_header.replace(
        "export 'plan_time_card_density.dart'",
        "export 'plan_card_density.dart'",
    )
    (NEW_PKG / "plan_time_task_card.dart").write_text(main_header + main_widget, encoding="utf-8")

    barrel = """// Compatibility barrel — canonical plan card lives under plan_time_task_card/.
export 'plan_time_task_card/plan_time_task_card.dart';
export 'plan_time_task_card/plan_card_metrics.dart';
export 'plan_time_task_card/plan_card_density.dart';
"""
    CARD.write_text(barrel, encoding="utf-8")
    print("plan_time_task_card package written")


if __name__ == "__main__":
    main()
