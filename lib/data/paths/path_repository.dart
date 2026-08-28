import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/paths/path_models.dart';
import 'package:uuid/uuid.dart';

export 'path_models.dart';

/// Durable first-class repository for Paths.
///
/// Storage is the dedicated PocketBase `paths` + `path_revisions` pair.
/// `paths.active_revision_link` is the only execution gate. Revisions are
/// append-only snapshots: editing an active Path publishes a new revision and
/// switches the project relation only after the new snapshot exists.
class PathRepository {
  PathRepository({DatabaseService? database})
    : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;
  static const Uuid _uuid = Uuid();
  final Map<String, Future<ProjectPathSnapshot?>> _saveChains =
      <String, Future<ProjectPathSnapshot?>>{};

  /// User-visible category trail for a Path, from root folder to leaf project.
  String categoryBreadcrumb(CategoryRule category) {
    final ids = _database.categoryPathFromRootToLocalId(category.id);
    if (ids.isEmpty) return category.name.trim();

    final names = <String>[];
    for (final id in ids) {
      final rule = _database.getCategoryRuleById(id);
      if (rule == null || rule.isArchived) continue;
      final name = rule.name.trim();
      if (name.isNotEmpty) names.add(name);
    }
    return names.isEmpty ? category.name.trim() : names.join(' › ');
  }

  Future<PathCatalogSnapshot> loadActivePaths() async {
    await _database.refreshCategoryRulesFromServer();
    final pathRows = await _database.fetchOwnedPathRows();
    final paths = <ProjectPathSnapshot>[];

    for (final row in pathRows) {
      final pathId = (row['path_id'] ?? '').toString().trim();
      final revisionRecordId = (row['active_revision_link'] ?? '')
          .toString()
          .trim();
      final categoryPocketBaseId = (row['category_link'] ?? '')
          .toString()
          .trim();
      if (pathId.isEmpty || revisionRecordId.isEmpty) continue;

      final resolvedCategory = categoryPocketBaseId.isEmpty
          ? null
          : _database.getCategoryRuleByBackendRowId(categoryPocketBaseId);
      final category =
          resolvedCategory == null || resolvedCategory.isArchived
          ? CategoryRule.uncategorized()
          : resolvedCategory;

      final revision = await _database.fetchOwnedPathRevisionRow(
        pathId: pathId,
        revisionRecordId: revisionRecordId,
      );
      if (revision == null) continue;

      final snapshot = _snapshotFromRows(
        pathRow: row,
        revisionRow: revision,
        category: category,
      );
      if (snapshot != null) paths.add(snapshot);
    }

    paths.sort((a, b) {
      final aUncategorized = a.category.backendRowId == 'uncategorized';
      final bUncategorized = b.category.backendRowId == 'uncategorized';
      if (aUncategorized != bUncategorized) return aUncategorized ? 1 : -1;
      return categoryBreadcrumb(
        a.category,
      ).toLowerCase().compareTo(categoryBreadcrumb(b.category).toLowerCase());
    });
    return PathCatalogSnapshot(paths: paths);
  }

  Future<ProjectPathSnapshot?> loadActivePath(String pathId) async {
    await _database.refreshCategoryRulesFromServer();
    final pathRow = await _database.fetchOwnedPathRowByBusinessId(pathId);
    if (pathRow == null || pathRow['archived'] == true) return null;

    final categoryPocketBaseId = (pathRow['category_link'] ?? '')
        .toString()
        .trim();
    final revisionRecordId = (pathRow['active_revision_link'] ?? '')
        .toString()
        .trim();
    if (revisionRecordId.isEmpty) return null;
    final resolvedCategory = categoryPocketBaseId.isEmpty
        ? null
        : _database.getCategoryRuleByBackendRowId(categoryPocketBaseId);
    final category = resolvedCategory == null || resolvedCategory.isArchived
        ? CategoryRule.uncategorized()
        : resolvedCategory;

    final revision = await _database.fetchOwnedPathRevisionRow(
      pathId: pathId,
      revisionRecordId: revisionRecordId,
    );
    if (revision == null) return null;
    return _snapshotFromRows(
      pathRow: pathRow,
      revisionRow: revision,
      category: category,
    );
  }

  Future<ProjectPathSnapshot?> createPath({
    required CategoryRule category,
    required String goal,
    required List<PathStageSnapshot> stages,
    String source = 'manual',
  }) async {
    final cleanGoal = goal.trim();
    final audit = auditPathStructure(goal: cleanGoal, stages: stages);
    final categoryPocketBaseId = category.backendRowId?.trim() ?? '';
    if (!audit.isValid || categoryPocketBaseId.isEmpty) return null;

    final pathId = _uuid.v4();
    final revisionId = _uuid.v4();
    Map<String, dynamic>? revision;
    try {
      revision = await _database.createOwnedPathRevision(
        pathId: pathId,
        revisionId: revisionId,
        version: 1,
        lifecycle: 'published',
        goal: cleanGoal,
        stages: stages.map((stage) => stage.toJson()).toList(growable: false),
        source: source,
      );
      final revisionRecordId = (revision['id'] ?? '').toString().trim();
      if (revisionRecordId.isEmpty) return null;
      final path = await _database.createOwnedPath(
        pathId: pathId,
        categoryPocketBaseId: categoryPocketBaseId,
        activeRevisionRecordId: revisionRecordId,
      );
      return _snapshotFromRows(
        pathRow: path,
        revisionRow: revision,
        category: category,
      );
    } catch (_) {
      // Revisions are immutable audit history. An unreferenced revision is
      // non-executable because only `paths.active_revision_link` activates it.
      return null;
    }
  }

  /// Deletes a Path independently of Path creation or replacement.
  ///
  /// The executable `paths` row is removed immediately. Immutable revisions are
  /// deliberately retained as audit history and cannot become active without a
  /// Path row pointing at them.
  Future<bool> deletePath(ProjectPathSnapshot path) async {
    final pathId = path.pathId.trim();
    final pathRecordId = path.pathRecordId.trim();
    if (pathId.isEmpty || pathRecordId.isEmpty) return false;

    final pendingSave = _saveChains[pathId];
    if (pendingSave != null) {
      try {
        await pendingSave;
      } catch (_) {}
    }

    try {
      await _database.deleteOwnedPath(pathRecordId: pathRecordId);
      _saveChains.remove(pathId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Serializes writes per Path so rapid optimistic edits cannot race for the
  /// same version number or fork revision ancestry.
  Future<ProjectPathSnapshot?> saveActivePath(ProjectPathSnapshot path) {
    final pathId = path.pathId.trim();
    if (pathId.isEmpty) return Future<ProjectPathSnapshot?>.value(null);

    final previous =
        _saveChains[pathId] ?? Future<ProjectPathSnapshot?>.value(null);
    late final Future<ProjectPathSnapshot?> next;
    next = previous.then((_) => _saveActivePathNow(path));
    _saveChains[pathId] = next;
    return next.whenComplete(() {
      if (identical(_saveChains[pathId], next)) {
        _saveChains.remove(pathId);
      }
    });
  }

  Future<ProjectPathSnapshot?> _saveActivePathNow(
    ProjectPathSnapshot requested,
  ) async {
    final audit = auditPathStructure(
      goal: requested.goal,
      stages: requested.stages,
    );
    if (!audit.isValid || requested.status != PathStatus.active) return null;

    // The caller may hold an older optimistic snapshot while an earlier edit is
    // still saving. Always anchor the next immutable revision to the current
    // server-active revision, but persist the caller's latest full content.
    final current = await loadActivePath(requested.pathId);
    if (current == null || current.status != PathStatus.active) return null;

    final revisionId = _uuid.v4();
    final version = current.version + 1;
    Map<String, dynamic>? revision;
    try {
      revision = await _database.createOwnedPathRevision(
        pathId: current.pathId,
        revisionId: revisionId,
        version: version,
        lifecycle: 'published',
        goal: requested.goal,
        stages: requested.stages
            .map((stage) => stage.toJson())
            .toList(growable: false),
        source: 'manual',
        parentRevisionId: current.revisionId,
      );
      final revisionRecordId = (revision['id'] ?? '').toString().trim();
      if (revisionRecordId.isEmpty) return null;
      await _database.setOwnedPathActiveRevision(
        pathRecordId: current.pathRecordId,
        revisionRecordId: revisionRecordId,
      );
      return ProjectPathSnapshot(
        pathRecordId: current.pathRecordId,
        pathId: current.pathId,
        revisionRecordId: revisionRecordId,
        revisionId: revisionId,
        category: current.category,
        goal: requested.goal,
        status: PathStatus.active,
        version: version,
        stages: requested.stages,
      );
    } catch (_) {
      // Failed pointer switches leave immutable, unreferenced audit revisions.
      // They cannot execute because the Path relation still points elsewhere.
      return null;
    }
  }

  PathStructureAudit audit(ProjectPathSnapshot path) =>
      auditPathStructure(goal: path.goal, stages: path.stages);

  ProjectPathSnapshot? _snapshotFromRows({
    required Map<String, dynamic> pathRow,
    required Map<String, dynamic> revisionRow,
    required CategoryRule category,
  }) {
    final pathRecordId = (pathRow['id'] ?? '').toString().trim();
    final pathId = (pathRow['path_id'] ?? '').toString().trim();
    final revisionRecordId = (revisionRow['id'] ?? '').toString().trim();
    final revisionId = (revisionRow['revision_id'] ?? '').toString().trim();
    final goal = (revisionRow['goal'] ?? '').toString().trim();
    final version = _asInt(revisionRow['version']);
    if (pathRecordId.isEmpty ||
        pathId.isEmpty ||
        revisionRecordId.isEmpty ||
        revisionId.isEmpty ||
        goal.isEmpty ||
        version <= 0) {
      return null;
    }

    final content = _asStringMap(revisionRow['content']);
    final rawStages = content['stages'];
    final stages = <PathStageSnapshot>[];
    if (rawStages is List) {
      for (var index = 0; index < rawStages.length; index++) {
        final raw = rawStages[index];
        if (raw is! Map) continue;
        final stage = PathStageSnapshot.fromJson(
          Map<String, dynamic>.from(raw),
          stageIndex: index,
        );
        if (stage.title.isNotEmpty) stages.add(stage);
      }
    }

    return ProjectPathSnapshot(
      pathRecordId: pathRecordId,
      pathId: pathId,
      revisionRecordId: revisionRecordId,
      revisionId: revisionId,
      category: category,
      goal: goal,
      status: PathStatus.active,
      version: version,
      stages: stages,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }
}
