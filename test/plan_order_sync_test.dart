import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningTask _task({
  required String id,
  required int order,
  String? pocketRecordId,
}) {
  return PlanningTask(
    id: id.hashCode.abs(),
    title: 'Task $id',
    categoryId: 1,
    isDone: false,
    dateKey: '2026-07-21',
    order: order,
    startTime: DateTime(2026, 7, 21, 10 + order),
    endDateTime: DateTime(2026, 7, 21, 10 + order, 30),
    planRowId: id,
    pocketRecordId: pocketRecordId ?? id.padRight(15, '0').substring(0, 15),
  );
}

void main() {
  final db = DatabaseService.instance;

  tearDown(() {
    db.debugResetPlanOrderSyncForTest();
    db.debugResetRecordBrainTestHarness();
  });

  group('PlanOrderSyncExtension', () {
    test('first baseline stays; latest pending list replaces previous', () async {
      db.debugActivateRecordBrainTestHarness(
        userId: 'planorderuser01',
        categories: const [],
      );

      final a = _task(id: 'aaaaaaaaaaaaaaa', order: 0);
      final b = _task(id: 'bbbbbbbbbbbbbbb', order: 1);
      final baseline = [a, b];
      final firstOrdered = [
        a.copyWith(order: 1),
        b.copyWith(order: 0),
      ];
      final secondOrdered = [
        b.copyWith(order: 0),
        a.copyWith(order: 1),
      ];

      await db.persistPlanningTaskOrder(
        firstOrdered,
        baselineBeforeReorder: baseline,
      );
      expect(
        db.debugPlanReorderBaselineForTest(),
        {'aaaaaaaaaaaaaaa': 0, 'bbbbbbbbbbbbbbb': 1},
      );
      expect(
        db.debugPendingPlanOrderIdsForTest(),
        ['aaaaaaaaaaaaaaa', 'bbbbbbbbbbbbbbb'],
      );

      // Second drag in same session: new pending list, baseline must not reseeds.
      await db.persistPlanningTaskOrder(
        secondOrdered,
        baselineBeforeReorder: [
          a.copyWith(order: 99),
          b.copyWith(order: 98),
        ],
      );
      expect(
        db.debugPlanReorderBaselineForTest(),
        {'aaaaaaaaaaaaaaa': 0, 'bbbbbbbbbbbbbbb': 1},
      );
      expect(
        db.debugPendingPlanOrderIdsForTest(),
        ['bbbbbbbbbbbbbbb', 'aaaaaaaaaaaaaaa'],
      );
    });
  });
}
