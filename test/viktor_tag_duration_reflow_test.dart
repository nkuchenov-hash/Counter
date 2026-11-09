import 'package:counter/data/ai/viktor_tag_duration_reflow.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask item(
    String id, String name, int startMinutes, int durationMinutes, {
    bool done = false,
    bool recurring = false,
  }) {
  final base = DateTime(2026, 11, 9);
  final start = base.add(Duration(minutes: startMinutes));
  return PlanningTask(
    id: 0,
    pocketRecordId: id,
    planRowId: id,
    title: name,
    categoryId: 1,
    dateKey: '2026-11-09',
    isDone: done,
    rrule: recurring ? 'FREQ=DAILY' : null,
    startTime: start,
    endDateTime: start.add(Duration(minutes: durationMinutes)),
  );
}

void main() {
  const planner = ViktorTagDurationReflow();
  final day = DateTime(2026, 11, 9);
  const flexible = 'aaaaabbbbbccccc';
  const anchor = 'dddddeeeeefffff';
  const later = 'ggggghhhhhiiiii';
  const completed = 'jjjjjkkkkklllll';

  test('fixed event stays put and flexible tasks use the next free slot', () {
    final plans = [
      item(flexible, 'Working block', 9 * 60, 60),
      item(anchor, 'Fixed call', 10 * 60, 60),
      item(later, 'Next work', 11 * 60, 30),
    ];
    final changes = planner.calculate(
      day: day, plans: plans,
      targetDurationMinutes: {flexible: 120},
      fixedTime: (p) => p.pocketRecordId == anchor,
    );
    expect(changes.map((m) => m.plan.pocketRecordId).toList(),
        [flexible, later]);
    expect(changes.first.start, DateTime(2026, 11, 9, 11));
    expect(changes.first.end, DateTime(2026, 11, 9, 13));
    expect(changes.last.start, DateTime(2026, 11, 9, 13));
    expect(changes.last.end, DateTime(2026, 11, 9, 13, 30));
    expect(changes.any((m) => m.plan.pocketRecordId == anchor), isFalse);
  });

  test('recurring and completed events are barriers, not changed patches', () {
    final plans = [
      item(flexible, 'Work', 9 * 60, 30),
      item(anchor, 'Daily recurring', 10 * 60, 30, recurring: true),
      item(completed, 'Completed call', 11 * 60, 30, done: true),
      item(later, 'Flexible', 10 * 60 + 30, 30),
    ];
    final result = planner.calculate(
      day: day, plans: plans, targetDurationMinutes: {flexible: 120},
      fixedTime: (_) => false,
    );
    expect(result.first.start, DateTime(2026, 11, 9, 11, 30));
    expect(result.first.end, DateTime(2026, 11, 9, 13, 30));
    expect(result.any((m) => m.plan.pocketRecordId == anchor), isFalse);
    expect(result.any((m) => m.plan.pocketRecordId == completed), isFalse);
    expect(result.every((m) => m.plan.isDone == false), isTrue);
  });

  test('an immovable barrier does not block independent earlier changes', () {
    final tasks = [
      item(flexible, 'Morning', 7 * 60, 30),
      item(anchor, 'Fixed', 10 * 60, 60),
      item(later, 'Afternoon', 14 * 60, 60),
    ];
    final changes = planner.calculate(
      day: day, plans: tasks,
      targetDurationMinutes: {flexible: 60, later: 45},
      fixedTime: (p) => p.pocketRecordId == anchor,
    );
    expect(changes, hasLength(2));
    expect(changes[0].start, tasks[0].startTime);
    expect(changes[0].end, DateTime(2026, 11, 9, 8));
    expect(changes[1].start, tasks[2].startTime);
    expect(changes[1].end, DateTime(2026, 11, 9, 14, 45));
  });

  test('insufficient free time is explicit and never returns partial moves', () {
    expect(() => planner.calculate(
      day: day,
      plans: [
        item(flexible, 'Late flexible', 22 * 60, 30),
        item(anchor, 'Protected meeting', 22 * 60 + 30, 60),
      ],
      targetDurationMinutes: {flexible: 90},
      fixedTime: (p) => p.pocketRecordId == anchor,
    ), throwsA(isA<StateError>().having(
      (e) => e.toString(), 'message', contains('Недостаточно места'))));
  });

  test('unchanged protected-only day has no writes', () {
    final changes = planner.calculate(
      day: day,
      plans: [item(anchor, 'Protected', 9 * 60, 60, recurring: true)],
      targetDurationMinutes: const {},
      fixedTime: (_) => false,
    );
    expect(changes, isEmpty);
  });
}
