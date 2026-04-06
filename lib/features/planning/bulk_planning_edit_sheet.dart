// Bulk edit: date + optional exact anchor time for selected planning tasks. UI only; Brain calls from planning_view.
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Earliest task in [tasks] by wall [PlanningTask.startTime]; tasks without start are skipped.
PlanningTask? bulkEditAnchorTask(Iterable<PlanningTask> tasks) {
  PlanningTask? best;
  DateTime? bestStart;
  for (final t in tasks) {
    final st = t.startTime;
    if (st == null) continue;
    if (bestStart == null || st.isBefore(bestStart)) {
      bestStart = st;
      best = t;
    }
  }
  return best;
}

/// Result of [showBulkPlanningEditSheet]: target calendar day + optional time re-anchor.
class BulkPlanningEditResult {
  const BulkPlanningEditResult({
    required this.targetDate,
    this.applyTimeReanchor = false,
    this.timeShift = Duration.zero,
    this.anchorNewStart,
  });

  /// Date-only (wall); time-of-day ignored for the calendar target.
  final DateTime targetDate;

  /// When true, [timeShift] and [anchorNewStart] define how start/end move (see [computeBulkEditWallTimes]).
  final bool applyTimeReanchor;

  /// Delta from the anchor task's previous start time-of-day to [anchorNewStart]. Applied to every
  /// task that already has a start time (+ same delta on end).
  final Duration timeShift;

  /// New start time-of-day for the anchor row; also used as the absolute start for tasks with no start time.
  final TimeOfDay? anchorNewStart;
}

class BulkEditWallTimes {
  const BulkEditWallTimes({required this.start, this.end});

  final DateTime start;
  final DateTime? end;
}

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
  final start = DateTime(targetDay.year, targetDay.month, targetDay.day, h, minute);
  DateTime? end;
  final en = task.endDateTime;
  if (en != null) {
    end = DateTime(targetDay.year, targetDay.month, targetDay.day, en.hour, en.minute);
  }
  return BulkEditWallTimes(start: start, end: end);
}

/// Wall-clock start/end after applying [edit] to [task] (date move ± optional anchor time block shift).
BulkEditWallTimes computeBulkEditWallTimes(
  PlanningTask task,
  BulkPlanningEditResult edit,
) {
  if (!edit.applyTimeReanchor || edit.anchorNewStart == null) {
    return _bulkEditMapDateOnly(task, edit.targetDate);
  }

  final picked = edit.anchorNewStart!;
  final st = task.startTime;
  final base = edit.targetDate;
  late final DateTime start;
  if (st != null) {
    start = DateTime(base.year, base.month, base.day, st.hour, st.minute).add(edit.timeShift);
  } else {
    start = DateTime(base.year, base.month, base.day, picked.hour, picked.minute);
  }

  DateTime? end;
  final en = task.endDateTime;
  if (en != null) {
    end = DateTime(base.year, base.month, base.day, en.hour, en.minute).add(edit.timeShift);
  }
  return BulkEditWallTimes(start: start, end: end);
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
  TimeOfDay? _pickedAnchorTime;

  int get _selectedCount => widget.selectedTasks.length;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDay;
    _date = DateTime(d.year, d.month, d.day);
  }

  TimeOfDay _defaultPickerSeed() {
    final anchor = bulkEditAnchorTask(widget.selectedTasks);
    final st = anchor?.startTime;
    if (st != null) {
      return TimeOfDay(hour: st.hour, minute: st.minute);
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2035),
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime() async {
    final initial = _pickedAnchorTime ?? _defaultPickerSeed();
    final mq = MediaQuery.of(context);
    TimeOfDay? out;

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      var wheel = DateTime(2020, 1, 1, initial.hour, initial.minute);
      final loc = currentLocale.value;
      out = await showCupertinoModalPopup<TimeOfDay>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Material(
              color: CupertinoColors.systemBackground.resolveFrom(ctx),
              child: SizedBox(
                height: 276,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(t(loc, 'cancel')),
                        ),
                        CupertinoButton(
                          onPressed: () {
                            Navigator.pop(
                              ctx,
                              TimeOfDay(hour: wheel.hour, minute: wheel.minute),
                            );
                          },
                          child: Text(t(loc, 'done')),
                        ),
                      ],
                    ),
                    Expanded(
                      child: CupertinoTheme(
                        data: CupertinoThemeData(
                          brightness: Theme.of(ctx).brightness,
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          initialDateTime: wheel,
                          use24hFormat: mq.alwaysUse24HourFormat,
                          minuteInterval: 1,
                          onDateTimeChanged: (d) => wheel = d,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      out = await showTimePicker(
        context: context,
        initialTime: initial,
        initialEntryMode: TimePickerEntryMode.dial,
        builder: (context, child) {
          return MediaQuery(
            data: mq.copyWith(alwaysUse24HourFormat: mq.alwaysUse24HourFormat),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
    }

    if (out != null && mounted) {
      setState(() => _pickedAnchorTime = out);
    }
  }

  void _resetTime() {
    setState(() => _pickedAnchorTime = null);
  }

  void _confirm() {
    final anchor = bulkEditAnchorTask(widget.selectedTasks);
    final applyTime = _pickedAnchorTime != null;
    Duration delta = Duration.zero;
    TimeOfDay? anchorNewStart;

    if (applyTime) {
      final picked = _pickedAnchorTime!;
      anchorNewStart = picked;
      final st = anchor?.startTime;
      if (st != null) {
        final oldMin = st.hour * 60 + st.minute;
        final newMin = picked.hour * 60 + picked.minute;
        delta = Duration(minutes: newMin - oldMin);
      } else {
        delta = Duration.zero;
      }
    }

    Navigator.pop(
      context,
      BulkPlanningEditResult(
        targetDate: _date,
        applyTimeReanchor: applyTime,
        timeShift: delta,
        anchorNewStart: anchorNewStart,
      ),
    );
  }

  String _timeRowSubtitle() {
    final loc = currentLocale.value;
    final pick = _pickedAnchorTime;
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
            label: t(loc, 'plan_bulk_edit_new_start_label'),
            value: _timeRowSubtitle(),
          ),
          if (_pickedAnchorTime != null) ...[
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
