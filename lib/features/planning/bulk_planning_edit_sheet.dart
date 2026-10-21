// Bulk edit: absolute target date + optional same start time for all selected plans. UI only; Brain calls from planning_view.
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Result of [showBulkPlanningEditSheet].
class BulkPlanningEditResult {
  const BulkPlanningEditResult({
    required this.targetDate,
    this.applyTargetTime = false,
    this.targetTime,
  });

  /// Calendar day (wall); assigned to each task’s schedule/date fields.
  final DateTime targetDate;

  /// When true, [targetTime] is applied as **start_time** for every selected task (see [computeBulkEditWallTimes]).
  final bool applyTargetTime;

  /// Same clock time for all tasks when [applyTargetTime] is true.
  final TimeOfDay? targetTime;
}

class BulkEditWallTimes {
  const BulkEditWallTimes({required this.start, this.end});

  final DateTime start;
  final DateTime? end;
}

/// Date move only: copy each task’s wall clock to [targetDay].
BulkEditWallTimes _bulkEditMapDateOnly(
  PlanningTask task,
  DateTime targetDay,
) {
  var h = 9;
  var minute = 0;
  final st = task.startTime;
  if (st != null) {
    h = st.hour;
    minute = st.minute;
  }
  final start =
      DateTime(targetDay.year, targetDay.month, targetDay.day, h, minute);
  DateTime? end;
  final en = task.endDateTime;
  if (en != null) {
    end = st != null && en.isAfter(st)
        ? start.add(en.difference(st))
        : DateTime(targetDay.year, targetDay.month, targetDay.day, en.hour, en.minute);
  }
  return BulkEditWallTimes(start: start, end: end);
}

/// Applies [edit] to [task]: direct [targetDate]; if [applyTargetTime], same [targetTime] as start, preserves interval length when possible.
BulkEditWallTimes computeBulkEditWallTimes(
  PlanningTask task,
  BulkPlanningEditResult edit,
) {
  final base = edit.targetDate;
  if (!edit.applyTargetTime || edit.targetTime == null) {
    return _bulkEditMapDateOnly(task, base);
  }

  final tod = edit.targetTime!;
  final newStart =
      DateTime(base.year, base.month, base.day, tod.hour, tod.minute);

  final oldStart = task.startTime;
  final oldEnd = task.endDateTime;
  if (oldStart != null &&
      oldEnd != null &&
      oldEnd.isAfter(oldStart)) {
    final dur = oldEnd.difference(oldStart);
    return BulkEditWallTimes(start: newStart, end: newStart.add(dur));
  }

  return BulkEditWallTimes(start: newStart, end: null);
}

/// When the user picks a time for multiple plans, the picked time is the
/// *block's* start, not the start of every member. Preserve visible/source
/// order and each plan's effective duration; never insert artificial gaps.
/// Without an explicit picked time, date-only moves preserve clock positions.
List<BulkEditWallTimes> computeSequentialBulkEditWallTimes(
  List<PlanningTask> orderedTasks,
  BulkPlanningEditResult edit, {
  required int Function(PlanningTask) durationMinutesForTask,
}) {
  if (!edit.applyTargetTime || edit.targetTime == null) {
    return [
      for (final task in orderedTasks) computeBulkEditWallTimes(task, edit),
    ];
  }
  final tod = edit.targetTime!;
  var cursor = DateTime(
    edit.targetDate.year,
    edit.targetDate.month,
    edit.targetDate.day,
    tod.hour,
    tod.minute,
  );
  final placements = <BulkEditWallTimes>[];
  for (final task in orderedTasks) {
    final start = task.startTime;
    final end = task.endDateTime;
    final duration = start != null && end != null && end.isAfter(start)
        ? end.difference(start)
        : Duration(minutes: durationMinutesForTask(task).clamp(1, 1440));
    final next = cursor.add(duration);
    placements.add(BulkEditWallTimes(start: cursor, end: next));
    cursor = next;
  }
  return placements;
}

/// Protect an explicitly inserted 09:00 batch from overlap with already
/// scheduled destination-day plans. Cascade only incumbents it would collide
/// with and any subsequent tasks affected by the displacement; preserve their
/// original durations, dates and gaps whenever no collision exists.
List<({PlanningTask task, BulkEditWallTimes times})>
computeBulkDestinationConflictShifts({
  required DateTime blockStart,
  required DateTime blockEnd,
  required List<PlanningTask> existingDestinationPlans,
  required int Function(PlanningTask) durationMinutesForTask,
}) {
  final existing = existingDestinationPlans
      .where((t) => t.startTime != null)
      .toList()
    ..sort((a, b) {
      final time = a.startTime!.compareTo(b.startTime!);
      if (time != 0) return time;
      final order = a.order.compareTo(b.order);
      if (order != 0) return order;
      return a.planRowIdForBackend.compareTo(b.planRowIdForBackend);
    });
  final result = <({PlanningTask task, BulkEditWallTimes times})>[];
  var occupiedUntil = blockEnd;
  for (final task in existing) {
    final oldStart = task.startTime!;
    final oldEnd = task.endDateTime;
    final duration = oldEnd != null && oldEnd.isAfter(oldStart)
        ? oldEnd.difference(oldStart)
        : Duration(minutes: durationMinutesForTask(task).clamp(1, 1440));
    final effectiveEnd = oldStart.add(duration);
    if (!effectiveEnd.isAfter(blockStart)) continue;
    if (oldStart.isBefore(occupiedUntil)) {
      final newEnd = occupiedUntil.add(duration);
      result.add((
        task: task,
        times: BulkEditWallTimes(start: occupiedUntil, end: newEnd),
      ));
      occupiedUntil = newEnd;
    } else {
      occupiedUntil = effectiveEnd;
    }
  }
  return result;
}

/// Compare actual wall-clock schedules, not just the destination day or UTC
/// DateTime representation. Used to avoid both false "no changes" and no-op PATCHes.
bool bulkPlacementMatchesTask(PlanningTask task, BulkEditWallTimes placement) {
  bool sameWall(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute &&
        a.second == b.second &&
        a.millisecond == b.millisecond;
  }

  final start = placement.start;
  final targetKey = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  return task.dateKey == targetKey &&
      sameWall(task.startTime, placement.start) &&
      sameWall(task.endDateTime, placement.end);
}

Future<BulkPlanningEditResult?> showBulkPlanningEditSheet(
  BuildContext context, {
  required DateTime initialDay,
  required List<PlanningTask> selectedTasks,
}) {
  return showModalBottomSheet<BulkPlanningEditResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => _BulkPlanningEditSheetBody(
      initialDay: initialDay,
      selectedTasks: selectedTasks,
    ),
  );
}

class _BulkPlanningEditSheetBody extends StatefulWidget {
  const _BulkPlanningEditSheetBody({
    required this.initialDay,
    required this.selectedTasks,
  });

  final DateTime initialDay;
  final List<PlanningTask> selectedTasks;

  @override
  State<_BulkPlanningEditSheetBody> createState() =>
      _BulkPlanningEditSheetBodyState();
}

class _BulkPlanningEditSheetBodyState extends State<_BulkPlanningEditSheetBody> {
  late DateTime _date;
  TimeOfDay? _pickedTargetTime;
  bool _dateOnly = false;
  bool _hasExplicitChoice = false;

  int get _selectedCount => widget.selectedTasks.length;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDay;
    _date = DateTime(d.year, d.month, d.day);
  }

  TimeOfDay _defaultPickerSeed() {
    for (final t in widget.selectedTasks) {
      final st = t.startTime;
      if (st != null) {
        return TimeOfDay(hour: st.hour, minute: st.minute);
      }
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  /// Date AND time are one user action. Never drop one half of Omni-Picker.
  Future<void> _pickDateTime() async {
    final time = _pickedTargetTime ?? _defaultPickerSeed();
    final picked = await showAppDateTimePicker(
      context,
      initial: DateTime(_date.year, _date.month, _date.day, time.hour, time.minute),
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _pickedTargetTime = TimeOfDay(hour: picked.hour, minute: picked.minute);
      _hasExplicitChoice = true;
    });
  }

  /// Date-only mode is explicit. A date-only picker is allowed by the
  /// Omni-Picker contract; per-task clock positions remain unchanged.
  Future<void> _pickDateOnly() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _hasExplicitChoice = true;
    });
  }

  void _confirm() {
    if (!_hasExplicitChoice || (!_dateOnly && _pickedTargetTime == null)) {
      return;
    }
    Navigator.pop(
      context,
      BulkPlanningEditResult(
        targetDate: _date,
        applyTargetTime: !_dateOnly,
        targetTime: _dateOnly ? null : _pickedTargetTime,
      ),
    );
  }

  String _dateLabel(String loc) {
    try {
      return DateFormat.yMMMMd(loc).format(_date);
    } catch (_) {
      return '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    }
  }

  String _selectionSummary(String loc) {
    if (!_hasExplicitChoice) {
      return t(loc, _dateOnly
          ? 'plan_bulk_edit_pick_date'
          : 'plan_bulk_edit_pick_start');
    }
    final dateText = _dateLabel(loc);
    if (_dateOnly) return dateText;
    final time = _pickedTargetTime!;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$dateText · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final loc = currentLocale.value;
    final title = t(loc, 'plan_bulk_edit_sheet_title')
        .replaceFirst('%s', '$_selectedCount');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20, 8, 20, 12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 16),
            Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _dateOnly ? _pickDateOnly : _pickDateTime,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _dateOnly ? Icons.event_rounded : Icons.schedule_rounded,
                        color: scheme.primary, size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(loc, _dateOnly
                                  ? 'plan_bulk_edit_date_only_start'
                                  : 'plan_bulk_edit_block_start'),
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectionSummary(loc),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant, size: 22),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                t(loc, 'plan_bulk_edit_date_only_mode'),
                style: theme.textTheme.bodyLarge,
              ),
              value: _dateOnly,
              onChanged: (enabled) => setState(() {
                _dateOnly = enabled;
                // Switching intention requires a fresh, unambiguous choice.
                _hasExplicitChoice = false;
              }),
            ),
            const SizedBox(height: 4),
            Text(
              t(loc, _dateOnly
                  ? 'plan_bulk_edit_date_only_hint'
                  : 'plan_bulk_edit_sequential_hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(loc, 'plan_bulk_edit_timezone_hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            AppButton.primary(
              label: t(loc, 'plan_bulk_edit_apply'),
              fullWidth: true,
              onPressed: _hasExplicitChoice ? _confirm : null,
            ),
          ],
        ),
      ),
    );
  }
}
