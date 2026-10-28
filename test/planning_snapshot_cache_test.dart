import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Planning snapshot / body cache pipeline', () {
    test('plansBodyEntryForDate emergency build is bodyReady with source', () {
      final day = DateTime(2026, 7, 20);
      final entry = DatabaseService.instance.plansBodyEntryForDate(
        day,
        allowEmergencyBuild: true,
      );
      expect(entry.bodyReady, isTrue);
      expect(entry.source, 'emergencySyncBuild');
      expect(entry.dateKey, '2026-07-20');
      expect(entry.tasks, isEmpty);
      expect(entry.knownEmpty, isTrue);
    });

    test('plansBodyEntryForDate pending path stays not ready', () {
      final day = DateTime(2026, 8, 1);
      final entry = DatabaseService.instance.plansBodyEntryForDate(
        day,
        allowEmergencyBuild: false,
      );
      expect(entry.bodyReady, isFalse);
      expect(entry.source, 'pending');
      expect(entry.tasks, isEmpty);
      expect(entry.knownEmpty, isTrue);
    });

    test('date-only Viktor plans belong to the intended day without time', () {
      final plan = PlanningTask(
        id: 12,
        title: 'LS Screening — remind John to sign the Cover Letter',
        categoryId: 1,
        dateKey: '2026-11-02',
      );
      expect(unscheduledPlanMatchesWallDay(plan, '2026-11-02'), isTrue);
      expect(unscheduledPlanMatchesWallDay(plan, '2026-11-01'), isFalse);
      expect(unscheduledPlanMatchesWallDay(plan, '2026-11-11'), isFalse);
      final timed = PlanningTask(
        id: 13,
        title: 'Scheduled',
        categoryId: 1,
        dateKey: '2026-11-02',
        startTime: DateTime(2026, 11, 2, 10),
      );
      expect(unscheduledPlanMatchesWallDay(timed, '2026-11-02'), isFalse);
    });

    test('real day projection preserves untimed plan only on November 2', () {
      final db = DatabaseService.instance;
      final plan = PlanningTask(
        id: 14,
        planRowId: 'nov2-date-only',
        title: 'LS Screening date-only',
        categoryId: 1,
        dateKey: '2026-11-02',
      );
      final other = PlanningTask(
        id: 15,
        planRowId: 'nov11-date-only',
        title: 'Other day',
        categoryId: 1,
        dateKey: '2026-11-11',
      );
      final all = [plan, other];
      final onNov2 = db.filterPlansForWallDayForTest(
        all,
        DateTime(2026, 11, 2),
      );
      expect(onNov2.map((t) => t.title), contains(plan.title));
      expect(onNov2, hasLength(1));
      expect(onNov2.single.startTime, isNull);
      expect(onNov2.single.startUtcInstant, isNull);
      expect(onNov2.single.dateKey, '2026-11-02');
      expect(
        db.filterPlansForWallDayForTest(all, DateTime(2026, 11, 1)),
        isEmpty,
      );
      expect(
        db.filterPlansForWallDayForTest(all, DateTime(2026, 11, 11))
            .map((t) => t.title),
        contains(other.title),
      );
    });

    test('planningDayTasksSnapshot returns empty list with no cache', () {
      final day = DateTime(2026, 7, 22);
      final tasks = DatabaseService.instance.planningDayTasksSnapshot(day);
      expect(tasks, isEmpty);
    });
  });
}
