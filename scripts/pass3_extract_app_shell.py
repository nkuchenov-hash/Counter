#!/usr/bin/env python3
"""Pass 3 — split lib/app_shell.dart into lib/shell/ modules."""
from __future__ import annotations

import pathlib
import re
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHELL = ROOT / "lib" / "shell"
SRC = ROOT / "lib" / "app_shell.dart"

STATE_FIELDS = [
    ("_shellPageIndex", "shellPageIndex"),
    ("_navBarSelectedIndex", "navBarSelectedIndex"),
    ("_shellTabDiagnosticLabel", "shellTabDiagnosticLabel"),
    ("_selectedDate", "selectedDate"),
    ("_focusedDay", "focusedDay"),
    ("_tasks", "tasks"),
    ("_tasksLoading", "tasksLoading"),
    ("_selectedDateListenable", "selectedDateListenable"),
    ("_timelineTasksRevision", "timelineTasksRevision"),
    ("_shellPageIndexListenable", "shellPageIndexListenable"),
    ("_timelineTabHost", "timelineTabHost"),
    ("_planningTabHost", "planningTabHost"),
    ("_calendarTabHost", "calendarTabHost"),
    ("_listsTabHost", "listsTabHost"),
    ("_rules", "rules"),
    ("_selectedCategoryId", "selectedCategoryId"),
    ("_titleController", "titleController"),
    ("_titleFocus", "titleFocus"),
    ("_notificationSub", "notificationSub"),
    ("_categoryRulesSub", "categoryRulesSub"),
    ("_shellLayout", "shellLayout"),
    ("_speech", "speech"),
    ("_speechHandle", "speechHandle"),
    ("_speechReady", "speechReady"),
    ("_speechLastInitError", "speechLastInitError"),
    ("_isVoiceListening", "isVoiceListening"),
    ("_speechStatusCallback", "speechStatusCallback"),
    ("_deviceLocalMidnightWatchTimer", "deviceLocalMidnightWatchTimer"),
    ("_deviceTodayAtLastMidnightCheck", "deviceTodayAtLastMidnightCheck"),
    ("_deviceLocalDayKeyLast", "deviceLocalDayKeyLast"),
    ("_lastPlayOrStartAction", "lastPlayOrStartAction"),
    ("_playStartDebounce", "playStartDebounce"),
    ("_lastStopRecordAction", "lastStopRecordAction"),
    ("_stopRecordDebounce", "stopRecordDebounce"),
    ("_lastSyncFailedSnackAt", "lastSyncFailedSnackAt"),
    ("_syncFailedSnackThrottle", "syncFailedSnackThrottle"),
    ("_selectedDateString", "selectedDateString"),
    ("_timelineVoiceDateKey", "timelineVoiceDateKey"),
    ("_isFutureDate", "isFutureDate"),
    ("_effectiveCategoryId", "effectiveCategoryId"),
]

HELPER_RENAMES = [
    ("_dateOnly", "shellDateOnly"),
    ("_sameCalendarDay", "shellSameCalendarDay"),
    ("_two", "shellTwoDigits"),
    ("_localToday", "shellLocalToday"),
    ("_shellIsNewPlanningDraft", "shellIsNewPlanningDraft"),
    ("_shellOptimisticPurgeDateKey", "shellOptimisticPurgeDateKey"),
    ("_prefsRecordLinkSuggestionsEnabled", "shellPrefsRecordLinkSuggestionsEnabled"),
    ("_prefsRecordLinkSuggestionMode", "shellPrefsRecordLinkSuggestionMode"),
    ("_prefsRecordLinkSuggestionDismissed", "shellPrefsRecordLinkSuggestionDismissed"),
    ("_recordLinkSuggestionModeAsk", "shellRecordLinkSuggestionModeAsk"),
    ("_recordLinkSuggestionModeAuto", "shellRecordLinkSuggestionModeAuto"),
]

DASH_PUBLIC_METHODS = [
    "_categoryVisibilityShellListener",
    "_onDeviceLocalCalendarDayWatchTick",
    "_setShellPageIndex",
    "_applySharedSelectedDate",
    "_loadTasksAndExtras",
    "_selectShellHeaderDate",
    "_loadTasksForDate",
    "_saveTasks",
    "_showSyncFailedSnackBar",
    "_retryWriteNewTask",
    "_startTaskFromInput",
    "_planTaskFromInput",
    "_stopTask",
    "_deleteRecordByDocId",
    "_stopRecordByDocId",
    "_stopAnyActiveTask",
    "_recordLinkPrefs",
    "_recordLinkSuggestionsEnabled",
    "_recordLinkSuggestionMode",
    "_recordLinkSuggestionDismissed",
    "_markRecordLinkSuggestionDismissed",
    "_disableRecordLinkSuggestions",
    "_showSourcePlanSuggestionSnack",
    "_patchSuggestedSourcePlanLink",
    "_deferSourcePlanLinkAfterFreeStart",
    "_startRecordFromPlanning",
    "_jumpToConflictDate",
]

NAV_METHODS = [
    "_onShellTabSelected",
    "_onDesktopSideNavSelected",
    "_desktopSideNavSelectedIndex",
]

EXT_METHODS = {
    "shell_core.dart": DASH_PUBLIC_METHODS,
    "shell_tab_host.dart": [
        "_buildTimelineSwipeTab",
        "_buildPlanningSwipeTab",
        "_buildCalendarTab",
        "_buildListsTab",
    ],
    "shell_edit_hosts.dart": [
        "_openNewTaskForPastDate",
        "_showEditRecordSheetForTimeline",
        "_openEditDialog",
        "_persistPlanningEditFromSheet",
        "_deletePlanningTaskOptimisticFollowUp",
    ],
    "shell_more_menu.dart": ["_openMoreMenu", *NAV_METHODS],
    "shell_voice_routing.dart": [
        "_refreshDesktopTrayMenu",
        "_initDesktopVoiceLayer",
        "_onDesktopVoiceHotkeyToggle",
        "_runDesktopVoiceAcceptanceCommand",
        "_reattachDesktopVoiceHotkey",
        "_retryVoiceWriteNewTask",
        "_retryVoicePlanningTask",
        "_retryVoiceBacklogTask",
        "_voiceSubmitTimeline",
        "_voiceSubmitPlanning",
        "_voiceSubmitBacklog",
        "_ensureSpeechReady",
        "_speechEngineHardReset",
        "_initializeSpeechInstance",
        "_logSttLocalesBestEffortWeb",
        "_desktopVoiceSubmitParsed",
        "_desktopVoiceUndoStop",
        "_desktopVoiceHotkeyStopRunning",
        "_toggleDesktopVoiceWidget",
        "_openDesktopVoiceOverlay",
        "_startVoiceInput",
    ],
}

PART_IMPORTS: dict[str, str] = {}  # imports live in library file only

LIBRARY_IMPORTS = """import 'dart:async';
import 'dart:io' show exit, Platform;

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/diagnostics/desktop_voice_log.dart';
import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/diagnostics/startup_log.dart';
import 'package:counter/core/navigation/app_navigator.dart';
import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/performance/runtime_flags.dart';
import 'package:counter/core/performance/shell_flags.dart';
import 'package:counter/core/services/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_tray_service.dart';
import 'package:counter/core/services/desktop_voice_acceptance_bridge.dart';
import 'package:counter/core/services/desktop_voice_confirmation.dart';
import 'package:counter/core/services/desktop_voice_overlay_bridge.dart';
import 'package:counter/core/services/desktop_voice_overlay_host.dart';
import 'package:counter/core/services/desktop_voice_record_submit.dart';
import 'package:counter/core/services/desktop_voice_hotkey.dart';
import 'package:counter/core/services/desktop_voice_hotkey_markers.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:counter/core/services/desktop_voice_smoke_bridge.dart';
import 'package:counter/core/services/speech_engine_handle.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/core/widgets/lazy_indexed_stack.dart';
import 'package:counter/core/widgets/tag_display_mode_scope.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:counter/features/calendar/calendar_view.dart';
import 'package:counter/features/categories/category_list_view.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/features/dev/component_lab_view.dart';
import 'package:counter/features/lists/lists_view.dart';
import 'package:counter/features/planning/planning_view.dart';
import 'package:counter/features/profile/desktop_voice_attempt_dialog.dart';
import 'package:counter/features/profile/profile_view.dart';
import 'package:counter/features/shared/desktop_voice_widget.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/features/shared/voice_capture_config.dart';
import 'package:counter/features/shared/voice_input_sheet.dart';
import 'package:counter/features/timeline/timeline_view.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shell/shell_offline_banner.dart';
import 'package:counter/shell/shell_shared.dart';
import 'package:counter/shell/shell_side_navigation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
"""


def find_method_block(lines: list[str], method_name: str) -> tuple[int, int]:
    pat = re.compile(
        rf"^  (?:Future<[\w<>,\?\s]+>|void|Widget|bool|int|String\??|Future<bool>) {re.escape(method_name)}\b"
    )
    start = next(i for i, l in enumerate(lines) if pat.match(l))
    depth = 0
    started = False
    for i in range(start, len(lines)):
        line = lines[i]
        if "{" in line:
            depth += line.count("{")
            started = True
        if "}" in line:
            depth -= line.count("}")
        if started and depth == 0:
            return start, i + 1
    raise RuntimeError(f"Could not find end of {method_name}")


def apply_renames(text: str) -> str:
    for old, new in HELPER_RENAMES:
        text = text.replace(old, new)
    for old, new in STATE_FIELDS:
        text = text.replace(old, new)
    return text


def strip_method_underscore(name: str) -> str:
    return name[1:] if name.startswith("_") else name


def all_public_method_names() -> list[str]:
    names = list(DASH_PUBLIC_METHODS)
    for group in EXT_METHODS.values():
        names.extend(group)
    return names


def publicize_methods(text: str, names: list[str] | None = None) -> str:
    if names is None:
        names = all_public_method_names()
    for n in names:
        pub = strip_method_underscore(n)
        text = re.sub(rf"\b{re.escape(n)}\b", pub, text)
    return text


def extract_methods(lines: list[str], names: list[str]) -> str:
    chunks: list[str] = []
    for name in names:
        s, e = find_method_block(lines, name)
        chunk = apply_renames("".join(lines[s:e]))
        chunk = publicize_methods(chunk, [name])
        chunks.append(chunk)
    return "\n".join(chunks)


def mixin_name(fname: str) -> str:
    if fname == "shell_core.dart":
        return "ShellCoreLogic"
    parts = fname.replace(".dart", "").split("_")
    return "".join(p.capitalize() for p in parts)


def main() -> None:
    raw = SRC.read_text(encoding="utf-8")
    if "class LifeOSDashboard" not in raw:
        raw = (ROOT / "lib" / "app_shell.dart.bak").read_text(encoding="utf-8")
        if "class LifeOSDashboard" not in raw:
            raise SystemExit("Restore app_shell.dart from git before re-running.")
    lines = raw.splitlines(keepends=True)

    SHELL.mkdir(parents=True, exist_ok=True)

    shared_end = next(i for i, l in enumerate(lines) if l.startswith("class LifeOSDashboard"))
    shared_body = apply_renames("".join(lines[63:shared_end]))
    shared_header = """import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';

"""
    (SHELL / "shell_shared.dart").write_text(shared_header + shared_body, encoding="utf-8")

    extracted_ranges: list[tuple[int, int]] = []
    mixin_names: list[str] = []
    for fname, names in EXT_METHODS.items():
        mname = mixin_name(fname)
        mixin_names.append(mname)
        body = extract_methods(lines, names)
        for n in names:
            extracted_ranges.append(find_method_block(lines, n))
        part_header = "part of 'life_os_dashboard.dart';\n\n"
        content = part_header + (
            f"mixin {mname} on ShellDashboardBase {{\n{body}}}\n"
            if fname == "shell_core.dart"
            else f"mixin {mname} on ShellCoreLogic {{\n{body}}}\n"
        )
        (SHELL / fname).write_text(content, encoding="utf-8")

    offline = """import 'package:counter/features/shared/offline_sync_status_bar.dart';
import 'package:counter/shell/profile_hydration_status_bar.dart';
import 'package:flutter/material.dart';

/// Top-of-shell status strip: profile hydration + offline sync banner.
class ShellTopStatusBars extends StatelessWidget {
  const ShellTopStatusBars({super.key, required this.routeTab});

  final String routeTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProfileHydrationStatusBar(),
        OfflineSyncStatusBar(routeTab: routeTab),
      ],
    );
  }
}
"""
    (SHELL / "shell_offline_banner.dart").write_text(offline, encoding="utf-8")

    shutil.copy2(
        ROOT / "lib/core/navigation/shell_side_navigation.dart",
        SHELL / "shell_side_navigation.dart",
    )
    shutil.copy2(
        ROOT / "lib/features/shared/profile_hydration_status_bar.dart",
        SHELL / "profile_hydration_status_bar.dart",
    )
    settings_src = ROOT / "lib/features/profile/settings/settings_page.dart"
    settings_text = settings_src.read_text(encoding="utf-8")
    if settings_text.startswith("export "):
        settings_text = (ROOT / "lib" / "features" / "profile" / "settings" / "settings_page.dart.bak").read_text(encoding="utf-8") if (ROOT / "lib" / "features" / "profile" / "settings" / "settings_page.dart.bak").exists() else settings_text
    marker = "// ---------------------------------------------------------------------------\n// LifeOS Dashboard"
    if marker in settings_text:
        settings_text = settings_text.split(marker)[0].rstrip() + "\n"
    (SHELL / "settings_page.dart").write_text(settings_text, encoding="utf-8")

    (ROOT / "lib/core/navigation/shell_side_navigation.dart").write_text(
        "export 'package:counter/shell/shell_side_navigation.dart';\n",
        encoding="utf-8",
    )
    (ROOT / "lib/features/shared/profile_hydration_status_bar.dart").write_text(
        "export 'package:counter/shell/profile_hydration_status_bar.dart';\n",
        encoding="utf-8",
    )
    (ROOT / "lib/features/profile/settings/settings_page.dart").write_text(
        "export 'package:counter/shell/settings_page.dart';\n",
        encoding="utf-8",
    )

    state_start = next(i for i, l in enumerate(lines) if l.startswith("class _LifeOSDashboardState"))
    state_end = next(i for i, l in enumerate(lines) if l.startswith("class _DesktopVoiceCommandIntent"))
    state_lines = lines[state_start:state_end]

    # Fields block ends at initState.
    init_idx = next(
        i
        for i, l in enumerate(state_lines)
        if l.strip() == "@override" and i + 1 < len(state_lines) and "void initState" in state_lines[i + 1]
    )
    fields_block = apply_renames("".join(state_lines[:init_idx]))
    fields_block = fields_block.replace(
        "class _LifeOSDashboardState extends State<LifeOSDashboard> {\n", ""
    )
    fields_mixin = f"mixin ShellDashboardBase on State<LifeOSDashboard> {{\n{fields_block}}}\n"

    remove_set = set()
    for s, e in extracted_ranges:
        for i in range(s, e):
            remove_set.add(i)

    kept_state: list[str] = []
    for i, l in enumerate(state_lines):
        idx = state_start + i
        if idx in remove_set:
            continue
        if i < init_idx:
            continue  # fields moved to ShellDashboardBase
        kept_state.append(l)

    state_text = apply_renames("".join(kept_state))
    state_text = state_text.replace(
        "class ShellDashboardState extends State<LifeOSDashboard> {\n", ""
    )
    state_text = state_text.replace("_LifeOSDashboardState", "ShellDashboardState")
    state_text = publicize_methods(state_text)
    state_text = state_text.replace(
        "setState(() => rules = List.from(rules));",
        "setState(() => this.rules = List.from(rules));",
    )
    state_text = state_text.replace("_buildTimelineSwipeTab()", "buildTimelineSwipeTab()")
    state_text = state_text.replace("_buildPlanningSwipeTab()", "buildPlanningSwipeTab()")
    state_text = state_text.replace("_buildCalendarTab()", "buildCalendarTab()")
    state_text = state_text.replace("_buildListsTab()", "buildListsTab()")
    state_text = state_text.replace(
        "ProfileHydrationStatusBar(),\n                        OfflineSyncStatusBar(\n                          routeTab: shellTabDiagnosticLabel(shellPageIndex),\n                        ),",
        "ShellTopStatusBars(\n                          routeTab: shellTabDiagnosticLabel(shellPageIndex),\n                        ),",
    )
    state_text = state_text.replace("_DesktopVoiceCommandIntent", "DesktopVoiceCommandIntent")

    part_lines = "".join(f"part '{fname}';\n" for fname in EXT_METHODS)
    dashboard_header = f"""// Life OS dashboard — shell state + build chrome.
library counter.shell.dashboard;

{LIBRARY_IMPORTS}
{part_lines}
"""

    intent_block = """
class DesktopVoiceCommandIntent extends Intent {
  const DesktopVoiceCommandIntent();
}
"""

    core_mixin = mixin_name("shell_core.dart")
    feature_mixins = [mixin_name(f) for f in EXT_METHODS if f != "shell_core.dart"]
    all_mixins = ["ShellDashboardBase", core_mixin, *feature_mixins]

    life_os = (
        dashboard_header
        + fields_mixin
        + """
class LifeOSDashboard extends StatefulWidget {
  const LifeOSDashboard({super.key});

  @override
  State<LifeOSDashboard> createState() => ShellDashboardState();
}

"""
        + f"class ShellDashboardState extends State<LifeOSDashboard> with {', '.join(all_mixins)} {{\n"
        + state_text
        + intent_block
    )

    (SHELL / "life_os_dashboard.dart").write_text(life_os, encoding="utf-8")

    pub_names = all_public_method_names()
    for fname in EXT_METHODS:
        path = SHELL / fname
        text = path.read_text(encoding="utf-8")
        if "mixin " in text:
            head, body = text.split("mixin ", 1)
            body = "mixin " + publicize_methods(body, pub_names)
            path.write_text(head + body, encoding="utf-8")

    # Cross-mixin tear-offs in tab host (edit methods live on ShellEditHosts).
    tab_path = SHELL / "shell_tab_host.dart"
    tab_text = tab_path.read_text(encoding="utf-8")
    for sym in (
        "openNewTaskForPastDate",
        "showEditRecordSheetForTimeline",
        "openEditDialog",
    ):
        tab_text = tab_text.replace(
            f"{sym},",
            f"(this as ShellDashboardState).{sym},",
        )
        tab_text = tab_text.replace(
            f"(task) => {sym}(task)",
            f"(task) => (this as ShellDashboardState).{sym}(task)",
        )
    tab_path.write_text(tab_text, encoding="utf-8")

    SRC.write_text(
        "// APP SHELL — thin entry; dashboard lives under lib/shell/.\n"
        "export 'package:counter/shell/life_os_dashboard.dart';\n",
        encoding="utf-8",
    )

    print("Pass 3 app_shell extraction complete.")
    for p in sorted(SHELL.glob("*.dart")):
        n = len(p.read_text(encoding="utf-8").splitlines())
        print(f"  {p.relative_to(ROOT)}: {n} lines")
    print(f"  lib/app_shell.dart: 2 lines")


if __name__ == "__main__":
    main()
