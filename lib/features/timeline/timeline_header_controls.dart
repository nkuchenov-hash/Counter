import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/features/timeline/timeline_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Timeline list/stats segmented control + record input row.
class TimelineHeaderControls extends StatelessWidget {
  const TimelineHeaderControls({
    super.key,
    required this.showStatsView,
    required this.visibleDate,
    required this.visibleIsFuture,
    required this.titleController,
    required this.titleFocus,
    required this.onShowStatsViewChanged,
    required this.onStart,
    required this.onPlan,
    required this.onNewTaskForPastDate,
  });

  final bool showStatsView;
  final DateTime visibleDate;
  final bool visibleIsFuture;
  final TextEditingController titleController;
  final FocusNode titleFocus;
  final ValueChanged<bool> onShowStatsViewChanged;
  final VoidCallback onStart;
  final VoidCallback onPlan;
  final VoidCallback onNewTaskForPastDate;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            height: kAppCompactControlHeight,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: appCompactSegmentedButtonStyle(
                context,
                segmentWidth: 112,
              ),
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.list_rounded),
                  label: AppCompactSegmentLabel(text: t(loc, 'list')),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: AppCompactSegmentLabel(text: t(loc, 'stats')),
                ),
              ],
              selected: {showStatsView},
              onSelectionChanged: (Set<bool> sel) {
                if (sel.isEmpty) return;
                onShowStatsViewChanged(sel.first);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: titleController,
                  focusNode: titleFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (visibleIsFuture) {
                      onPlan();
                    } else if (timelineIsToday(visibleDate)) {
                      onStart();
                    } else {
                      onNewTaskForPastDate();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: t(loc, 'input_placeholder_record'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  final projectedToday = timelineLocalToday();
                  final isToday =
                      visibleDate.year == projectedToday.year &&
                      visibleDate.month == projectedToday.month &&
                      visibleDate.day == projectedToday.day;
                  final isFuture = visibleIsFuture;
                  return FilledButton.icon(
                    onPressed: () {
                      if (isFuture) {
                        onPlan();
                      } else if (isToday) {
                        onStart();
                      } else {
                        onNewTaskForPastDate();
                      }
                    },
                    icon: Icon(
                      isFuture
                          ? Icons.event_rounded
                          : isToday
                          ? Icons.play_arrow_rounded
                          : Icons.add_task_rounded,
                    ),
                    label: Text(
                      isFuture
                          ? t(loc, 'plan')
                          : isToday
                          ? t(loc, 'start_timer')
                          : t(loc, 'new_record_btn'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
      ],
    );
  }
}
