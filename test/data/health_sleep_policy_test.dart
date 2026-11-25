import 'package:counter/data/health/health_sleep_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device fallback fills only missing, non-conflicting nights', () {
    final start = DateTime.utc(2026, 11, 24, 23);
    final end = DateTime.utc(2026, 11, 25, 7);
    bool allowed(List<Map<String, dynamic>> records) => canRecoverMissingSleep(
      records: records,
      sleepStartUtc: start,
      sleepEndUtc: end,
    );
    expect(allowed([]), isTrue);
    expect(allowed([{'title': 'Work', 'start_time': start.subtract(
      const Duration(hours: 1)).toIso8601String(), 'end_time': null}]), isTrue);
    expect(allowed([{'title': 'Сон', 'start_time': start.toIso8601String(),
      'end_time': end.toIso8601String()}]), isFalse);
    expect(allowed([{'title': 'Work', 'start_time': start.add(
      const Duration(hours: 1)).toIso8601String(),
      'end_time': end.toIso8601String()}]), isFalse);
    expect(allowed([{'title': 'Work', 'start_time': start.subtract(
      const Duration(hours: 1)).toIso8601String(),
      'end_time': end.toIso8601String()}]), isFalse);
  });

  test(
    'sleep trims prior action, deletes conflicts, and matches correction',
    () {
      final start = DateTime.utc(2026, 7, 26, 23);
      final end = DateTime.utc(2026, 7, 27, 7);
      final records = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'prior',
          'title': 'Work',
          'start_time': DateTime.utc(2026, 7, 26, 22).toIso8601String(),
          'end_time': DateTime.utc(2026, 7, 27, 8).toIso8601String(),
        },
        <String, dynamic>{
          'id': 'inside',
          'title': 'Morning routine',
          'start_time': DateTime.utc(2026, 7, 27, 6, 30).toIso8601String(),
          'end_time': DateTime.utc(2026, 7, 27, 7, 30).toIso8601String(),
        },
        <String, dynamic>{
          'id': 'before',
          'title': 'Dinner',
          'start_time': DateTime.utc(2026, 7, 26, 21).toIso8601String(),
          'end_time': DateTime.utc(2026, 7, 26, 22).toIso8601String(),
        },
        <String, dynamic>{
          'id': 'sleep',
          'title': 'Sleep',
          'start_time': DateTime.utc(2026, 7, 26, 23, 10).toIso8601String(),
          'end_time': DateTime.utc(2026, 7, 27, 6, 50).toIso8601String(),
        },
      ];
      final existing = findExistingSleepRecord(
        records: records,
        sleepStartUtc: start,
        sleepEndUtc: end,
      );
      expect(recordIdentityKey(existing!), 'sleep');

      final actions = planSleepConflictActions(
        records: records,
        sleepStartUtc: start,
        sleepEndUtc: end,
        existingSleepRecordKey: 'sleep',
      );

      expect(actions, hasLength(2));
      expect(actions[0].recordKey, 'prior');
      expect(actions[0].kind, SleepConflictKind.trimToSleepStart);
      expect(actions[1].recordKey, 'inside');
      expect(actions[1].kind, SleepConflictKind.delete);
    },
  );
}
