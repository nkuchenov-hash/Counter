#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one regex match, found {count}")
    return updated


# ---------------------------------------------------------------------------
# 1) Edit-sheet P0: title typing must not mutate selected time and must not
#    rebuild/refresh the entire Planning surface on every keystroke.
# ---------------------------------------------------------------------------
path = "lib/features/shared/planning_task_edit_sheet.dart"
text = read(path)

text = text.replace(
    "import 'package:counter/data/smart_input_parser.dart';\n",
    "",
    1,
)

text = replace_once(
    text,
    "  StreamSubscription<DocChange>? _planQuillChangesSub;\n",
    "  StreamSubscription<DocChange>? _planQuillChangesSub;\n"
    "  Timer? _titleAssistDebounce;\n",
    "planning edit title debounce field",
)

text = replace_once(
    text,
    "    unawaited(_planQuillChangesSub?.cancel());\n",
    "    unawaited(_planQuillChangesSub?.cancel());\n"
    "    _titleAssistDebounce?.cancel();\n",
    "planning edit title debounce dispose",
)

text = regex_once(
    text,
    r"  void _onTitleChangedForSmartTime\(String raw\) \{.*?\n  \}\n\n  Future<void> _openTagManagerAndReload",
    "  void _onTitleChanged(String raw) {\n"
    "    // Title input owns title/category only. A time selected on the Time View\n"
    "    // grid may change only through an explicit time control. Debounce fuzzy\n"
    "    // category matching so typing does not scan the category tree per key.\n"
    "    _titleAssistDebounce?.cancel();\n"
    "    _titleAssistDebounce = Timer(const Duration(milliseconds: 450), () {\n"
    "      if (!mounted) return;\n"
    "      _applyFuzzyCategoryFromTitle(\n"
    "        raw.trim().isEmpty ? _titleController.text : raw,\n"
    "      );\n"
    "    });\n"
    "    _onPlanFieldChanged();\n"
    "  }\n\n"
    "  Future<void> _openTagManagerAndReload",
    "planning edit title handler",
)

text = replace_once(
    text,
    "                    onChanged: _onTitleChangedForSmartTime,\n",
    "                    onChanged: _onTitleChanged,\n",
    "planning edit title callback",
)

text = regex_once(
    text,
    r"  void _onPlanFieldChanged\(\{bool immediate = false\}\) \{.*?\n  \}\n\n  bool _planDraftsSemanticallyEqual",
    "  void _onPlanFieldChanged({bool immediate = false}) {\n"
    "    // New drafts are committed once by the shell on explicit Save. Building a\n"
    "    // Quill/checklist draft on every keypress is wasted work on web.\n"
    "    if (!_isPersistedPlan) return;\n\n"
    "    void applyAndSync(PlanningTask draft) {\n"
    "      _applyPlanDraftLocally(draft);\n"
    "      unawaited(_syncPlanDraftToNetwork(draft));\n"
    "    }\n\n"
    "    if (immediate) {\n"
    "      final draft = _buildDraftTask();\n"
    "      if (draft == null) return;\n"
    "      _planAutosaveGate.markDirty();\n"
    "      _planAutosaveGate.flush(() => applyAndSync(draft));\n"
    "      return;\n"
    "    }\n\n"
    "    // Text/notes/checklist typing updates the visible field immediately, but\n"
    "    // coalesces the expensive global optimistic merge + Planning refresh.\n"
    "    _planAutosaveGate.schedule(() {\n"
    "      final latest = _buildDraftTask();\n"
    "      if (latest != null) {\n"
    "        applyAndSync(latest);\n"
    "      }\n"
    "    });\n"
    "  }\n\n"
    "  bool _planDraftsSemanticallyEqual",
    "planning edit autosave hot path",
)

write(path, text)


# ---------------------------------------------------------------------------
# 2) Brain helper: resolve a newly created scheduled task against the current
#    day without moving existing tasks. Duration is preserved; touching edges
#    are valid and do not count as overlap.
# ---------------------------------------------------------------------------
path = "lib/data/plans/plan_time_cascade_helpers.dart"
text = read(path)
anchor = "  /// Non-blocking overload hints after scheduling plans on a day.\n"
helper = """  /// Resolves a newly created scheduled task into the first valid free slot.
  /// Existing plans are never moved; the new task keeps its requested duration.
  ({PlanningTask task, bool adjusted}) resolvePlanningCreateCollision({
    required PlanningTask task,
    required DateTime wallDay,
    required List<PlanningTask> existingDayPlans,
  }) {
    final requestedStart = task.startTime;
    if (requestedStart == null) {
      return (task: task, adjusted: false);
    }

    final requestedEnd = task.endDateTime;
    final explicitDurationMinutes =
        requestedEnd != null && requestedEnd.isAfter(requestedStart)
        ? requestedEnd.difference(requestedStart).inMinutes
        : resolvePlanDurationMinutesFromTags(task.tags);
    final schedule = resolveAutoPlanSchedule(
      wallDay: DateTime(wallDay.year, wallDay.month, wallDay.day),
      categoryId: task.categoryId,
      tags: task.tags,
      existingDayPlans: existingDayPlans,
      explicitStartWall: requestedStart,
      explicitEndWall: requestedEnd,
      hasExplicitTimeRange:
          requestedEnd != null && requestedEnd.isAfter(requestedStart),
      explicitDurationMinutes: explicitDurationMinutes,
    );
    final walls = profileDisplayWallsFromAutoSchedule(schedule);
    final dayKey =
        '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';

    return (
      task: task.copyWith(
        dateKey: dayKey,
        date: DateTime.utc(wallDay.year, wallDay.month, wallDay.day),
        startTime: walls.startWall,
        endDateTime: walls.endWall,
        endDateKey: dayKey,
        clearEnd: false,
      ),
      adjusted: walls.startWall != requestedStart,
    );
  }

"""
if "resolvePlanningCreateCollision" not in text:
    text = replace_once(text, anchor, helper + anchor, "planning create collision helper")
write(path, text)


# ---------------------------------------------------------------------------
# 3) Shell create path: use cached day plans, resolve collision once, then add.
# ---------------------------------------------------------------------------
path = "lib/app/shell/shared/shell_edit_hosts.dart"
text = read(path)
old = """      if (shellIsNewPlanningDraft(task)) {
        final day =
            planningDateFromKey(result.dateKey) ??
            DatabaseService.instance.getTimelineDeviceLocalToday();
        final nextOrder = await DatabaseService.instance
            .nextPlanningOrderForDate(day);
        final toCreate = result.copyWith(order: nextOrder);
        final ok = await DatabaseService.instance.addPlanningTask(toCreate);
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
          return;
        }
        HapticFeedback.heavyImpact();
      } else {
"""
new = """      if (shellIsNewPlanningDraft(task)) {
        final day =
            planningDateFromKey(result.dateKey) ??
            DatabaseService.instance.getTimelineDeviceLocalToday();
        final nextOrder = await DatabaseService.instance
            .nextPlanningOrderForDate(day);
        final collision = DatabaseService.instance
            .resolvePlanningCreateCollision(
              task: result.copyWith(order: nextOrder),
              wallDay: day,
              existingDayPlans: DatabaseService.instance
                  .planningDayTasksSnapshot(day)
                  .where((candidate) => candidate.startTime != null)
                  .toList(),
            );
        final toCreate = collision.task;
        final ok = await DatabaseService.instance.addPlanningTask(toCreate);
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
          return;
        }
        if (collision.adjusted && toCreate.startTime != null) {
          final movedTo =
              '${toCreate.startTime!.hour.toString().padLeft(2, '0')}:'
              '${toCreate.startTime!.minute.toString().padLeft(2, '0')}';
          AppSnack.warning(
            t(loc, 'plan_schedule_adjusted').replaceFirst('%s', movedTo),
          );
        }
        HapticFeedback.heavyImpact();
      } else {
"""
text = replace_once(text, old, new, "shell new-plan collision create path")
write(path, text)


# ---------------------------------------------------------------------------
# 4) Localization and behavior contract.
# ---------------------------------------------------------------------------
def add_l10n_entry(path: str, entry: str) -> None:
    text = read(path)
    if "'plan_schedule_adjusted'" in text:
        return
    idx = text.rfind("};")
    if idx < 0:
        raise RuntimeError(f"{path}: map terminator not found")
    text = text[:idx] + entry + text[idx:]
    write(path, text)


add_l10n_entry(
    "lib/l10n/langs/en.dart",
    "  'plan_schedule_adjusted': 'Overlapped another task — moved to %s',\n",
)
add_l10n_entry(
    "lib/l10n/langs/ru.dart",
    "  'plan_schedule_adjusted': 'Пересекается с другой задачей — перенесено на %s',\n",
)

path = "docs/UX_CONTRACT.md"
text = read(path)
ux_anchor = "## Planning Time Mode\n\n"
ux_rules = (
    "- **Selected-time stability:** typing or editing a task title, notes, checklist, "
    "category, or tags must not change a start time selected on the Time View grid. "
    "Start/end changes require an explicit time control or drag/resize gesture.\n"
    "- **Create anti-overlap:** a newly created scheduled task that intersects another "
    "task moves forward to the first free slot, preserves duration, treats touching "
    "boundaries as valid, and shows one concise adjustment notice. Existing tasks are "
    "not moved by this create correction.\n"
    "- **Editor hot-path:** text and rich-note typing must not rebuild the full Planning "
    "surface or emit global planning refreshes per keystroke; expensive draft merge/sync "
    "work is debounced.\n"
)
if "**Selected-time stability:**" not in text:
    text = replace_once(text, ux_anchor, ux_anchor + ux_rules, "UX Planning Time Mode rules")
write(path, text)

path = "CHANGELOG.md"
text = read(path)
entry = """## [2026-07-30] - P0 Planning selected-time stability and web editor load [shipped]

* **`planning_task_edit_sheet.dart`:** [shipped] Task-title typing no longer parses or overwrites the start time selected on the Time View grid; fuzzy category matching is debounced.
* **Planning edit hot path:** [shipped] New drafts no longer serialize rich notes/checklists on every keypress; persisted draft optimistic merge + global Planning refresh is coalesced behind the existing autosave debounce.
* **New scheduled plans:** [shipped] Creation now reuses Brain collision resolution, moves only the new task to the first free slot, preserves duration, and shows one localized adjustment notice.

"""
if "P0 Planning selected-time stability and web editor load" not in text:
    first_heading = text.find("## [")
    if first_heading < 0:
        raise RuntimeError("CHANGELOG: first dated heading not found")
    text = text[:first_heading] + entry + text[first_heading:]
write(path, text)


# ---------------------------------------------------------------------------
# 5) Three bounded regression tests only.
# ---------------------------------------------------------------------------
test_path = ROOT / "test/plan_create_collision_and_edit_time_guard_test.dart"
test_path.write_text(
    """import 'dart:io';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask _task({
  required String title,
  required DateTime start,
  DateTime? end,
  int order = 0,
}) {
  return PlanningTask(
    id: order + 1,
    title: title,
    categoryId: 1,
    isDone: false,
    dateKey: '2026-07-30',
    order: order,
    startTime: start,
    endDateTime: end,
    checklist: const [],
    parentPlanId: null,
  );
}

void main() {
  test('new plan moves after an overlapping task and preserves duration', () {
    final day = DateTime(2026, 7, 30);
    final result = DatabaseService.instance.resolvePlanningCreateCollision(
      task: _task(
        title: 'New',
        start: DateTime(2026, 7, 30, 10),
        order: 1,
      ),
      wallDay: day,
      existingDayPlans: [
        _task(
          title: 'Previous',
          start: DateTime(2026, 7, 30, 9),
          end: DateTime(2026, 7, 30, 10, 15),
        ),
      ],
    );

    expect(result.adjusted, isTrue);
    expect(result.task.startTime, DateTime(2026, 7, 30, 10, 15));
    expect(result.task.endDateTime, DateTime(2026, 7, 30, 10, 45));
  });

  test('touching interval boundaries are not treated as overlap', () {
    final day = DateTime(2026, 7, 30);
    final result = DatabaseService.instance.resolvePlanningCreateCollision(
      task: _task(
        title: 'New',
        start: DateTime(2026, 7, 30, 10, 15),
        end: DateTime(2026, 7, 30, 10, 45),
        order: 1,
      ),
      wallDay: day,
      existingDayPlans: [
        _task(
          title: 'Previous',
          start: DateTime(2026, 7, 30, 9),
          end: DateTime(2026, 7, 30, 10, 15),
        ),
      ],
    );

    expect(result.adjusted, isFalse);
    expect(result.task.startTime, DateTime(2026, 7, 30, 10, 15));
    expect(result.task.endDateTime, DateTime(2026, 7, 30, 10, 45));
  });

  test('planning edit title input does not own schedule parsing', () {
    final source = File(
      'lib/features/shared/planning_task_edit_sheet.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('parseTitleForScheduledTime')));
    expect(source, isNot(contains('parseTitleForTimeRange')));
    expect(source, contains('Timer(const Duration(milliseconds: 450)'));
  });
}
""",
    encoding="utf-8",
)

# Remove the temporary automation from the resulting product commit.
for temporary in (
    ROOT / "scripts/manual/apply_p0_planning_fix.py",
    ROOT / ".github/workflows/p0_planning_fix.yml",
):
    if temporary.exists():
        temporary.unlink()
