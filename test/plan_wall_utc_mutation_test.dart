import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith can invalidate stale UTC when wall schedule changes', () {
    final task = PlanningTask(
      id: 0,
      planRowId: 'plan-1',
      title: 'Plan',
      categoryId: 1,
      dateKey: '2026-09-29',
      startTime: DateTime(2026, 9, 29, 10),
      endDateTime: DateTime(2026, 9, 29, 10, 30),
      startUtcInstant: DateTime.utc(2026, 9, 29, 14),
      endUtcInstant: DateTime.utc(2026, 9, 29, 14, 30),
    );

    final moved = task.copyWith(
      startTime: DateTime(2026, 9, 29, 12),
      endDateTime: DateTime(2026, 9, 29, 12, 30),
      clearStartUtc: true,
      clearEndUtc: true,
    );

    expect(moved.startTime, DateTime(2026, 9, 29, 12));
    expect(moved.startUtcInstant, isNull);
    expect(moved.endUtcInstant, isNull);
  });

  test(
    'collision-resolved create does not retain pre-collision UTC instant',
    () {
      final incoming = PlanningTask(
        id: 0,
        planRowId: 'incoming',
        title: 'Incoming',
        categoryId: 1,
        dateKey: '2026-09-29',
        startTime: DateTime(2026, 9, 29, 10),
        endDateTime: DateTime(2026, 9, 29, 10, 30),
        startUtcInstant: DateTime.utc(2026, 9, 29, 14),
        endUtcInstant: DateTime.utc(2026, 9, 29, 14, 30),
      );
      final occupied = PlanningTask(
        id: 0,
        planRowId: 'occupied',
        title: 'Occupied',
        categoryId: 1,
        dateKey: '2026-09-29',
        startTime: DateTime(2026, 9, 29, 10),
        endDateTime: DateTime(2026, 9, 29, 11),
      );

      final resolved = DatabaseService.instance
          .resolvePlanningCreateCollision(
            task: incoming,
            wallDay: DateTime(2026, 9, 29),
            existingDayPlans: [occupied],
          )
          .task;

      expect(resolved.startTime, DateTime(2026, 9, 29, 11));
      expect(resolved.startUtcInstant, isNull);
      expect(resolved.endUtcInstant, isNull);
    },
  );
}
