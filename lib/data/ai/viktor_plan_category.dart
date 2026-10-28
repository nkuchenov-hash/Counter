import 'package:counter/data/models.dart';

/// Uses the same already-loaded title/keyword category resolver as Planning's
/// quick-add. Viktor never invents or hard-codes category names or IDs.
CategoryRule resolveViktorPlanCategory({
  required String title,
  required CategoryRule? Function(String) identifyCategory,
  required CategoryRule? Function(int) categoryById,
  required int? defaultCategoryId,
  required Iterable<CategoryRule> rootCategories,
  bool Function(CategoryRule)? canSave,
}) {
  bool active(CategoryRule? rule) =>
      rule != null && !rule.isArchived &&
      rule.id != CategoryRule.uncategorizedSyntheticId &&
      (canSave == null || canSave(rule));
  final match = identifyCategory(title.trim());
  if (active(match)) {
    final stored = categoryById(match!.id);
    if (active(stored)) return stored!;
  }
  if (defaultCategoryId != null) {
    final fallback = categoryById(defaultCategoryId);
    if (active(fallback)) return fallback!;
  }
  for (final root in rootCategories) {
    final stored = categoryById(root.id);
    if (active(stored)) return stored!;
  }
  throw StateError('Для нового плана не найдена доступная категория.');
}
