import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Explicit parent for picker create — never inferred from selection/search UI.
@immutable
class CategoryPickerCreateTarget {
  const CategoryPickerCreateTarget._({
    required this.parentLocalId,
    this.parentDisplayName,
  });

  const CategoryPickerCreateTarget.root()
      : parentLocalId = null,
        parentDisplayName = null;

  const CategoryPickerCreateTarget.child({
    required int parentLocalId,
    required String parentDisplayName,
  }) : parentLocalId = parentLocalId,
       parentDisplayName = parentDisplayName;

  final int? parentLocalId;
  final String? parentDisplayName;

  bool get isRoot => parentLocalId == null;

  @override
  bool operator ==(Object other) =>
      other is CategoryPickerCreateTarget &&
      other.parentLocalId == parentLocalId &&
      other.parentDisplayName == parentDisplayName;

  @override
  int get hashCode => Object.hash(parentLocalId, parentDisplayName);
}

@visibleForTesting
CategoryPickerCreateTarget categoryPickerCreateTargetForRow(CategoryRule rule) {
  return CategoryPickerCreateTarget.child(
    parentLocalId: rule.id,
    parentDisplayName: rule.name.trim(),
  );
}

@immutable
class CategoryPickerCreateResult {
  const CategoryPickerCreateResult({
    required this.localCategoryId,
    required this.displayName,
    this.parentLocalId,
    this.pocketBaseSystemId,
  });

  final int localCategoryId;
  final String displayName;
  final int? parentLocalId;
  final String? pocketBaseSystemId;
}

/// Result of tree sheet: picked id, or "all" for nullable filters, or dismissed.
sealed class CategoryTreeSheetResult {}

class CategoryTreeSheetPicked extends CategoryTreeSheetResult {
  CategoryTreeSheetPicked(this.id);
  final int id;
}

/// Nullable filter: user chose "all categories".
class CategoryTreeSheetAll extends CategoryTreeSheetResult {}

/// True when [id] cannot be used as a concrete plan/record category (incl. create placeholder `-1`).
bool isNonPersistableCategoryLocalId(int? id) {
  if (id == null) return true;
  if (id == 0) return true;
  if (id == CategoryRule.uncategorizedSyntheticId) return true;
  return false;
}

String categoryPickerCreateDialogTitle(
  String loc,
  CategoryPickerCreateTarget target,
) {
  if (target.isRoot) {
    return t(loc, 'category_create_root_title');
  }
  final parentName = (target.parentDisplayName ?? '').trim();
  return t(loc, 'category_create_inside_title').replaceFirst('%s', parentName);
}

/// Always-visible picker create row (top / bottom / search miss).
Key get categoryPickerTopAddKey =>
    const ValueKey<String>('category_picker_top_add');

Key get categoryPickerBottomAddKey =>
    const ValueKey<String>('category_picker_bottom_add');

Key categoryPickerFolderAddKey(int categoryId) =>
    ValueKey<String>('category_picker_folder_add_$categoryId');

String categoryPickerAddInsideLabel(String loc, String folderName) {
  return t(loc, 'category_picker_add_inside').replaceFirst('%s', folderName);
}

Key categoryPickerRowAddKey(int categoryId) =>
    ValueKey<String>('category_picker_row_add_$categoryId');

bool categoryTreeNodeShowsPickerAddChild({
  required bool showPickerCreateChrome,
  required void Function(CategoryRule parent)? onPickerAddChild,
}) {
  return showPickerCreateChrome && onPickerAddChild != null;
}

Widget categoryPickerCreateListTile({
  required Key key,
  required String label,
  required VoidCallback? onTap,
  String? subtitle,
}) {
  return ListTile(
    key: key,
    leading: const Icon(Icons.add_rounded),
    title: Text(label),
    subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle) : null,
    enabled: onTap != null,
    onTap: onTap,
  );
}
