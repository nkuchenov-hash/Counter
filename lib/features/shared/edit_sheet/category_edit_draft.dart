import 'package:counter/data/database_service.dart';
import 'package:counter/shared/categories/picker/category_picker_models.dart';
import 'package:flutter/foundation.dart';

export 'package:counter/shared/categories/picker/category_picker_models.dart'
    show isNonPersistableCategoryLocalId;

/// Resolves category id for edit fields — prefer in-memory tree over stale pair lists.
@visibleForTesting
int resolveEditFieldCategoryIdValues({
  required int categoryId,
  required bool existsInTree,
  required Iterable<int> knownPairIds,
}) {
  if (existsInTree) return categoryId;
  if (knownPairIds.contains(categoryId)) return categoryId;
  // Keep explicit picker/create handoff id — never substitute pairs.first.
  return categoryId;
}

@visibleForTesting
int resolveEditFieldCategoryId({
  required DatabaseService db,
  required int categoryId,
}) {
  return resolveEditFieldCategoryIdValues(
    categoryId: categoryId,
    existsInTree: db.categoryExists(categoryId),
    knownPairIds: db.allCategoryIdPathPairs.map((p) => p.id),
  );
}

/// Canonical draft category for edit Save — explicit picker/create id owns the draft.
/// Never fall back to [originalTaskCategoryId] when an explicit selection exists.
@visibleForTesting
int resolvePlanningEditDraftCategoryId({
  required int draftCategoryId,
  required int originalTaskCategoryId,
  required bool existsInTree,
  required Iterable<int> knownPairIds,
}) {
  final resolved = resolveEditFieldCategoryIdValues(
    categoryId: draftCategoryId,
    existsInTree: existsInTree,
    knownPairIds: knownPairIds,
  );
  // Explicit draft wins even when tree/pairs are momentarily stale after create.
  if (!isNonPersistableCategoryLocalId(resolved)) return resolved;
  // Only if draft is unusable, keep original (legacy empty picker).
  return originalTaskCategoryId;
}

/// Whether a plan PATCH body should include `category_id` for [localCategoryId].
@visibleForTesting
bool planPatchShouldIncludeCategoryRelation({
  required int? localCategoryId,
  required String? pocketBaseCategoryRowId,
}) {
  if (isNonPersistableCategoryLocalId(localCategoryId)) return false;
  final pb = (pocketBaseCategoryRowId ?? '').trim();
  if (pb.isEmpty) return false;
  if (pb.length < 14 || pb.length > 17) return false;
  if (pb.contains('-')) return false;
  return RegExp(r'^[a-z0-9]+$').hasMatch(pb);
}
