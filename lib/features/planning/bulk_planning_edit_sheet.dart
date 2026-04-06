// Bulk edit: date + time shift for selected planning tasks. UI only; Brain calls from planning_view.
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Result of [showBulkPlanningEditSheet]: target calendar day + additive shift on start/end.
class BulkPlanningEditResult {
  const BulkPlanningEditResult({
    required this.targetDate,
    this.timeShift = Duration.zero,
  });

  /// Date-only (wall); time-of-day ignored.
  final DateTime targetDate;
  final Duration timeShift;
}

class BulkEditWallTimes {
  const BulkEditWallTimes({required this.start, this.end});

  final DateTime start;
  final DateTime? end;
}

/// Wall-clock start/end after moving [task] to [targetDay] (Y/M/D) and adding [shift] to both bounds.
BulkEditWallTimes computeBulkEditWallTimes(
  PlanningTask task,
  DateTime targetDay,
  Duration shift,
) {
  var h = 9;
  var minute = 0;
  final st = task.startTime;
  if (st != null) {
    h = st.hour;
    minute = st.minute;
  }
  var start = DateTime(
    targetDay.year,
    targetDay.month,
    targetDay.day,
    h,
    minute,
  );
  start = start.add(shift);
  DateTime? end;
  final en = task.endDateTime;
  if (en != null) {
    end = DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      en.hour,
      en.minute,
    );
    end = end.add(shift);
  }
  return BulkEditWallTimes(start: start, end: end);
}

Future<BulkPlanningEditResult?> showBulkPlanningEditSheet(
  BuildContext context, {
  required DateTime initialDay,
  required int selectedCount,
}) {
  return showModalBottomSheet<BulkPlanningEditResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => _BulkPlanningEditSheetBody(
      initialDay: initialDay,
      selectedCount: selectedCount,
    ),
  );
}

class _BulkPlanningEditSheetBody extends StatefulWidget {
  const _BulkPlanningEditSheetBody({
    required this.initialDay,
    required this.selectedCount,
  });

  final DateTime initialDay;
  final int selectedCount;

  @override
  State<_BulkPlanningEditSheetBody> createState() =>
      _BulkPlanningEditSheetBodyState();
}

class _BulkPlanningEditSheetBodyState extends State<_BulkPlanningEditSheetBody> {
  late DateTime _date;
  Duration _shift = Duration.zero;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDay;
    _date = DateTime(d.year, d.month, d.day);
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

  void _setShift(Duration d) {
    setState(() => _shift = d);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final title = t(loc, 'plan_bulk_edit_sheet_title')
        .replaceFirst('%s', '${widget.selectedCount}');
    String dateLabel;
    try {
      dateLabel = DateFormat.yMMMMd(loc).format(_date);
    } catch (_) {
      dateLabel =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    Widget shiftChip(String label, Duration d) {
      final selected = _shift == d;
      return FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _setShift(d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 16 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, color: scheme.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(loc, 'plan_bulk_edit_date_label'),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t(loc, 'plan_bulk_edit_shift_section'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            t(loc, 'plan_bulk_edit_shift_hint'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              shiftChip(t(loc, 'plan_bulk_edit_shift_none'), Duration.zero),
              shiftChip(t(loc, 'plan_time_shift_minus_1h'), const Duration(minutes: -60)),
              shiftChip(t(loc, 'plan_time_shift_minus_30m'), const Duration(minutes: -30)),
              shiftChip(t(loc, 'plan_time_shift_minus_15m'), const Duration(minutes: -15)),
              shiftChip(t(loc, 'plan_time_shift_plus_15m'), const Duration(minutes: 15)),
              shiftChip(t(loc, 'plan_time_shift_plus_30m'), const Duration(minutes: 30)),
              shiftChip(t(loc, 'plan_time_shift_plus_1h'), const Duration(minutes: 60)),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(
                context,
                BulkPlanningEditResult(
                  targetDate: _date,
                  timeShift: _shift,
                ),
              );
            },
            child: Text(t(loc, 'plan_bulk_edit_apply')),
          ),
        ],
      ),
    );
  }
}
