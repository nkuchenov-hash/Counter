import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';

/// Compatibility marker for the currently shipped plan-backed Path storage.
///
/// New Paths code must go through [PathRepository] instead of reading marker
/// rows directly. This lets the storage move later without changing feature UI.
const String kLegacyActivePathMarker = 'LIFEOS_PATH::V2';

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
  }) =>
      PathStageSnapshot(
        id: id,
        title: title,
        completionCriteria: completionCriteria,
        isDone: isDone ?? this.isDone,
        actions: actions ?? this.actions,
      );

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
    required this.category,
    required this.root,
    required this.goal,
    required this.status,
    required this.version,
    required this.stages,
  });

  final CategoryRule category;
  final PlanningTask root;
  final String goal;
  final PathStatus status;
  final int version;
  final List<PathStageSnapshot> stages;

  ProjectPathSnapshot copyWith({
    String? goal,
    List<PathStageSnapshot>? stages,
  }) =>
      ProjectPathSnapshot(
        category: category,
        root: root,
        goal: goal ?? this.goal,
        status: status,
        version: version,
        stages: stages ?? this.stages,
      );
}

class PathCatalogSnapshot {
  const PathCatalogSnapshot({
    required this.paths,
    required this.duplicateActiveRootCategoryIds,
  });

  final List<ProjectPathSnapshot> paths;

  /// Categories with more than one active legacy root. Load is intentionally
  /// read-only: the repository reports duplicates but never retires rows just
  /// because the screen was opened.
  final Set<int> duplicateActiveRootCategoryIds;
}

class PathStructureAudit {
  const PathStructureAudit(this.problems);

  final List<String> problems;
  bool get isValid => problems.isEmpty;
}

/// First-class domain boundary for Paths.
///
/// Today it is a compatibility adapter over the existing `plans` rows. It is
/// deliberately free of page-open migrations, Planner generation and
/// project-specific profiles. Those concerns must be explicit services/actions.
class PathRepository {
  PathRepository({DatabaseService? database})
      : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;

  Future<PathCatalogSnapshot> loadActivePaths() async {
    await _database.refreshCategoryRulesFromServer();
    final tasks = await _database.fetchBacklogPlans(includeCompleted: true);

    final grouped = <int, List<PlanningTask>>{};
    for (final task in tasks) {
      if ((task.notesPlain ?? '').trim() != kLegacyActivePathMarker) continue;
      grouped.putIfAbsent(task.categoryId, () => <PlanningTask>[]).add(task);
    }

    final duplicates = <int>{};
    final paths = <ProjectPathSnapshot>[];
    for (final entry in grouped.entries) {
      final category = _database.getCategoryRuleById(entry.key);
      if (category == null || category.isArchived) continue;
      if (entry.value.length > 1) duplicates.add(entry.key);

      final root = _selectCanonicalRoot(entry.value);
      paths.add(
        ProjectPathSnapshot(
          category: category,
          root: root,
          goal: root.title.trim(),
          status: PathStatus.active,
          version: 1,
          stages: _parseStages(root.checklist),
        ),
      );
    }

    paths.sort(
      (a, b) => a.category.name.toLowerCase().compareTo(
            b.category.name.toLowerCase(),
          ),
    );
    return PathCatalogSnapshot(
      paths: paths,
      duplicateActiveRootCategoryIds: duplicates,
    );
  }

  Future<bool> saveActivePath(ProjectPathSnapshot path) {
    return _database.updatePlanningTask(
      path.root.planRowIdForBackend,
      planBusinessId: path.root.planRowId,
      title: path.goal,
      categoryId: path.category.id,
      isDone: true,
      notesPlain: kLegacyActivePathMarker,
      checklist: path.stages.map((stage) => stage.toJson()).toList(growable: false),
      suppressAppSnack: true,
    );
  }

  PathStructureAudit audit(ProjectPathSnapshot path) {
    final problems = <String>[];
    if (path.goal.trim().isEmpty) problems.add('Path goal is empty.');
    if (path.stages.isEmpty) problems.add('Path has no stages.');

    for (var stageIndex = 0; stageIndex < path.stages.length; stageIndex++) {
      final stage = path.stages[stageIndex];
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
      for (var actionIndex = 0; actionIndex < stage.actions.length; actionIndex++) {
        final action = stage.actions[actionIndex];
        final actionNumber = actionIndex + 1;
        if (action.text.trim().isEmpty) {
          problems.add('Stage $number action $actionNumber has no action text.');
        }
        if (action.expectedResult.trim().isEmpty) {
          problems.add('Stage $number action $actionNumber has no expected result.');
        }
        if (action.minutes <= 0 || action.minutes > 30) {
          problems.add('Stage $number action $actionNumber must fit in 1–30 minutes.');
        }
      }
    }
    return PathStructureAudit(problems);
  }

  PlanningTask _selectCanonicalRoot(List<PlanningTask> roots) {
    if (roots.length == 1) return roots.single;

    // Existing data can contain duplicate active roots. Do not mutate them on
    // read. Pick deterministically so opening Paths is safe and stable, and
    // surface the duplicate through PathCatalogSnapshot for explicit repair.
    final copy = List<PlanningTask>.from(roots)
      ..sort(
        (a, b) => a.planRowIdForBackend
            .toString()
            .compareTo(b.planRowIdForBackend.toString()),
      );
    return copy.first;
  }

  List<PathStageSnapshot> _parseStages(List<Map<String, dynamic>> checklist) {
    final stages = <PathStageSnapshot>[];
    for (var stageIndex = 0; stageIndex < checklist.length; stageIndex++) {
      final rawStage = checklist[stageIndex];
      final title = (rawStage['text'] ?? '').toString().trim();
      if (title.isEmpty) continue;

      final actions = <PathActionSnapshot>[];
      final rawActions = rawStage['actions'];
      if (rawActions is List) {
        for (var actionIndex = 0; actionIndex < rawActions.length; actionIndex++) {
          final raw = rawActions[actionIndex];
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final text = (map['text'] ?? '').toString().trim();
          if (text.isEmpty) continue;
          final rawMinutes = map['minutes'];
          final minutes = rawMinutes is int
              ? rawMinutes
              : int.tryParse(rawMinutes?.toString() ?? '') ?? 0;
          actions.add(
            PathActionSnapshot(
              id: (map['id'] ?? 'action-$stageIndex-$actionIndex').toString(),
              text: text,
              expectedResult: (map['result'] ?? '').toString().trim(),
              minutes: minutes,
              track: (map['track'] ?? 'execution').toString().trim(),
              isDone: map['isDone'] == true,
            ),
          );
        }
      }

      stages.add(
        PathStageSnapshot(
          id: (rawStage['id'] ?? 'stage-$stageIndex').toString(),
          title: title,
          completionCriteria:
              (rawStage['definitionOfDone'] ?? '').toString().trim(),
          isDone: rawStage['isDone'] == true,
          actions: actions,
        ),
      );
    }
    return stages;
  }
}
