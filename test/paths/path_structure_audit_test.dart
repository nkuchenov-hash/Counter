import 'package:counter/data/paths/path_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PathActionSnapshot action({
    String text = 'Do the experiment',
    String result = 'Measured result',
    int minutes = 20,
  }) {
    return PathActionSnapshot(
      id: 'action-1',
      text: text,
      expectedResult: result,
      minutes: minutes,
      track: 'execution',
      isDone: false,
    );
  }

  PathStageSnapshot stage({
    String title = 'Validate the approach',
    String doneWhen = 'Evidence is recorded',
    List<PathActionSnapshot>? actions,
  }) {
    return PathStageSnapshot(
      id: 'stage-1',
      title: title,
      completionCriteria: doneWhen,
      isDone: false,
      actions: actions ?? <PathActionSnapshot>[action()],
    );
  }

  test('rejects an empty Path', () {
    final audit = auditPathStructure(
      goal: '   ',
      stages: const <PathStageSnapshot>[],
    );

    expect(audit.isValid, isFalse);
    expect(audit.problems, contains('Path goal is empty.'));
    expect(audit.problems, contains('Path has no stages.'));
  });

  test('accepts an executable Path stage and action', () {
    final audit = auditPathStructure(
      goal: 'Prove the first usable prototype',
      stages: <PathStageSnapshot>[stage()],
    );

    expect(audit.isValid, isTrue);
    expect(audit.problems, isEmpty);
  });

  test('rejects actions longer than the 30 minute Path action contract', () {
    final audit = auditPathStructure(
      goal: 'Prove the first usable prototype',
      stages: <PathStageSnapshot>[
        stage(actions: <PathActionSnapshot>[action(minutes: 45)]),
      ],
    );

    expect(audit.isValid, isFalse);
    expect(
      audit.problems,
      contains('Stage 1 action 1 must fit in 1–30 minutes.'),
    );
  });
}
