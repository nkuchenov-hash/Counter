import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile timezone full-plan reprojection is burst-deduplicated', () {
    final source = File(
      'lib/data/plans/plan_projection_types.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('String? _lastAppliedProfileTimezoneProjectionSignature;'),
    );
    expect(
      source,
      contains('DateTime? _lastAppliedProfileTimezoneProjectionAt;'),
    );
    expect(source, contains('_profileTimezoneProjectionDedupeWindow'));
    expect(source, contains("\${currentProfileId ?? '-'}|"));
    expect(
      source,
      contains(
        '_lastAppliedProfileTimezoneProjectionSignature == signature &&',
      ),
    );
    expect(
      source,
      contains('now.difference(_lastAppliedProfileTimezoneProjectionAt!) <'),
    );
    expect(
      source,
      contains('_lastAppliedProfileTimezoneProjectionSignature = signature;'),
    );
    expect(
      source,
      contains('_lastAppliedProfileTimezoneProjectionAt = DateTime.now();'),
    );
  });

  test('Time View bulk drag includes only normally movable selected rows', () {
    final source = File(
      'lib/features/planning/time_view/time_view_drag_controller.dart',
    ).readAsStringSync();

    expect(source, contains('.where(planIsTimelineScheduledDraggable)'));
    expect(
      source,
      isNot(
        contains('.where((t) => t.startTime != null)\n          .toList();'),
      ),
    );
  });

  test(
    'category default schedule save stays on targeted PocketBase hot path',
    () {
      final source = File(
        'lib/data/categories/category_default_time.dart',
      ).readAsStringSync();

      expect(source, contains('_patchCategoryDefaultPlanScheduleFields'));
      expect(source, isNot(contains('await patchCategoryDelta(categoryId')));
    },
  );

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
    expect(
      flagsSource,
      contains('const bool kPlanStreamLifecycleDiag = false;'),
    );
  });
}
