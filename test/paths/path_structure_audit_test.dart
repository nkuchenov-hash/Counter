import 'package:counter/data/models.dart';
import 'package:counter/data/paths/path_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PathActionSnapshot action({
    String text = 'Do the experiment',
    String result = 'Measured result',
    int minutes = 20,
  }) => PathActionSnapshot(
    id: 'action-1',
    text: text,
    expectedResult: result,
    minutes: minutes,
    track: 'execution',
    isDone: false,
  );

  PathStageSnapshot stage({
    String title = 'Validate the approach',
    String doneWhen = 'Evidence is recorded',
    List<PathActionSnapshot>? actions,
  }) => PathStageSnapshot(
    id: 'stage-1',
    title: title,
    completionCriteria: doneWhen,
    isDone: false,
    actions: actions ?? <PathActionSnapshot>[action()],
  );

  CategoryRule category(
    int id,
    String name, {
    required String backendId,
    int order = 0,
    List<CategoryRule>? children,
  }) => CategoryRule(
    id: id,
    name: name,
    backendRowId: backendId,
    normalizedId: name.toLowerCase().replaceAll(' ', '-'),
    order: order,
    children: children ?? <CategoryRule>[],
  );

  ProjectPathSnapshot path(String id, CategoryRule category, {String? goal}) =>
      ProjectPathSnapshot(
        pathRecordId: 'record-$id',
        pathId: id,
        revisionRecordId: 'revision-record-$id',
        revisionId: 'revision-$id',
        category: category,
        goal: goal ?? 'Goal $id',
        status: PathStatus.active,
        version: 1,
        stages: <PathStageSnapshot>[stage()],
      );

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

  test('Path category projection preserves the canonical hierarchy', () {
    final laredo = category(4, 'Laredo', backendId: 'cat-laredo');
    final priceReporter = category(
      3,
      'Price Reporter',
      backendId: 'cat-price',
      children: <CategoryRule>[laredo],
    );
    final atozed = category(2, 'Atozed', backendId: 'cat-atozed');
    final work = category(
      1,
      'Work',
      backendId: 'cat-work',
      children: <CategoryRule>[atozed, priceReporter],
    );
    final personal = category(5, 'Personal', backendId: 'cat-personal');
    final pricePath = path('price', priceReporter);
    final laredoPath = path('laredo', laredo);
    final personalPath = path('personal', personal);

    final projection = buildPathCategoryProjection(
      categoryRoots: <CategoryRule>[work, personal],
      paths: <ProjectPathSnapshot>[pricePath, laredoPath, personalPath],
      selectedRootKeys: null,
    );

    expect(projection.roots.map((node) => node.category.name), <String>[
      'Work',
      'Personal',
    ]);
    final workNode = projection.roots.first;
    expect(workNode.children.map((node) => node.category.name), <String>[
      'Price Reporter',
    ]);
    expect(workNode.children.single.paths.single.pathId, 'price');
    expect(workNode.children.single.children.single.category.name, 'Laredo');
    expect(
      projection.visiblePaths.map((item) => item.pathId).toList(),
      <String>['price', 'laredo', 'personal'],
    );
  });

  test('selecting a parent category includes its complete Path subtree', () {
    final leaf = category(3, 'Client', backendId: 'cat-client');
    final work = category(
      1,
      'Work',
      backendId: 'cat-work',
      children: <CategoryRule>[leaf],
    );
    final personal = category(2, 'Personal', backendId: 'cat-personal');
    final projection = buildPathCategoryProjection(
      categoryRoots: <CategoryRule>[work, personal],
      paths: <ProjectPathSnapshot>[path('client', leaf), path('personal', personal)],
      selectedRootKeys: <String>{'cat-work'},
    );

    expect(projection.roots.length, 1);
    expect(projection.roots.single.category.name, 'Work');
    expect(projection.visiblePaths.single.pathId, 'client');
  });

  test('redundant selected descendants normalize to the selected ancestor', () {
    final leaf = category(3, 'Client', backendId: 'cat-client');
    final group = category(
      2,
      'Price Reporter',
      backendId: 'cat-price',
      children: <CategoryRule>[leaf],
    );
    final work = category(
      1,
      'Work',
      backendId: 'cat-work',
      children: <CategoryRule>[group],
    );

    expect(
      normalizePathCategoryRootKeys(
        categoryRoots: <CategoryRule>[work],
        selectedKeys: <String>{'cat-work', 'cat-price', 'cat-client'},
      ),
      <String>{'cat-work'},
    );
  });

  test('multiple Paths in one category keep independent Path identities', () {
    final project = category(1, 'Project', backendId: 'cat-project');
    final projection = buildPathCategoryProjection(
      categoryRoots: <CategoryRule>[project],
      paths: <ProjectPathSnapshot>[
        path('path-a', project, goal: 'First goal'),
        path('path-b', project, goal: 'Second goal'),
      ],
      selectedRootKeys: null,
    );

    expect(
      projection.visiblePaths.map((item) => item.pathId).toSet(),
      <String>{'path-a', 'path-b'},
    );
    expect(projection.roots.single.paths.length, 2);
  });

  test('Paths detached from the category tree remain visible as uncategorized', () {
    final work = category(1, 'Work', backendId: 'cat-work');
    final detached = category(99, 'Detached', backendId: 'cat-detached');
    final detachedPath = path('detached', detached);
    final projection = buildPathCategoryProjection(
      categoryRoots: <CategoryRule>[work],
      paths: <ProjectPathSnapshot>[detachedPath],
      selectedRootKeys: null,
    );

    expect(projection.roots, isEmpty);
    expect(projection.uncategorizedPaths.single.pathId, 'detached');
    expect(projection.visiblePaths.single.pathId, 'detached');
  });
}
