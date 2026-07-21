import 'package:counter/data/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Planning stream hubs / refresh', () {
    test('refresh notifications and events share the same refresh signal', () async {
      final db = DatabaseService.instance;
      final fromNotifications = <void>[];
      final fromEvents = <void>[];
      final subN = db.planningRefreshNotifications.listen(fromNotifications.add);
      final subE = db.planningRefreshEvents.listen(fromEvents.add);

      db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
      await Future<void>.delayed(Duration.zero);

      expect(fromNotifications, hasLength(1));
      expect(fromEvents, hasLength(1));
      await subN.cancel();
      await subE.cancel();
    });

    test('notifyPlanningRefresh emits immediate event without network schedule', () async {
      final db = DatabaseService.instance;
      final events = <void>[];
      final sub = db.planningRefreshEvents.listen(events.add);
      db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      await sub.cancel();
    });

    test('planningStream shares one hub and releases on cancel', () async {
      final db = DatabaseService.instance;
      final day = DateTime(2026, 9, 1);
      final first = <List<dynamic>>[];
      final second = <List<dynamic>>[];

      final sub1 = db
          .planningStream(day, listenToGlobalPlanningRefresh: false)
          .listen(first.add);
      final sub2 = db
          .planningStream(day, listenToGlobalPlanningRefresh: false)
          .listen(second.add);

      await Future<void>.delayed(Duration.zero);
      expect(first, isNotEmpty);
      expect(second, isNotEmpty);
      expect(first.first, isEmpty);

      await sub1.cancel();
      await sub2.cancel();
      await Future<void>.delayed(Duration.zero);

      // After both listeners cancel, a new subscribe should still emit cache-first.
      final after = <List<dynamic>>[];
      final sub3 = db
          .planningStream(day, listenToGlobalPlanningRefresh: false)
          .listen(after.add);
      await Future<void>.delayed(Duration.zero);
      expect(after, isNotEmpty);
      await sub3.cancel();
    });
  });
}
