// ---------------------------------------------------------------------------
// Unified app bar title: weekday + calendar date + live clock (no section label).
// Tap opens the same day picker flow as Timeline (web + native).
// ---------------------------------------------------------------------------

import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/widgets/app_bar_live_clock.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> _pickDayForGlobalHeader(
  BuildContext context,
  DateTime initialDate,
  void Function(DateTime day) onSelected,
) async {
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
  });

  final DateTime selectedDate;
  final void Function(DateTime date) onDateSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.w500);
    final clockStyle = titleStyle.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    final weekday = DateFormat.EEEE(loc).format(selectedDate);
    final dateStr = DateFormat.yMMMd(loc).format(selectedDate);

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
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
            ],
          ),
        ),
      ),
    );
  }
}
