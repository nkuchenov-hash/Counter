import 'dart:async';

import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/features/planning/planning_sort_mode.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

const double kPlanningDesktopChromeMaxWidth = 1240;

/// Planning view selector and its actions share one toolbar above quick-add.
/// The selected view uses an underline; inactive modes stay simple text.
class PlanningSortModeBar extends StatelessWidget {
  const PlanningSortModeBar({
    super.key,
    required this.sortMode,
    required this.onSortModeChanged,
    required this.onSettings,
    required this.onSmart,
    required this.settingsTooltip,
    required this.smartTooltip,
    this.desktopTitle,
  });

  final PlanSortMode sortMode;
  final ValueChanged<PlanSortMode> onSortModeChanged;
  final VoidCallback onSettings;
  final VoidCallback onSmart;
  final String settingsTooltip;
  final String smartTooltip;
  final String? desktopTitle;

  void _selectMode(PlanSortMode next) {
    if (next == sortMode) return;
    onSortModeChanged(next);
    unawaited(
      DatabaseService.instance.persistPlanActiveTabIndex(
        planSortModeToPersistedIndex(next),
      ),
    );
  }

  Widget _textTab(BuildContext context, PlanSortMode mode, String title) {
    final scheme = Theme.of(context).colorScheme;
    final selected = mode == sortMode;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectMode(mode),
          child: Container(
            height: kAppCompactControlHeight,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 2,
                  color: selected ? scheme.primary : Colors.transparent,
                ),
              ),
            ),
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant.withValues(alpha: 0.80),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeTabs(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _textTab(context, PlanSortMode.category,
            t(currentLocale.value, 'plan_sort_category')),
        _textTab(context, PlanSortMode.time,
            t(currentLocale.value, 'plan_sort_time')),
        _textTab(context, PlanSortMode.tags,
            t(currentLocale.value, 'plan_sort_tags')),
        _textTab(context, PlanSortMode.custom,
            t(currentLocale.value, 'plan_sort_custom')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final desktop = desktopTitle != null;
    final settingsButton = AppIconButton(
      icon: Icons.settings_rounded,
      tooltip: settingsTooltip,
      onPressed: onSettings,
      variant: AppIconButtonVariant.subtle,
      size: desktop ? AppIconButtonSize.m : AppIconButtonSize.s,
    );
    final smartButton = AppIconButton(
      icon: Icons.auto_awesome_rounded,
      tooltip: smartTooltip,
      onPressed: onSmart,
      variant: AppIconButtonVariant.subtle,
      size: desktop ? AppIconButtonSize.m : AppIconButtonSize.s,
    );

    if (desktop) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kPlanningDesktopChromeMaxWidth,
          ),
          child: SizedBox(
            width: double.infinity,
            child: AppDesktopSectionControlRow(
              title: desktopTitle!,
              controls: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 428, child: _modeTabs(context)),
                  const SizedBox(width: 10),
                  settingsButton,
                  const SizedBox(width: 4),
                  smartButton,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          Expanded(child: _modeTabs(context)),
          const SizedBox(width: 6),
          settingsButton,
          const SizedBox(width: 4),
          smartButton,
        ],
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
    required this.tagStrip,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.addLabel,
    required this.onAdd,
    required this.loading,
  });

  final bool desktop;
  final Widget tagStrip;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String addLabel;
  final VoidCallback onAdd;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final inputRow = AppQuickEntryRow(
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      actionLabel: addLabel,
      actionIcon: Icons.add_rounded,
      onAction: onAdd,
      onSubmitted: (_) => onAdd(),
      loading: loading,
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
            ? [inputRow, const SizedBox(height: 8), SizedBox(height: 40, child: tagStrip)]
            : [SizedBox(height: 40, child: tagStrip), const SizedBox(height: 10), inputRow],
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
