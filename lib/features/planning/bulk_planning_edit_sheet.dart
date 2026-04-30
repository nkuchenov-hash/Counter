// Bulk edit: absolute target date + optional same start time for all selected plans. UI only; Brain calls from planning_view.
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
    end = DateTime(targetDay.year, targetDay.month, targetDay.day, en.hour, en.minute);
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

  Future<void> _pickDate() async {
    final seed = DateTime(
      _date.year, _date.month, _date.day,
      _pickedTargetTime?.hour ?? 9,
      _pickedTargetTime?.minute ?? 0,
    );
    final picked = await showAppDateTimePicker(
      context,
      initial: seed,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2035),
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime() async {
    final initial = _pickedTargetTime ?? _defaultPickerSeed();
    final seed = DateTime(
      _date.year, _date.month, _date.day,
      initial.hour, initial.minute,
    );
    final picked = await showAppDateTimePicker(
      context,
      initial: seed,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2035),
    );
    if (picked != null && mounted) {
      setState(() => _pickedTargetTime = TimeOfDay(hour: picked.hour, minute: picked.minute));
    }
  }

  void _resetTime() {
    setState(() => _pickedTargetTime = null);
  }

  void _confirm() {
    Navigator.pop(
      context,
      BulkPlanningEditResult(
        targetDate: _date,
        applyTargetTime: _pickedTargetTime != null,
        targetTime: _pickedTargetTime,
      ),
    );
  }

  String _timeRowSubtitle() {
    final loc = currentLocale.value;
    final pick = _pickedTargetTime;
    if (pick == null) {
      return t(loc, 'plan_bulk_edit_time_not_set');
    }
    return pick.format(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final loc = currentLocale.value;
    final title = t(loc, 'plan_bulk_edit_sheet_title').replaceFirst('%s', '$_selectedCount');
    String dateLabel;
    try {
      dateLabel = DateFormat.yMMMMd(loc).format(_date);
    } catch (_) {
      dateLabel =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    Widget sheetCard({
      required VoidCallback onTap,
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 22),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 12 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          sheetCard(
            onTap: _pickDate,
            icon: Icons.event_rounded,
            label: t(loc, 'plan_bulk_edit_date_label'),
            value: dateLabel,
          ),
          const SizedBox(height: 8),
          sheetCard(
            onTap: _pickTime,
            icon: Icons.schedule_rounded,
            label: t(loc, 'plan_bulk_edit_set_time_label'),
            value: _timeRowSubtitle(),
          ),
          if (_pickedTargetTime != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetTime,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(t(loc, 'plan_bulk_edit_time_reset')),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            t(loc, 'plan_bulk_edit_time_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _confirm,
            child: Text(t(loc, 'plan_bulk_edit_apply')),
          ),
        ],
      ),
    );
  }
}
