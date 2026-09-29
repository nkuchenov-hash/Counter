from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one replacement, found {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# Late timeline: the old default ended at 23:00, which means the last rendered
# hour row is 22:00–23:00. Restore the extended day through 03:00.
replace_once(
    "lib/shared/time/plan_time_visible_window.dart",
    "  static const int defaultEndExtended = 23;",
    "  static const int defaultEndExtended = 27;",
)

prefs = Path("lib/features/planning/planning_day_start_prefs.dart")
text = prefs.read_text(encoding="utf-8")
old = "  static const String _legacyKeyEnd = 'planning_day_end_hour';\n"
new = (
    "  static const String _legacyKeyEnd = 'planning_day_end_hour';\n"
    "  static const String _keyLateHoursMigration =\n"
    "      'visible_day_end_27_v1_migrated';\n"
)
if text.count(old) != 1:
    raise SystemExit("planning_day_start_prefs.dart: migration-key anchor mismatch")
text = text.replace(old, new, 1)
old_load = """  static Future<({int start, int end})> loadVisibleDayRange() async {
    final p = await SharedPreferences.getInstance();
    if (p.containsKey(_keyStartExtended) && p.containsKey(_keyEndExtended)) {
      return normalizeExtendedRange(
        p.getInt(_keyStartExtended) ?? defaultStartExtended,
        p.getInt(_keyEndExtended) ?? defaultEndExtended,
      );
    }
    return migrateLegacyRange(
      legacyStart: p.getInt(_legacyKeyStart),
      legacyEnd: p.containsKey(_legacyKeyEnd) ? p.getInt(_legacyKeyEnd) : null,
    );
  }
"""
new_load = """  static Future<({int start, int end})> loadVisibleDayRange() async {
    final p = await SharedPreferences.getInstance();
    final migrationDone = p.getBool(_keyLateHoursMigration) ?? false;

    var range =
        p.containsKey(_keyStartExtended) && p.containsKey(_keyEndExtended)
        ? normalizeExtendedRange(
            p.getInt(_keyStartExtended) ?? defaultStartExtended,
            p.getInt(_keyEndExtended) ?? defaultEndExtended,
          )
        : migrateLegacyRange(
            legacyStart: p.getInt(_legacyKeyStart),
            legacyEnd: p.containsKey(_legacyKeyEnd)
                ? p.getInt(_legacyKeyEnd)
                : null,
          );

    // 23:00 was the old default end, which rendered no 23:00+ timeline. Upgrade
    // that stale default once to the supported extended-day end (03:00 next day).
    if (!migrationDone && range.end == 23) {
      range = normalizeExtendedRange(range.start, defaultEndExtended);
      await p.setInt(_keyStartExtended, range.start);
      await p.setInt(_keyEndExtended, range.end);
      await p.setInt(_legacyKeyStart, range.start.clamp(0, 23));
      await p.setInt(_legacyKeyEnd, range.end - 24);
    }
    if (!migrationDone) {
      await p.setBool(_keyLateHoursMigration, true);
    }
    return range;
  }
"""
if text.count(old_load) != 1:
    raise SystemExit("planning_day_start_prefs.dart: loadVisibleDayRange anchor mismatch")
prefs.write_text(text.replace(old_load, new_load, 1), encoding="utf-8")

replace_once(
    "lib/features/planning/time_view/planning_time_view_coordinator.dart",
    "import 'package:counter/features/planning/plan_time_view_layout.dart';\n",
    "import 'package:counter/features/planning/plan_time_view_layout.dart';\n"
    "import 'package:counter/features/planning/planning_day_start_prefs.dart';\n",
)
replace_once(
    "lib/features/planning/time_view/planning_time_view_coordinator.dart",
    "  int timelineHourStart = 0;\n  int timelineHourEnd = 23;",
    "  int timelineHourStart = PlanningSheetTimelinePrefs.defaultStartExtended;\n"
    "  int timelineHourEnd = PlanningSheetTimelinePrefs.defaultEndExtended;",
)

# Placement mode: distinguish a deliberate user selection from the stale
# afterLastPlan value left by the old regression.
helper = Path("lib/data/plans/plan_time_cascade_helpers.dart")
text = helper.read_text(encoding="utf-8")
old = """const String _keyPlanAutoPlacementGapMigration =
    'plan_auto_placement_gap_v2_migrated';
"""
new = """const String _keyPlanAutoPlacementGapMigration =
    'plan_auto_placement_gap_v2_migrated';
const String _keyPlanAutoPlacementExplicitChoice =
    'plan_auto_placement_explicit_choice_v1';
"""
if text.count(old) != 1:
    raise SystemExit("plan helper: preference key anchor mismatch")
text = text.replace(old, new, 1)

old_load = """    final gapMigrationDone =
        prefs.getBool(_keyPlanAutoPlacementGapMigration) ?? false;

    // The previous regression made afterLastPlan the default. A device that
    // persisted that value must be returned to smart gap placement once.
    if (!gapMigrationDone &&
        raw == PlanAutoPlacementMode.afterLastPlan.name) {
      _planAutoPlacementMode = PlanAutoPlacementMode.nearestFreeSlot;
      await prefs.setString(
        _keyPlanAutoPlacementMode,
        PlanAutoPlacementMode.nearestFreeSlot.name,
      );
    } else {
      _planAutoPlacementMode = PlanAutoPlacementMode.values.firstWhere(
        (mode) => mode.name == raw,
        orElse: () => PlanAutoPlacementMode.nearestFreeSlot,
      );
    }

    if (!gapMigrationDone) {
      await prefs.setBool(_keyPlanAutoPlacementGapMigration, true);
    }
"""
new_load = """    final gapMigrationDone =
        prefs.getBool(_keyPlanAutoPlacementGapMigration) ?? false;
    final explicitChoice =
        prefs.getBool(_keyPlanAutoPlacementExplicitChoice) ?? false;

    // afterLastPlan was once persisted as a broken default. Keep it only when
    // the user explicitly selected it in settings; otherwise recover to gap fill.
    if (!explicitChoice &&
        raw == PlanAutoPlacementMode.afterLastPlan.name) {
      _planAutoPlacementMode = PlanAutoPlacementMode.nearestFreeSlot;
      await prefs.setString(
        _keyPlanAutoPlacementMode,
        PlanAutoPlacementMode.nearestFreeSlot.name,
      );
    } else {
      _planAutoPlacementMode = PlanAutoPlacementMode.values.firstWhere(
        (mode) => mode.name == raw,
        orElse: () => PlanAutoPlacementMode.nearestFreeSlot,
      );
    }

    if (!gapMigrationDone) {
      await prefs.setBool(_keyPlanAutoPlacementGapMigration, true);
    }
"""
if text.count(old_load) != 1:
    raise SystemExit("plan helper: load mode anchor mismatch")
text = text.replace(old_load, new_load, 1)

old_set = """    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlanAutoPlacementMode, mode.name);
"""
new_set = """    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlanAutoPlacementMode, mode.name);
    await prefs.setBool(_keyPlanAutoPlacementExplicitChoice, true);
"""
if text.count(old_set) != 1:
    raise SystemExit("plan helper: set mode anchor mismatch")
text = text.replace(old_set, new_set, 1)

anchor = "  /// Auto start/end for a new plan on a day. Explicit parsed range always wins.\n"
helper_method = """  bool _planBelongsToWallDay(PlanningTask plan, DateTime wallDay) {
    final targetKey =
        '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    final key = plan.dateKey.trim();
    if (key.length >= 10) return key.substring(0, 10) == targetKey;
    final start = plan.startTime;
    if (start == null) return false;
    return start.year == wallDay.year &&
        start.month == wallDay.month &&
        start.day == wallDay.day;
  }

"""
if text.count(anchor) != 1:
    raise SystemExit("plan helper: auto schedule anchor mismatch")
text = text.replace(anchor, helper_method + anchor, 1)

sig_end = """    DateTime? currentWall,
  }) {
"""
relevant = """    DateTime? currentWall,
  }) {
    final relevantDayPlans = existingDayPlans
        .where((plan) => _planBelongsToWallDay(plan, wallDay))
        .toList(growable: false);
"""
if text.count(sig_end) != 1:
    raise SystemExit("plan helper: resolver signature anchor mismatch")
text = text.replace(sig_end, relevant, 1)

start = text.index("  resolveAutoPlanSchedule({")
end = text.index("\n  PlanningTask planningTaskWithAutoSchedule", start)
segment = text[start:end]
init_marker = """    final relevantDayPlans = existingDayPlans
        .where((plan) => _planBelongsToWallDay(plan, wallDay))
        .toList(growable: false);
"""
init_end = segment.index(init_marker) + len(init_marker)
segment = segment[:init_end] + segment[init_end:].replace(
    "existingDayPlans", "relevantDayPlans"
)
old_category = """        startWall = _snapPlanWallDateTime(
          DateTime(wallDay.year, wallDay.month, wallDay.day, h, m),
        );
"""
new_category = """        final categoryStart = _snapPlanWallDateTime(
          DateTime(wallDay.year, wallDay.month, wallDay.day, h, m),
        );
        startWall = _firstAvailablePlanWallStart(
          earliestStartWall: categoryStart,
          durationMin: durationMin,
          existingDayPlans: relevantDayPlans,
        );
"""
if segment.count(old_category) != 1:
    raise SystemExit("plan helper: category start anchor mismatch")
segment = segment.replace(old_category, new_category, 1)
text = text[:start] + segment + text[end:]
helper.write_text(text, encoding="utf-8")

# Regression tests.
test = Path("test/plan_time_visible_window_test.dart")
text = test.read_text(encoding="utf-8")
old = """    test('default 7→23 remains valid', () {
      final range = PlanTimeVisibleWindow.normalizeExtendedRange(7, 23);
      expect(range.start, 7);
      expect(range.end, 23);
      expect(PlanTimeVisibleWindow.visibleDurationHours(7, 23), 16);
    });
"""
new = """    test('default visible window reaches 03:00 next day', () {
      expect(PlanTimeVisibleWindow.defaultStartExtended, 7);
      expect(PlanTimeVisibleWindow.defaultEndExtended, 27);
      final hours = PlanTimeVisibleWindow.visibleExtendedHoursOrdered(
        PlanTimeVisibleWindow.defaultStartExtended,
        PlanTimeVisibleWindow.defaultEndExtended,
      );
      expect(hours.first, 7);
      expect(hours.last, 26);
      expect(hours, containsAll(<int>[23, 24, 25, 26]));
    });
"""
if text.count(old) != 1:
    raise SystemExit("visible-window test anchor mismatch")
test.write_text(text.replace(old, new, 1), encoding="utf-8")

placement_test = Path("test/auto_plan_nearest_free_slot_test.dart")
text = placement_test.read_text(encoding="utf-8")
insert = """  test('ignores polluted scheduled plans owned by another day', () {
    final foreign = PlanningTask(
      id: 0,
      planRowId: 'foreign',
      title: 'foreign',
      categoryId: 1,
      isDone: false,
      dateKey: '2026-07-25',
      order: 0,
      startTime: DateTime(2026, 7, 24, 8),
      endDateTime: DateTime(2026, 7, 24, 22),
    );

    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [foreign],
      timelineDayStartHour: 8,
    );

    expect(schedule.startWall, DateTime(2026, 7, 24, 8));
    expect(schedule.endWall, DateTime(2026, 7, 24, 8, 30));
  });

"""
marker = "  test('target-card drop after is exactly adjacent in scheduled time', () {\n"
if text.count(marker) != 1:
    raise SystemExit("placement test insertion anchor mismatch")
placement_test.write_text(text.replace(marker, insert + marker, 1), encoding="utf-8")

prefs_test = Path("test/planning_timeline_bounds_prefs_test.dart")
prefs_test.write_text(
    """import 'package:counter/features/planning/planning_day_start_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('old 23:00 timeline end migrates once to 03:00 next day', () async {
    SharedPreferences.setMockInitialValues({
      'visibleDayStartHourExtended': 7,
      'visibleDayEndHourExtended': 23,
    });

    final range = await PlanningSheetTimelinePrefs.loadVisibleDayRange();
    expect(range.start, 7);
    expect(range.end, 27);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('visibleDayEndHourExtended'), 27);
  });

  test('explicit 23:00 end is preserved after migration marker exists', () async {
    SharedPreferences.setMockInitialValues({
      'visibleDayStartHourExtended': 7,
      'visibleDayEndHourExtended': 23,
      'visible_day_end_27_v1_migrated': true,
    });

    final range = await PlanningSheetTimelinePrefs.loadVisibleDayRange();
    expect(range.start, 7);
    expect(range.end, 23);
  });
}
""",
    encoding="utf-8",
)
