import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/paths/path_models.dart';
import 'package:uuid/uuid.dart';

export 'path_models.dart';

/// Durable first-class repository for Paths.
///
/// Storage is the dedicated PocketBase `paths` + `path_revisions` pair.
/// `paths.active_revision_id` is the only execution gate. Revisions are
/// append-only snapshots: editing an active Path publishes a new revision and
/// switches the project pointer only after the new snapshot exists.
class PathRepository {
  PathRepository({DatabaseService? database})
      : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;
  static const Uuid _uuid = Uuid();
  final Map<String, Future<ProjectPathSnapshot?>> _saveChains =
      <String, Future<ProjectPathSnapshot?>>{};

  Future<PathCatalogSnapshot> loadActivePaths() async {
    await _database.refreshCategoryRulesFromServer();
    final pathRows = await _database.fetchOwnedPathRows();
    final paths = <ProjectPathSnapshot>[];

    for (final row in pathRows) {
      final pathId = (row['path_id'] ?? '').toString().trim();
      final revisionId = (row['active_revision_id'] ?? '').toString().trim();
      final categoryId = _asInt(row['category_id']);
      if (pathId.isEmpty || revisionId.isEmpty || categoryId <= 0) continue;

      final category = _database.getCategoryRuleById(categoryId);
      if (category == null || category.isArchived) continue;

      final revision = await _database.fetchOwnedPathRevisionRow(
        pathId: pathId,
        revisionId: revisionId,
      );
      if (revision == null) continue;

      final snapshot = _snapshotFromRows(
        pathRow: row,
        revisionRow: revision,
        category: category,
      );
      if (snapshot != null) paths.add(snapshot);
    }

    paths.sort(
      (a, b) => a.category.name.toLowerCase().compareTo(
            b.category.name.toLowerCase(),
          ),
    );
    return PathCatalogSnapshot(paths: paths);
  }

  Future<ProjectPathSnapshot?> loadActivePath(String pathId) async {
    await _database.refreshCategoryRulesFromServer();
    final pathRow = await _database.fetchOwnedPathRowByBusinessId(pathId);
    if (pathRow == null || pathRow['archived'] == true) return null;

    final categoryId = _asInt(pathRow['category_id']);
    final revisionId = (pathRow['active_revision_id'] ?? '').toString().trim();
    if (categoryId <= 0 || revisionId.isEmpty) return null;
    final category = _database.getCategoryRuleById(categoryId);
    if (category == null || category.isArchived) return null;

    final revision = await _database.fetchOwnedPathRevisionRow(
      pathId: pathId,
      revisionId: revisionId,
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
    if (!audit.isValid) return null;

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
      final path = await _database.createOwnedPath(
        pathId: pathId,
        categoryId: category.id,
        title: category.name,
        activeRevisionId: revisionId,
      );
      return _snapshotFromRows(
        pathRow: path,
        revisionRow: revision,
        category: category,
      );
    } catch (_) {
      final revisionRecordId = (revision?['id'] ?? '').toString().trim();
      if (revisionRecordId.isNotEmpty) {
        try {
          await _database.deleteOwnedPathRevision(revisionRecordId);
        } catch (_) {
          // Orphan revisions are not executable because no Path points to them.
        }
      }
      return null;
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
      await _database.setOwnedPathActiveRevision(
        pathRecordId: current.pathRecordId,
        revisionId: revisionId,
        title: current.category.name,
      );
      final revisionRecordId = (revision['id'] ?? '').toString().trim();
      if (revisionRecordId.isEmpty) return null;
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
      final revisionRecordId = (revision?['id'] ?? '').toString().trim();
      if (revisionRecordId.isNotEmpty) {
        try {
          await _database.deleteOwnedPathRevision(revisionRecordId);
        } catch (_) {
          // Safe to leave: only the pointer in `paths` grants active status.
        }
      }
      return null;
    }
  }

  PathStructureAudit audit(ProjectPathSnapshot path) => auditPathStructure(
        goal: path.goal,
        stages: path.stages,
      );

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
