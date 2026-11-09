import 'dart:io';

import 'package:counter/data/models.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
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
  test('November 2026 month grid never duplicates November 1 at DST rollback', () {
    final month = DateTime(2026, 11, 1);
    expect(calendarMonthWeekCount(month), 6);
    expect(calendarMonthGridStart(month), DateTime(2026, 10, 26));
    expect(calendarMonthGridDay(month, 0, 6), DateTime(2026, 11, 1));
    expect(calendarMonthGridDay(month, 1, 0), DateTime(2026, 11, 2));
    expect(calendarMonthGridDay(month, 2, 0), DateTime(2026, 11, 9));
    expect(calendarMonthGridDay(month, 5, 0), DateTime(2026, 11, 30));
    expect(calendarMonthGridDay(month, 5, 6), DateTime(2026, 12, 6));
  });

  test('civil-day helpers preserve weekday placement across spring DST', () {
    expect(calendarAddDays(DateTime(2027, 3, 8), 6),
        DateTime(2027, 3, 14));
    expect(calendarAddDays(DateTime(2027, 3, 8), 7),
        DateTime(2027, 3, 15));
    expect(calendarWeekStartMonday(DateTime(2027, 3, 14)),
        DateTime(2027, 3, 8));
    expect(calendarWeekStartMonday(DateTime(2027, 3, 15)),
        DateTime(2027, 3, 15));
  });

  test('calendar day taps open the Plans tab, without implicit plan creation', () {
    final calendar = File('lib/features/calendar/calendar_view.dart')
        .readAsStringSync();
    final shell = File('lib/app/shell/shared/shell_tab_host.dart')
        .readAsStringSync();
    final monthGrid = File('lib/features/calendar/calendar_month_grid.dart')
        .readAsStringSync();
    final weekGrid = File('lib/features/calendar/calendar_week_grid.dart')
        .readAsStringSync();

    expect(calendar, contains('unawaited(widget.onSelectDate(d, d));'));
    expect(calendar, isNot(contains('bool createPlan = true')));
    expect(calendar, contains('onSlotTap: _onDayTapped'));
    expect(shell, contains('setShellPageIndex(1);'));
    expect(monthGrid, contains('calendarMonthGridDay('));
    expect(weekGrid, contains('calendarAddDays(weekStart, i)'));
    expect(weekGrid, isNot(contains('weekStart.add(Duration(days:')));
  });

}
