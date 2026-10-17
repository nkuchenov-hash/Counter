import 'package:counter/data/models.dart';
import 'package:counter/features/calendar/calendar_drag_and_reschedule.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask scheduled(String title, int hour, int minute, {int duration = 30}) {
  final start = DateTime(2026, 10, 19, hour, minute);
  return PlanningTask(
    id: 4,
    title: title,
    categoryId: 2,
    dateKey: '2026-10-19',
    startTime: start,
    endDateTime: start.add(Duration(minutes: duration)),
  );
}

void main() {
  test('rigid group move preserves individual durations and relative gaps', () {
    final moved = calendarShiftedPlans([
      scheduled('A', 9, 0),
      scheduled('B', 9, 50, duration: 45),
    ], DateTime(2026, 10, 20, 11, 20));

    expect(moved[0].start, DateTime(2026, 10, 20, 11, 20));
    expect(moved[0].end, DateTime(2026, 10, 20, 11, 50));
    expect(moved[1].start, DateTime(2026, 10, 20, 12, 10));
    expect(moved[1].end, DateTime(2026, 10, 20, 12, 55));
  });

  test('month move retains wall time while crossing a month boundary', () {
    final moved = calendarShiftedPlans(
      [scheduled('A', 14, 30)],
      DateTime(2026, 11, 1, 14, 30),
    );
    expect(moved.single.start, DateTime(2026, 11, 1, 14, 30));
  });

  test('drag does not mutate the original source plan', () {
    final original = scheduled('A', 9, 0);
    calendarShiftedPlans([original], DateTime(2026, 10, 20, 10, 0));
    expect(original.startTime, DateTime(2026, 10, 19, 9, 0));
  });
}
