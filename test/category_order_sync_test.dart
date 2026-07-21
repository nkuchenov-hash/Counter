import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final db = DatabaseService.instance;

  tearDown(() {
    db.debugResetRecordBrainTestHarness();
  });

  group('CategoryOrderSyncExtension', () {
    test('applyLocalCategorySiblingOrder assigns 0..n-1 for root and child siblings', () {
      final a = CategoryRule(id: 1, name: 'A', order: 5);
      final b = CategoryRule(id: 2, name: 'B', order: 3);
      final c = CategoryRule(id: 3, name: 'C', order: 0);
      final parent = CategoryRule(
        id: 10,
        name: 'Parent',
        children: [
          CategoryRule(id: 11, name: 'Child1', order: 2),
          CategoryRule(id: 12, name: 'Child2', order: 0),
        ],
      );
      db.debugActivateRecordBrainTestHarness(
        userId: 'categoryorder01',
        categories: [a, b, c, parent],
      );

      db.applyLocalCategorySiblingOrder(null, [c, a, b, parent]);
      final roots = db.getChildrenOf(null);
      expect(roots.map((r) => r.id).toList(), [3, 1, 2, 10]);
      expect(roots.take(3).map((r) => r.order).toList(), [0, 1, 2]);

      final storedParent = db.getCategoryRuleById(10)!;
      db.applyLocalCategorySiblingOrder(10, [
        storedParent.children![1],
        storedParent.children![0],
      ]);
      final kids = db.getChildrenOf(10);
      expect(kids.map((r) => r.id).toList(), [12, 11]);
      expect(kids.map((r) => r.order).toList(), [0, 1]);
    });
  });
}
