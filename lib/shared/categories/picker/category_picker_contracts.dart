import 'package:counter/data/models.dart';
import 'package:flutter/foundation.dart';

/// Narrow category tree reads for shared picker/tree/visibility UI.
///
/// Wired once at the composition root (`main.dart`) from Brain callbacks.
/// Shared Categories must not import `database_service.dart`.
abstract final class CategoryTreeSource {
  static List<CategoryRule> Function(int? parentLocalId)? getChildrenOf;
  static Stream<List<CategoryRule>> Function()? categoryStream;
  static List<int> Function(int categoryId)? pathFromRootToLocalId;
  static bool Function(int categoryId)? categoryExists;
  static String Function(int categoryId)? getCategoryPath;
  static int Function()? newLocalId;
  static int? Function(int categoryId)? getParentId;

  static List<CategoryRule> childrenOf(int? parentLocalId) {
    final fn = getChildrenOf;
    assert(fn != null, 'CategoryTreeSource.getChildrenOf not wired');
    return fn?.call(parentLocalId) ?? const <CategoryRule>[];
  }

  static Stream<List<CategoryRule>> watchCategories() {
    final fn = categoryStream;
    assert(fn != null, 'CategoryTreeSource.categoryStream not wired');
    return fn?.call() ?? const Stream<List<CategoryRule>>.empty();
  }

  static List<int> pathFromRoot(int categoryId) {
    final fn = pathFromRootToLocalId;
    assert(fn != null, 'CategoryTreeSource.pathFromRootToLocalId not wired');
    return fn?.call(categoryId) ?? const <int>[];
  }

  static bool exists(int categoryId) {
    final fn = categoryExists;
    assert(fn != null, 'CategoryTreeSource.categoryExists not wired');
    return fn?.call(categoryId) ?? false;
  }

  static String pathLabel(int categoryId) {
    final fn = getCategoryPath;
    assert(fn != null, 'CategoryTreeSource.getCategoryPath not wired');
    return fn?.call(categoryId) ?? '';
  }
}

/// Narrow create/mutation surface for shared picker create UI.
abstract final class CategoryPickerActions {
  /// Test hook — when set, bypasses [isCreateAllowed].
  @visibleForTesting
  static bool Function()? createAllowedOverride;

  /// Test hook — when set, bypasses Brain [addNestedCategory].
  static Future<int?> Function(int? parentLocalId, CategoryRule child)?
      addNestedCategoryOverride;

  static bool Function()? isCreateAllowed;
  static int? Function({
    required int? parentLocalId,
    required String displayName,
  })? findCreatedUnderParent;
  static Future<int?> Function(int? parentLocalId, CategoryRule child)?
      addNestedCategory;

  static bool createAllowed() {
    if (createAllowedOverride != null) {
      return createAllowedOverride!();
    }
    final fn = isCreateAllowed;
    assert(fn != null, 'CategoryPickerActions.isCreateAllowed not wired');
    return fn?.call() ?? false;
  }
}

/// Back-compat aliases for existing tests and call sites.
@visibleForTesting
bool Function()? get categoryCreateFromPickerAllowedOverride =>
    CategoryPickerActions.createAllowedOverride;

@visibleForTesting
set categoryCreateFromPickerAllowedOverride(bool Function()? value) {
  CategoryPickerActions.createAllowedOverride = value;
}

@visibleForTesting
Future<int?> Function(int? parentLocalId, CategoryRule child)?
    get categoryPickerAddNestedCategoryOverride =>
        CategoryPickerActions.addNestedCategoryOverride;

@visibleForTesting
set categoryPickerAddNestedCategoryOverride(
  Future<int?> Function(int? parentLocalId, CategoryRule child)? value,
) {
  CategoryPickerActions.addNestedCategoryOverride = value;
}

bool categoryCreateFromPickerAllowed() => CategoryPickerActions.createAllowed();
