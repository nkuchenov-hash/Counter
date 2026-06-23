import 'package:counter/data/models.dart';

String formatPlanningWallTime(DateTime wall) {
  return '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';
}

String timelineTimeRangeLabel(PlanningTask task) {
  final start = task.startTime;
  if (start == null) return '';
  final startLabel = formatPlanningWallTime(start);
  final end = task.endDateTime;
  if (end != null) {
    return '$startLabel – ${formatPlanningWallTime(end)}';
  }
  return startLabel;
}
