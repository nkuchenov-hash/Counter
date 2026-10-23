import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/settings/categories/category_list_view.dart';
import 'package:counter/features/settings/categories/category_row_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final db = DatabaseService.instance;

  tearDown(() {
    db.debugResetRecordBrainTestHarness();
  });

  group('stationary category drop geometry', () {
    test('top / center / bottom are unambiguous and do not depend on list insertion', () {
      expect(categoryDropPositionFor(0, 60), CategoryDropPosition.before);
      expect(categoryDropPositionFor(10, 60), CategoryDropPosition.before);
      expect(categoryDropPositionFor(30, 60), CategoryDropPosition.inside);
      expect(categoryDropPositionFor(50, 60), CategoryDropPosition.after);
      expect(categoryDropPositionFor(60, 60), CategoryDropPosition.after);
    });

    testWidgets('category nesting target stays in place while dragging', (
      tester,
    ) async {
      final parent = CategoryRule(id: 110, name: 'Fixed target');
      final moving = CategoryRule(id: 120, name: 'Moving category');
      db.debugActivateRecordBrainTestHarness(
        userId: 'categorydrag03',
        categories: [parent, moving],
      );
      await tester.pumpWidget(MaterialApp(
        home: CategoriesPage(
          rules: [parent, moving],
          onChanged: () async {},
        ),
      ));

      const targetKey = ValueKey('category-drop-target-110');
      const sourceKey = ValueKey('category-drag-source-120');
      final target = find.byKey(targetKey);
      final source = find.byKey(sourceKey);
      final initialTarget = tester.getTopLeft(target);
      final initialSource = tester.getTopLeft(source);
      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump(const Duration(milliseconds: 350));
      // Ensure Flutter actually recognized the long press before we move.
      expect(
        find.descendant(
          of: source,
          matching: find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity < 0.5,
          ),
        ),
        findsOneWidget,
      );
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.byIcon(Icons.subdirectory_arrow_right_rounded),
          findsOneWidget);
      // Hover previews must not move either real row. Only the dragged
      // floating feedback moves.
      expect(tester.getTopLeft(target), initialTarget);
      expect(tester.getTopLeft(source), initialSource);
      expect(find.byKey(const ValueKey('category-stationary-tree')),
          findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(db.getParentId(120), 110);
    });
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

    testWidgets('category band selects and opens the editor on long press', (
      tester,
    ) async {
      final a = CategoryRule(id: 1, name: 'A');
      final b = CategoryRule(id: 2, name: 'B');
      int? selectedId;
      CategoryRule? edited;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              child: StatefulBuilder(
                builder: (context, setState) => CategoryRowWidget(
                  items: [a, b],
                  depth: 0,
                  immediateParentId: null,
                  selectedId: selectedId,
                  onSelect: (id) => setState(() => selectedId = id),
                  onLongPressOpenEditor: (rule) => edited = rule,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('A'));
      await tester.pump();
      expect(selectedId, 1);

      await tester.tap(find.text('A'));
      await tester.pump();
      expect(selectedId, isNull);

      await tester.longPress(find.text('B'));
      await tester.pump();
      expect(edited?.id, 2);
    });

    testWidgets('drilling into child categories preserves the hierarchy', (
      tester,
    ) async {
      final parent = CategoryRule(
        id: 10,
        name: 'Parent',
        children: [CategoryRule(id: 11, name: 'Child')],
      );
      db.debugActivateRecordBrainTestHarness(
        userId: 'categorydrag02',
        categories: [parent],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CategoriesPage(
            rules: [parent],
            onChanged: () async {},
          ),
        ),
      );

      await tester.tap(find.text('Parent'));
      await tester.pump();
      expect(find.text('Child'), findsOneWidget);

      await tester.tap(find.text('Child'));
      await tester.pump();
      expect(db.getParentId(10), isNull);
      expect(db.getParentId(11), 10);
      expect(db.getChildrenOf(null).map((r) => r.id), contains(10));
      expect(db.getChildrenOf(10).map((r) => r.id), contains(11));
    });
  });
}
