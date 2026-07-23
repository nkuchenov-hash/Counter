import 'package:counter/data/models.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:counter/shared/categories/tree/category_tree_body.dart';
import 'package:flutter/material.dart';

/// Full categories browser: roots only until expanded; active-path opacity.
class CategoryRecursiveBrowsePanel extends StatelessWidget {
  const CategoryRecursiveBrowsePanel({
    super.key,
    required this.selectedCategoryId,
    required this.onSelect,
    required this.onFullSettingsTap,
    required this.onAppearanceTap,
    required this.onAddChild,
    this.editMode = false,
  });

  final int? selectedCategoryId;
  final ValueChanged<int> onSelect;
  final void Function(CategoryRule r) onFullSettingsTap;
  final void Function(CategoryRule r) onAppearanceTap;
  final void Function(CategoryRule parent) onAddChild;
  final bool editMode;

  @override
  Widget build(BuildContext context) {
    final roots = CategoryTreeSource.childrenOf(null);
    if (roots.isEmpty) {
      return const SizedBox.shrink();
    }
    return CategoryTreeBody(
      roots: roots,
      selectedCategoryId: selectedCategoryId,
      expandSelectionPath: true,
      onSelect: onSelect,
      showEditChrome: editMode,
      onFullSettingsTap: onFullSettingsTap,
      onAppearanceTap: onAppearanceTap,
      onAddChild: onAddChild,
    );
  }
}
