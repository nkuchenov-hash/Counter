import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/features/planning/time_view/time_view_drop_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = TimeViewCardLayout(
    planId: 'target',
    topPx: 100,
    heightPx: 50,
  );

  test('edge overlap only clamps next to target without reorder', () {
    final movingDown = resolveTimeViewCollisionAndInsertion(
      draggedTopPx: 51,
      draggedHeightPx: 50,
      verticalDeltaPx: 1,
      scheduledCardLayouts: const [target],
      draggedPlanId: 'dragged',
    );
    final movingUp = resolveTimeViewCollisionAndInsertion(
      draggedTopPx: 149,
      draggedHeightPx: 50,
      verticalDeltaPx: -1,
      scheduledCardLayouts: const [target],
      draggedPlanId: 'dragged',
    );

    expect(movingDown.resolvedTopPx, 50);
    expect(movingDown.insertionIntent, isNull);
    expect(movingDown.contactPlanId, 'target');
    expect(movingUp.resolvedTopPx, 150);
    expect(movingUp.insertionIntent, isNull);
    expect(movingUp.contactPlanId, 'target');
  });

  test('crossing target center creates directional reorder intent', () {
    final movingDown = resolveTimeViewCollisionAndInsertion(
      draggedTopPx: 100,
      draggedHeightPx: 50,
      verticalDeltaPx: 50,
      scheduledCardLayouts: const [target],
      draggedPlanId: 'dragged',
    );
    final movingUp = resolveTimeViewCollisionAndInsertion(
      draggedTopPx: 100,
      draggedHeightPx: 50,
      verticalDeltaPx: -50,
      scheduledCardLayouts: const [target],
      draggedPlanId: 'dragged',
    );

    expect(
      movingDown.insertionIntent?.kind,
      TimeViewDropIntentKind.targetCardAfter,
    );
    expect(
      movingUp.insertionIntent?.kind,
      TimeViewDropIntentKind.targetCardBefore,
    );
  });

  test('exact edge contact keeps raw position and has no contact target', () {
    final resolution = resolveTimeViewCollisionAndInsertion(
      draggedTopPx: 50,
      draggedHeightPx: 50,
      verticalDeltaPx: 1,
      scheduledCardLayouts: const [target],
      draggedPlanId: 'dragged',
    );

    expect(resolution.resolvedTopPx, 50);
    expect(resolution.insertionIntent, isNull);
    expect(resolution.contactPlanId, isNull);
  });
}
