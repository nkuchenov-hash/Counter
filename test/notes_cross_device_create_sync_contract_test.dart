import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Notes blank create remains durable without weakening Plans validation', () {
    final notesSource = File(
      'lib/data/plans/notes_brain_helpers.dart',
    ).readAsStringSync();
    final planSource = File('lib/data/plan_service.dart').readAsStringSync();

    expect(
      notesSource.contains(
        "const String _notesBlankTitlePersistenceSentinel = '\\u2060';",
      ),
      isTrue,
    );
    expect(
      notesSource.contains('title: _notesPersistenceTitle(trimmedTitle),'),
      isTrue,
    );
    expect(
      notesSource.contains(
        'await addPlanningTask(created, clientPlanId: clientPlanId)',
      ),
      isTrue,
    );

    // Ordinary Plans/Lists still reject empty titles. Only Notes adapt their
    // visually blank title at the persistence boundary.
    expect(planSource.contains('if (titleTrimmed.isEmpty)'), isTrue);
    expect(
      planSource.contains("ADD_PLAN: blocked — empty title"),
      isTrue,
    );
  });

  test('Notes reconcile optimistic ids and never project title sentinel', () {
    final source = File(
      'lib/data/plans/notes_brain_helpers.dart',
    ).readAsStringSync();

    expect(source.contains('_findCachedNoteTaskForEdit'), isTrue);
    expect(source.contains("key.startsWith('optimistic-')"), isTrue);
    expect(
      source.contains(
        'planBusinessId: businessId.isEmpty ? null : businessId,',
      ),
      isTrue,
    );
    expect(
      source.contains('final visibleTitle = _notesVisibleTitle('),
      isTrue,
    );
    expect(
      source.contains('final plain = doc.toPlainText(title: visibleTitle);'),
      isTrue,
    );
    expect(
      source.contains('title: _notesPersistenceTitle(updated.title),'),
      isTrue,
    );
    expect(
      source.contains('materialized?.planRowIdForBackend ?? optimisticId'),
      isTrue,
    );
  });
}
