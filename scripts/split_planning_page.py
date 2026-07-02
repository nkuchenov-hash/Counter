#!/usr/bin/env python3
"""Split planning_view.dart into shell + page modules."""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
PV = ROOT / "lib" / "features" / "planning" / "planning_view.dart"

SHELL_HEADER = """// Planning date pager shell — wraps [PlanningPage] per day.
import 'dart:async';

import 'package:counter/core/date_pager_settle_gate.dart';
import 'package:counter/core/date_swipe_physics.dart';
import 'package:counter/core/performance/runtime_flags.dart';
import 'package:counter/core/diagnostics/runtime_log.dart';
import 'package:counter/core/diagnostics/platform_log.dart';
import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/planning_page.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;

"""

PAGE_HEADER = """// Single-day Planning tab body (task list, Time View, quick-add).
"""

BARREL = """// Planning feature barrel — re-exports shell + page entry points.
export 'planning_page.dart';
export 'planning_page_shell.dart';
export 'planning_sort_mode.dart';
"""


def main() -> None:
    lines = PV.read_text(encoding="utf-8").splitlines(keepends=True)

    # Find line with `class PlanningSwipeWrapper`
    shell_start = next(i for i, l in enumerate(lines) if l.startswith("class PlanningSwipeWrapper"))
    page_start = next(i for i, l in enumerate(lines) if l.startswith("class PlanningPage"))

    shell_body = "".join(lines[shell_start:page_start])
    page_body = "".join(lines[page_start:])

    (ROOT / "lib/features/planning/planning_page_shell.dart").write_text(
        SHELL_HEADER + shell_body,
        encoding="utf-8",
    )

    # page_body already has imports at top from original file - keep them
    page_imports_end = next(
        i for i, l in enumerate(lines) if l.startswith("/// Scheduled Time View canvas")
    )
    page_imports = "".join(lines[:page_imports_end])
    (ROOT / "lib/features/planning/planning_page.dart").write_text(
        PAGE_HEADER + page_imports + page_body,
        encoding="utf-8",
    )

    (ROOT / "lib/features/planning/planning_view.dart").write_text(BARREL, encoding="utf-8")

    print(
        "planning_page_shell:",
        len((SHELL_HEADER + shell_body).splitlines()),
        "planning_page:",
        len((PAGE_HEADER + page_imports + page_body).splitlines()),
    )


if __name__ == "__main__":
    main()
