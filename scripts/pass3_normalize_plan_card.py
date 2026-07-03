#!/usr/bin/env python3
"""Pass 3 — safe plan_time_task_card/ package normalization."""
from __future__ import annotations

import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[1]
WIDGETS = ROOT / "lib" / "core" / "widgets"
PKG = WIDGETS / "plan_time_task_card"
CARD = WIDGETS / "plan_time_task_card.dart"
OLD = WIDGETS / "plan_card"

LAYOUTS_HEADER = """import 'package:counter/core/plan_category_lookup.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_progress.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_density.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_sections.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

"""

PROGRESS_HEADER = """import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_sections.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';

"""

DENSITY_FUNCS_HEADER = """import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_density.dart';
import 'package:counter/data/models.dart';

"""

MAIN_HEADER = """import 'dart:math' as math;

import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/plan_category_lookup.dart';
import 'package:counter/data/models.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

import 'plan_card_controls.dart';
import 'plan_card_geometry.dart';
import 'plan_card_metrics.dart';
import 'plan_card_sections.dart';
import 'plan_card_progress.dart';
import 'plan_card_layouts.dart';
import 'plan_card_density.dart';

export 'plan_card_metrics.dart';
export 'plan_card_density.dart';

"""

BARREL = """export 'plan_time_task_card/plan_time_task_card.dart';
export 'plan_time_task_card/plan_card_metrics.dart';
export 'plan_time_task_card/plan_card_density.dart';
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


def ren(text: str) -> str:
    for a, b in RENAMES.items():
        text = text.replace(a, b)
    return text


def copy_helpers() -> None:
    PKG.mkdir(parents=True, exist_ok=True)
    files = {
        "plan_card_geometry.dart": "plan_card_geometry.dart",
        "plan_card_metrics.dart": "plan_card_metrics.dart",
        "plan_time_card_density.dart": "plan_card_density.dart",
        "plan_card_controls.dart": "plan_card_controls.dart",
        "plan_card_sections.dart": "plan_card_sections.dart",
    }
    for src, dst in files.items():
        text = (OLD / src).read_text(encoding="utf-8")
        text = text.replace("plan_card/", "plan_time_task_card/")
        text = text.replace(
            "plan_time_card_density.dart",
            "plan_card_density.dart",
        )
        (PKG / dst).write_text(text, encoding="utf-8")


def main() -> None:
    copy_helpers()
    lines = CARD.read_text(encoding="utf-8").splitlines(keepends=True)

    progress_start = next(i for i, l in enumerate(lines) if l.startswith("class PlanCardProgressSlot"))
    layouts_start = next(i for i, l in enumerate(lines) if l.startswith("// --- Time View explicit"))
    layouts_end = next(i for i, l in enumerate(lines) if l.startswith("// --- Shared parts"))
    density_start = next(
        i for i, l in enumerate(lines) if l.startswith("PlanTimeTaskCardDensity planTimeCardDensityForBlock")
    )
    widget_end = progress_start

    progress = ren("".join(lines[progress_start:layouts_start]))
    layouts = ren("".join(lines[layouts_start:layouts_end]))
    density_funcs = ren("".join(lines[density_start:]))
    widget = ren("".join(lines[26:widget_end])).replace(
        "_TimeViewDensityBody(",
        "TimeViewDensityBody(",
    )

    (PKG / "plan_card_progress.dart").write_text(PROGRESS_HEADER + progress, encoding="utf-8")
    (PKG / "plan_card_layouts.dart").write_text(LAYOUTS_HEADER + layouts, encoding="utf-8")

    density_path = PKG / "plan_card_density.dart"
    existing = density_path.read_text(encoding="utf-8")
    density_path.write_text(existing + "\n" + DENSITY_FUNCS_HEADER + density_funcs, encoding="utf-8")

    (PKG / "plan_time_task_card.dart").write_text(MAIN_HEADER + widget, encoding="utf-8")
    CARD.write_text(
        "// Compatibility barrel — canonical plan card package.\n" + BARREL,
        encoding="utf-8",
    )

    # Keep old plan_card/ as re-export stubs for any stale imports
    stub = "export 'package:counter/core/widgets/plan_time_task_card/{name}';\n"
    for name in [
        "plan_card_geometry.dart",
        "plan_card_metrics.dart",
        "plan_card_controls.dart",
        "plan_card_sections.dart",
    ]:
        (OLD / name).write_text(stub.format(name=name), encoding="utf-8")
    (OLD / "plan_time_card_density.dart").write_text(
        "export 'package:counter/core/widgets/plan_time_task_card/plan_card_density.dart';\n",
        encoding="utf-8",
    )

    print(
        "widget",
        len((MAIN_HEADER + widget).splitlines()),
        "layouts",
        len((LAYOUTS_HEADER + layouts).splitlines()),
        "progress",
        len((PROGRESS_HEADER + progress).splitlines()),
    )


if __name__ == "__main__":
    main()
