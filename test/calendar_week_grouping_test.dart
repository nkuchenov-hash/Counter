import 'package:counter/data/models.dart';
import 'package:counter/features/calendar/calendar_week_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask makeTask(String title, int category, int hour, int minute,
    {int length = 30}) {
  final start = DateTime(2026, 10, 19, hour, minute);
  return PlanningTask(
    id: 0,
    title: title,
    categoryId: category,
    dateKey: '2026-10-19',
    startTime: start,
    endDateTime: start.add(Duration(minutes: length)),
  );
}

void main() {
  test('nearby tasks in same parent category create one visual block', () {
    final tasks = [
      makeTask('A', 11, 9, 0),
      makeTask('B', 12, 9, 35),
      makeTask('C', 13, 10, 10),
    ];
    final blocks = buildCalendarWeekBlocks(tasks, (_) => 1);
    expect(blocks, hasLength(1));
    expect(blocks.single.tasks, hasLength(3));
    expect(blocks.single.start, DateTime(2026, 10, 19, 9));
    expect(blocks.single.end, DateTime(2026, 10, 19, 10, 40));
  });
  test('different parent branches remain independent', () {
    final blocks = buildCalendarWeekBlocks(
      [makeTask('A', 11, 9, 0), makeTask('B', 12, 9, 15)],
      (id) => id,
    );
    expect(blocks, hasLength(2));
    final lanes = layoutCalendarWeekBlocks(blocks);
    expect(lanes.map((p) => p.lane).toSet(), {0, 1});
    expect(lanes.map((p) => p.laneCount).toSet(), {2});
  });
  test('large temporal gaps never become one giant group', () {
    final blocks = buildCalendarWeekBlocks(
      [makeTask('A', 11, 9, 0), makeTask('B', 11, 15, 0)],
      (_) => 1,
    );
    expect(blocks, hasLength(2));
    expect(layoutCalendarWeekBlocks(blocks).map((p) => p.laneCount), [1, 1]);
  });
}
