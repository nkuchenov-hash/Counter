// ---------------------------------------------------------------------------
// Unified app bar title: weekday + calendar date + live clock (no section label).
// Tap opens the same day picker flow as Timeline (web + native).
// ---------------------------------------------------------------------------

import 'package:counter/core/widgets/app_bar_live_clock.dart';
import 'package:counter/core/widgets/timezone_quick_picker.dart';
import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const double kGlobalCompactHeaderHeight = 48;
const Color kGlobalCompactHeaderColor = Color(0xFF111111);
const Color kGlobalCompactHeaderForeground = Colors.white;

Future<void> _pickDayForGlobalHeader(
  BuildContext context,
  DateTime initialDate,
  void Function(DateTime day) onSelected,
) {
  // Date-only navigation: one calendar with an inline text field on every
  // platform. This is separate from the unified date+time Omni-Picker.
  final locale = currentLocale.value;
  return showDialog<void>(
    context: context,
    builder: (_) => _HeaderDayPicker(
      initialDate: initialDate,
      locale: locale,
      onSelected: (day) {
        if (context.mounted) onSelected(day);
      },
    ),
  );
}

class _HeaderDayPicker extends StatefulWidget {
  const _HeaderDayPicker({
    required this.initialDate,
    required this.locale,
    required this.onSelected,
  });

  final DateTime initialDate;
  final String locale;
  final ValueChanged<DateTime> onSelected;

  @override
  State<_HeaderDayPicker> createState() => _HeaderDayPickerState();
}

class _HeaderDayPickerState extends State<_HeaderDayPicker> {
  static final DateTime _firstDate = DateTime(2020);
  static final DateTime _lastDate = DateTime(2035, 12, 31);
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  late final TextEditingController _dateController;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: _dateFormat.format(widget.initialDate),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  void _selectDate(DateTime date) {
    Navigator.of(context).pop();
    // Run synchronously on the selection gesture, not after the dialog's
    // dismissal animation or a second confirmation action.
    widget.onSelected(DateTime(date.year, date.month, date.day));
  }

  void _submitManualDate() {
    DateTime date;
    try {
      date = _dateFormat.parseStrict(_dateController.text.trim());
    } on FormatException {
      setState(() => _dateError = t(widget.locale, 'header_date_picker_invalid'));
      return;
    }
    if (date.isBefore(_firstDate) || date.isAfter(_lastDate)) {
      setState(() => _dateError = t(widget.locale, 'header_date_picker_invalid'));
      return;
    }
    _selectDate(date);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(t(widget.locale, 'header_date_picker_title')),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      content: SizedBox(
        width: 328,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dateController,
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                labelText: t(widget.locale, 'header_date_picker_enter'),
                hintText: 'DD.MM.YYYY',
                errorText: _dateError,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: t(widget.locale, 'header_date_picker_go'),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _submitManualDate,
                ),
              ),
              onChanged: (_) {
                if (_dateError != null) setState(() => _dateError = null);
              },
              onSubmitted: (_) => _submitManualDate(),
            ),
            const SizedBox(height: 12),
            CalendarDatePicker(
              initialDate: widget.initialDate,
              firstDate: _firstDate,
              lastDate: _lastDate,
              onDateChanged: _selectDate,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared header row: `{Weekday} · {date} · {HH:mm}`.
class GlobalAppHeader extends StatelessWidget {
  const GlobalAppHeader({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.enabled = true,
    this.compact = false,
    this.foregroundColor,
  });

  final DateTime selectedDate;
  final void Function(DateTime date) onDateSelected;
  final bool enabled;
  final bool compact;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    rebuildMetricsTick('GlobalAppHeader');
    final loc = currentLocale.value;
    final compactForeground = foregroundColor ?? kGlobalCompactHeaderForeground;
    final titleStyle = compact
        ? Theme.of(context).textTheme.titleSmall?.copyWith(
                color: compactForeground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ) ??
              TextStyle(
                color: compactForeground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.1,
              )
        : Theme.of(context).appBarTheme.titleTextStyle ??
              const TextStyle(fontSize: 20, fontWeight: FontWeight.w500);
    final clockStyle = titleStyle.copyWith(
      color: compact ? compactForeground : titleStyle.color,
      fontSize: compact ? 13 : 14,
      fontWeight: compact ? FontWeight.w600 : FontWeight.w400,
    );
    final weekday = DateFormat.EEEE(loc).format(selectedDate);
    final dateStr = DateFormat.yMMMd(loc).format(selectedDate);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4, horizontal: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled
                      ? () async {
                          await _pickDayForGlobalHeader(
                            context,
                            selectedDate,
                            onDateSelected,
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      '$weekday · $dateStr',
                      style: titleStyle,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            Text(' · ', style: titleStyle),
            AppBarLiveClock(textStyle: clockStyle),
            Text(' · ', style: clockStyle),
            HeaderTimezoneQuickSwitcher(
              textStyle: clockStyle,
              enabled: enabled,
            ),
          ],
        ),
      ),
    );
  }
}
