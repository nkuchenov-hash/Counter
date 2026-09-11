import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:flutter_test/flutter_test.dart';

TimeModeProjectedPlan _projection({
  required int minute,
  required String id,
}) {
  final start = DateTime.utc(2026, 9, 11, 19, minute);
  final end = start.add(const Duration(minutes: 10));
  final task = PlanningTask(
    id: id.hashCode.abs(),
    title: 'Task $id',
    dateKey: '2026-09-11',
    startTime: start,
    endDateTime: end,
    order: 0,
    isDone: false,
    categoryId: 1,
    planRowId: id,
    startUtcInstant: start,
    endUtcInstant: end,
  );
  return TimeModeProjectedPlan(
    task: task,
    startUtc: start,
    endUtc: end,
    wallStart: start,
    wallEnd: end,
    wallDateKey: '2026-09-11',
    plannedTimeLabel: '',
  );
}

void main() {
  test('equal 10-minute cards keep equal height at end of an adjacent group', () {
    final result = PlanTimeViewLayoutCalculator.compute(
      projections: [
        _projection(minute: 30, id: 'first'),
        _projection(minute: 40, id: 'last'),
      ],
      visibleHours: const [19],
      rangeStart: 19,
      baseHourHeightPx: 120,
      startMinOf: (p) => (p.startMinuteOfDay - 19 * 60).toDouble(),
      endMinOf: (p) =>
          (p.startMinuteOfDay - 19 * 60 + p.durationMinutes).toDouble(),
    );

    final first = result.layouts[0];
    final last = result.layouts[1];

    expect(first.heightPx, closeTo(kPlanTimeCardMinHeightPx, 0.01));
    expect(last.heightPx, closeTo(kPlanTimeCardMinHeightPx, 0.01));
    expect(last.heightPx, closeTo(first.heightPx, 0.01));
    expect(
      last.topPx - (first.topPx + first.heightPx),
      closeTo(kPlanTimeCardGapPx, 0.01),
    );
  });
}
