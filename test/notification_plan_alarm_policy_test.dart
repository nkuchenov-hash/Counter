import 'package:counter/data/models.dart';
import 'package:counter/services/notifications/plan_alarm_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

PlanningTask _task({
  required String key,
  required DateTime start,
  DateTime? startUtc,
  int? reminderOffset = 15,
  bool isDone = false,
  String title = 'Review',
}) => PlanningTask(
  id: 0,
  planRowId: key,
  title: title,
  categoryId: 1,
  isDone: isDone,
  dateKey: '2026-07-17',
  startTime: start,
  startUtcInstant: startUtc,
  reminderOffset: reminderOffset,
);

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('stable notification id is deterministic and positive', () {
    final first = planAlarmNotificationIdFromStableKey('pb-row-123');
    final second = planAlarmNotificationIdFromStableKey('pb-row-123');
    expect(first, second);
    expect(first, inInclusiveRange(0, 0x7fffffff));
  });

  test('stored UTC wins over a mismatched wall-clock projection', () {
    final location = tz.getLocation('America/New_York');
    final candidates = buildPlanAlarmCandidates(
      tasks: [
        _task(
          key: 'utc-source',
          start: DateTime(2026, 7, 17, 22),
          startUtc: DateTime.utc(2026, 7, 17, 15),
        ),
      ],
      location: location,
      now: tz.TZDateTime(location, 2026, 7, 17, 8),
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.when.toUtc(), DateTime.utc(2026, 7, 17, 14, 45));
  });

  test('legacy task falls back to its device wall-clock start', () {
    final location = tz.getLocation('Europe/Helsinki');
    final candidates = buildPlanAlarmCandidates(
      tasks: [
        _task(
          key: 'legacy-wall',
          start: DateTime(2026, 7, 17, 14, 30),
          reminderOffset: 30,
        ),
      ],
      location: location,
      now: tz.TZDateTime(location, 2026, 7, 17, 12),
    );

    expect(candidates.single.when.hour, 14);
    expect(candidates.single.when.minute, 0);
  });

  test('completed, unscheduled, invalid, and past reminders are excluded', () {
    final location = tz.UTC;
    final start = DateTime.utc(2026, 7, 17, 12);
    final candidates = buildPlanAlarmCandidates(
      tasks: [
        _task(key: 'done', start: start, startUtc: start, isDone: true),
        _task(key: 'unset', start: start, startUtc: start, reminderOffset: null),
        _task(
          key: 'invalid',
          start: start,
          startUtc: start,
          reminderOffset: -1,
        ),
        _task(key: 'past', start: start, startUtc: start, reminderOffset: 60),
      ],
      location: location,
      now: tz.TZDateTime(tz.UTC, 2026, 7, 17, 12),
    );

    expect(candidates, isEmpty);
  });

  test('future reminders are sorted and capped', () {
    final location = tz.UTC;
    final candidates = buildPlanAlarmCandidates(
      tasks: [
        _task(
          key: 'later',
          start: DateTime.utc(2026, 7, 17, 15),
          startUtc: DateTime.utc(2026, 7, 17, 15),
        ),
        _task(
          key: 'first',
          start: DateTime.utc(2026, 7, 17, 13),
          startUtc: DateTime.utc(2026, 7, 17, 13),
        ),
      ],
      location: location,
      now: tz.TZDateTime(tz.UTC, 2026, 7, 17, 10),
      limit: 1,
    );

    expect(candidates.single.stableKey, 'first');
  });
}
