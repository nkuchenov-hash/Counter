import 'package:counter/l10n/dictionary.dart';
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
