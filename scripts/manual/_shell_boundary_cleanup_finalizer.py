from __future__ import annotations

from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def move_once(old: str, new: str) -> None:
    src = ROOT / old
    dst = ROOT / new
    dst.parent.mkdir(parents=True, exist_ok=True)
    if src.exists():
        if dst.exists():
            raise RuntimeError(f"Both old and new ownership paths exist: {old}, {new}")
        shutil.move(src, dst)
    elif not dst.exists():
        raise RuntimeError(f"Neither ownership path exists: {old}, {new}")


# Shell shared is a small shared-helper file. The old executable Paths V2 stack
# below these helpers was superseded by the first-class PathRepository/PathsPage.
write(
    "lib/app/shell/shared/shell_shared.dart",
    """import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';

// --- Shell-local time helpers (Planetary: UTC + profile offset). ---
DateTime shellDateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

bool shellSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String shellTwoDigits(int n) => n.toString().padLeft(2, '0');

DateTime shellLocalToday() =>
    DatabaseService.instance.getTimelineDeviceLocalToday();

/// Planning task opened from quick-add / draft: not yet on server (no PATCH id).
bool shellIsNewPlanningDraft(PlanningTask t) {
  if (t.id != 0) return false;
  final p = t.planRowId?.trim() ?? '';
  return p.isEmpty;
}

/// Hides a plan on the current day in optimistic merge until DELETE completes.
const String shellOptimisticPurgeDateKey = '2099-12-31';
const String shellPrefsRecordLinkSuggestionsEnabled =
    'plans_record_link_suggestions_enabled';
const String shellPrefsRecordLinkSuggestionMode =
    'plans_record_link_suggestion_mode';
const String shellPrefsRecordLinkSuggestionDismissed =
    'plans_record_link_suggestion_dismissed_record_ids';
const String shellRecordLinkSuggestionModeAsk = 'ask';
const String shellRecordLinkSuggestionModeAuto = 'auto';
""",
)

# Keep only the actual More-menu mixin and make Paths opening pure shell navigation.
more_path = "lib/app/shell/shared/shell_more_menu.dart"
more = read(more_path)
mixin_marker = "mixin ShellMoreMenu on ShellCoreLogic {"
if mixin_marker not in more:
    raise RuntimeError("ShellMoreMenu mixin marker not found")
more = "part of '../app_shell.dart';\n\n" + more[more.index(mixin_marker) :]
open_start = more.index("  void openProjectPaths() {")
more_start = more.index("  void openMoreMenu(", open_start)
more = (
    more[:open_start]
    + """  void openProjectPaths() {
    if (shellPageIndex == 6) return;
    setState(() => setShellPageIndex(6));
  }

"""
    + more[more_start:]
)
write(more_path, more)

# Data-writing transition services belong to Brain domains, not shell.
move_once(
    "lib/app/shell/shared/shell_daily_routine.dart",
    "lib/data/plans/daily_routine_service.dart",
)
move_once(
    "lib/app/shell/shared/shell_path_governance.dart",
    "lib/data/paths/legacy/path_governance_service.dart",
)

governance_path = "lib/data/paths/legacy/path_governance_service.dart"
governance = read(governance_path)
governance = governance.replace(
    "import 'shell_daily_routine.dart';",
    "import 'package:counter/data/plans/daily_routine_service.dart';",
)
write(governance_path, governance)

# Shell keeps only the explicit deferred startup call into the Brain service.
app_path = "lib/app/shell/app_shell.dart"
app = read(app_path)
app = app.replace(
    "import 'package:counter/app/shell/shared/shell_path_governance.dart';",
    "import 'package:counter/data/paths/legacy/path_governance_service.dart';",
)
override_start = app.find("  /// Paths is a real shell destination.")
if override_start != -1:
    override_end = app.index(
        "  /// Keep the real Paths item selected",
        override_start,
    )
    app = app[:override_start] + app[override_end:]
write(app_path, app)

# Existing focused contract follows behavior to its new owner paths.
test_path = "test/daily_routine_contract_test.dart"
test = read(test_path)
test = test.replace(
    "lib/app/shell/shared/shell_daily_routine.dart",
    "lib/data/plans/daily_routine_service.dart",
).replace(
    "lib/app/shell/shared/shell_path_governance.dart",
    "lib/data/paths/legacy/path_governance_service.dart",
)
write(test_path, test)

# Canonical structure map.
structure_path = "docs/APP_STRUCTURE.md"
doc = read(structure_path)
doc = doc.replace(
    "## 0. Current status (2026-08-17)",
    "## 0. Current status (2026-08-18)",
)
doc = doc.replace(
    "| **Paths ownership** | 2026-08-17: first-class UI under `lib/features/paths/`; Path domain transition adapter under `lib/data/paths/`; shell owns navigation only; opening Paths performs no migration or Planner generation |",
    "| **Paths ownership** | 2026-08-18: first-class UI under `lib/features/paths/`; Path repository + marker-era compatibility/governance under `lib/data/paths/`; shell owns navigation only; opening Paths performs no migration or Planner generation |",
)
doc = doc.replace(
    "| `app/shell/shared/shell_more_menu.dart` | More bottom sheet plus retained transition Path code; new Paths UI is owned by `features/paths/` *(part)* |",
    "| `app/shell/shared/shell_more_menu.dart` | More bottom sheet and shell navigation actions only; Paths opens shell destination 6 *(part)* |",
)
for stale in (
    "| `app/shell/shared/shell_path_governance.dart` | Transition Path audit and Path-action → Planner orchestration; first-class Paths does not invoke it on page open |\n",
    "| `app/shell/shared/shell_daily_routine.dart` | One-time bootstrap for baseline personal daily recurring Planner series; preserves existing/user-edited recurrence |\n",
):
    doc = doc.replace(stale, "")

plan_row = "| `plans/daily_routine_service.dart` | Baseline personal recurring Planner series bootstrap and legacy dedupe; Brain-owned mutation service, not shell UI |"
plan_anchor = "| `plans/diagnostics/plan_duplicate_log.dart` | Planning-domain duplicate / stream lifecycle markers inside Brain (not shared diagnostics, not feature UI) |"
if plan_row not in doc:
    if plan_anchor not in doc:
        raise RuntimeError("Plans structure anchor not found")
    doc = doc.replace(plan_anchor, plan_row + "\n" + plan_anchor)

legacy_row = "| `paths/legacy/path_governance_service.dart` | Marker-era Path audit and Path-action → Planner compatibility orchestration; isolated from shell and not invoked by opening Paths |"
path_anchor = "| `paths/path_repository.dart` | First-class Path domain boundary: transition storage interpretation, explicit Path/stage/action snapshots, duplicate-root reporting, generic structure audit, writes delegated to existing Brain plan APIs |"
if legacy_row not in doc:
    if path_anchor not in doc:
        raise RuntimeError("Path structure anchor not found")
    doc = doc.replace(path_anchor, path_anchor + "\n" + legacy_row)
write(structure_path, doc)

# Governing architecture records the transitional compatibility boundary.
architecture_path = "docs/ARCHITECTURE.md"
arch = read(architecture_path)
arch = arch.replace(
    "| `lib/data/paths/` | **Path domain** | `PathRepository` owns first-class Path interpretation and generic validation. Current storage is an adapter over existing plan-backed Path rows; feature UI must not parse marker rows directly. |",
    "| `lib/data/paths/` | **Path domain** | `PathRepository` owns first-class Path interpretation and generic validation. Current storage is an adapter over existing plan-backed Path rows; marker-era Path → Planner compatibility is isolated under `paths/legacy/`; feature UI and shell must not parse marker rows directly. |",
)
planner_note = "- Marker-era audit and Path-action → Planner orchestration is transitional Brain logic under `lib/data/paths/legacy/`; it is never a shell/page-open responsibility and must disappear when durable Path revisions + the explicit Planner bridge replace it."
anchor = "- The current `PathRepository` is a compatibility adapter over existing plan-backed Path roots; this does **not** redefine `plans` as the permanent Path schema."
if planner_note not in arch:
    if anchor not in arch:
        raise RuntimeError("Paths → Planner architecture anchor not found")
    arch = arch.replace(anchor, anchor + "\n" + planner_note)
write(architecture_path, arch)

# Engineering journal: ownership-only change, no feature behavior claim.
changelog_path = "CHANGELOG.md"
changelog = read(changelog_path)
entry = """## 2026-08-18 — Shell / Paths ownership cleanup [engineering]

- Removed the retired embedded Paths V2/V3 UI/bootstrap stack from `shell_shared.dart` and `shell_more_menu.dart`; shell now only navigates to the first-class `PathsPage` destination.
- Moved marker-era Path → Planner compatibility/governance to `lib/data/paths/legacy/` and daily-routine Planner bootstrap to `lib/data/plans/` without changing their scheduling/dedupe behavior or running them on Paths open.
- Updated canonical architecture/structure docs and the existing focused contract test to the new owners.

"""
if not changelog.startswith("## 2026-08-18 — Shell / Paths ownership cleanup [engineering]"):
    changelog = entry + changelog
write(changelog_path, changelog)
