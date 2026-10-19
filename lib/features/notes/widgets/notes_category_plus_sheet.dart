import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_picker_models.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:counter/shared/categories/picker/create_category_from_picker.dart';
import 'package:flutter/material.dart';

/// Explicit Notes '+' flow: pin an existing category, or create and pin a new one.
/// Delegates all category mutations to the canonical category picker/Brain.
Future<Set<int>?> showNotesAddFolderSheet(
  BuildContext context, {
  required Set<int> currentCategoryIds,
}) async {
  final loc = currentLocale.value;
  final ru = loc == 'ru';
  final action = await showModalBottomSheet<_NotesFolderAddAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
              child: Text(
                ru ? 'Добавить вкладку' : 'Add a folder tab',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            ListTile(
              key: const ValueKey('notes_add_existing_category'),
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(ru ? 'Из существующих категорий' : 'Choose existing categories'),
              subtitle: Text(ru
                  ? 'Выбрать одну или несколько категорий'
                  : 'Choose one or more categories'),
              onTap: () => Navigator.of(sheetContext)
                  .pop(_NotesFolderAddAction.existing),
            ),
            ListTile(
              key: const ValueKey('notes_create_new_category'),
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(ru ? 'Создать новую категорию' : 'Create new category'),
              subtitle: categoryCreateFromPickerAllowed()
                  ? null
                  : Text(t(loc, 'category_create_requires_connection')),
              enabled: categoryCreateFromPickerAllowed(),
              onTap: () => Navigator.of(sheetContext)
                  .pop(_NotesFolderAddAction.create),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return null;
  switch (action) {
    case _NotesFolderAddAction.existing:
      return showCategoryTreeMultiPicker(
        context,
        initialCategoryIds: currentCategoryIds,
      );
    case _NotesFolderAddAction.create:
      final created = await showCreateCategoryFromPickerDialog(
        context,
        target: const CategoryPickerCreateTarget.root(),
      );
      if (created == null) return null;
      return {...currentCategoryIds, created};
  }
}

enum _NotesFolderAddAction { existing, create }
