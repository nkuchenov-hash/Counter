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

/// Planning quick-entry chrome. Desktop uses the same canonical entry row as
/// Timeline; phone/tablet preserve the established tag-first arrangement.
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
    final settingsButton = IconButton(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
      ),
      icon: const Icon(Icons.settings_rounded),
      tooltip: settingsTooltip,
      onPressed: onSettings,
    );
    final smartButton = IconButton(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
      ),
      icon: const Icon(Icons.auto_awesome_rounded),
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
    final inputRow = desktop
        ? AppQuickEntryRow(
            controller: controller,
            focusNode: focusNode,
            hintText: hintText,
            actionLabel: addLabel,
            actionIcon: Icons.add_rounded,
            onAction: onAdd,
            onSubmitted: (_) => onAdd(),
            loading: loading,
          )
        : Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(hintText: hintText),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(addLabel),
              ),
              const SizedBox(width: 8),
              smartButton,
            ],
          );
    return Padding(
      padding: desktop
          ? const EdgeInsets.fromLTRB(24, 0, 16, 10)
          : const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: desktop
            ? [inputRow, const SizedBox(height: 8), tagsRow]
            : [tagsRow, const SizedBox(height: 10), inputRow],
      ),
    );
  }
}
