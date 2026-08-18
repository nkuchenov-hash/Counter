import 'package:counter/data/paths/path_repository.dart';

class PathPlannerActionCandidate {
  const PathPlannerActionCandidate({
    required this.pathId,
    required this.revisionId,
    required this.categoryId,
    required this.stageId,
    required this.actionId,
    required this.title,
    required this.expectedResult,
    required this.minutes,
    required this.track,
  });

  final String pathId;
  final String revisionId;
  final int categoryId;
  final String stageId;
  final String actionId;
  final String title;
  final String expectedResult;
  final int minutes;
  final String track;

  /// Stable idempotency tuple for future Planner materialization.
  String get sourceKey => '$pathId:$revisionId:$actionId';
}

class PathPlannerProjection {
  const PathPlannerProjection({
    required this.pathId,
    required this.revisionId,
    required this.version,
    required this.actions,
  });

  final String pathId;
  final String revisionId;
  final int version;
  final List<PathPlannerActionCandidate> actions;
}

/// The only canonical Path → Planner boundary.
///
/// Paths owns goals, stages, actions and immutable revisions. Planner owns dates,
/// ordering, recurrence and plan-row persistence. This bridge only exposes
/// executable actions from the currently active revision; it never mutates a
/// Path and never schedules by itself.
class PathPlannerBridge {
  PathPlannerBridge({PathRepository? paths})
    : _paths = paths ?? PathRepository();

  final PathRepository _paths;

  Future<PathPlannerProjection?> projectActiveActions(String pathId) async {
    final path = await _paths.loadActivePath(pathId);
    if (path == null || path.status != PathStatus.active) return null;
    if (!_paths.audit(path).isValid) return null;

    final actions = <PathPlannerActionCandidate>[];
    for (final stage in path.stages) {
      if (stage.isDone) continue;
      for (final action in stage.actions) {
        if (action.isDone) continue;
        actions.add(
          PathPlannerActionCandidate(
            pathId: path.pathId,
            revisionId: path.revisionId,
            categoryId: path.category.id,
            stageId: stage.id,
            actionId: action.id,
            title: action.text,
            expectedResult: action.expectedResult,
            minutes: action.minutes,
            track: action.track,
          ),
        );
      }
    }

    return PathPlannerProjection(
      pathId: path.pathId,
      revisionId: path.revisionId,
      version: path.version,
      actions: List<PathPlannerActionCandidate>.unmodifiable(actions),
    );
  }
}
