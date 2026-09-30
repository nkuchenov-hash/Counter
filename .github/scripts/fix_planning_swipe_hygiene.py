from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected one match in {path}, found {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")

planning = "lib/features/planning/planning_page.dart"
replace_once(
    planning,
    """    if (!widget.isActivePlanningDay) {
      if (_sortMode != PlanSortMode.time) {
        return const ColoredBox(
          color: Colors.transparent,
          child: SizedBox.expand(),
        );
      }
      if (tasks.isEmpty) {
        return TickerMode(
          enabled: false,
          child: IgnorePointer(
            child: PlanningDayEmptyState(onFocusQuickAdd: () {}),
          ),
        );
      }
      final frozenActualByPbId = DatabaseService.instance
          .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);
      return TickerMode(
        enabled: false,
        child: IgnorePointer(
          child: RepaintBoundary(
            child: timeView.buildHourGridView(tasks, frozenActualByPbId),
          ),
        ),
      );
    }
""",
    """    if (!widget.isActivePlanningDay) {
      return timeView.buildFrozenHourGrid(
        tasks,
        wallDay,
        enabled: _sortMode == PlanSortMode.time,
      );
    }
""",
)

hour_grid = "lib/features/planning/time_view/time_view_hour_grid.dart"
replace_once(
    hour_grid,
    """extension PlanningTimeViewTimeViewHourGrid on PlanningTimeViewCoordinator {
  Future<void> onPlanningTaskDroppedOnHour(
""",
    """extension PlanningTimeViewTimeViewHourGrid on PlanningTimeViewCoordinator {
  Widget buildFrozenHourGrid(
    List<PlanningTask> tasks,
    DateTime wallDay, {
    required bool enabled,
  }) {
    if (!enabled || tasks.isEmpty) {
      return const ColoredBox(
        color: Colors.transparent,
        child: SizedBox.expand(),
      );
    }
    final actualByPlanId = DatabaseService.instance
        .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);
    return TickerMode(
      enabled: false,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: buildHourGridView(tasks, actualByPlanId),
        ),
      ),
    );
  }

  Future<void> onPlanningTaskDroppedOnHour(
""",
)

shell = "lib/features/planning/planning_page_shell.dart"
replace_once(
    shell,
    """    } else {
      setState(() => _activePageIndex = page);
    }
""",
    """    } else {
      setState(() {
        _visiblePageIndex = page;
        _activePageIndex = page;
      });
    }
""",
)

test = "test/auto_plan_nearest_free_slot_test.dart"
replace_once(
    test,
    """      final planning = File(
        'lib/features/planning/planning_page.dart',
      ).readAsStringSync();
      final inactiveStart = planning.indexOf(
        'if (!widget.isActivePlanningDay) {',
      );
      final actualStart = planning.indexOf(
        'final planActualByPbId = DatabaseService.instance',
        inactiveStart,
      );
      expect(inactiveStart, greaterThanOrEqualTo(0));
      expect(actualStart, greaterThan(inactiveStart));
      final inactiveBlock = planning.substring(inactiveStart, actualStart);
      expect(inactiveBlock, contains('_sortMode != PlanSortMode.time'));
      expect(inactiveBlock, contains('TickerMode('));
      expect(inactiveBlock, contains('enabled: false'));
      expect(inactiveBlock, contains('IgnorePointer('));
      expect(inactiveBlock, contains('timeView.buildHourGridView('));
""",
    """      final planning = File(
        'lib/features/planning/planning_page.dart',
      ).readAsStringSync();
      expect(planning, contains('timeView.buildFrozenHourGrid('));

      final hourGrid = File(
        'lib/features/planning/time_view/time_view_hour_grid.dart',
      ).readAsStringSync();
      expect(hourGrid, contains('Widget buildFrozenHourGrid('));
      expect(
        hourGrid,
        contains('aggregateSourcePlanActualSecondsForWallCalendarDay'),
      );
      expect(hourGrid, contains('TickerMode('));
      expect(hourGrid, contains('enabled: false'));
      expect(hourGrid, contains('IgnorePointer('));
      expect(hourGrid, contains('buildHourGridView(tasks, actualByPlanId)'));
""",
)
