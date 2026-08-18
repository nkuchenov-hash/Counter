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
/// atomically switches the project pointer only after the new snapshot exists.
class PathRepository {
  PathRepository({DatabaseService? database})
      : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;
  static const Uuid _uuid = Uuid();

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

  Future<bool> saveActivePath(ProjectPathSnapshot path) async {
    final audit = auditPathStructure(goal: path.goal, stages: path.stages);
    if (!audit.isValid || path.status != PathStatus.active) return false;

    final revisionId = _uuid.v4();
    Map<String, dynamic>? revision;
    try {
      revision = await _database.createOwnedPathRevision(
        pathId: path.pathId,
        revisionId: revisionId,
        version: path.version + 1,
        lifecycle: 'published',
        goal: path.goal,
        stages: path.stages
            .map((stage) => stage.toJson())
            .toList(growable: false),
        source: 'manual',
        parentRevisionId: path.revisionId,
      );
      await _database.setOwnedPathActiveRevision(
        pathRecordId: path.pathRecordId,
        revisionId: revisionId,
        title: path.category.name,
      );
      return true;
    } catch (_) {
      final revisionRecordId = (revision?['id'] ?? '').toString().trim();
      if (revisionRecordId.isNotEmpty) {
        try {
          await _database.deleteOwnedPathRevision(revisionRecordId);
        } catch (_) {
          // Safe to leave: only the pointer in `paths` grants active status.
        }
      }
      return false;
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
