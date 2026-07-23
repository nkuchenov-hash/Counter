import 'package:counter/data/plan_time_sequential_cascade.dart';
import 'package:counter/features/planning/time_view/time_view_drop_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = TimeViewCardLayout(
    planId: 'target',
    topPx: 100,
    heightPx: 50,
  );

  test('one pixel overlap while moving down inserts after target', () {
    final intent = resolveTimeViewOnePixelOverlapIntent(
      draggedTopPx: 51,
      draggedHeightPx: 50,
      verticalDeltaPx: 1,
      scheduledCardLayouts: const [target],
      draggedPlanId: 'dragged',
    );

    expect(intent?.kind, TimeViewDropIntentKind.targetCardAfter);
    expect(intent?.targetPlanId, 'target');
  });

  test('one pixel overlap while moving up inserts before target', () {
    final intent = resolveTimeViewOnePixelOverlapIntent(
      draggedTopPx: 149,
      draggedHeightPx: 50,
      verticalDeltaPx: -1,
      scheduledCardLayouts: const [target],
      draggedPlanId: 'dragged',
    );

    expect(intent?.kind, TimeViewDropIntentKind.targetCardBefore);
    expect(intent?.targetPlanId, 'target');
  });

  test('edge contact without overlap does not reorder', () {
    final intent = resolveTimeViewOnePixelOverlapIntent(
      draggedTopPx: 50,
      draggedHeightPx: 50,
      verticalDeltaPx: 1,
      scheduledCardLayouts: const [target],
      draggedPlanId: 'dragged',
    );

    expect(intent, isNull);
  });
}
