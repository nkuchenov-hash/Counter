import 'package:counter/data/models.dart';

enum PathStatus { draft, reviewed, active, archived }

class PathActionSnapshot {
  const PathActionSnapshot({
    required this.id,
    required this.text,
    required this.expectedResult,
    required this.minutes,
    required this.track,
    required this.isDone,
  });

  final String id;
  final String text;
  final String expectedResult;
  final int minutes;
  final String track;
  final bool isDone;

  PathActionSnapshot copyWith({bool? isDone}) => PathActionSnapshot(
    id: id,
    text: text,
    expectedResult: expectedResult,
    minutes: minutes,
    track: track,
    isDone: isDone ?? this.isDone,
  );

  factory PathActionSnapshot.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
  }) {
    final rawMinutes = json['minutes'];
    final minutes = rawMinutes is int
        ? rawMinutes
        : rawMinutes is num
        ? rawMinutes.round()
        : int.tryParse(rawMinutes?.toString() ?? '') ?? 0;
    return PathActionSnapshot(
      id: (json['id'] ?? fallbackId).toString(),
      text: (json['text'] ?? '').toString().trim(),
      expectedResult: (json['result'] ?? '').toString().trim(),
      minutes: minutes,
      track: (json['track'] ?? 'execution').toString().trim(),
      isDone: json['isDone'] == true || json['is_done'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'text': text,
    'result': expectedResult,
    'minutes': minutes,
    'track': track,
    'isDone': isDone,
  };
}

class PathStageSnapshot {
  const PathStageSnapshot({
    required this.id,
    required this.title,
    required this.completionCriteria,
    required this.isDone,
    required this.actions,
  });

  final String id;
  final String title;
  final String completionCriteria;
  final bool isDone;
  final List<PathActionSnapshot> actions;

  PathStageSnapshot copyWith({
    bool? isDone,
    List<PathActionSnapshot>? actions,
  }) => PathStageSnapshot(
    id: id,
    title: title,
    completionCriteria: completionCriteria,
    isDone: isDone ?? this.isDone,
    actions: actions ?? this.actions,
  );

  factory PathStageSnapshot.fromJson(
    Map<String, dynamic> json, {
    required int stageIndex,
  }) {
    final actions = <PathActionSnapshot>[];
    final rawActions = json['actions'];
    if (rawActions is List) {
      for (
        var actionIndex = 0;
        actionIndex < rawActions.length;
        actionIndex++
      ) {
        final raw = rawActions[actionIndex];
        if (raw is! Map) continue;
        final action = PathActionSnapshot.fromJson(
          Map<String, dynamic>.from(raw),
          fallbackId: 'action-$stageIndex-$actionIndex',
        );
        if (action.text.isNotEmpty) actions.add(action);
      }
    }
    return PathStageSnapshot(
      id: (json['id'] ?? 'stage-$stageIndex').toString(),
      title: (json['text'] ?? '').toString().trim(),
      completionCriteria: (json['definitionOfDone'] ?? '').toString().trim(),
      isDone: json['isDone'] == true || json['is_done'] == true,
      actions: actions,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'stage',
    'id': id,
    'text': title,
    'definitionOfDone': completionCriteria,
    'isDone': isDone,
    'actions': actions.map((action) => action.toJson()).toList(growable: false),
  };
}

class ProjectPathSnapshot {
  const ProjectPathSnapshot({
    required this.pathRecordId,
    required this.pathId,
    required this.revisionRecordId,
    required this.revisionId,
    required this.category,
    required this.goal,
    required this.status,
    required this.version,
    required this.stages,
  });

  final String pathRecordId;
  final String pathId;
  final String revisionRecordId;
  final String revisionId;
  final CategoryRule category;
  final String goal;
  final PathStatus status;
  final int version;
  final List<PathStageSnapshot> stages;

  ProjectPathSnapshot copyWith({
    String? goal,
    List<PathStageSnapshot>? stages,
  }) => ProjectPathSnapshot(
    pathRecordId: pathRecordId,
    pathId: pathId,
    revisionRecordId: revisionRecordId,
    revisionId: revisionId,
    category: category,
    goal: goal ?? this.goal,
    status: status,
    version: version,
    stages: stages ?? this.stages,
  );
}

class PathCatalogSnapshot {
  const PathCatalogSnapshot({required this.paths});

  final List<ProjectPathSnapshot> paths;
}

/// Stable key used by the Paths display preference.
/// PocketBase category row id survives category rename/reorder.
String pathCategoryPreferenceKey(CategoryRule category) {
  final pbId = category.backendRowId?.trim() ?? '';
  if (pbId.isNotEmpty) return pbId;
  return category.categoryKey.trim();
}

class PathCategoryNode {
  const PathCategoryNode({
    required this.category,
    required this.paths,
    required this.children,
  });

  final CategoryRule category;
  final List<ProjectPathSnapshot> paths;
  final List<PathCategoryNode> children;

  Iterable<ProjectPathSnapshot> get allPaths sync* {
    yield* paths;
    for (final child in children) {
      yield* child.allPaths;
    }
  }
}

class PathCategoryProjection {
  const PathCategoryProjection({
    required this.roots,
    required this.uncategorizedPaths,
  });

  final List<PathCategoryNode> roots;
  final List<ProjectPathSnapshot> uncategorizedPaths;

  List<ProjectPathSnapshot> get visiblePaths => <ProjectPathSnapshot>[
    for (final root in roots) ...root.allPaths,
    ...uncategorizedPaths,
  ];
}

class _PathCategoryIndex {
  _PathCategoryIndex(List<CategoryRule> roots) {
    void walk(CategoryRule category, int? parentId) {
      byId[category.id] = category;
      parentById[category.id] = parentId;
      final key = pathCategoryPreferenceKey(category);
      if (key.isNotEmpty) idByKey[key] = category.id;
      orderedIds.add(category.id);
      for (final child in category.children ?? const <CategoryRule>[]) {
        walk(child, category.id);
      }
    }

    for (final root in roots) {
      walk(root, null);
    }
  }

  final Map<int, CategoryRule> byId = <int, CategoryRule>{};
  final Map<int, int?> parentById = <int, int?>{};
  final Map<String, int> idByKey = <String, int>{};
  final List<int> orderedIds = <int>[];
}

/// Removes invalid/redundant selections. A selected ancestor owns its subtree,
/// so selected descendants are implied rather than persisted twice.
Set<String> normalizePathCategoryRootKeys({
  required List<CategoryRule> categoryRoots,
  required Iterable<String> selectedKeys,
}) {
  final index = _PathCategoryIndex(categoryRoots);
  final selectedIds = <int>{};
  for (final raw in selectedKeys) {
    final id = index.idByKey[raw.trim()];
    final category = id == null ? null : index.byId[id];
    if (id != null && category != null && !category.isArchived) {
      selectedIds.add(id);
    }
  }

  final normalizedIds = <int>{};
  for (final id in index.orderedIds) {
    if (!selectedIds.contains(id)) continue;
    var parent = index.parentById[id];
    var covered = false;
    while (parent != null) {
      if (selectedIds.contains(parent)) {
        covered = true;
        break;
      }
      parent = index.parentById[parent];
    }
    if (!covered) normalizedIds.add(id);
  }

  return <String>{
    for (final id in index.orderedIds)
      if (normalizedIds.contains(id))
        pathCategoryPreferenceKey(index.byId[id]!),
  };
}

/// Category ids needed by the Paths folder selector: every Path category plus
/// the ancestor chain needed to preserve the real hierarchy.
Set<int> relevantPathCategoryIds({
  required List<CategoryRule> categoryRoots,
  required Iterable<ProjectPathSnapshot> paths,
}) {
  final index = _PathCategoryIndex(categoryRoots);
  final relevantIds = <int>{};
  for (final path in paths) {
    var id = path.category.id;
    if (!index.byId.containsKey(id)) continue;
    while (true) {
      relevantIds.add(id);
      final parent = index.parentById[id];
      if (parent == null) break;
      id = parent;
    }
  }
  return relevantIds;
}

Set<String> relevantPathCategoryKeys({
  required List<CategoryRule> categoryRoots,
  required Iterable<ProjectPathSnapshot> paths,
}) {
  final index = _PathCategoryIndex(categoryRoots);
  final ids = relevantPathCategoryIds(
    categoryRoots: categoryRoots,
    paths: paths,
  );
  return <String>{
    for (final id in index.orderedIds)
      if (ids.contains(id) && index.byId[id]?.isArchived != true)
        pathCategoryPreferenceKey(index.byId[id]!),
  };
}

Set<int> pathCategoryRootIdsForKeys({
  required List<CategoryRule> categoryRoots,
  required Iterable<String> rootKeys,
}) {
  final index = _PathCategoryIndex(categoryRoots);
  final out = <int>{};
  for (final key in normalizePathCategoryRootKeys(
    categoryRoots: categoryRoots,
    selectedKeys: rootKeys,
  )) {
    final id = index.idByKey[key];
    if (id != null) out.add(id);
  }
  return out;
}

Set<String> pathCategoryKeysForRootIds({
  required List<CategoryRule> categoryRoots,
  required Iterable<int> rootIds,
}) {
  final index = _PathCategoryIndex(categoryRoots);
  return normalizePathCategoryRootKeys(
    categoryRoots: categoryRoots,
    selectedKeys: <String>{
      for (final id in rootIds)
        if (index.byId[id] != null)
          pathCategoryPreferenceKey(index.byId[id]!),
    },
  );
}

Set<int> effectivePathCategoryIdsForRoots({
  required List<CategoryRule> categoryRoots,
  required Set<int> selectedRootIds,
}) {
  final out = <int>{};
  void walk(CategoryRule category, bool covered) {
    final selected = selectedRootIds.contains(category.id);
    final effective = covered || selected;
    if (effective) out.add(category.id);
    for (final child in category.children ?? const <CategoryRule>[]) {
      walk(child, effective);
    }
  }

  for (final root in categoryRoots) {
    walk(root, false);
  }
  return out;
}

bool pathCategoryIsCoveredBySelectedAncestor({
  required List<CategoryRule> categoryRoots,
  required Set<int> selectedRootIds,
  required int categoryId,
}) {
  final index = _PathCategoryIndex(categoryRoots);
  var parent = index.parentById[categoryId];
  while (parent != null) {
    if (selectedRootIds.contains(parent)) return true;
    parent = index.parentById[parent];
  }
  return false;
}

PathCategoryProjection buildPathCategoryProjection({
  required List<CategoryRule> categoryRoots,
  required List<ProjectPathSnapshot> paths,
  required Set<String>? selectedRootKeys,
}) {
  final index = _PathCategoryIndex(categoryRoots);
  final pathsByCategoryId = <int, List<ProjectPathSnapshot>>{};
  final uncategorized = <ProjectPathSnapshot>[];

  for (final path in paths) {
    if (!index.byId.containsKey(path.category.id)) {
      uncategorized.add(path);
      continue;
    }
    pathsByCategoryId
        .putIfAbsent(path.category.id, () => <ProjectPathSnapshot>[])
        .add(path);
  }

  PathCategoryNode? buildNode(CategoryRule category) {
    final childNodes = <PathCategoryNode>[];
    for (final child in category.children ?? const <CategoryRule>[]) {
      final node = buildNode(child);
      if (node != null) childNodes.add(node);
    }
    final directPaths = List<ProjectPathSnapshot>.from(
      pathsByCategoryId[category.id] ?? const <ProjectPathSnapshot>[],
    );
    directPaths.sort(
      (a, b) => a.goal.toLowerCase().compareTo(b.goal.toLowerCase()),
    );
    if (category.isArchived || (directPaths.isEmpty && childNodes.isEmpty)) {
      return null;
    }
    return PathCategoryNode(
      category: category,
      paths: directPaths,
      children: childNodes,
    );
  }

  final projectionRoots = <PathCategoryNode>[];
  if (selectedRootKeys == null) {
    for (final root in categoryRoots) {
      final node = buildNode(root);
      if (node != null) projectionRoots.add(node);
    }
  } else {
    final normalized = normalizePathCategoryRootKeys(
      categoryRoots: categoryRoots,
      selectedKeys: selectedRootKeys,
    );
    for (final id in index.orderedIds) {
      final category = index.byId[id]!;
      if (!normalized.contains(pathCategoryPreferenceKey(category))) continue;
      final node = buildNode(category);
      if (node != null) projectionRoots.add(node);
    }
  }

  return PathCategoryProjection(
    roots: projectionRoots,
    uncategorizedPaths: uncategorized,
  );
}

class PathStructureAudit {
  const PathStructureAudit(this.problems);

  final List<String> problems;
  bool get isValid => problems.isEmpty;
}

PathStructureAudit auditPathStructure({
  required String goal,
  required List<PathStageSnapshot> stages,
}) {
  final problems = <String>[];
  if (goal.trim().isEmpty) problems.add('Path goal is empty.');
  if (stages.isEmpty) problems.add('Path has no stages.');

  for (var stageIndex = 0; stageIndex < stages.length; stageIndex++) {
    final stage = stages[stageIndex];
    final number = stageIndex + 1;
    if (stage.title.trim().isEmpty) {
      problems.add('Stage $number has no outcome title.');
    }
    if (stage.completionCriteria.trim().isEmpty) {
      problems.add('Stage $number has no completion criteria.');
    }
    if (!stage.isDone && stage.actions.isEmpty) {
      problems.add('Stage $number has no executable actions.');
    }
    for (
      var actionIndex = 0;
      actionIndex < stage.actions.length;
      actionIndex++
    ) {
      final action = stage.actions[actionIndex];
      final actionNumber = actionIndex + 1;
      if (action.text.trim().isEmpty) {
        problems.add('Stage $number action $actionNumber has no action text.');
      }
      if (action.expectedResult.trim().isEmpty) {
        problems.add(
          'Stage $number action $actionNumber has no expected result.',
        );
      }
      if (action.minutes <= 0 || action.minutes > 30) {
        problems.add(
          'Stage $number action $actionNumber must fit in 1–30 minutes.',
        );
      }
    }
  }
  return PathStructureAudit(problems);
}
