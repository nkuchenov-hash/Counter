import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PlanningTask planAt(
    DateTime day,
    int hour,
    int minute, {
    required int duration,
    required int order,
  }) {
    final start = DateTime(day.year, day.month, day.day, hour, minute);
    final dayKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return PlanningTask(
      id: order + 1,
      title: 'existing-$order',
      categoryId: 0,
      isDone: false,
      dateKey: dayKey,
      order: order,
      startTime: start,
      endDateTime: start.add(Duration(minutes: duration)),
    );
  }

  test('explicit plan stays in a gap when its full duration fits', () async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseService.instance;
    await db.setPlanAutoPlacementMode(PlanAutoPlacementMode.nearestFreeSlot);
    final day = DateTime(2026, 7, 6);
    final existing = [
      planAt(day, 9, 0, duration: 60, order: 0),
      planAt(day, 10, 20, duration: 40, order: 1),
    ];

    final schedule = db.resolveAutoPlanSchedule(
      wallDay: day,
      categoryId: 0,
      tags: const [],
      existingDayPlans: existing,
      explicitStartWall: DateTime(2026, 7, 6, 10, 0),
      explicitEndWall: DateTime(2026, 7, 6, 10, 20),
      hasExplicitTimeRange: true,
    );

    expect(schedule.startWall, DateTime(2026, 7, 6, 10, 0));
    expect(schedule.endWall, DateTime(2026, 7, 6, 10, 20));
  });

  test(
    'explicit plan skips a too-small gap without squeezing existing plans',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = DatabaseService.instance;
      await db.setPlanAutoPlacementMode(PlanAutoPlacementMode.nearestFreeSlot);
      final day = DateTime(2026, 7, 6);
      final existing = [
        planAt(day, 9, 0, duration: 60, order: 0),
        planAt(day, 10, 20, duration: 40, order: 1),
      ];
      final secondStartBefore = existing[1].startTime;
      final secondEndBefore = existing[1].endDateTime;

      final schedule = db.resolveAutoPlanSchedule(
        wallDay: day,
        categoryId: 0,
        tags: const [],
        existingDayPlans: existing,
        explicitStartWall: DateTime(2026, 7, 6, 10, 0),
        explicitEndWall: DateTime(2026, 7, 6, 10, 30),
        hasExplicitTimeRange: true,
      );

      expect(schedule.startWall, DateTime(2026, 7, 6, 11, 0));
      expect(schedule.endWall, DateTime(2026, 7, 6, 11, 30));
      expect(existing[1].startTime, secondStartBefore);
      expect(existing[1].endDateTime, secondEndBefore);
    },
  );
}
