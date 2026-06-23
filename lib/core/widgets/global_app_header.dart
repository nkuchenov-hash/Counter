// ---------------------------------------------------------------------------
// Unified app bar title: weekday + calendar date + live clock (no section label).
// Tap opens the same day picker flow as Timeline (web + native).
// ---------------------------------------------------------------------------

import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/widgets/app_bar_live_clock.dart';
import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/time/app_clock.dart';
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
) async {
  // Date-only: Omni-Picker Law (ARCHITECTURE §8.1) applies when both date and
  // time are selected; see showAppDateTimePicker in shared_widgets.dart.
  final loc = currentLocale.value;
  if (useKeyboardFriendlyMaterialPickers()) {
    final picked = await showDatePicker(
      context: context,
      locale: Locale(loc),
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialEntryMode: appDatePickerEntryMode(),
    );
    if (picked != null && context.mounted) {
      onSelected(DateTime(picked.year, picked.month, picked.day));
    }
    return;
  }
  final picked = await showDialog<DateTime>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t(loc, 'calendar')),
      content: SizedBox(
        width: 320,
        child: CalendarDatePicker(
          initialDate: initialDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          onDateChanged: (d) {
            Navigator.of(ctx).pop(DateTime(d.year, d.month, d.day));
          },
        ),
      ),
    ),
  );
  if (picked != null && context.mounted) {
    onSelected(picked);
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
  });

  final DateTime selectedDate;
  final void Function(DateTime date) onDateSelected;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    rebuildMetricsTick('GlobalAppHeader');
    final loc = currentLocale.value;
    final titleStyle = compact
        ? Theme.of(context).textTheme.titleSmall?.copyWith(
                color: kGlobalCompactHeaderForeground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ) ??
              const TextStyle(
                color: kGlobalCompactHeaderForeground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.1,
              )
        : Theme.of(context).appBarTheme.titleTextStyle ??
              const TextStyle(fontSize: 20, fontWeight: FontWeight.w500);
    final clockStyle = titleStyle.copyWith(
      color: compact ? kGlobalCompactHeaderForeground : titleStyle.color,
      fontSize: compact ? 13 : 14,
      fontWeight: compact ? FontWeight.w600 : FontWeight.w400,
    );
    final weekday = DateFormat.EEEE(loc).format(selectedDate);
    final dateStr = DateFormat.yMMMd(loc).format(selectedDate);
    final tzLabel = AppClock.timezoneShortLabel?.call() ?? '';

    return Material(
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
          padding: EdgeInsets.symmetric(
            vertical: compact ? 2 : 4,
            horizontal: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '$weekday · $dateStr',
                  style: titleStyle,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              Text(' · ', style: titleStyle),
              AppBarLiveClock(textStyle: clockStyle),
              Text(' · ', style: clockStyle),
              Text(tzLabel, style: clockStyle),
            ],
          ),
        ),
      ),
    );
  }
}
