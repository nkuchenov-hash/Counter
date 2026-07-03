import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

DateTime timelineLocalToday() =>
    DatabaseService.instance.getTimelineDeviceLocalToday();

bool timelineIsToday(DateTime date) {
  final today = DatabaseService.instance.getTimelineDeviceLocalToday();
  return date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;
}

DateTime timelineDateOnlyCalendar(DateTime d) => DateTime(d.year, d.month, d.day);

String timelineWallCalendarDayKeyFromUtcInstant(DateTime startUtcOrAny) {
  final wall = DatabaseService.instance.applyUserOffset(startUtcOrAny.toUtc());
  return '${wall.year}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';
}

String timelineFormatTimeOfDay(DateTime dt) =>
    DateFormat.Hm(currentLocale.value).format(dt);

DateTime timelineUtcToDisplay(DateTime utc) =>
    DatabaseService.instance.applyUserOffset(utc);

String timelineFormatDuration(Duration d) {
  final totalSeconds = d.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  if (m > 0) {
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${s}s';
}

List<Widget> timelineRowMetaIconsFromVm(
  BuildContext context,
  TimelineRecordRowVm vm,
) {
  final base = Theme.of(context).iconTheme.color;
  final color = base?.withValues(alpha: 0.48);
  if (color == null) return const [];
  final out = <Widget>[];
  void add(IconData icon) {
    if (out.isNotEmpty) out.add(const SizedBox(width: 4));
    out.add(Icon(icon, size: 15, color: color));
  }

  if (vm.showNotesIcon) add(Icons.sticky_note_2_outlined);
  if (vm.showChecklistIcon) add(Icons.checklist_rounded);
  if (vm.showParentIcon) add(Icons.account_tree_outlined);
  if (vm.showLinkedSubsIcon) add(Icons.layers_outlined);
  return out;
}
