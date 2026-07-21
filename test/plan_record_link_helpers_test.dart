import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final db = DatabaseService.instance;

  tearDown(() {
    db.debugResetRecordBrainTestHarness();
  });

  group('PlanRecordLinkExtension', () {
    test('resolveCurrentPlanCategoryForRecordStart prefers cached plan over stale UI', () {
      const planPb = 'planpbrow000001';
      const cachedCat = 202;
      const staleUiCat = 101;
      db.debugActivateRecordBrainTestHarness(
        userId: 'planrecordlink01',
        categories: [
          CategoryRule(id: staleUiCat, name: 'Stale', backendRowId: 'stale0000000001'),
          CategoryRule(id: cachedCat, name: 'Cached', backendRowId: 'cached000000001'),
        ],
      );

      db.applyOptimisticPlanningTask(
        PlanningTask(
          id: 1,
          title: 'Linked plan',
          categoryId: cachedCat,
          isDone: false,
          dateKey: '2026-07-21',
          order: 0,
          startTime: DateTime(2026, 7, 21, 10),
          endDateTime: DateTime(2026, 7, 21, 10, 30),
          planRowId: 'biz-linked-plan-1',
          pocketRecordId: planPb,
        ),
      );

      final resolved = db.resolveCurrentPlanCategoryForRecordStart(
        sourcePlanPocketRecordId: planPb,
        planBusinessId: 'biz-linked-plan-1',
        uiCategoryId: staleUiCat,
      );
      expect(resolved, cachedCat);
    });
  });
}
