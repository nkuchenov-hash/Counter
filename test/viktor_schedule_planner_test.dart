import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_schedule_planner.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

const a = 'aaaaabbbbbccccc';
const b = 'dddddeeeeefffff';
const c = 'ggggghhhhhiiiii';

PlanningTask task(String id, String title, int start, int end,
    {String? rrule}) => PlanningTask(
  id: 0, pocketRecordId: id, planRowId: id,
  categoryId: 1, title: title, dateKey: '2026-10-17',
  startTime: DateTime(2026, 10, 17, start ~/ 60, start % 60),
  endDateTime: DateTime(2026, 10, 17, end ~/ 60, end % 60),
  rrule: rrule,
);

ViktorActionBatch proposal(List<Map<String, dynamic>> actions) =>
    ViktorActionBatch.fromJson({
      'version': 1,
      'request_id': 'req_20261017_test',
      'actions': actions,
    });

void main() {
  final calc = const ViktorSchedulePlanner();
  final day = DateTime(2026, 10, 17);
  final basics = [
    task(a, 'Зарядка', 540, 580),
    task(b, 'Завтрак', 580, 610),
    task(c, 'Душ', 610, 640),
  ];

  test('40 to 30 minutes and breakfast right after exercise', () {
    final batch = proposal([
      {'name': 'update_plan_duration', 'arguments': {
        'plan_id': a, 'expected_duration_minutes': 40,
        'duration_minutes': 30}},
      {'name': 'move_plan_after', 'arguments': {
        'plan_id': b, 'after_plan_id': a,
        'wall_day': '2026-10-17'}},
    ]);
    final result = calc.calculate(day: day, plans: basics,
      actions: batch.actions, fixedTime: (_) => false);
    final exercise = result.after.firstWhere((p) => p.pocketRecordId == a);
    final breakfast = result.after.firstWhere((p) => p.pocketRecordId == b);
    expect(exercise.endDateTime, DateTime(2026, 10, 17, 9, 30));
    expect(breakfast.startTime, exercise.endDateTime);
    expect(breakfast.endDateTime, DateTime(2026, 10, 17, 10, 0));
    expect(result.changed.length, 2);
  });

  test('fixed-time later task blocks a collision', () {
    final result = () => calc.calculate(
      day: day, plans: basics,
      actions: proposal([{'name': 'update_plan_duration', 'arguments': {
        'plan_id': a, 'expected_duration_minutes': 40,
        'duration_minutes': 60,
      }}]).actions,
      fixedTime: (p) => p.pocketRecordId == b,
    );
    expect(result, throwsStateError);
  });

  test('recurrent plan never shifts implicitly', () {
    expect(() => calc.calculate(
      day: day,
      plans: [basics.first, task(b, 'Завтрак', 580, 610,
          rrule: 'FREQ=DAILY')],
      actions: proposal([{'name': 'update_plan_duration', 'arguments': {
        'plan_id': a, 'expected_duration_minutes': 40,
        'duration_minutes': 30,
      }}]).actions,
      fixedTime: (_) => false,
    ), throwsStateError);
  });

  test('stale original duration rejects without a patch', () {
    expect(() => calc.calculate(
      day: day, plans: basics,
      actions: proposal([{'name': 'update_plan_duration', 'arguments': {
        'plan_id': a, 'expected_duration_minutes': 50,
        'duration_minutes': 30,
      }}]).actions,
      fixedTime: (_) => false,
    ), throwsStateError);
  });

  test('cannot move item after itself', () {
    expect(() => proposal([{'name': 'move_plan_after', 'arguments': {
      'plan_id': a, 'after_plan_id': a, 'wall_day': '2026-10-17',
    }}]), throwsFormatException);
  });
}
