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

  Widget _textTab(BuildContext context, PlanSortMode mode, String title) =>
      _PlanningTextModeTab(
        label: title,
        selected: sortMode == mode,
        onTap: () => _selectMode(mode),
      );

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
    );
    final smartButton = AppIconButton(
      icon: Icons.auto_awesome_rounded,
      tooltip: smartTooltip,
      onPressed: onSmart,
      variant: AppIconButtonVariant.subtle,
    );

    // The same max-width and horizontal gutter as PlanningQuickAddChrome.
    // One expanded middle slot lets the two actions finish at the exact
    // same right edge as the Add button, regardless of viewport width.
    if (desktop) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kPlanningDesktopChromeMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              kShellDesktopContentHorizontalPadding,
              kShellDesktopContentTopPadding,
              kShellDesktopContentHorizontalPadding,
              6,
            ),
            child: SizedBox(
              height: kAppCompactControlHeight,
              child: Row(
                children: [
                  Text(
                    desktopTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 428),
                        child: _modeTabs(context),
                      ),
                    ),
                  ),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
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

/// Text-only view tab. Hover changes the label color, not its rectangle.
/// This widget owns only its local hover state and never rebuilds the day grid.
class _PlanningTextModeTab extends StatefulWidget {
  const _PlanningTextModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PlanningTextModeTab> createState() => _PlanningTextModeTabState();
}

class _PlanningTextModeTabState extends State<_PlanningTextModeTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlighted = widget.selected || _hovered;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            height: kAppCompactControlHeight,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: widget.selected
                    ? BorderSide(color: scheme.primary, width: 2)
                    : BorderSide.none,
              ),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 120),
              style: (Theme.of(context).textTheme.bodyMedium ??
                      const TextStyle())
                  .copyWith(
                fontSize: 15,
                fontWeight: widget.selected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: highlighted
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant.withValues(alpha: 0.80),
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ),
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
