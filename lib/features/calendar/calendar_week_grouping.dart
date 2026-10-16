import 'package:counter/data/models.dart';

/// A visual-only grouping of scheduled tasks. Does not mutate tasks or write data.
class CalendarWeekBlock {
  CalendarWeekBlock({required this.groupCategoryId, required this.start, required this.end, required this.tasks});
  final int groupCategoryId;
  final DateTime start;
  DateTime end;
  final List<PlanningTask> tasks;
}

class CalendarWeekPlacement {
  const CalendarWeekPlacement(this.block, this.lane, this.laneCount);
  final CalendarWeekBlock block;
  final int lane;
  final int laneCount;
}

/// Join consecutive or overlapping tasks in the same *specific category branch*.
/// Never span a gap greater than 10 minutes, and never merge different branches.
List<CalendarWeekBlock> buildCalendarWeekBlocks(
  List<PlanningTask> tasks,
  int Function(int) categoryBranch,
) {
  final ordered = tasks.where((task) => task.startTime != null).toList()
    ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
  final blocks = <CalendarWeekBlock>[];
  for (final task in ordered) {
    final start = task.startTime!;
    final rawEnd = task.endDateTime ?? start.add(const Duration(minutes: 45));
    final end = rawEnd.isAfter(start) ? rawEnd : start.add(const Duration(minutes: 10));
    final branch = categoryBranch(task.categoryId);
    final last = blocks.isEmpty ? null : blocks.last;
    if (last != null && last.groupCategoryId == branch &&
        !start.isAfter(last.end.add(const Duration(minutes: 10)))) {
      last.tasks.add(task);
      if (end.isAfter(last.end)) last.end = end;
    } else {
      blocks.add(CalendarWeekBlock(
        groupCategoryId: branch, start: start, end: end, tasks: [task],
      ));
    }
  }
  return blocks;
}

/// Assign independent lanes to genuinely overlapping visual blocks.
/// Non-overlapping groups regain full column width.
List<CalendarWeekPlacement> layoutCalendarWeekBlocks(List<CalendarWeekBlock> blocks) {
  final sorted = blocks.toList()..sort((a, b) => a.start.compareTo(b.start));
  final placed = <CalendarWeekPlacement>[];
  var i = 0;
  while (i < sorted.length) {
    final cluster = <CalendarWeekBlock>[sorted[i++]];
    var end = cluster.first.end;
    while (i < sorted.length && sorted[i].start.isBefore(end)) {
      final next = sorted[i++];
      cluster.add(next);
      if (next.end.isAfter(end)) end = next.end;
    }
    final laneEnds = <DateTime>[];
    final assigned = <int>[];
    for (final block in cluster) {
      var lane = laneEnds.indexWhere((e) => !e.isAfter(block.start));
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(block.end);
      } else {
        laneEnds[lane] = block.end;
      }
      assigned.add(lane);
    }
    final width = laneEnds.length;
    for (var n = 0; n < cluster.length; n++) {
      placed.add(CalendarWeekPlacement(cluster[n], assigned[n], width));
    }
  }
  return placed;
}
