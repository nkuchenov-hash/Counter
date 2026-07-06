import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Bulk selection mode chrome above the Planning day body.
class PlanningSelectModeHeader extends StatelessWidget {
  const PlanningSelectModeHeader({
    super.key,
    required this.scheme,
    required this.onExit,
    this.visiblePlans,
    required this.allVisibleSelected,
    this.onToggleSelectAll,
  });

  final ColorScheme scheme;
  final VoidCallback onExit;
  final List<PlanningTask>? visiblePlans;
  final bool allVisibleSelected;
  final VoidCallback? onToggleSelectAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: scheme.surface,
          elevation: 0,
          surfaceTintColor: scheme.surfaceTint,
          child: SizedBox(
            height: kGlobalCompactHeaderHeight,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onExit,
                  tooltip: t(currentLocale.value, 'plan_exit_select'),
                ),
                Expanded(
                  child: Text(
                    t(currentLocale.value, 'plan_select_mode'),
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (visiblePlans != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                    ),
                    onPressed: onToggleSelectAll,
                    child: Text(
                      allVisibleSelected
                          ? t(
                              currentLocale.value,
                              'plan_deselect_visible',
                            )
                          : t(currentLocale.value, 'plan_select_all'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
      ],
    );
  }
}
