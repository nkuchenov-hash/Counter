import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile timezone full-plan reprojection is deduplicated', () {
    final source = File(
      'lib/data/plans/plan_projection_types.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('String? _lastAppliedProfileTimezoneProjectionSignature;'),
    );
    expect(
      source,
      contains(
        'if (_lastAppliedProfileTimezoneProjectionSignature == signature) return;',
      ),
    );
    expect(
      source,
      contains('_lastAppliedProfileTimezoneProjectionSignature = signature;'),
    );
  });

  test('Time View bulk drag includes only normally movable selected rows', () {
    final source = File(
      'lib/features/planning/time_view/time_view_drag_controller.dart',
    ).readAsStringSync();

    expect(source, contains('.where(planIsTimelineScheduledDraggable)'));
    expect(
      source,
      isNot(contains('.where((t) => t.startTime != null)\n          .toList();')),
    );
  });

  test('category default schedule save stays on targeted PocketBase hot path', () {
    final source = File(
      'lib/data/categories/category_default_time.dart',
    ).readAsStringSync();

    expect(source, contains('_patchCategoryDefaultPlanScheduleFields'));
    expect(
      source,
      isNot(contains('await patchCategoryDelta(categoryId')),
    );
  });
}
