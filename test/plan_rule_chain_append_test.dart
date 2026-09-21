import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask _task(
  String id,
  int categoryId,
  int hour,
  int minute, {
  int duration = 30,
  bool explicitEnd = true,
}) {
  final start = DateTime(2026, 9, 21, hour, minute);
  return PlanningTask(
    id: id.hashCode,
    title: id,
    categoryId: categoryId,
    isDone: false,
    dateKey: '2026-09-21',
    order: 0,
    startTime: start,
    endDateTime: explicitEnd
        ? start.add(Duration(minutes: duration))
        : null,
    planRowId: id,
  );
}

void main() {
  test('category-rule creation appends after the latest same-rule plan', () {
    final first = _task('first', 10, 9, 0);
    final later = _task('later', 11, 10, 0);
    final unrelated = _task('unrelated', 20, 11, 0, duration: 60);

    final start = computePlanRuleChainAppendStart(
      anchorStartWall: DateTime(2026, 9, 21, 9, 0),
      sourceCategoryId: 10,
      existingDayPlans: [first, later, unrelated],
      resolveRuleSourceCategoryId: (categoryId) => switch (categoryId) {
        10 || 11 => 10,
        20 => 20,
        _ => null,
      },
      resolveDurationMinutes: (_) => 30,
    );

    expect(start, DateTime(2026, 9, 21, 10, 30));
  });

  test('inherited child category participates in the same rule chain', () {
    final parentPlan = _task('parent', 10, 9, 0);
    final childPlan = _task('child', 11, 9, 30);

    final start = computePlanRuleChainAppendStart(
      anchorStartWall: DateTime(2026, 9, 21, 9, 0),
      sourceCategoryId: 10,
      existingDayPlans: [parentPlan, childPlan],
      resolveRuleSourceCategoryId: (categoryId) =>
          categoryId == 10 || categoryId == 11 ? 10 : null,
      resolveDurationMinutes: (_) => 30,
    );

    expect(start, DateTime(2026, 9, 21, 10, 0));
  });

  test('rule chain keeps its anchor when no matching plan exists', () {
    final unrelated = _task('unrelated', 20, 10, 0);
    final anchor = DateTime(2026, 9, 21, 9, 0);

    final start = computePlanRuleChainAppendStart(
      anchorStartWall: anchor,
      sourceCategoryId: 10,
      existingDayPlans: [unrelated],
      resolveRuleSourceCategoryId: (categoryId) =>
          categoryId == 20 ? 20 : null,
      resolveDurationMinutes: (_) => 30,
    );

    expect(start, anchor);
  });

  test('rule chain resolves duration when an existing plan has no end', () {
    final openEnded = _task(
      'open-ended',
      10,
      10,
      0,
      explicitEnd: false,
    );

    final start = computePlanRuleChainAppendStart(
      anchorStartWall: DateTime(2026, 9, 21, 9, 0),
      sourceCategoryId: 10,
      existingDayPlans: [openEnded],
      resolveRuleSourceCategoryId: (_) => 10,
      resolveDurationMinutes: (_) => 45,
    );

    expect(start, DateTime(2026, 9, 21, 10, 45));
  });
}
