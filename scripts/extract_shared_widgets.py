#!/usr/bin/env python3
"""Extract shared edit-sheet modules from shared_widgets.dart (structure pass)."""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SW = ROOT / "lib" / "features" / "shared" / "shared_widgets.dart"

COMMON_IMPORTS = """import 'dart:async';
import 'dart:convert';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/omni_date_time_picker_dialog.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:counter/data/smart_input_parser.dart';
import 'package:counter/features/planning/recurrence_scope_dialog.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import 'package:url_launcher/url_launcher.dart';

"""

REPEAT_RENAMES = {
    "_PlanRepeatUi": "PlanRepeatUi",
    "_planRruleForUiParse": "planRruleForUiParse",
    "_rruleHasFreqWeekly": "rruleHasFreqWeekly",
    "_rruleHasBydayClause": "rruleHasBydayClause",
    "_bydayClauseValue": "bydayClauseValue",
    "_isWeekdaysMoToFrRrule": "isWeekdaysMoToFrRrule",
    "_planRepeatUiFromTask": "planRepeatUiFromTask",
    "_rruleWireFromRepeatUi": "rruleWireFromRepeatUi",
}

CHECKLIST_RENAMES = {
    "_syncChecklistDoneLength": "syncChecklistDoneLength",
    "_partitionChecklistRowsByDone": "partitionChecklistRowsByDone",
    "_removeChecklistRowAt": "removeChecklistRowAt",
}

SHEET_RENAMES = {
    **REPEAT_RENAMES,
    **CHECKLIST_RENAMES,
    "_launchUrlFromQuillEditor": "launchUrlFromQuillEditor",
    "_planningTaskEditQuillToolbarConfig": "planningTaskEditQuillToolbarConfig",
    "_clampDay": "clampPickerDay",
    "_shortMonths": "kShortMonths",
}

EXTRACTS: list[tuple[int, int, str, list[str], dict[str, str]]] = [
    (
        29,
        37,
        "lib/features/shared/edit_sheet/quill_link_launcher.dart",
        [
            "import 'package:url_launcher/url_launcher.dart';",
            "",
        ],
        {"_launchUrlFromQuillEditor": "launchUrlFromQuillEditor"},
    ),
    (
        39,
        50,
        "lib/features/shared/edit_sheet/sheet_time_helpers.dart",
        [
            "import 'package:intl/intl.dart';",
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:counter/data/database_service.dart';",
            "",
        ],
        {},
    ),
    (
        52,
        85,
        "lib/features/shared/edit_sheet/sheet_autosave_gate.dart",
        ["import 'dart:async';", ""],
        {},
    ),
    (
        87,
        212,
        "lib/features/shared/edit_sheet/sheet_time_picker.dart",
        [
            "import 'package:counter/core/picker_entry_modes.dart';",
            "import 'package:counter/core/widgets/omni_date_time_picker_dialog.dart';",
            "import 'package:counter/data/database_service.dart';",
            "import 'package:flutter/material.dart';",
            "import 'package:omni_datetime_picker/omni_datetime_picker.dart';",
            "",
        ],
        {"_clampDay": "clampPickerDay", "_shortMonths": "kShortMonths"},
    ),
    (
        214,
        259,
        "lib/features/shared/edit_sheet/quill_toolbar_config.dart",
        [
            "import 'package:counter/core/theme.dart';",
            "import 'package:flutter/material.dart';",
            "import 'package:flutter_quill/flutter_quill.dart';",
            "",
        ],
        {"_planningTaskEditQuillToolbarConfig": "planningTaskEditQuillToolbarConfig"},
    ),
    (
        261,
        330,
        "lib/features/shared/edit_sheet/checklist_helpers.dart",
        ["import 'package:flutter/material.dart';", ""],
        CHECKLIST_RENAMES,
    ),
    (
        332,
        425,
        "lib/features/shared/empty_state_placeholder.dart",
        [
            "import 'package:counter/l10n/dictionary.dart';",
            "import 'package:flutter/material.dart';",
            "",
        ],
        {},
    ),
    (
        430,
        513,
        "lib/features/shared/edit_sheet/plan_repeat_helpers.dart",
        [
            "import 'package:counter/data/models.dart';",
            "",
        ],
        REPEAT_RENAMES,
    ),
    (
        559,
        2283,
        "lib/features/shared/planning_task_edit_sheet.dart",
        [
            COMMON_IMPORTS,
            "import 'package:counter/features/shared/edit_sheet/checklist_helpers.dart';",
            "import 'package:counter/features/shared/edit_sheet/plan_repeat_helpers.dart';",
            "import 'package:counter/features/shared/edit_sheet/quill_link_launcher.dart';",
            "import 'package:counter/features/shared/edit_sheet/quill_toolbar_config.dart';",
            "import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';",
            "import 'package:counter/features/shared/edit_sheet/sheet_time_helpers.dart';",
            "import 'package:counter/features/shared/edit_sheet/sheet_time_picker.dart';",
            "",
        ],
        {
            **SHEET_RENAMES,
            "_PlanningTaskEditSheet": "PlanningTaskEditSheet",
            "_PlanningTaskEditSheetState": "PlanningTaskEditSheetState",
        },
    ),
    (
        2285,
        3361,
        "lib/features/shared/timeline_record_edit_sheet.dart",
        [
            COMMON_IMPORTS,
            "import 'package:counter/features/shared/edit_sheet/checklist_helpers.dart';",
            "import 'package:counter/features/shared/edit_sheet/quill_link_launcher.dart';",
            "import 'package:counter/features/shared/edit_sheet/quill_toolbar_config.dart';",
            "import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';",
            "import 'package:counter/features/shared/edit_sheet/sheet_time_helpers.dart';",
            "import 'package:counter/features/shared/edit_sheet/sheet_time_picker.dart';",
            "",
        ],
        {
            **SHEET_RENAMES,
            "_TimelineRecordSheetContent": "TimelineRecordSheetContent",
            "_TimelineRecordSheetContentState": "TimelineRecordSheetContentState",
        },
    ),
    (
        3363,
        3916,
        "lib/features/shared/edit_sheet/parallel_record_panels.dart",
        [
            COMMON_IMPORTS,
            "import 'package:counter/features/shared/edit_sheet/sheet_time_helpers.dart';",
            "",
        ],
        {
            "_BacklogSubItemsPanel": "BacklogSubItemsPanel",
            "_BacklogSubItemsPanelState": "BacklogSubItemsPanelState",
            "_ParallelActivitiesTab": "ParallelActivitiesTab",
            "_ParallelActivitiesTabState": "ParallelActivitiesTabState",
            "_ChildParallelEditBar": "ChildParallelEditBar",
            "_ChildParallelEditBarState": "ChildParallelEditBarState",
        },
    ),
]

BARREL = """// ---------------------------------------------------------------------------
// SHARED UI — barrel re-exports for Timeline, Planning, Categories sheets.
// ---------------------------------------------------------------------------

export 'activity_detail_sheet.dart';
export 'empty_state_placeholder.dart';
export 'planning_task_edit_sheet.dart';
export 'timeline_record_edit_sheet.dart';
export 'edit_sheet/checklist_helpers.dart';
export 'edit_sheet/parallel_record_panels.dart';
export 'edit_sheet/plan_repeat_helpers.dart';
export 'edit_sheet/quill_link_launcher.dart';
export 'edit_sheet/quill_toolbar_config.dart';
export 'edit_sheet/sheet_autosave_gate.dart';
export 'edit_sheet/sheet_time_helpers.dart';
export 'edit_sheet/sheet_time_picker.dart';
"""


def apply_renames(text: str, renames: dict[str, str]) -> str:
    for old, new in renames.items():
        text = text.replace(old, new)
    return text


def extract_range(lines: list[str], start: int, end: int) -> str:
    return "".join(lines[start - 1 : end])


def main() -> None:
    lines = SW.read_text(encoding="utf-8").splitlines(keepends=True)

    for start, end, rel, header, renames in EXTRACTS:
        chunk = apply_renames(extract_range(lines, start, end), renames)
        out = ROOT / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        body = "".join(header) + chunk
        if not body.endswith("\n"):
            body += "\n"
        out.write_text(body, encoding="utf-8")
        print(f"Wrote {rel} ({end - start + 1} lines)")

    router = extract_range(lines, 427, 427) + extract_range(lines, 515, 557)
    router = apply_renames(
        router,
        {
            "_PlanningTaskEditSheet": "PlanningTaskEditSheet",
            "_TimelineRecordSheetContent": "TimelineRecordSheetContent",
        },
    )
    router_path = ROOT / "lib/features/shared/activity_detail_sheet.dart"
    router_path.write_text(
        "import 'package:counter/data/models.dart';\n"
        "import 'package:counter/features/shared/planning_task_edit_sheet.dart';\n"
        "import 'package:counter/features/shared/timeline_record_edit_sheet.dart';\n"
        "import 'package:flutter/material.dart';\n\n"
        + router,
        encoding="utf-8",
    )
    print("Wrote activity_detail_sheet.dart")

    SW.write_text(BARREL, encoding="utf-8")
    print(f"shared_widgets.dart barrel: {len(BARREL.splitlines())} lines")


if __name__ == "__main__":
    main()
