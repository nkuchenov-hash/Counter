import 'package:counter/data/models.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';

const double kCategoryInactiveBranchOpacity = 0.4;

/// Spine-based opacity: on path to [selectedCategoryId] = 1.0; deeper descendants
/// of leaf = 1.0; siblings off-spine = [kCategoryInactiveBranchOpacity].
double categoryBranchOpacityForSelection({
  required int? selectedCategoryId,
  required int nodeId,
  required int depth,
  List<int> Function(int categoryId)? pathFromRoot,
}) {
  if (selectedCategoryId == null) return 1.0;
  final resolve = pathFromRoot ?? CategoryTreeSource.pathFromRoot;
  final spine = resolve(selectedCategoryId);
  if (spine.isEmpty) return 1.0;
  if (depth < spine.length) {
    return nodeId == spine[depth] ? 1.0 : kCategoryInactiveBranchOpacity;
  }
  final path = resolve(nodeId);
  if (path.length <= spine.length) return kCategoryInactiveBranchOpacity;
  final anchor = spine.last;
  final idx = path.indexOf(anchor);
  return (idx >= 0 && idx < path.length - 1)
      ? 1.0
      : kCategoryInactiveBranchOpacity;
}

/// Filters category roots for picker search (label match on node or descendants).
List<CategoryRule> filterCategoryRootsForPickerSearch(
  List<CategoryRule> roots,
  String query,
  String Function(CategoryRule rule) labelFor,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return roots;

  CategoryRule? filterNode(CategoryRule rule) {
    final labelMatch = labelFor(rule).toLowerCase().contains(q);
    final childrenRaw = rule.children ?? const <CategoryRule>[];
    final filteredChildren = <CategoryRule>[
      for (final c in childrenRaw)
        if (filterNode(c) case final filtered?) filtered,
    ];
    if (labelMatch || filteredChildren.isNotEmpty) {
      return rule.copyWith(children: filteredChildren);
    }
    return null;
  }

  return [
    for (final r in roots)
      if (filterNode(r) case final filtered?) filtered,
  ];
}
