import 'package:counter/core/widgets/plan_time_task_card.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:flutter_test/flutter_test.dart';

TimeModeProjectedPlan _proj({
  required int hour,
  required int minute,
  required int durationMin,
  required String id,
}) {
  final start = DateTime.utc(2026, 6, 15, hour, minute);
  final end = start.add(Duration(minutes: durationMin));
  final task = PlanningTask(
    id: id.hashCode.abs(),
    title: 'Task $id',
    dateKey: '2026-06-15',
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
    wallDateKey: '2026-06-15',
    plannedTimeLabel: '00:00',
  );
}

void main() {
  group('TIME_VIEW_DURATION_FIDELITY_CHECK', () {
    test('60-minute task fills hour slot at base scale', () {
      const baseHour = 120.0;
      final result = PlanTimeViewLayoutCalculator.compute(
        projections: [_proj(hour: 11, minute: 0, durationMin: 60, id: 'h')],
        visibleHours: const [11],
        rangeStart: 11,
        baseHourHeightPx: baseHour,
        startMinOf: (p) => (p.startMinuteOfDay - 11 * 60).toDouble(),
        endMinOf: (p) =>
            (p.startMinuteOfDay - 11 * 60 + p.durationMinutes).toDouble(),
      );
      final card = result.layouts.single;
      final hourHeight = result.grid.hourHeightsPx.single;
      expect(card.topPx, closeTo(0, 0.51));
      expect(card.heightPx, closeTo(hourHeight, 0.51));
      expect(card.heightPx, closeTo(60 * (baseHour / 60), 0.51));
    });

    test('30-minute task occupies half-hour slot', () {
      const baseHour = 120.0;
      final ppm = baseHour / 60;
      final result = PlanTimeViewLayoutCalculator.compute(
        projections: [_proj(hour: 11, minute: 0, durationMin: 30, id: 'm')],
        visibleHours: const [11],
        rangeStart: 11,
        baseHourHeightPx: baseHour,
        startMinOf: (p) => (p.startMinuteOfDay - 11 * 60).toDouble(),
        endMinOf: (p) =>
            (p.startMinuteOfDay - 11 * 60 + p.durationMinutes).toDouble(),
      );
      final card = result.layouts.single;
      expect(card.heightPx, closeTo(30 * ppm, 0.51));
      expect(card.heightPx, closeTo(result.grid.hourHeightsPx.single / 2, 0.51));
    });

    test('10-minute task keeps 38px minimum height', () {
      final result = PlanTimeViewLayoutCalculator.compute(
        projections: [_proj(hour: 11, minute: 0, durationMin: 10, id: 't')],
        visibleHours: const [11],
        rangeStart: 11,
        baseHourHeightPx: 120,
        startMinOf: (p) => (p.startMinuteOfDay - 11 * 60).toDouble(),
        endMinOf: (p) =>
            (p.startMinuteOfDay - 11 * 60 + p.durationMinutes).toDouble(),
      );
      expect(result.layouts.single.heightPx, closeTo(38, 0.51));
    });

    test('scheduled slot height helper matches duration truth', () {
      expect(
        PlanTimeViewLayoutCalculator.scheduledSlotHeightPx(60, 2),
        closeTo(120, 0.01),
      );
      expect(
        PlanTimeViewLayoutCalculator.scheduledSlotHeightPx(10, 2),
        closeTo(38, 0.01),
      );
    });
  });
}
