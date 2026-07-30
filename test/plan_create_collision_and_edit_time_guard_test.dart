import 'dart:io';

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
      task: _task(title: 'New', start: DateTime(2026, 7, 30, 10), order: 1),
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
