import 'package:counter/data/ai/viktor_tag_duration_reflow.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/time_view_fixed_time_policy.dart';
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

  test('fixed-time tag protects meeting with a flexible-plan category', () {
    const callTag = Tag(
        tagId: 15, name: 'Meeting', pbRecordId: 'mmmmmnnnnnooooo');
    final meeting = item(anchor, 'Client meeting', 10 * 60, 45)
        .copyWith(tags: [callTag]);
    final fixedTags = <String>{'mmmmmnnnnnooooo'};
    expect(isPlanFixedInTimeView(meeting, fixedTags), isTrue);
    final moves = planner.calculate(
      day: day,
      plans: [
        item(flexible, 'Flexible work', 9 * 60, 60),
        meeting,
        item(later, 'Later work', 10 * 60 + 45, 30),
      ],
      targetDurationMinutes: {flexible: 90},
      fixedTime: (p) => isPlanFixedInTimeView(p, fixedTags),
    );
    expect(moves.map((m) => m.plan.pocketRecordId), [flexible, later]);
    expect(moves.first.start, DateTime(2026, 11, 9, 10, 45));
    expect(moves.first.end, DateTime(2026, 11, 9, 12, 15));
    expect(moves.last.start, DateTime(2026, 11, 9, 12, 15));
    expect(moves.any((m) => m.plan.pocketRecordId == anchor), isFalse);
    expect(meeting.startTime, DateTime(2026, 11, 9, 10));
    expect(meeting.endDateTime, DateTime(2026, 11, 9, 10, 45));
  });

  test('overflow explains the exact task and requires a user decision', () {
    final plans = [
      item(flexible, 'Late flexible', 22 * 60, 30),
      item(anchor, 'Protected', 22 * 60 + 30, 60),
    ];
    expect(() => planner.calculate(
      day: day, plans: plans,
      targetDurationMinutes: {flexible: 90},
      fixedTime: (p) => p.pocketRecordId == anchor,
    ), throwsA(isA<ViktorTagDurationOverflow>().having(
      (e) => e.toString(), 'details', allOf(
        contains('Late flexible'), contains('90 мин'), contains('9.11'),
      ),
    )));
  });

  test('feasible alternative keeps earlier expansion and skips only overflow',
      () {
    final plans = [
      item(flexible, 'Earlier', 21 * 60, 15),
      item(later, 'Overflow', 21 * 60 + 15, 15),
      item(anchor, 'Late call', 22 * 60, 105),
    ];
    final subset = planner.calculateFeasibleSubset(
      day: day, plans: plans,
      targetDurationMinutes: {flexible: 30, later: 60},
      fixedTime: (p) => p.pocketRecordId == anchor,
    );
    expect(subset.excludedPlans, ['Overflow']);
    expect(subset.moves.any((m) => m.plan.pocketRecordId == anchor), isFalse);
    final earlier = subset.moves.firstWhere(
        (m) => m.plan.pocketRecordId == flexible);
    expect(earlier.start, DateTime(2026, 11, 9, 21));
    expect(earlier.end, DateTime(2026, 11, 9, 21, 30));
    final next = subset.moves.firstWhere(
        (m) => m.plan.pocketRecordId == later);
    expect(next.start, DateTime(2026, 11, 9, 21, 30));
    expect(next.end, DateTime(2026, 11, 9, 21, 45));
  });

  test('partial alternative never reverts reductions that free time', () {
    final plans = [
      item(flexible, 'Shorten first', 21 * 60, 60),
      item(later, 'Too long', 22 * 60, 15),
      item(anchor, 'Fixed late', 22 * 60 + 30, 75),
    ];
    final subset = planner.calculateFeasibleSubset(
      day: day, plans: plans,
      targetDurationMinutes: {flexible: 30, later: 120},
      fixedTime: (p) => p.pocketRecordId == anchor,
    );
    expect(subset.excludedPlans, ['Too long']);
    expect(subset.moves.first.plan.pocketRecordId, flexible);
    expect(subset.moves.first.end, DateTime(2026, 11, 9, 21, 30));
  });

  test('if no requested expansion fits, the alternative has no silent writes',
      () {
    final subset = planner.calculateFeasibleSubset(
      day: day,
      plans: [item(flexible, 'Late', 23 * 60 + 15, 30)],
      targetDurationMinutes: {flexible: 90},
      fixedTime: (_) => false,
    );
    expect(subset.moves, isEmpty);
    expect(subset.excludedPlans, ['Late']);
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
