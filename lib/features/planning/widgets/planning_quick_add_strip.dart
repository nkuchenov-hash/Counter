import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Quick-add tag strip above the Planning inline task field.
class PlanningQuickAddTagStrip extends StatelessWidget {
  const PlanningQuickAddTagStrip({
    super.key,
    required this.scheme,
    required this.tagsLoading,
    required this.availableTags,
    required this.selectedTags,
    required this.onToggleTag,
    required this.onOpenTagManager,
    required this.onReorder,
  });

  final ColorScheme scheme;
  final bool tagsLoading;
  final List<Tag> availableTags;
  final List<Tag> selectedTags;
  final ValueChanged<Tag> onToggleTag;
  final VoidCallback onOpenTagManager;
  final void Function(int oldIndex, int newIndex)? onReorder;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    if (tagsLoading && availableTags.isEmpty) {
      return const SizedBox.shrink();
    }
    if (availableTags.isEmpty) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: onOpenTagManager,
          child: Text(t(loc, 'plan_quick_add_no_tags')),
        ),
      );
    }
    return TagQuickPickStrip(
      tags: availableTags,
      selected: selectedTags,
      onToggle: onToggleTag,
      fallbackColor: scheme.primary,
      variant: CategoryChipVariant.largePicker,
      externalSelectionRing: true,
      onReorder: onReorder,
    );
  }
}
