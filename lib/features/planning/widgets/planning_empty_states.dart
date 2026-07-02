import 'package:counter/features/shared/shared_widgets.dart';
import 'package:flutter/material.dart';

/// Standard Planning day empty state (no tasks for selected day).
class PlanningDayEmptyState extends StatelessWidget {
  const PlanningDayEmptyState({
    super.key,
    this.onFocusQuickAdd,
  });

  final VoidCallback? onFocusQuickAdd;

  @override
  Widget build(BuildContext context) {
    return EmptyStatePlaceholder(
      icon: Icons.track_changes_rounded,
      titleL10nKey: 'empty_planning_title',
      subtitleL10nKey: 'empty_planning_subtitle',
      actionLabelL10nKey: onFocusQuickAdd != null
          ? 'empty_action_focus_planning_field'
          : null,
      onAction: onFocusQuickAdd,
    );
  }
}

/// Empty state inside frozen plan card list (no action button).
class PlanningFrozenListEmptyState extends StatelessWidget {
  const PlanningFrozenListEmptyState({super.key, required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surface,
      child: const PlanningDayEmptyState(),
    );
  }
}
