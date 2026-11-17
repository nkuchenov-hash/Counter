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
  test('Narrated user chores preserve their durations and only create Plans', () {
    final input = 'Сегодня приём пищи был полчаса, после этого был '
        'вайбкодинг на час, после дела по дому: приготовление яиц '
        'полчаса, приготовление рыбы 20 минут, обустройство электрики '
        'в спальне оставшееся время';
    final batch = ViktorDateScope.narratedChoreBatch(
      input: input, profileToday: DateTime(2026, 11, 17),
      requestId: 'viktor_real_chore_intent');
    expect(batch, isNotNull);
    expect(batch!.actions.map((a) => a.name), ['create_plans_batch']);
    final plans = batch.actions.single.arguments['plans'] as List;
    expect(plans.length, 3);
    expect(plans[0]['title'], 'приготовление яиц');
    expect(plans[0]['duration_minutes'], 30);
    expect(plans[1]['title'], 'приготовление рыбы');
    expect(plans[1]['duration_minutes'], 20);
    expect(plans[2]['title'], 'обустройство электрики в спальне');
    expect(plans[2]['fill_remaining'], true);
    expect(plans.every((p) => p['wall_day'] == '2026-11-17'), true);
    expect(plans.every((p) => !p.containsKey('start_time')), true);
    expect(plans.any((p) => p['title'].toString().contains('вайбкодинг')),
        false, reason: 'Past activity cannot become a future Plan');
  });

  test('Conservative chores parser refuses unspecified/unsafe durations', () {
    for (final sentence in [
      'Сегодня приём пищи, после дела по дому: приготовить яйца, рыбу',
      'Сегодня после дела по дому: яйца полчаса, рыба немного',
      'Вчера после дела по дому: яйца полчаса, рыба 20 минут',
      'Сегодня после дела по дому: яйца полчаса, рыба 20 минут, '
          'ремонт оставшееся время, звонок 10 минут',
    ]) {
      expect(ViktorDateScope.narratedChoreBatch(
          input: sentence, profileToday: DateTime(2026, 11, 17),
          requestId: 'viktor_no_guesses'), isNull, reason: sentence);
    }
  });

  test('Explicit yesterday unfinished carry-forward bypasses model', () {
    final batch = ViktorDateScope.directYesterdayCarryForward(
      input: 'Перенеси вчерашние невыполненные планы на сегодня',
      profileToday: DateTime(2026, 11, 17),
      requestId: 'viktor_direct_20261117',
    );
    expect(batch, isNotNull);
    expect(batch!.actions.single.name, 'bulk_replan');
    expect(batch.requiresPreview, isTrue);
    final op = (batch.actions.single.arguments['operations'] as List).single
        as Map;
    expect(op['kind'], 'move');
    expect(op['status'], 'incomplete');
    expect(op['source_day'], '2026-11-16');
    expect(op['target_day'], '2026-11-17');
    expect(op.containsKey('start_time'), false);
    final dec = ViktorDateScope.directYesterdayCarryForward(
      input: 'Перенеси вчерашние незавершённые задачи на сегодня',
      profileToday: DateTime(2027, 1, 1),
      requestId: 'viktor_direct_20270101',
    );
    expect((dec!.actions.single.arguments['operations'] as List)
        .single['source_day'], '2026-12-31');
    final spring = ViktorDateScope.directYesterdayCarryForward(
      input: 'Перенеси вчерашние невыполненные планы на сегодня',
      profileToday: DateTime(2027, 3, 15),
      requestId: 'viktor_direct_spring',
    );
    expect((spring!.actions.single.arguments['operations'] as List)
        .single['source_day'], '2027-03-14');
  });

  test('Native transfer never guesses scope of a qualified request', () {
    for (final input in [
      'Перенеси вчерашние невыполненные планы на завтра',
      'Перенеси вчерашние невыполненные планы на сегодня, кроме работы',
      'Перенеси только вчерашние невыполненные задачи на сегодня',
      'Почему вчерашние невыполненные планы не перенесены на сегодня?',
    ]) {
      expect(ViktorDateScope.directYesterdayCarryForward(
        input: input, profileToday: DateTime(2026, 11, 17),
        requestId: 'viktor_qualified_test',
      ), isNull, reason: input);
    }
  });

  test('An expressly selected source default-time plan can move day', () {
    final action = _batch([{
      'name': 'bulk_replan', 'arguments': {'operations': [{
        'kind': 'move', 'status': 'incomplete',
        'source_day': '2026-10-20', 'target_day': '2026-10-21',
      }]},
    }]).actions.single;
    final selected = _plan('aaaaabbbbbccccc', 'Source default-time plan', 9, 0);
    final occupied = _plan('dddddeeeeefffff', 'Protected target', 10, 30,
        date: '2026-10-21');
    final preview = const ViktorBulkPlanner().calculate(
      action: action, source: [selected], target: [occupied],
      sourceDay: '2026-10-20', targetDay: '2026-10-21',
      fixedTime: (task) => task.pocketRecordId == selected.pocketRecordId ||
          task.pocketRecordId == occupied.pocketRecordId,
      wallTime: (_, _, _) => throw StateError('No explicit clock'),
      autoStart: (_) => DateTime(2026, 10, 21, 10, 20),
    );
    expect(preview.moves.single.start, DateTime(2026, 10, 21, 11, 15));
    expect(occupied.startTime, DateTime(2026, 10, 21, 10, 30));
  });

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

  test('Yesterday unfinished move auto-fits after now without moving existing plans', () {
    final batch = _batch([{
      'name': 'bulk_replan',
      'arguments': {'operations': [{
        'kind': 'move', 'status': 'incomplete',
        'source_day': '2026-10-20',
        'target_day': '2026-10-21',
      }]}
    }]);
    final source = [
      _plan('aaaaabbbbbccccc', 'Completed - leave yesterday', 8, 0, done: true),
      _plan('dddddeeeeefffff', 'Unfinished one', 13, 0),
      _plan('ggggghhhhhiiiii', 'Unfinished two', 17, 0),
    ];
    final target = [
      _plan('jjjjjkkkkklllll', 'Existing plan', 10, 45,
          date: '2026-10-21'),
      _plan('mmmmnnnnnooooo', 'Price Reporter Planning', 11, 45,
          date: '2026-10-21'),
    ];
    final preview = const ViktorBulkPlanner().calculate(
      action: batch.actions.single, source: source, target: target,
      sourceDay: '2026-10-20', targetDay: '2026-10-21',
      fixedTime: (_) => false,
      wallTime: (_, _, _) => throw StateError('No fabricated time allowed'),
      autoStart: (date) {
        expect(date, '2026-10-21');
        return DateTime(2026, 10, 21, 10, 30);
      },
    );
    expect(preview.moves.map((m) => m.plan.title),
        ['Unfinished one', 'Unfinished two']);
    expect(preview.moves[0].start, DateTime(2026, 10, 21, 12, 30));
    expect(preview.moves[0].end, DateTime(2026, 10, 21, 13, 15));
    expect(preview.moves[1].start, DateTime(2026, 10, 21, 13, 15));
    expect(source.first.isDone, isTrue);
    expect(target[1].startTime, DateTime(2026, 10, 21, 11, 45));
  });

  test('Auto-placement refuses overflow rather than changing the day', () {
    final action = _batch([{
      'name': 'bulk_replan',
      'arguments': {'operations': [{
        'kind': 'move', 'status': 'incomplete',
        'source_day': '2026-10-20', 'target_day': '2026-10-21',
      }]}
    }]).actions.single;
    expect(() => const ViktorBulkPlanner().calculate(
      action: action,
      source: [_plan('aaaaabbbbbccccc', 'Unfinished', 12, 0)],
      target: [_plan('dddddeeeeefffff', 'Late commitment', 23, 0,
          date: '2026-10-21')],
      sourceDay: '2026-10-20', targetDay: '2026-10-21',
      wallTime: (_, _, _) => throw StateError('No fabricated clock'),
      fixedTime: (_) => false,
      autoStart: (_) => DateTime(2026, 10, 21, 23, 20),
    ), throwsStateError);
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
