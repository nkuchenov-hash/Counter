import 'dart:async';

import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Select-mode chrome row above the Lists body.
class ListsBulkSelectModeBar extends StatelessWidget {
  const ListsBulkSelectModeBar({
    super.key,
    required this.locale,
    required this.filterCategoryId,
    required this.visibleFlat,
    required this.allVisibleSelected,
    required this.onExitSelectMode,
    required this.onToggleSelectAllVisible,
  });

  final String locale;
  final int? filterCategoryId;
  final List<PlanningTask> visibleFlat;
  final bool allVisibleSelected;
  final VoidCallback onExitSelectMode;
  final VoidCallback onToggleSelectAllVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: theme.colorScheme.surface,
          elevation: 0,
          surfaceTintColor: theme.colorScheme.surfaceTint,
          child: SizedBox(
            height: kGlobalCompactHeaderHeight,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onExitSelectMode,
                  tooltip: t(locale, 'plan_exit_select'),
                ),
                Expanded(
                  child: Text(
                    t(locale, 'plan_select_mode'),
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (filterCategoryId != null && visibleFlat.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: onToggleSelectAllVisible,
                    child: Text(
                      allVisibleSelected
                          ? t(locale, 'plan_deselect_visible')
                          : t(locale, 'plan_select_all'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}

/// Bottom bulk-action bar when list rows are selected.
class ListsBulkBottomBar extends StatelessWidget {
  const ListsBulkBottomBar({
    super.key,
    required this.locale,
    required this.selectedCount,
    required this.onEdit,
    required this.onDelete,
  });

  final String locale;
  final int selectedCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                  t(locale, 'selected_count').replaceFirst(
                    '%s',
                    '$selectedCount',
                  ),
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: t(locale, 'edit'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: t(locale, 'delete'),
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
