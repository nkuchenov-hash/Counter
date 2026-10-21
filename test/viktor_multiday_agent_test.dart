import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_date_scope.dart';
import 'package:counter/data/ai/viktor_schedule_planner.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

ViktorActionBatch _batch(List<Map<String, dynamic>> actions) =>
    ViktorActionBatch.fromJson({
      'version': 1,
      'request_id': 'viktor_20261021_scope_test',
      'actions': actions,
    });

ViktorActionBatch _move({
  String source = '2026-10-20',
  String target = '2026-10-21',
}) => _batch([{
  'name': 'bulk_replan',
  'arguments': {
    'operations': [{
      'kind': 'move',
      'status': 'incomplete',
      'source_day': source,
      'target_day': target,
      'start_time': '09:00',
      'timezone': 'America/New_York',
    }]
  }
}]);

PlanningTask _plan(String id, String title, int hour, int minute,
    {bool done = false, String date = '2026-10-20'}) {
  final day = ViktorDateScope.parseDay(date);
  final start = DateTime(day.year, day.month, day.day, hour, minute);
  return PlanningTask(
    id: 0, planRowId: id, pocketRecordId: id,
    title: title, categoryId: 1, dateKey: date,
    isDone: done, startTime: start,
    endDateTime: start.add(const Duration(minutes: 45)),
  );
}

void main() {
  test('Intent bulk dates are independent of selected calendar day', () {
    final selectedCalendarDay = DateTime(2026, 9, 3);
    final action = _move().actions.single;
    final scope = ViktorDateScope.bulkDays(action);
    expect(ViktorDateScope.key(selectedCalendarDay), '2026-09-03');
    expect(scope.sourceDay, '2026-10-20');
    expect(scope.targetDay, '2026-10-21');
    expect(ViktorDateScope.parseDay(scope.sourceDay), DateTime(2026, 10, 20));
  });

  test('Profile relative dates work across month/year boundaries', () {
    final jan1 = DateTime(2027, 1, 1);
    expect(ViktorDateScope.key(
        DateTime(jan1.year, jan1.month, jan1.day - 1)),
        '2026-12-31');
    expect(ViktorDateScope.key(
        DateTime(jan1.year, jan1.month, jan1.day + 1)),
        '2027-01-02');
    expect(() => ViktorDateScope.parseDay('2026-02-30'),
        throwsFormatException);
  });

  test('Planning edit follows action wall_day, not selected page', () {
    final batch = _batch([{
      'name': 'move_plan_after',
      'arguments': {
        'plan_id': 'aaaaabbbbbccccc',
        'after_plan_id': 'dddddeeeeefffff',
        'wall_day': '2026-10-20',
      }
    }]);
    expect(ViktorDateScope.scheduleDay(batch, DateTime(2026, 10, 21)),
        DateTime(2026, 10, 20));
  });

  test('Duration edit can explicitly target a day outside the UI', () {
    final batch = _batch([{
      'name': 'update_plan_duration',
      'arguments': {
        'plan_id': 'aaaaabbbbbccccc',
        'expected_duration_minutes': 60,
        'duration_minutes': 45,
        'wall_day': '2026-10-20',
      }
    }]);
    expect(ViktorDateScope.scheduleDay(batch, DateTime(2026, 10, 21)),
        DateTime(2026, 10, 20));
  });

  test('Bulk move independently selects only unfinished source plans', () {
    final action = _move().actions.single;
    final scope = ViktorDateScope.bulkDays(action);
    final previous = [
      _plan('aaaaabbbbbccccc', 'Already done', 8, 0, done: true),
      _plan('dddddeeeeefffff', 'First unfinished', 13, 0),
      _plan('ggggghhhhhiiiii', 'Second unfinished', 17, 15),
    ];
    final preview = const ViktorBulkPlanner().calculate(
      action: action,
      source: previous,
      target: [],
      sourceDay: scope.sourceDay,
      targetDay: scope.targetDay,
      wallTime: (day, time, timezone) {
        expect(timezone, 'America/New_York');
        expect(day, '2026-10-21');
        expect(time, '09:00');
        return DateTime(2026, 10, 21, 9);
      },
      fixedTime: (_) => false,
    );
    expect(preview.moves.map((m) => m.plan.title).toList(),
        ['First unfinished', 'Second unfinished']);
    expect(preview.moves.map((m) => m.day).toSet(), {'2026-10-21'});
    expect(preview.moves[0].start, DateTime(2026, 10, 21, 9));
    expect(preview.moves[1].start, DateTime(2026, 10, 21, 9, 45));
    expect(preview.moves.last.end, DateTime(2026, 10, 21, 10, 30));
  });

  test('Bulk rejects multiple source days instead of loading arbitrary rows', () {
    final batch = _batch([{
      'name': 'bulk_replan',
      'arguments': {
        'operations': [
          {
            'kind': 'move', 'status': 'incomplete',
            'source_day': '2026-10-20',
            'target_day': '2026-10-21',
            'start_time': '09:00',
          },
          {
            'kind': 'compact', 'status': 'complete',
            'source_day': '2026-10-19',
          }
        ]
      }
    }]);
    expect(() => ViktorDateScope.bulkDays(batch.actions.single),
        throwsStateError);
  });
}
