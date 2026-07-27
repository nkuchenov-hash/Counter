import 'package:counter/data/health/health_sleep_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sleep trims the prior action and deletes records inside sleep', () {
    final start = DateTime.utc(2026, 7, 26, 23);
    final end = DateTime.utc(2026, 7, 27, 7);
    final actions = planSleepConflictActions(
      records: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'prior',
          'title': 'Work',
          'start_time': DateTime.utc(2026, 7, 26, 22).toIso8601String(),
          'end_time': DateTime.utc(2026, 7, 27, 8).toIso8601String(),
        },
        <String, dynamic>{
          'id': 'inside',
          'title': 'Morning routine',
          'start_time':
              DateTime.utc(2026, 7, 27, 6, 30).toIso8601String(),
          'end_time':
              DateTime.utc(2026, 7, 27, 7, 30).toIso8601String(),
        },
        <String, dynamic>{
          'id': 'before',
          'title': 'Dinner',
          'start_time': DateTime.utc(2026, 7, 26, 21).toIso8601String(),
          'end_time': DateTime.utc(2026, 7, 26, 22).toIso8601String(),
        },
        <String, dynamic>{
          'id': 'imported',
          'title': 'Sleep',
          'note': healthSleepMarker('existing'),
          'start_time': start.toIso8601String(),
          'end_time': end.toIso8601String(),
        },
      ],
      sleepStartUtc: start,
      sleepEndUtc: end,
    );

    expect(actions, hasLength(2));
    expect(actions[0].recordKey, 'prior');
    expect(actions[0].kind, SleepConflictKind.trimToSleepStart);
    expect(actions[1].recordKey, 'inside');
    expect(actions[1].kind, SleepConflictKind.delete);
  });
}
