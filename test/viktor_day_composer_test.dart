import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_day_composer.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask plan(String id, String title, String day, int start, int duration,
    {bool done = false, List<Tag> tags = const []}) => PlanningTask(
  id: 0, pocketRecordId: id, planRowId: id, categoryId: 1,
  title: title, dateKey: day, isDone: done, tags: tags,
  startTime: DateTime.parse(day).add(Duration(minutes: start)),
  endDateTime: DateTime.parse(day).add(Duration(minutes: start + duration)),
);

ViktorAction compose({List<Map<String, Object?>>? meetings}) =>
  ViktorAction.fromJson({
    'name': 'compose_day',
    'arguments': {
      'source_day': '2026-10-20',
      'target_day': '2026-10-21',
      'source_filter': 'Price Reporter',
      'start_time': '09:00',
      'timezone': 'New York',
      'urgent_first': true,
      'meetings': meetings ?? [
        {'title': 'Price Reporter Case Study',
         'start_time': '11:00', 'duration_minutes': 60},
        {'title': 'MISSION IT Authorized Negotiator',
         'start_time': '13:00', 'duration_minutes': 30},
        {'title': 'LAREDO TS Weekly Call',
         'start_time': '15:00', 'duration_minutes': 30},
      ],
    }
  });

DateTime wall(String day, String time, String zone) {
  expect(zone, 'New York');
  final hh = time.split(':').map(int.parse).toList();
  return DateTime.parse(day).add(Duration(hours: hh[0], minutes: hh[1]));
}

const urgency = Tag(tagId: 1, name: 'Срочно');

void main() {
  const planner = ViktorDayComposer();

  final source = [
    plan('aaaaabbbbbccccc', 'Ordinary A', '2026-10-20', 540, 60),
    plan('dddddeeeeefffff', 'Urgent B', '2026-10-20', 600, 60,
      tags: [urgency]),
    plan('ggggghhhhhiiiii', 'Ordinary C', '2026-10-20', 660, 30),
    plan('jjjjjkkkkklllll', 'Done D', '2026-10-20', 720, 30,
      done: true),
  ];
  final existing = [
    plan('mmmmnnnnooooppp', 'Existing appointment',
      '2026-10-21', 720, 30),
  ];

  ViktorComposedDay build({
      List<PlanningTask>? src,
      List<PlanningTask>? dest,
      ViktorAction? action,
      bool Function(PlanningTask)? fixed,
  }) => planner.calculate(
    action: action ?? compose(),
    source: src ?? source,
    target: dest ?? existing,
    sourceMatches: (p) => p.categoryId == 1,
    urgent: (p) => p.tags.any((t) => t.name == 'Срочно'),
    fixedTime: fixed ?? (_) => false,
    wallTime: wall,
  );

  test('one preview moves incomplete yesterday and reserves all three meetings',
      () {
    final result = build();
    expect(result.moves.length, 3);
    expect(result.urgentCount, 1);
    expect(result.moves.map((m) => m.plan.title).toList(),
      ['Urgent B', 'Ordinary A', 'Ordinary C']);
    expect(result.moves[0].start.hour, 9);
    expect(result.moves[1].start.hour, 10);
    expect(result.moves[2].start.hour, 12);
    expect(result.moves[2].start.minute, 30);
    expect(result.moves[2].end.hour, 13);
    expect(result.meetings.map((m) => m.start.hour), [11, 13, 15]);
    expect(result.meetings.every((m) => !m.alreadyExists), true);
    expect(result.describe(), contains('MISSION IT Authorized Negotiator'));
    expect(result.describe(), contains('LAREDO TS Weekly Call'));
    expect(result.moves.every((m) => !m.plan.isDone), true);
  });

  test('existing identical appointment is not added twice', () {
    final already = plan('pppppqqqqqrrrrr',
        'Price Reporter Case Study', '2026-10-21', 660, 60);
    final result = build(dest: [...existing, already]);
    expect(result.meetings.first.alreadyExists, true);
    expect(result.meetings.where((m) => !m.alreadyExists).length, 2);
  });

  test('meeting conflicting with existing plan aborts entire preview', () {
    final occupied = plan('sssssuuuuuvvvvv',
        'Important fixed call', '2026-10-21', 660, 60);
    expect(() => build(dest: [...existing, occupied]), throwsStateError);
  });

  test('recurring, fixed and unsynced source task fail closed', () {
    expect(() => build(fixed: (p) => p.title == 'Urgent B'),
      throwsStateError);
    final recurrent = source.first.copyWith(rrule: 'FREQ=DAILY');
    expect(() => build(src: [recurrent, ...source.skip(1)]),
      throwsStateError);
    final unsynced = source.first.copyWith(isSynced: false);
    expect(() => build(src: [unsynced, ...source.skip(1)]),
      throwsStateError);
  });

  test('does not guess source filter when category or tag not found', () {
    expect(() => planner.calculate(
      action: compose(),
      source: source, target: existing,
      sourceMatches: (_) => false,
      urgent: (_) => false, fixedTime: (_) => false, wallTime: wall,
    ), throwsStateError);
  });

  test('remainder that cannot fit today fails without mutations', () {
    final giant = plan('wwwwwxxxxxyyyyy', 'Long work',
        '2026-10-20', 540, 900);
    expect(() => build(src: [giant]), throwsStateError);
  });
}
