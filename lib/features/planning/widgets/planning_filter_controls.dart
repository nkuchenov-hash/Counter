import 'dart:async';

import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Compact sort-mode tabs above the Planning quick-add row.
class PlanningSortModeBar extends StatelessWidget {
  const PlanningSortModeBar({
    super.key,
    required this.sortMode,
    required this.onSortModeChanged,
    this.desktopTitle,
  });

  final PlanSortMode sortMode;
  final ValueChanged<PlanSortMode> onSortModeChanged;
  final String? desktopTitle;

  @override
  Widget build(BuildContext context) {
    final selector = SizedBox(
      height: kAppCompactControlHeight,
      child: SegmentedButton<PlanSortMode>(
        showSelectedIcon: false,
        style: appCompactSegmentedButtonStyle(context, segmentWidth: 78),
        segments: [
          ButtonSegment<PlanSortMode>(
            value: PlanSortMode.category,
            label: AppCompactSegmentLabel(
              text: t(currentLocale.value, 'plan_sort_category'),
            ),
          ),
          ButtonSegment<PlanSortMode>(
            value: PlanSortMode.time,
            label: AppCompactSegmentLabel(
              text: t(currentLocale.value, 'plan_sort_time'),
            ),
          ),
          ButtonSegment<PlanSortMode>(
            value: PlanSortMode.tags,
            label: AppCompactSegmentLabel(
              text: t(currentLocale.value, 'plan_sort_tags'),
            ),
          ),
          ButtonSegment<PlanSortMode>(
            value: PlanSortMode.custom,
            label: AppCompactSegmentLabel(
              text: t(currentLocale.value, 'plan_sort_custom'),
            ),
          ),
        ],
        selected: {sortMode},
        onSelectionChanged: (Set<PlanSortMode> next) {
          if (next.isEmpty) return;
          final mode = next.first;
          onSortModeChanged(mode);
          unawaited(
            DatabaseService.instance.persistPlanActiveTabIndex(
              planSortModeToPersistedIndex(mode),
            ),
          );
        },
      ),
    );
    final title = desktopTitle;
    if (title != null) {
      return AppDesktopSectionControlRow(title: title, controls: selector);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: selector,
      ),
    );
  }
}
