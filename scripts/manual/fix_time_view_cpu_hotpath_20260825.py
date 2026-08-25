from pathlib import Path


def replace_between(path: str, start_marker: str, end_marker: str, replacement: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f'{path}: start marker not found: {start_marker!r}')
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f'{path}: end marker not found: {end_marker!r}')
    p.write_text(text[:start] + replacement + text[end:], encoding='utf-8')


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if text.count(old) != 1:
        raise SystemExit(f'{path}: expected exactly one match, found {text.count(old)}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


# 1) Time View: decorate once, then sort using cached projections. Never call
# timezone projection from the sort comparator.
replace_between(
    'lib/features/planning/time_view/planning_time_view.dart',
    '  List<PlanningTask> tasksForTimeMode(',
    '  bool timelineCompactLayout(',
    '''  List<({PlanningTask task, TimeModeProjectedPlan? projection})>\n  projectedTasksForTimeMode(\n    List<PlanningTask> tasks,\n    DateTime planWallDay,\n    int dayStartExtended,\n  ) {\n    final decorated =\n        <({PlanningTask task, TimeModeProjectedPlan? projection})>[\n          for (final task in tasks)\n            (\n              task: task,\n              projection: DatabaseService.instance.projectPlanForTimeMode(task),\n            ),\n        ];\n    decorated.sort((a, b) {\n      final ap = a.projection;\n      final bp = b.projection;\n      if (ap == null && bp == null) return host.taskSortCmp(a.task, b.task);\n      if (ap == null) return 1;\n      if (bp == null) return -1;\n      final ca = planningClockOrderMinutes(\n        ap.profileWallStart,\n        planWallDay,\n        dayStartExtended,\n      );\n      final cb = planningClockOrderMinutes(\n        bp.profileWallStart,\n        planWallDay,\n        dayStartExtended,\n      );\n      if (ca != cb) return ca.compareTo(cb);\n      return host.taskSortCmp(a.task, b.task);\n    });\n    return decorated;\n  }\n\n  List<PlanningTask> tasksForTimeMode(\n    List<PlanningTask> tasks,\n    DateTime planWallDay,\n    int dayStartExtended,\n  ) => [\n    for (final item in projectedTasksForTimeMode(\n      tasks,\n      planWallDay,\n      dayStartExtended,\n    ))\n      item.task,\n  ];\n\n''',
)

# 2) Hour grid: one snapshot + one projection per plan + one sort. The old code
# immediately repeated the full sort after merely scheduling a post-frame
# overlap normalization, then projected every row yet again in a second scan.
replace_between(
    'lib/features/planning/time_view/time_view_hour_grid.dart',
    '    var ordered = tasksForTimeMode(',
    '    cachedTimeModeProjections = projections;',
    '''    final orderedProjected = projectedTasksForTimeMode(\n      planningTasksForTimeViewWindow(planWallDay),\n      planWallDay,\n      rangeStart,\n    );\n    final schedulablePre = <PlanningTask>[];\n    final unscheduled = <PlanningTask>[];\n    final projections = <TimeModeProjectedPlan>[];\n    for (final item in orderedProjected) {\n      final task = item.task;\n      final proj = item.projection;\n      if (proj == null) {\n        if (task.dateKey.length >= 10 &&\n            task.dateKey.substring(0, 10) == selectedDayKey) {\n          unscheduled.add(task);\n        }\n        continue;\n      }\n      if (!projectedPlanInTimeViewWindow(\n        proj,\n        planWallDay,\n        rangeStart,\n        rangeEnd,\n      )) {\n        continue;\n      }\n      schedulablePre.add(task);\n      projections.add(proj);\n    }\n    if (schedulablePre.isNotEmpty) {\n      maybeNormalizeTimeViewOverlapsOnce(planWallDay, schedulablePre);\n    }\n''',
)

# 3) Current-time line does not justify rebuilding the whole Time View 4x/min.
# Keep minute-resolution correctness and own/cancel the timer explicitly.
replace_once(
    'lib/features/planning/time_view/planning_time_view_coordinator.dart',
    '    Timer.periodic(const Duration(seconds: 15), (timer) {',
    '    nowLineTimer = Timer.periodic(const Duration(minutes: 1), (timer) {',
)
replace_once(
    'lib/features/planning/time_view/planning_time_view_coordinator.dart',
    '  final PlanningTimeViewHost host;\n',
    '  final PlanningTimeViewHost host;\n  Timer? nowLineTimer;\n',
)
replace_once(
    'lib/features/planning/time_view/planning_time_view.dart',
    '''  void disposeTimeView() {\n    stopHourGridEdgeScroll();\n    hourGridEdgeScrollTicker.dispose();\n    hourGridScrollController.dispose();\n  }''',
    '''  void disposeTimeView() {\n    nowLineTimer?.cancel();\n    nowLineTimer = null;\n    stopHourGridEdgeScroll();\n    hourGridEdgeScrollTicker.dispose();\n    hourGridScrollController.dispose();\n  }''',
)

# 4) Release builds must not run stream lifecycle diagnostics continuously.
replace_once(
    'lib/shared/diagnostics/performance/runtime_flags.dart',
    'const bool kPlanStreamLifecycleDiag = true;',
    'const bool kPlanStreamLifecycleDiag = false;',
)

# 5) Adjacent PageView days exist ahead of time. They must not react to global
# streams or load Time View resources while hidden.
replace_once(
    'lib/features/planning/planning_page.dart',
    '  late final PlanningTimeViewCoordinator timeView;\n',
    '  late final PlanningTimeViewCoordinator timeView;\n  bool _activePlanningResourcesLoaded = false;\n',
)
replace_once(
    'lib/features/planning/planning_page.dart',
    '''    _planningTimeSub = DatabaseService.instance.timeUpdates.listen((_) {\n      if (!mounted) return;\n      final t = DatabaseService.instance.cachedPrimaryRunningTitle''',
    '''    _planningTimeSub = DatabaseService.instance.timeUpdates.listen((_) {\n      if (!mounted || !widget.isActivePlanningDay || !widget.shellTabActive) {\n        return;\n      }\n      final t = DatabaseService.instance.cachedPrimaryRunningTitle''',
)
replace_once(
    'lib/features/planning/planning_page.dart',
    '''    _tagsCatalogSub = DatabaseService.instance.tagsCatalogUpdated.listen((_) {\n      if (!mounted) return;\n      setState(() {});\n    });''',
    '''    _tagsCatalogSub = DatabaseService.instance.tagsCatalogUpdated.listen((_) {\n      if (!mounted || !widget.isActivePlanningDay || !widget.shellTabActive) {\n        return;\n      }\n      setState(() {});\n    });''',
)
replace_between(
    'lib/features/planning/planning_page.dart',
    '    _settingsSub = DatabaseService.instance.userSettingsStream.listen((s) {',
    '    timeView = PlanningTimeViewCoordinator(this);',
    '''    _settingsSub = DatabaseService.instance.userSettingsStream.listen((s) {\n      if (!mounted) return;\n      final timezoneChanged =\n          s.timezoneOffsetHours != lastTzOffset ||\n          s.preferredTimeZone != lastTzLabel;\n      lastTzOffset = s.timezoneOffsetHours;\n      lastTzLabel = s.preferredTimeZone;\n      if (!timezoneChanged ||\n          !widget.isActivePlanningDay ||\n          !widget.shellTabActive) {\n        return;\n      }\n      DatabaseService.instance.reprojectAllPlansForProfileTimezone();\n      _refreshPlanningTasksAfterTimezoneChange();\n      DatabaseService.instance.notifyPlanningRefresh(\n        scheduleNetworkRefresh: false,\n      );\n      setState(() {});\n    });\n''',
)
replace_once(
    'lib/features/planning/planning_page.dart',
    '''    timeView = PlanningTimeViewCoordinator(this);\n    timeView.initHourGridTicker(createTicker);\n    unawaited(timeView.loadPlanningTimelineBounds());\n    unawaited(timeView.loadTimeViewFixedTagIds());\n    unawaited(_quickAddTags.reload());\n  }''',
    '''    timeView = PlanningTimeViewCoordinator(this);\n    timeView.initHourGridTicker(createTicker);\n    _ensureActivePlanningResources();\n  }\n\n  void _ensureActivePlanningResources() {\n    if (_activePlanningResourcesLoaded ||\n        !widget.isActivePlanningDay ||\n        !widget.shellTabActive) {\n      return;\n    }\n    _activePlanningResourcesLoaded = true;\n    unawaited(timeView.loadPlanningTimelineBounds());\n    unawaited(timeView.loadTimeViewFixedTagIds());\n    unawaited(_quickAddTags.reload());\n  }''',
)
replace_once(
    'lib/features/planning/planning_page.dart',
    '''      _syncPlanningShellFabBulkReserve();\n    }\n  }\n\n  @override\n  void dispose() {''',
    '''      _syncPlanningShellFabBulkReserve();\n      _ensureActivePlanningResources();\n    }\n  }\n\n  @override\n  void dispose() {''',
)

# 6) Extend the existing performance contract instead of adding another tracked
# test file (keeps documentation parity stable).
p = Path('test/plans_time_performance_contract_test.dart')
text = p.read_text(encoding='utf-8')
needle = '\n}\n'
if not text.endswith(needle):
    raise SystemExit('performance contract: unexpected file ending')
extra = r'''

  test('Time View projects each plan once per rebuild hot path', () {
    final projectionSource = File(
      'lib/features/planning/time_view/planning_time_view.dart',
    ).readAsStringSync();
    final hourGridSource = File(
      'lib/features/planning/time_view/time_view_hour_grid.dart',
    ).readAsStringSync();

    expect(projectionSource, contains('projectedTasksForTimeMode('));
    final sortStart = projectionSource.indexOf('decorated.sort((a, b) {');
    final sortEnd = projectionSource.indexOf('return decorated;', sortStart);
    expect(sortStart, greaterThanOrEqualTo(0));
    expect(sortEnd, greaterThan(sortStart));
    expect(
      projectionSource.substring(sortStart, sortEnd),
      isNot(contains('projectPlanForTimeMode(')),
    );

    expect(
      hourGridSource,
      contains('final orderedProjected = projectedTasksForTimeMode('),
    );
    final hotStart = hourGridSource.indexOf(
      'final orderedProjected = projectedTasksForTimeMode(',
    );
    final hotEnd = hourGridSource.indexOf(
      'cachedTimeModeProjections = projections;',
      hotStart,
    );
    expect(hotStart, greaterThanOrEqualTo(0));
    expect(hotEnd, greaterThan(hotStart));
    expect(
      hourGridSource.substring(hotStart, hotEnd),
      isNot(contains('projectPlanForTimeMode(')),
    );
    expect(
      hourGridSource.substring(hotStart, hotEnd),
      isNot(contains('ordered = tasksForTimeMode(')),
    );
  });

  test('Time View background work is active-page only and minute cadence', () {
    final pageSource = File(
      'lib/features/planning/planning_page.dart',
    ).readAsStringSync();
    final coordinatorSource = File(
      'lib/features/planning/time_view/planning_time_view_coordinator.dart',
    ).readAsStringSync();
    final viewSource = File(
      'lib/features/planning/time_view/planning_time_view.dart',
    ).readAsStringSync();
    final flagsSource = File(
      'lib/shared/diagnostics/performance/runtime_flags.dart',
    ).readAsStringSync();

    expect(
      pageSource,
      contains('!widget.isActivePlanningDay || !widget.shellTabActive'),
    );
    expect(pageSource, contains('_ensureActivePlanningResources();'));
    expect(
      coordinatorSource,
      contains('Timer.periodic(const Duration(minutes: 1)'),
    );
    expect(
      coordinatorSource,
      isNot(contains('Timer.periodic(const Duration(seconds: 15)')),
    );
    expect(viewSource, contains('nowLineTimer?.cancel();'));
    expect(flagsSource, contains('const bool kPlanStreamLifecycleDiag = false;'));
  });
'''
p.write_text(text[:-2] + extra + '\n}\n', encoding='utf-8')

print('Time View CPU hot-path repair applied.')
