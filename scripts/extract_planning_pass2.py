#!/usr/bin/env python3
"""Structure refactor pass 2 — planning_view.dart safe UI extractions."""
from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
PV = ROOT / "lib" / "features" / "planning" / "planning_view.dart"

SORT_MODE = """enum PlanSortMode { category, time, tags, custom }

/// Order matches [SegmentedButton] segments (persisted as [DatabaseService.kPrefsPlanActiveTab]).
int planSortModeToPersistedIndex(PlanSortMode m) {
  switch (m) {
    case PlanSortMode.category:
      return 0;
    case PlanSortMode.time:
      return 1;
    case PlanSortMode.tags:
      return 2;
    case PlanSortMode.custom:
      return 3;
  }
}

PlanSortMode planSortModeFromPersistedIndex(int i) {
  switch (i) {
    case 0:
      return PlanSortMode.category;
    case 1:
      return PlanSortMode.time;
    case 2:
      return PlanSortMode.tags;
    default:
      return PlanSortMode.custom;
  }
}
"""

BULK_BAR = """import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Bulk selection action bar (Planning tab bottom overlay).
class PlanningBulkBottomBar extends StatelessWidget {
  const PlanningBulkBottomBar({
    super.key,
    required this.selectedCount,
    required this.onClear,
    required this.onBulkEdit,
    required this.onBulkDelete,
  });

  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onBulkEdit;
  final VoidCallback onBulkDelete;

  @override
  Widget build(BuildContext context) {
    if (selectedCount <= 0) return const SizedBox.shrink();
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Material(
        elevation: 6,
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t(
                    loc,
                    'selected_count',
                  ).replaceFirst('%s', '$selectedCount'),
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: Text(t(loc, 'cancel')),
              ),
              IconButton(
                tooltip: t(loc, 'plan_bulk_edit'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: onBulkEdit,
              ),
              IconButton(
                tooltip: t(loc, 'delete'),
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                onPressed: onBulkDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
"""

FILTER_CONTROLS = """import 'dart:async';

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
  });

  final PlanSortMode sortMode;
  final ValueChanged<PlanSortMode> onSortModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          height: kAppCompactControlHeight,
          child: SegmentedButton<PlanSortMode>(
            showSelectedIcon: false,
            style: appCompactSegmentedButtonStyle(
              context,
              segmentWidth: 78,
            ),
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
        ),
      ),
    );
  }
}
"""

EMPTY_STATES = """import 'package:counter/features/shared/shared_widgets.dart';
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
"""

REORDER_DECORATOR = """import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Shared elevation proxy for Planning reorderable lists.
Widget planningReorderProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, c) {
      final v = Curves.easeInOut.transform(animation.value);
      return Material(
        elevation: lerpDouble(0, 10, v) ?? 0,
        shadowColor: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: c,
      );
    },
    child: child,
  );
}
"""


def rename_sort_mode(text: str) -> str:
    text = text.replace("_PlanSortMode", "PlanSortMode")
    text = text.replace("_planSortModeToPersistedIndex", "planSortModeToPersistedIndex")
    text = text.replace("_planSortModeFromPersistedIndex", "planSortModeFromPersistedIndex")
    return text


def main() -> None:
    lines = PV.read_text(encoding="utf-8").splitlines(keepends=True)

    (ROOT / "lib/features/planning/planning_sort_mode.dart").write_text(
        SORT_MODE + "\n",
        encoding="utf-8",
    )
    (ROOT / "lib/features/planning/widgets/planning_bulk_bar.dart").write_text(
        BULK_BAR,
        encoding="utf-8",
    )
    (ROOT / "lib/features/planning/widgets/planning_filter_controls.dart").write_text(
        FILTER_CONTROLS,
        encoding="utf-8",
    )
    (ROOT / "lib/features/planning/widgets/planning_empty_states.dart").write_text(
        EMPTY_STATES,
        encoding="utf-8",
    )
    (ROOT / "lib/features/planning/widgets/planning_list_helpers.dart").write_text(
        REORDER_DECORATOR,
        encoding="utf-8",
    )

    kept = lines[:70] + lines[98:]
    text = rename_sort_mode("".join(kept))

    imports = [
        "import 'package:counter/features/planning/planning_sort_mode.dart';",
        "import 'package:counter/features/planning/widgets/planning_bulk_bar.dart';",
        "import 'package:counter/features/planning/widgets/planning_empty_states.dart';",
        "import 'package:counter/features/planning/widgets/planning_filter_controls.dart';",
        "import 'package:counter/features/planning/widgets/planning_list_helpers.dart';",
    ]
    marker = "import 'package:counter/features/planning/widgets/planning_menu_overlay.dart';"
    text = text.replace(marker, marker + "\n" + "\n".join(imports) + "\n", 1)

    text = re.sub(
        r"  Widget\? _planningBulkBottomBar\(\s*BuildContext context,\s*ColorScheme scheme,\s*List<PlanningTask> tasks,\s*\) \{[\s\S]*?\n  \}\n\n",
        "",
        text,
        count=1,
    )

    text = text.replace(
        "? _planningBulkBottomBar(context, scheme, displayedForChrome)",
        """? PlanningBulkBottomBar(
                selectedCount: _selectedPlanKeys.length,
                onClear: _clearSelection,
                onBulkEdit: () => unawaited(_openBulkPlanningEdit(displayedForChrome)),
                onBulkDelete: () => unawaited(_bulkDelete(displayedForChrome)),
              )""",
    )

    text = text.replace(
        """        if (!_planSelectMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                height: kAppCompactControlHeight,
                child: SegmentedButton<PlanSortMode>(
                  showSelectedIcon: false,
                  style: appCompactSegmentedButtonStyle(
                    context,
                    segmentWidth: 78,
                  ),
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
                  selected: {_sortMode},
                  onSelectionChanged: (Set<PlanSortMode> next) {
                    if (next.isEmpty) return;
                    final mode = next.first;
                    setState(() {
                      _sortMode = mode;
                    });
                    unawaited(
                      DatabaseService.instance.persistPlanActiveTabIndex(
                        planSortModeToPersistedIndex(mode),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),""",
        """        if (!_planSelectMode)
          PlanningSortModeBar(
            sortMode: _sortMode,
            onSortModeChanged: (mode) => setState(() => _sortMode = mode),
          ),""",
    )

    text = text.replace(
        """      return ColoredBox(
        color: scheme.surface,
        child: EmptyStatePlaceholder(
          icon: Icons.track_changes_rounded,
          titleL10nKey: 'empty_planning_title',
          subtitleL10nKey: 'empty_planning_subtitle',
        ),
      );""",
        "      return PlanningFrozenListEmptyState(scheme: scheme);",
    )
    text = text.replace(
        """      return EmptyStatePlaceholder(
        icon: Icons.track_changes_rounded,
        titleL10nKey: 'empty_planning_title',
        subtitleL10nKey: 'empty_planning_subtitle',
        actionLabelL10nKey: 'empty_action_focus_planning_field',
        onAction: () => FocusScope.of(context).requestFocus(_quickAddFocus),
      );""",
        """      return PlanningDayEmptyState(
        onFocusQuickAdd: () => FocusScope.of(context).requestFocus(_quickAddFocus),
      );""",
    )

    # Replace inline proxyDecorator closures with shared helper
    text = text.replace(
        """    Widget proxyDecorator(
      Widget child,
      int index,
      Animation<double> animation,
    ) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, c) {
          final v = Curves.easeInOut.transform(animation.value);
          return Material(
            elevation: lerpDouble(0, 10, v) ?? 0,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: c,
          );
        },
        child: child,
      );
    }

    var firstCategoryGroup = true;""",
        """    var firstCategoryGroup = true;""",
    )
    text = text.replace("proxyDecorator: proxyDecorator,", "proxyDecorator: planningReorderProxyDecorator,")
    text = text.replace(
        """    Widget proxyDecorator(
      Widget child,
      int index,
      Animation<double> animation,
    ) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, c) {
          final v = Curves.easeInOut.transform(animation.value);
          return Material(
            elevation: lerpDouble(0, 10, v) ?? 0,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: c,
          );
        },
        child: child,
      );
    }

    var firstGroup = true;""",
        """    var firstGroup = true;""",
    )

    text = text.replace(
        """      proxyDecorator: (Widget child, int index, Animation<double> anim) {
        return AnimatedBuilder(
          animation: anim,
          builder: (context, c) {
            final v = Curves.easeInOut.transform(anim.value);
            return Material(
              elevation: lerpDouble(0, 10, v) ?? 0,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: c,
            );
          },
          child: child,
        );
      },""",
        "      proxyDecorator: planningReorderProxyDecorator,",
    )

    PV.write_text(text, encoding="utf-8")
    print(f"planning_view.dart -> {len(text.splitlines())} lines")


if __name__ == "__main__":
    main()
