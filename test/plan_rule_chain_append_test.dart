import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask _task(
  String id,
  int categoryId,
  int hour,
  int minute, {
  int duration = 30,
  bool explicitEnd = true,
}) {
  final start = DateTime(2026, 9, 21, hour, minute);
  return PlanningTask(
    id: id.hashCode,
    title: id,
    categoryId: categoryId,
    isDone: false,
    dateKey: '2026-09-21',
    order: 0,
    startTime: start,
    endDateTime: explicitEnd
        ? start.add(Duration(minutes: duration))
        : null,
    planRowId: id,
  );
}

void main() {
  final db = DatabaseService.instance;
  final day = DateTime(2026, 9, 21);

  test('explicit time collision moves to the next available slot', () {
    final first = _task('first', 10, 9, 0);
    final later = _task('later', 11, 10, 0);
    final unrelated = _task('unrelated', 20, 11, 0, duration: 60);

    final resolved = db.resolveAutoPlanSchedule(
      wallDay: day,
      categoryId: 10,
      tags: const [],
      existingDayPlans: [first, later, unrelated],
      explicitStartWall: DateTime(2026, 9, 21, 9, 0),
      explicitEndWall: DateTime(2026, 9, 21, 9, 30),
      hasExplicitTimeRange: true,
    );

    expect(resolved.startWall, DateTime(2026, 9, 21, 9, 30));
    expect(resolved.endWall, DateTime(2026, 9, 21, 10, 0));
  });

  test('a gap shorter than the plan duration is skipped', () {
    final first = _task('first', 10, 9, 0);
    final second = _task('second', 11, 9, 45);

    final resolved = db.resolveAutoPlanSchedule(
      wallDay: day,
      categoryId: 10,
      tags: const [],
      existingDayPlans: [first, second],
      explicitStartWall: DateTime(2026, 9, 21, 9, 0),
      explicitEndWall: DateTime(2026, 9, 21, 9, 30),
      hasExplicitTimeRange: true,
    );

    expect(resolved.startWall, DateTime(2026, 9, 21, 10, 15));
    expect(resolved.endWall, DateTime(2026, 9, 21, 10, 45));
  });

  test('an explicit non-overlapping interval keeps its original time', () {
    final unrelated = _task('unrelated', 20, 11, 0);
    final requestedStart = DateTime(2026, 9, 21, 9, 0);
    final requestedEnd = DateTime(2026, 9, 21, 9, 30);

    final resolved = db.resolveAutoPlanSchedule(
      wallDay: day,
      categoryId: 10,
      tags: const [],
      existingDayPlans: [unrelated],
      explicitStartWall: requestedStart,
      explicitEndWall: requestedEnd,
      hasExplicitTimeRange: true,
    );

    expect(resolved.startWall, requestedStart);
    expect(resolved.endWall, requestedEnd);
  });

  test('existing plans without an end use their resolved duration', () {
    final openEnded = _task(
      'open-ended',
      10,
      10,
      0,
      explicitEnd: false,
    );

    final resolved = db.resolveAutoPlanSchedule(
      wallDay: day,
      categoryId: 10,
      tags: const [],
      existingDayPlans: [openEnded],
      explicitStartWall: DateTime(2026, 9, 21, 10, 0),
      explicitEndWall: DateTime(2026, 9, 21, 10, 30),
      hasExplicitTimeRange: true,
    );

    expect(resolved.startWall, DateTime(2026, 9, 21, 10, 30));
    expect(resolved.endWall, DateTime(2026, 9, 21, 11, 0));
  });
}
