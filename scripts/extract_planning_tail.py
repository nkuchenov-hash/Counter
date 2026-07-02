#!/usr/bin/env python3
"""One-shot extract of planning_view.dart tail widgets (structure refactor)."""
from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
PV = ROOT / "lib" / "features" / "planning" / "planning_view.dart"

# 1-based inclusive line ranges -> (relative_path, header_lines, renames)
EXTRACTS: list[tuple[int, int, str, list[str], dict[str, str]]] = [
    (
        6011,
        6031,
        "lib/features/planning/widgets/planning_day_card_list_keep_alive.dart",
        [
            "import 'package:flutter/material.dart';",
            "",
        ],
        {
            "_PlanningDayCardListKeepAlive": "PlanningDayCardListKeepAlive",
            "_PlanningDayCardListKeepAliveState": "PlanningDayCardListKeepAliveState",
        },
    ),
    (
        6033,
        6257,
        "lib/features/planning/widgets/planning_menu_overlay.dart",
        [
            "import 'dart:async';",
            "import 'dart:math' as math;",
            "",
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/services.dart';",
            "",
        ],
        {
            "_SemicirclePlanningMenuOverlay": "SemicirclePlanningMenuOverlay",
            "_SemicirclePlanningMenuOverlayState": "SemicirclePlanningMenuOverlayState",
        },
    ),
    (
        6259,
        6357,
        "lib/features/planning/settings/plan_record_link_settings.dart",
        [
            "import 'dart:async';",
            "",
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:flutter/material.dart';",
            "import 'package:shared_preferences/shared_preferences.dart';",
            "",
        ],
        {
            "_PlanRecordLinkSuggestionSettingsBlock": "PlanRecordLinkSuggestionSettingsBlock",
            "_PlanRecordLinkSuggestionSettingsBlockState":
            "PlanRecordLinkSuggestionSettingsBlockState",
        },
    ),
    (
        6359,
        6459,
        "lib/features/planning/settings/planning_no_tags_settings.dart",
        [
            "import 'dart:async';",
            "",
            "import 'package:counter/core/tag_contrast.dart';",
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:flutter/material.dart';",
            "",
        ],
        {
            "_PlanningNoTagsSettingsBlock": "PlanningNoTagsSettingsBlock",
            "_PlanningNoTagsSettingsBlockState": "PlanningNoTagsSettingsBlockState",
        },
    ),
    (
        6461,
        6529,
        "lib/features/planning/settings/default_plan_category_search.dart",
        [
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:flutter/material.dart';",
            "",
        ],
        {
            "_DefaultPlanCategoryOption": "DefaultPlanCategoryOption",
            "_DefaultPlanCategorySearchDelegate": "DefaultPlanCategorySearchDelegate",
        },
    ),
    (
        6531,
        6591,
        "lib/features/planning/settings/default_plan_timezone_search.dart",
        [
            "import 'package:counter/features/profile/timezone_settings.dart' as tz_settings;",
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:flutter/material.dart';",
            "",
        ],
        {
            "_DefaultPlanTimezoneSearchDelegate": "DefaultPlanTimezoneSearchDelegate",
        },
    ),
    (
        6593,
        6706,
        "lib/features/planning/time_view/time_view_fixed_time_settings.dart",
        [
            "import 'dart:async';",
            "",
            "import 'package:counter/data/database_service.dart';",
            "import 'package:counter/data/models.dart';",
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:flutter/material.dart';",
            "",
        ],
        {
            "_TimeViewFixedTagsSettingsBlock": "TimeViewFixedTagsSettingsBlock",
            "_TimeViewFixedTagsSettingsBlockState": "TimeViewFixedTagsSettingsBlockState",
        },
    ),
    (
        6708,
        6815,
        "lib/features/planning/settings/planning_timeline_bounds_sheet.dart",
        [
            "import 'package:counter/features/planning/planning_day_start_prefs.dart';",
            "import 'package:flutter/material.dart';",
            "",
        ],
        {
            "_PlanningTimelineBoundsSheet": "PlanningTimelineBoundsSheet",
            "_PlanningTimelineBoundsSheetState": "PlanningTimelineBoundsSheetState",
        },
    ),
    (
        6817,
        6819,
        "lib/features/planning/time_view/time_view_drag_state.dart",
        [
            "",
        ],
        {
            "_TimelineResizeEdge": "TimelineResizeEdge",
            "_TimelinePointerGesturePhase": "TimelinePointerGesturePhase",
        },
    ),
    (
        6821,
        7213,
        "lib/features/planning/time_view/time_view_interaction_block.dart",
        [
            "import 'dart:math' as math;",
            "",
            "import 'package:counter/features/planning/plan_time_gesture_contract.dart';",
            "import 'package:counter/features/planning/time_view/time_view_drag_state.dart';",
            "import 'package:flutter/foundation.dart';",
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/services.dart';",
            "",
        ],
        {
            "_TimelinePlanInteractionBlock": "TimelinePlanInteractionBlock",
            "_TimelinePlanInteractionBlockState": "TimelinePlanInteractionBlockState",
            "_TimelineResizeEdgeHandle": "TimelineResizeEdgeHandle",
            "_TimelineResizeEdgeHandleState": "TimelineResizeEdgeHandleState",
            "_TimelineResizeEdge": "TimelineResizeEdge",
            "_TimelinePointerGesturePhase": "TimelinePointerGesturePhase",
        },
    ),
    (
        7215,
        7272,
        "lib/features/planning/widgets/plan_card_reorder_settle.dart",
        [
            "import 'package:flutter/material.dart';",
            "",
        ],
        {
            "_PlanCardReorderSettle": "PlanCardReorderSettle",
            "_PlanCardReorderSettleState": "PlanCardReorderSettleState",
        },
    ),
]

IMPORTS = [
    "import 'package:counter/features/planning/settings/default_plan_category_search.dart';",
    "import 'package:counter/features/planning/settings/default_plan_timezone_search.dart';",
    "import 'package:counter/features/planning/settings/plan_record_link_settings.dart';",
    "import 'package:counter/features/planning/settings/planning_no_tags_settings.dart';",
    "import 'package:counter/features/planning/settings/planning_timeline_bounds_sheet.dart';",
    "import 'package:counter/features/planning/time_view/time_view_drag_state.dart';",
    "import 'package:counter/features/planning/time_view/time_view_fixed_time_settings.dart';",
    "import 'package:counter/features/planning/time_view/time_view_interaction_block.dart';",
    "import 'package:counter/features/planning/widgets/plan_card_reorder_settle.dart';",
    "import 'package:counter/features/planning/widgets/planning_day_card_list_keep_alive.dart';",
    "import 'package:counter/features/planning/widgets/planning_menu_overlay.dart';",
]

GLOBAL_RENAMES = {
    "_PlanningDayCardListKeepAlive": "PlanningDayCardListKeepAlive",
    "_SemicirclePlanningMenuOverlay": "SemicirclePlanningMenuOverlay",
    "_PlanRecordLinkSuggestionSettingsBlock": "PlanRecordLinkSuggestionSettingsBlock",
    "_PlanningNoTagsSettingsBlock": "PlanningNoTagsSettingsBlock",
    "_DefaultPlanCategoryOption": "DefaultPlanCategoryOption",
    "_DefaultPlanCategorySearchDelegate": "DefaultPlanCategorySearchDelegate",
    "_DefaultPlanTimezoneSearchDelegate": "DefaultPlanTimezoneSearchDelegate",
    "_TimeViewFixedTagsSettingsBlock": "TimeViewFixedTagsSettingsBlock",
    "_PlanningTimelineBoundsSheet": "PlanningTimelineBoundsSheet",
    "_TimelineResizeEdge": "TimelineResizeEdge",
    "_TimelinePointerGesturePhase": "TimelinePointerGesturePhase",
    "_TimelinePlanInteractionBlock": "TimelinePlanInteractionBlock",
    "_TimelineResizeEdgeHandle": "TimelineResizeEdgeHandle",
    "_PlanCardReorderSettle": "PlanCardReorderSettle",
}


def apply_renames(text: str, renames: dict[str, str]) -> str:
    for old, new in renames.items():
        text = text.replace(old, new)
    return text


def main() -> None:
    lines = PV.read_text(encoding="utf-8").splitlines(keepends=True)
    for start, end, rel, header, renames in EXTRACTS:
        chunk = "".join(lines[start - 1 : end])
        chunk = apply_renames(chunk, renames)
        out = ROOT / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        body = "".join(header) + chunk
        if not body.endswith("\n"):
            body += "\n"
        out.write_text(body, encoding="utf-8")
        print(f"Wrote {rel} ({end - start + 1} lines)")

    kept = lines[:6010]
    text = "".join(kept)
    if not text.endswith("\n"):
        text += "\n"

    import_block = "\n".join(IMPORTS) + "\n"
    marker = "import 'package:counter/core/widgets/plan_time_task_card.dart';"
    if marker not in text:
        raise SystemExit("import marker not found")
    text = text.replace(marker, marker + "\n" + import_block, 1)

    text = apply_renames(text, GLOBAL_RENAMES)
    PV.write_text(text, encoding="utf-8")
    print(f"Trimmed {PV} to {len(text.splitlines())} lines")


if __name__ == "__main__":
    main()
