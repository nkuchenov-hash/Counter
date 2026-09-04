import 'package:counter/core/shell_adaptive.dart';
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
    final desktopShell = shellUsesSideNavigation(
      MediaQuery.sizeOf(context).width,
    );
    final projectedToday = timelineLocalToday();
    final isToday =
        visibleDate.year == projectedToday.year &&
        visibleDate.month == projectedToday.month &&
        visibleDate.day == projectedToday.day;
    void submit() {
      if (visibleIsFuture) {
        onPlan();
      } else if (isToday) {
        onStart();
      } else {
        onNewTaskForPastDate();
      }
    }

    final selector = SizedBox(
      height: kAppCompactControlHeight,
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        style: appCompactSegmentedButtonStyle(context, segmentWidth: 112),
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
    );
    final actionIcon = visibleIsFuture
        ? Icons.event_rounded
        : isToday
        ? Icons.play_arrow_rounded
        : Icons.add_task_rounded;
    final actionLabel = visibleIsFuture
        ? t(loc, 'plan')
        : isToday
        ? t(loc, 'start_timer')
        : t(loc, 'new_record_btn');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (desktopShell)
          AppDesktopSectionControlRow(
            title: t(loc, 'tab_timeline'),
            controls: selector,
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: selector,
          ),
        if (!showStatsView) ...[
          if (desktopShell)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
              child: AppQuickEntryRow(
                controller: titleController,
                focusNode: titleFocus,
                hintText: t(loc, 'input_placeholder_record'),
                actionLabel: actionLabel,
                actionIcon: actionIcon,
                onAction: submit,
                onSubmitted: (_) => submit(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: titleController,
                      focusNode: titleFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        hintText: t(loc, 'input_placeholder_record'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: submit,
                    icon: Icon(actionIcon),
                    label: Text(actionLabel),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        const Divider(height: 1),
      ],
    );
  }
}
