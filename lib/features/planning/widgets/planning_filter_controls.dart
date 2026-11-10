import 'dart:async';

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

const double kPlanningDesktopChromeMaxWidth = 1240;

/// Compact sort-mode tabs above the Planning quick-add row.
class PlanningSortModeBar extends StatelessWidget {
  const PlanningSortModeBar({
    super.key,
    required this.sortMode,
    required this.onSortModeChanged,
    this.desktopTitle,
    this.onAdjacentDayRequested,
    this.dayNavigationEnabled = true,
  });

  final PlanSortMode sortMode;
  final ValueChanged<PlanSortMode> onSortModeChanged;
  final String? desktopTitle;
  final ValueChanged<int>? onAdjacentDayRequested;
  final bool dayNavigationEnabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildForWidth(context, constraints.maxWidth),
  );

  Widget _buildForWidth(BuildContext context, double availableWidth) {
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
    // Navigation stays with fixed controls instead of taking 192px from
    // every plan card. Narrow phones use the existing day-content swipe.
    final minWidth = desktopTitle == null ? 600.0 : 900.0;
    final showDayButtons = availableWidth >= minWidth &&
        onAdjacentDayRequested != null;
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: t(currentLocale.value, 'date_previous_day'),
          onPressed: dayNavigationEnabled && onAdjacentDayRequested != null
              ? () => onAdjacentDayRequested!.call(-1)
              : null,
          size: AppIconButtonSize.m,
        ),
        const SizedBox(width: 8),
        AppIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: t(currentLocale.value, 'date_next_day'),
          onPressed: dayNavigationEnabled && onAdjacentDayRequested != null
              ? () => onAdjacentDayRequested!.call(1)
              : null,
          size: AppIconButtonSize.m,
        ),
      ],
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        selector,
        if (showDayButtons) ...[
          const SizedBox(width: 40),
          navigation,
        ],
      ],
    );
    final title = desktopTitle;
    if (title != null) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kPlanningDesktopChromeMaxWidth,
          ),
          child: SizedBox(
            width: double.infinity,
            child: AppDesktopSectionControlRow(
              title: title,
              controls: controls,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: showDayButtons
          ? Row(
              children: [
                selector,
                const Spacer(),
                navigation,
              ],
            )
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: selector,
            ),
    );
  }
}

/// Planning quick-entry chrome. All form factors use the same canonical
/// quick-entry row; phone/tablet only differ in surrounding action placement.
class PlanningQuickAddChrome extends StatelessWidget {
  const PlanningQuickAddChrome({
    super.key,
    required this.desktop,
    required this.scheme,
    required this.tagStrip,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.addLabel,
    required this.settingsTooltip,
    required this.smartTooltip,
    required this.onAdd,
    required this.onSettings,
    required this.onSmart,
    required this.loading,
  });

  final bool desktop;
  final ColorScheme scheme;
  final Widget tagStrip;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String addLabel;
  final String settingsTooltip;
  final String smartTooltip;
  final VoidCallback onAdd;
  final VoidCallback onSettings;
  final VoidCallback onSmart;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final settingsButton = AppIconButton(
      icon: Icons.settings_rounded,
      tooltip: settingsTooltip,
      onPressed: onSettings,
    );
    final smartButton = AppIconButton(
      icon: Icons.auto_awesome_rounded,
      tooltip: smartTooltip,
      onPressed: onSmart,
    );
    final tagsRow = Row(
      children: [
        Expanded(child: SizedBox(height: 40, child: tagStrip)),
        const SizedBox(width: 8),
        settingsButton,
        if (desktop) smartButton,
      ],
    );
    final inputRow = Row(
      children: [
        Expanded(
          child: AppQuickEntryRow(
            controller: controller,
            focusNode: focusNode,
            hintText: hintText,
            actionLabel: addLabel,
            actionIcon: Icons.add_rounded,
            onAction: onAdd,
            onSubmitted: (_) => onAdd(),
            loading: loading,
          ),
        ),
        if (!desktop) ...[
          const SizedBox(width: 8),
          smartButton,
        ],
      ],
    );
    final content = Padding(
      padding: desktop
          ? const EdgeInsets.fromLTRB(
              kShellDesktopContentHorizontalPadding,
              0,
              kShellDesktopContentHorizontalPadding,
              10,
            )
          : const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: desktop
            ? [inputRow, const SizedBox(height: 8), tagsRow]
            : [tagsRow, const SizedBox(height: 10), inputRow],
      ),
    );
    if (!desktop) return content;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: kPlanningDesktopChromeMaxWidth,
        ),
        child: SizedBox(width: double.infinity, child: content),
      ),
    );
  }
}
