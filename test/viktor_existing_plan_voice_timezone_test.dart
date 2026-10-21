import 'package:counter/data/ai/viktor_existing_plan.dart';
import 'package:counter/data/ai/viktor_plan_timezone.dart';
import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_voice_error.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

PlanningTask task(String id, String title, DateTime at) => PlanningTask(
  id: 0, planRowId: id, pocketRecordId: id,
  categoryId: 1, dateKey: '${at.year}-${at.month}-${at.day}',
  title: title, startTime: at,
  endDateTime: at.add(const Duration(minutes: 30)),
);

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  test('Already scheduled AGE Solutions call blocks duplicate before unrelated conflict', () {
    final existingCall = task('aaaaabbbbbccccc',
      'AGE Solutions - ADD SIN', DateTime(2026, 10, 23, 12));
    final falcon = task('dddddeeeeefffff',
      'FALCON ADD SIN Review and reply', DateTime(2026, 10, 23, 12, 15));
    final found = ViktorExistingPlan.find(
      title: 'Call AGE Solutions - ADD SIN',
      start: DateTime(2026, 10, 23, 12),
      plans: [falcon, existingCall],
    );
    expect(found?.pocketRecordId, existingCall.pocketRecordId);
    expect(ViktorExistingPlan.describe(found!), contains('уже существует'));
  });

  test('Only same date and same meaningful title count as duplicate', () {
    final p = task('aaaaabbbbbccccc',
      'AGE Solutions - ADD SIN', DateTime(2026, 10, 23, 12));
    expect(ViktorExistingPlan.find(title: 'AGE Solutions - ADD SIN',
      start: DateTime(2026, 10, 24, 12), plans: [p]), isNull);
    expect(ViktorExistingPlan.find(title: 'FALCON ADD SIN',
      start: DateTime(2026, 10, 23, 12), plans: [p]), isNull);
  });

  test('NY explicitly uses NY local wall time, not computer or profile clock', () {
    final start = viktorPlanStartInProfileWall(
      wallDay: '2026-10-23', startTime: '12:00', timezone: 'NY',
      profileTimezone: 'Moscow',
      toProfileWall: (utc) => tz.TZDateTime.from(
        utc, tz.getLocation('Europe/Moscow')),
    );
    expect(start.year, 2026);
    expect(start.month, 10);
    expect(start.day, 23);
    expect(start.hour, 19);
    expect(start.minute, 0);
  });

  test('NY local 12 retains 12 on NY profile, with seasonal DST', () {
    final start = viktorPlanStartInProfileWall(
      wallDay: '2026-10-23', startTime: '12:00',
      timezone: 'America/New_York',
      profileTimezone: 'New York', toProfileWall: (_) => throw StateError('noop'),
    );
    expect(start, DateTime(2026, 10, 23, 12));
  });

  test('Create-plan tool accepts explicit timezone but not unapproved fields', () {
    final parsed = ViktorAction.fromJson({
      'name': 'create_plan',
      'arguments': {
        'title': 'AGE Solutions - ADD SIN', 'wall_day': '2026-10-23',
        'start_time': '12:00', 'duration_minutes': 30,
        'timezone': 'America/New_York',
      }
    });
    expect(parsed.arguments['timezone'], 'America/New_York');
  });

  test('Audio errors identify capture versus recognition without exposing raw data', () {
    expect(viktorVoiceErrorText(StateError('voice_capture_failed'),
      stage: 'capture'), contains('захвата звука'));
    expect(viktorVoiceErrorText(Exception('unknown audio recording error'),
      stage: 'capture'), contains('микрофона'));
    expect(viktorVoiceErrorText(const FormatException('speech_provider_rejected (HTTP 403)')),
      contains('авторизацию'));
    expect(viktorVoiceErrorText(Exception('secret=abcdef')),
      isNot(contains('abcdef')));
  });
}
