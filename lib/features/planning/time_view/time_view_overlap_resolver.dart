import 'dart:math' as math;

import 'package:counter/data/plan_time_sequential_cascade.dart';

/// Resolves list-like Time View reordering from actual card overlap.
///
/// A target becomes active as soon as the dragged card overlaps it by at least
/// [minimumOverlapPx]. Moving down inserts after the deepest crossed card;
/// moving up inserts before the highest crossed card.
TimeViewDropIntent? resolveTimeViewOnePixelOverlapIntent({
  required double draggedTopPx,
  required double draggedHeightPx,
  required double verticalDeltaPx,
  required List<TimeViewCardLayout> scheduledCardLayouts,
  required String draggedPlanId,
  double minimumOverlapPx = 1.0,
}) {
  if (verticalDeltaPx == 0 || draggedHeightPx <= 0) return null;

  final draggedBottomPx = draggedTopPx + draggedHeightPx;
  final candidates = <TimeViewCardLayout>[];

  for (final layout in scheduledCardLayouts) {
    if (layout.planId == draggedPlanId) continue;
    final overlapPx = math.min(draggedBottomPx, layout.bottomPx) -
        math.max(draggedTopPx, layout.topPx);
    if (overlapPx >= minimumOverlapPx) candidates.add(layout);
  }

  if (candidates.isEmpty) return null;

  if (verticalDeltaPx > 0) {
    candidates.sort((a, b) => a.topPx.compareTo(b.topPx));
    return TimeViewDropIntent.targetCardAfter(candidates.last.planId);
  }

  candidates.sort((a, b) => a.bottomPx.compareTo(b.bottomPx));
  return TimeViewDropIntent.targetCardBefore(candidates.first.planId);
}
