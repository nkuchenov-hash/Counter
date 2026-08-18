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
  }) =>
      PathStageSnapshot(
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
      for (var actionIndex = 0;
          actionIndex < rawActions.length;
          actionIndex++) {
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
  }) =>
      ProjectPathSnapshot(
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
    for (var actionIndex = 0; actionIndex < stage.actions.length; actionIndex++) {
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
