from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"needle not found in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "lib/shared/time/plan_time_visible_window.dart",
    "  static const int defaultEndExtended = 23;\n",
    "  static const int defaultEndExtended = 24;\n",
)
replace_once(
    "lib/shared/time/plan_time_visible_window.dart",
    "  static bool needsNextDayTasks(int endExtended) =>\n      clampEndExtended(endExtended, defaultStartExtended) > 24;\n",
    """  /// Expand the rendered end boundary enough to keep a scheduled plan visible.
  /// The persisted/user-selected range remains the baseline; this only grows it
  /// for actual content and never beyond the supported D+1 03:00 boundary.
  static int endExtendedIncludingWallEnd(
    DateTime day,
    int configuredEndExtended,
    DateTime wallEnd,
  ) {
    final base = clampEndExtended(
      configuredEndExtended,
      defaultStartExtended,
    );
    final minutes = wallEnd.difference(dayMidnight(day)).inMinutes;
    if (minutes <= 0) return base;
    final requiredEnd = ((minutes + 59) ~/ 60).clamp(
      extendedMin + 1,
      extendedMax,
    );
    return requiredEnd > base ? requiredEnd : base;
  }

  static bool needsNextDayTasks(int endExtended) =>
      clampEndExtended(endExtended, defaultStartExtended) > 24;
""",
)

replace_once(
    "lib/features/planning/planning_day_start_prefs.dart",
    "  static const String _legacyKeyEnd = 'planning_day_end_hour';\n",
    """  static const String _legacyKeyEnd = 'planning_day_end_hour';
  static const String _keyEnd24Migration =
      'visibleDayEndHour24V1Migrated';
""",
)
replace_once(
    "lib/features/planning/planning_day_start_prefs.dart",
    """    if (p.containsKey(_keyStartExtended) && p.containsKey(_keyEndExtended)) {
      return normalizeExtendedRange(
        p.getInt(_keyStartExtended) ?? defaultStartExtended,
        p.getInt(_keyEndExtended) ?? defaultEndExtended,
      );
    }
""",
    """    if (p.containsKey(_keyStartExtended) && p.containsKey(_keyEndExtended)) {
      var range = normalizeExtendedRange(
        p.getInt(_keyStartExtended) ?? defaultStartExtended,
        p.getInt(_keyEndExtended) ?? defaultEndExtended,
      );
      final end24Migrated = p.getBool(_keyEnd24Migration) ?? false;
      if (!end24Migrated) {
        if (range.end == 23) {
          range = normalizeExtendedRange(range.start, 24);
          await p.setInt(_keyEndExtended, range.end);
        }
        await p.setBool(_keyEnd24Migration, true);
      }
      return range;
    }
""",
)
replace_once(
    "lib/features/planning/planning_day_start_prefs.dart",
    "  static bool needsNextDayTasks(int endExtended) =>\n      PlanTimeVisibleWindow.needsNextDayTasks(endExtended);\n",
    """  static int endExtendedIncludingWallEnd(
    DateTime day,
    int configuredEndExtended,
    DateTime wallEnd,
  ) => PlanTimeVisibleWindow.endExtendedIncludingWallEnd(
    day,
    configuredEndExtended,
    wallEnd,
  );

  static bool needsNextDayTasks(int endExtended) =>
      PlanTimeVisibleWindow.needsNextDayTasks(endExtended);
""",
)

replace_once(
    "lib/features/planning/time_view/planning_time_view_coordinator.dart",
    "  int timelineHourEnd = 23;\n",
    "  int timelineHourEnd = 24;\n",
)

replace_once(
    "lib/features/planning/time_view/time_view_hour_grid.dart",
    "    final rangeStart = timelineHourStart;\n    final rangeEnd = timelineHourEnd;\n",
    "    final rangeStart = timelineHourStart;\n    var rangeEnd = timelineHourEnd;\n",
)
replace_once(
    "lib/features/planning/time_view/time_view_hour_grid.dart",
    """    final orderedProjected = projectedTasksForTimeMode(
      planningTasksForTimeViewWindow(planWallDay),
      planWallDay,
      rangeStart,
    );
    final schedulablePre = <PlanningTask>[];
""",
    """    final orderedProjected = projectedTasksForTimeMode(
      planningTasksForTimeViewWindow(planWallDay),
      planWallDay,
      rangeStart,
    );
    for (final item in orderedProjected) {
      final proj = item.projection;
      if (proj == null) continue;
      final wallEnd =
          proj.profileWallEnd ??
          proj.profileWallStart.add(Duration(minutes: proj.durationMinutes));
      rangeEnd = PlanningSheetTimelinePrefs.endExtendedIncludingWallEnd(
        planWallDay,
        rangeEnd,
        wallEnd,
      );
    }
    final schedulablePre = <PlanningTask>[];
""",
)

replace_once(
    "lib/data/plans/plan_time_cascade_helpers.dart",
    """      if (h != null && m != null) {
        usedCategoryDefault = true;
        categoryDefaultTimezoneIana = catSchedule!.timezoneIana;
        startWall = _snapPlanWallDateTime(
          DateTime(wallDay.year, wallDay.month, wallDay.day, h, m),
        );
      } else {
""",
    """      if (h != null && m != null) {
        usedCategoryDefault = true;
        categoryDefaultTimezoneIana = catSchedule!.timezoneIana;
        final defaultSourceCategoryId = catSchedule.sourceCategoryId;
        final sameDefaultGroupPlans = <PlanningTask>[
          for (final plan in existingDayPlans)
            if (defaultSourceCategoryId != null
                ? effectiveDefaultPlanScheduleForCategory(
                        plan.categoryId,
                      )?.sourceCategoryId ==
                      defaultSourceCategoryId
                : plan.categoryId == categoryId)
              plan,
        ];
        final categoryAnchor = _snapPlanWallDateTime(
          DateTime(wallDay.year, wallDay.month, wallDay.day, h, m),
        );
        startWall = _firstAvailablePlanWallStart(
          earliestStartWall: categoryAnchor,
          durationMin: durationMin,
          existingDayPlans: sameDefaultGroupPlans,
        );
      } else {
""",
)
replace_once(
    "lib/data/plans/plan_time_cascade_helpers.dart",
    """    var resolvedStart = _avoidPlanWallScheduleCollisions(
      startWall: startWall,
      durationMin: durationMin,
      existingDayPlans: existingDayPlans,
    );
""",
    """    var resolvedStart = usedCategoryDefault
        ? startWall
        : _avoidPlanWallScheduleCollisions(
            startWall: startWall,
            durationMin: durationMin,
            existingDayPlans: existingDayPlans,
          );
""",
)
replace_once(
    "lib/data/plans/plan_time_cascade_helpers.dart",
    """    final dayKey =
        '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
    const probePlanId = '__auto_schedule_probe__';
    final probe = PlanningTask(
      id: 0,
      title: '',
      categoryId: categoryId,
      isDone: false,
      dateKey: dayKey,
      order: 999999,
      startTime: resolvedStart,
      endDateTime: endWall,
      tags: tags,
      planRowId: probePlanId,
    );
    final cascadedProbe = normalizeSequentialPlanTimesForDay([
      ...existingDayPlans,
      probe,
    ]).firstWhere((t) => t.planRowId == probePlanId);
    resolvedStart = cascadedProbe.startTime ?? resolvedStart;
    endWall = cascadedProbe.endDateTime ?? endWall;
""",
    """    if (!usedCategoryDefault) {
      final dayKey =
          '${wallDay.year}-${_two(wallDay.month)}-${_two(wallDay.day)}';
      const probePlanId = '__auto_schedule_probe__';
      final probe = PlanningTask(
        id: 0,
        title: '',
        categoryId: categoryId,
        isDone: false,
        dateKey: dayKey,
        order: 999999,
        startTime: resolvedStart,
        endDateTime: endWall,
        tags: tags,
        planRowId: probePlanId,
      );
      final cascadedProbe = normalizeSequentialPlanTimesForDay([
        ...existingDayPlans,
        probe,
      ]).firstWhere((t) => t.planRowId == probePlanId);
      resolvedStart = cascadedProbe.startTime ?? resolvedStart;
      endWall = cascadedProbe.endDateTime ?? endWall;
    }
""",
)
replace_once(
    "lib/data/plans/plan_time_cascade_helpers.dart",
    "      final startUtc = wallUtcForCategoryDefaultWall(\n        wallDay: wallDay,\n",
    """      final startUtc = wallUtcForCategoryDefaultWall(
        wallDay: DateTime(
          resolvedStart.year,
          resolvedStart.month,
          resolvedStart.day,
        ),
""",
)

replace_once(
    "lib/data/plan_service.dart",
    "  }) async {\n    final optimisticId = 'optimistic-$clientPlanId';\n",
    """  }) async {
    final optimisticId = 'optimistic-$clientPlanId';
    var taskForCreate = task;
""",
)
replace_once(
    "lib/data/plan_service.dart",
    """            applySequentialTimeViewCascadeIfNeeded(wallDay: DateTime(y, m, d));
          }
""",
    """            final wallDay = DateTime(y, m, d);
            applySequentialTimeViewCascadeIfNeeded(wallDay: wallDay);
            for (final candidate in planningDayTasksSnapshot(wallDay)) {
              if ((candidate.planRowId?.trim() ?? '') == clientPlanId) {
                taskForCreate = candidate;
                break;
              }
            }
          }
""",
)
replace_once(
    "lib/data/plan_service.dart",
    "      body = await _buildPocketPlanCreateBody(\n        task,\n",
    "      body = await _buildPocketPlanCreateBody(\n        taskForCreate,\n",
)

page = Path("lib/features/planning/planning_page.dart")
text = page.read_text(encoding="utf-8")
old = """      ..._optimisticTasks.where(
        (t) => t.dateKey == taskDateKey || t.startTime != null,
      ),
"""
new = """      ..._optimisticTasks.where((t) {
        if (t.dateKey == taskDateKey) return true;
        final start = t.startTime;
        if (start == null) return false;
        return _dateKeyFromDate(start) == taskDateKey;
      }),
"""
count = text.count(old)
if count != 2:
    raise SystemExit(f"expected 2 optimistic day filters, found {count}")
page.write_text(text.replace(old, new), encoding="utf-8")

visible_test = Path("test/plan_time_visible_window_test.dart")
text = visible_test.read_text(encoding="utf-8")
old = """    test('default 7→23 remains valid', () {
      final range = PlanTimeVisibleWindow.normalizeExtendedRange(7, 23);
      expect(range.start, 7);
      expect(range.end, 23);
      expect(PlanTimeVisibleWindow.visibleDurationHours(7, 23), 16);
    });
"""
new = """    test('default day includes the 23:00 hour', () {
      expect(PlanTimeVisibleWindow.defaultStartExtended, 7);
      expect(PlanTimeVisibleWindow.defaultEndExtended, 24);
      expect(
        PlanTimeVisibleWindow.visibleExtendedHoursOrdered(7, 24).last,
        23,
      );
      expect(PlanTimeVisibleWindow.visibleDurationHours(7, 24), 17);
    });
"""
if old not in text:
    raise SystemExit("default window test marker missing")
text = text.replace(old, new, 1)
marker = "    test('formatExtendedHourClock maps -3 to 21:00', () {"
extra = """    test('late scheduled content expands the rendered end boundary', () {
      final day = DateTime(2026, 6, 23);
      expect(
        PlanTimeVisibleWindow.endExtendedIncludingWallEnd(
          day,
          24,
          DateTime(2026, 6, 24, 1, 20),
        ),
        26,
      );
      expect(
        PlanTimeVisibleWindow.endExtendedIncludingWallEnd(
          day,
          24,
          DateTime(2026, 6, 24, 4),
        ),
        27,
      );
    });

"""
if marker not in text:
    raise SystemExit("visible-window insertion marker missing")
visible_test.write_text(text.replace(marker, extra + marker, 1), encoding="utf-8")

auto_test = Path("test/auto_plan_nearest_free_slot_test.dart")
text = auto_test.read_text(encoding="utf-8")
marker = "  test('after-last placement is resolved before category default lookup', () {"
extra = """  test('category-default automatic placement is allowed to cascade the day', () {
    final source = File(
      'lib/data/plans/plan_time_cascade_helpers.dart',
    ).readAsStringSync();
    expect(source, contains('final sameDefaultGroupPlans = <PlanningTask>['));
    expect(source, contains('var resolvedStart = usedCategoryDefault'));
    expect(source, contains('if (!usedCategoryDefault) {'));
  });

  test('create POST reads the post-cascade optimistic schedule', () {
    final source = File('lib/data/plan_service.dart').readAsStringSync();
    expect(source, contains('var taskForCreate = task;'));
    expect(source, contains('taskForCreate = candidate;'));
    expect(source, contains('_buildPocketPlanCreateBody(\\n        taskForCreate,'));
  });

"""
if marker not in text:
    raise SystemExit("auto-placement test marker missing")
auto_test.write_text(text.replace(marker, extra + marker, 1), encoding="utf-8")
