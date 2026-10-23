import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:flutter/material.dart';

/// Notes '+' opens the canonical category tree immediately. The tree already
/// supports selecting/pinning multiple existing categories and creating both
/// root and child categories in-place. No preliminary action-choice sheet.
Future<Set<int>?> showNotesAddFolderSheet(
  BuildContext context, {
  required Set<int> currentCategoryIds,
}) => showCategoryTreeMultiPicker(
  context,
  initialCategoryIds: currentCategoryIds,
);
