import 'package:counter/data/ai/viktor_action_contract.dart';
import 'package:counter/data/ai/viktor_schedule_planner.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask plan(String id, String title, int start, int end, {
  bool done = false, String? recurrence,
}) => PlanningTask(
  id: 0, pocketRecordId: id, planRowId: id,
  title: title, categoryId: 1, dateKey: '2026-10-21',
  isDone: done, rrule: recurrence,
  startTime: DateTime(2026, 10, 21, start ~/ 60, start % 60),
  endDateTime: DateTime(2026, 10, 21, end ~/ 60, end % 60),
);

ViktorActionBatch proposal(String policy) =>
  ViktorActionBatch.fromJson({
    'version': 1, 'request_id': 'priority_20261021_test',
    'actions': [{
      'name': 'create_plan',
      'arguments': {
        'title': 'MISSION IT Authorized Negotiator',
        'wall_day': '2026-10-21',
        'start_time': '13:00',
        'duration_minutes': 30,
        'conflict_policy': policy,
      }
    }]
  });

void main() {
  const planner = ViktorPlanInsertionPlanner();
  final day = DateTime(2026, 10, 21);
  final desiredStart = DateTime(2026, 10, 21, 13);
  const a = 'aaaaabbbbbccccc';
  const b = 'dddddeeeeefffff';
  const c = 'ggggghhhhhiiiii';

  test('Priority meeting cascades existing plans, preserving gaps and order', () {
    final existing = [
      plan(a, 'First', 12 * 60 + 45, 13 * 60 + 15),
      plan(b, 'Second', 13 * 60 + 20, 14 * 60 + 5),
      plan(c, 'After a gap', 16 * 60, 17 * 60),
    ];
    final inserted = planner.calculate(
      day: day, plans: existing, start: desiredStart,
      durationMinutes: 30, shiftConflicts: true,
      fixedTime: (_) => false,
    );
    expect(inserted.end, DateTime(2026, 10, 21, 13, 30));
    expect(inserted.shifted.map((p) => p.title).toList(),
      ['First', 'Second']);
    expect(inserted.shifted[0].startTime, DateTime(2026, 10, 21, 13, 30));
    expect(inserted.shifted[0].endDateTime, DateTime(2026, 10, 21, 14));
    expect(inserted.shifted[1].startTime, DateTime(2026, 10, 21, 14));
    expect(inserted.shifted[1].endDateTime, DateTime(2026, 10, 21, 14, 45));
    expect(inserted.shifted.map((p) => p.pocketRecordId).toList(), [a, b]);
    expect(inserted.shifted.length, 2);
  });

  test('Free slot causes no unrelated shift', () {
    final inserted = planner.calculate(
      day: day,
      plans: [plan(a, 'Before', 540, 600), plan(b, 'After', 900, 960)],
      start: desiredStart,
      durationMinutes: 30, shiftConflicts: true, fixedTime: (_) => false,
    );
    expect(inserted.shifted, isEmpty);
  });

  test('Do not change old unrelated overlapping tasks after a free gap', () {
    final proposed = planner.calculate(
      day: day,
      plans: [
        plan(a, 'Existing A', 900, 960),
        plan(b, 'Existing B overlapping A', 930, 990),
      ],
      start: desiredStart, durationMinutes: 30,
      shiftConflicts: true, fixedTime: (_) => false,
    );
    expect(proposed.shifted, isEmpty);
  });

  test('Reject policy refuses overlap, without modifying source plans', () {
    final existing = [plan(a, 'Meeting', 780, 840)];
    expect(() => planner.calculate(
      day: day, plans: existing, start: desiredStart,
      durationMinutes: 30, shiftConflicts: false,
      fixedTime: (_) => false,
    ), throwsStateError);
    expect(existing.single.startTime, DateTime(2026, 10, 21, 13));
  });

  test('No cascading through protected, completed or recurring plans', () {
    for (final protected in [
      plan(a, 'Fixed', 780, 840),
      plan(a, 'Completed', 780, 840, done: true),
      plan(a, 'Recurring', 780, 840, recurrence: 'FREQ=DAILY'),
    ]) {
      expect(() => planner.calculate(
        day: day, plans: [protected], start: desiredStart,
        durationMinutes: 30, shiftConflicts: true,
        fixedTime: (p) => p.title == 'Fixed',
      ), throwsStateError);
    }
    expect(() => planner.calculate(
      day: day, plans: [
        plan(a, 'Flexible', 780, 840),
        plan(b, 'Pinned later', 840, 900),
      ],
      start: desiredStart, durationMinutes: 30,
      shiftConflicts: true, fixedTime: (p) => p.pocketRecordId == b,
    ), throwsStateError);
  });

  test('Cannot cascade past midnight', () {
    expect(() => planner.calculate(
      day: day,
      plans: [
        plan(a, 'Long evening', 19 * 60, 23 * 60 + 45),
      ],
      start: DateTime(2026, 10, 21, 19),
      durationMinutes: 90,
      shiftConflicts: true, fixedTime: (_) => false,
    ), throwsStateError);
  });

  test('Source fingerprint covers unrelated rows and stale state', () {
    final first = planner.calculate(
      day: day, plans: [plan(a, 'Flexible', 780, 840)],
      start: desiredStart, durationMinutes: 30,
      shiftConflicts: true, fixedTime: (_) => false);
    final later = planner.calculate(
      day: day, plans: [
        plan(a, 'Flexible', 780, 840),
        plan(b, 'Another', 930, 990),
      ], start: desiredStart, durationMinutes: 30,
      shiftConflicts: true, fixedTime: (_) => false);
    expect(first.signature, isNot(later.signature));
  });

  test('Shift policy requires confirmation, normal create may be automatic', () {
    expect(proposal('shift').isSingleReversibleWrite, false);
    expect(proposal('shift').requiresPreview, true);
    expect(proposal('reject').isSingleReversibleWrite, true);
    expect(() => proposal('delete_and_force'), throwsFormatException);
  });

  test('Invalid duration or plan date rejected', () {
    expect(() => planner.calculate(
      day: day, plans: const [], start: desiredStart,
      durationMinutes: 0, shiftConflicts: true, fixedTime: (_) => false,
    ), throwsStateError);
    expect(() => planner.calculate(
      day: day, plans: const [],
      start: DateTime(2026, 10, 20, 13), durationMinutes: 30,
      shiftConflicts: true, fixedTime: (_) => false,
    ), throwsStateError);
  });
}
