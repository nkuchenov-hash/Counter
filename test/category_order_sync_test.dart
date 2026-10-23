import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/settings/categories/category_list_view.dart';
import 'package:counter/features/settings/categories/category_editor_sheet.dart';
import 'package:counter/features/settings/categories/category_row_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[390, 900]) {
    testWidgets('category editor appearance follows approved equal columns at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 780);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final category = CategoryRule(id: 101, name: 'Work');
      db.debugActivateRecordBrainTestHarness(
        userId: 'category-appearance-layout',
        categories: [category],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 780,
            child: CategoryEditorSheet(
              category: category,
              inline: true,
              onSaved: () {},
              onCancel: () {},
            ),
          ),
        ),
      ));
      await tester.pump();

      final appearance = find.byKey(const Key('category_appearance_columns'));
      final leftColumn = find.byKey(const Key('category_color_column'));
      final iconGrid = find.byKey(const Key('category_icon_grid'));
      final moreIcons = find.byKey(const Key('category_more_icons'));
      expect(appearance, findsOneWidget);
      expect(leftColumn, findsOneWidget);
      expect(iconGrid, findsOneWidget);
      expect(moreIcons, findsOneWidget);
      final rowRect = tester.getRect(appearance);
      final colorRect = tester.getRect(leftColumn);
      final iconRect = tester.getRect(iconGrid);
      expect(colorRect.right, lessThan(iconRect.left));
      expect((colorRect.width - iconRect.width).abs(), lessThan(1.5));
      expect(rowRect.height, lessThan(180),
          reason: 'Picker must not leave empty grid space between sections.');
      expect(iconRect.height, closeTo(114, 0.1));
      expect(tester.takeException(), isNull);
    });
  }


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
