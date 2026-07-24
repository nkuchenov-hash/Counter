import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlanningTask _plan(String id, DateTime start, DateTime end) => PlanningTask(
  id: 0,
  planRowId: id,
  title: id,
  categoryId: 1,
  isDone: false,
  dateKey: '2026-07-24',
  order: 0,
  startTime: start,
  endDateTime: end,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseService.instance.setPlanAutoPlacementMode(
      PlanAutoPlacementMode.nearestFreeSlot,
    );
  });

  test('uses the current free gap when duration fits', () {
    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [
        _plan('a', DateTime(2026, 7, 24, 9), DateTime(2026, 7, 24, 10)),
        _plan('b', DateTime(2026, 7, 24, 11), DateTime(2026, 7, 24, 12)),
      ],
      timelineDayStartHour: 8,
      currentWall: DateTime(2026, 7, 24, 10, 5),
    );
    expect(schedule.startWall, DateTime(2026, 7, 24, 10, 5));
    expect(schedule.endWall, DateTime(2026, 7, 24, 10, 35));
  });

  test('skips a gap that is too short', () {
    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [
        _plan('a', DateTime(2026, 7, 24, 11), DateTime(2026, 7, 24, 12)),
      ],
      timelineDayStartHour: 8,
      currentWall: DateTime(2026, 7, 24, 10, 45),
    );
    expect(schedule.startWall, DateTime(2026, 7, 24, 12));
    expect(schedule.endWall, DateTime(2026, 7, 24, 12, 30));
  });

  test('after-last mode preserves the previous rule', () async {
    await DatabaseService.instance.setPlanAutoPlacementMode(
      PlanAutoPlacementMode.afterLastPlan,
    );
    final schedule = DatabaseService.instance.resolveAutoPlanSchedule(
      wallDay: DateTime(2026, 7, 24),
      categoryId: 1,
      tags: const [],
      existingDayPlans: [
        _plan('a', DateTime(2026, 7, 24, 9), DateTime(2026, 7, 24, 10)),
        _plan('b', DateTime(2026, 7, 24, 14), DateTime(2026, 7, 24, 15)),
      ],
      timelineDayStartHour: 8,
      currentWall: DateTime(2026, 7, 24, 10, 5),
    );
    expect(schedule.startWall, DateTime(2026, 7, 24, 15));
    expect(schedule.endWall, DateTime(2026, 7, 24, 15, 30));
  });
}
