// ---------------------------------------------------------------------------
// TIMELINE — small shared chrome widgets (Strike 24: no [AppBar] height tax).
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/l10n/dictionary.dart';

/// Date strip with optional web day chevrons (content formerly in [AppBar.title]).
class TimelineTopDateStrip extends StatelessWidget {
  const TimelineTopDateStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.onNavigateToDate,
  });

  final DateTime selectedDate;
  final void Function(DateTime date) onDateSelected;
  final void Function(DateTime date)? onNavigateToDate;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final enabled = onNavigateToDate != null;
    return Material(
      color: kGlobalCompactHeaderColor,
      elevation: 0,
      child: IconTheme(
        data: const IconThemeData(color: kGlobalCompactHeaderForeground),
        child: SizedBox(
          height: kGlobalCompactHeaderHeight,
          child: Row(
            children: [
              if (kIsWeb)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: t(loc, 'date_previous_day'),
                  onPressed: enabled
                      ? () {
                          final d = selectedDate.subtract(
                            const Duration(days: 1),
                          );
                          onNavigateToDate!(DateTime(d.year, d.month, d.day));
                        }
                      : null,
                ),
              Expanded(
                child: GlobalAppHeader(
                  selectedDate: selectedDate,
                  enabled: enabled,
                  onDateSelected: onDateSelected,
                  compact: true,
                ),
              ),
              if (kIsWeb)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: t(loc, 'date_next_day'),
                  onPressed: enabled
                      ? () {
                          final d = selectedDate.add(const Duration(days: 1));
                          onNavigateToDate!(DateTime(d.year, d.month, d.day));
                        }
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
