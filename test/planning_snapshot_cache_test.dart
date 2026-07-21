import 'package:counter/data/database_service.dart';
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

    test('planningDayTasksSnapshot returns empty list with no cache', () {
      final day = DateTime(2026, 7, 22);
      final tasks = DatabaseService.instance.planningDayTasksSnapshot(day);
      expect(tasks, isEmpty);
    });
  });
}
