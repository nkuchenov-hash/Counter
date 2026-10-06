import 'package:counter/core/picker_entry_modes.dart';import 'package:counter/core/widgets/omni_date_time_picker_dialog.dart';import 'package:counter/data/database_service.dart';import 'package:flutter/material.dart';import 'package:omni_datetime_picker/omni_datetime_picker.dart';/// Shared start/end time control for Timeline and Planning edit sheets.
class AppEditSheetTimeButton extends StatelessWidget {
  const AppEditSheetTimeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

Future<DateTime?> showAppDateTimePicker(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final defaultInitial = DatabaseService.instance.applyUserOffset(
    DatabaseService.getPlanetaryNow(),
  );
  final base = initial ?? defaultInitial;

  if (useKeyboardFriendlyMaterialPickersFromContext(context)) {
    final fd = firstDate ?? DateTime.utc(2020);
    final ld = lastDate ?? DateTime.utc(2030);
    final clampedDay = clampPickerDay(base, fd, ld);
    final initialCombined = DateTime(
      clampedDay.year,
      clampedDay.month,
      clampedDay.day,
      base.hour,
      base.minute,
    );
    return showOmniDateTimePickerDialog(
      context,
      initial: initialCombined,
      firstDate: DateTime(fd.year, fd.month, fd.day),
      lastDate: DateTime(ld.year, ld.month, ld.day),
    );
  }

  final theme = Theme.of(context);
  return showOmniDateTimePicker(
    context: context,
    initialDate: base,
    firstDate: firstDate ?? DateTime.utc(2020),
    lastDate: lastDate ?? DateTime.utc(2030),
    is24HourMode: true,
    theme: theme,
  );
}

DateTime clampPickerDay(DateTime value, DateTime first, DateTime last) {
  final d = DateTime(value.year, value.month, value.day);
  final f = DateTime(first.year, first.month, first.day);
  final l = DateTime(last.year, last.month, last.day);
  if (d.isBefore(f)) return f;
  if (d.isAfter(l)) return l;
  return d;
}

DateTime? planningDateFromKey(String key) {
  if (key.length < 10) return null;
  final y = int.tryParse(key.substring(0, 4));
  final m = int.tryParse(key.substring(5, 7));
  final d = int.tryParse(key.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d);
}

const List<String> kShortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
