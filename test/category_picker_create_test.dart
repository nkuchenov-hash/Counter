import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/features/categories/create_category_from_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _node(
  int id,
  String name, {
  String? backendRowId,
  List<CategoryRule>? children,
}) {
  return CategoryRule(
    id: id,
    name: name,
    backendRowId: backendRowId ?? 'pb$id',
    children: children,
  );
}

void main() {
  tearDown(() {
    categoryPickerAddNestedCategoryOverride = null;
    categoryCreateFromPickerAllowedOverride = null;
  });

  setUp(() {
    categoryCreateFromPickerAllowedOverride = () => true;
  });

  group('filterCategoryRootsForPickerSearch', () {
    final roots = [
      _node(1, 'Work', children: [
        _node(2, 'Meetings'),
        _node(3, 'Deep Work'),
      ]),
      _node(4, 'Health'),
    ];

    test('empty query returns all roots', () {
      final out = filterCategoryRootsForPickerSearch(
        roots,
        '',
        (r) => r.name,
      );
      expect(out.length, 2);
    });

    test('no match returns empty list', () {
      final out = filterCategoryRootsForPickerSearch(
        roots,
        'missing',
        (r) => r.name,
      );
      expect(out, isEmpty);
    });
  });

  group('category picker create chrome', () {
    test('row add shows when picker chrome enabled', () {
      expect(
        categoryTreeNodeShowsPickerAddChild(
          showPickerCreateChrome: true,
          onPickerAddChild: (_) {},
        ),
        isTrue,
      );
    });

    test('row add hidden when picker chrome disabled', () {
      expect(
        categoryTreeNodeShowsPickerAddChild(
          showPickerCreateChrome: false,
          onPickerAddChild: (_) {},
        ),
        isFalse,
      );
    });

    test('row target uses exact row category id', () {
      final priceReporter = _node(100, 'Price Reporter');
      final work = _node(1, 'Work');

      final prTarget = categoryPickerCreateTargetForRow(priceReporter);
      final workTarget = categoryPickerCreateTargetForRow(work);

      expect(prTarget.parentLocalId, 100);
      expect(prTarget.parentDisplayName, 'Price Reporter');
      expect(workTarget.parentLocalId, 1);
      expect(workTarget.parentDisplayName, 'Work');
    });

    test('folder add label includes parent name', () {
      expect(
        categoryPickerAddInsideLabel('en', 'Price Reporter'),
        contains('Price Reporter'),
      );
    });
  });

  group('createCategoryFromPickerSubmit parent contract', () {
    test('row plus on Price Reporter records parent 100 not Work 1', () async {
      int? recordedParentId;
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        recordedParentId = parentId;
        return true;
      };

      final target = CategoryPickerCreateTarget.child(
        parentLocalId: 100,
        parentDisplayName: 'Price Reporter',
      );

      await createCategoryFromPickerSubmit(
        name: 'New Client',
        target: target,
      );

      expect(recordedParentId, 100);
      expect(recordedParentId, isNot(1));
    });

    test('row plus on Work records parent 1', () async {
      int? recordedParentId;
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        recordedParentId = parentId;
        return true;
      };

      await createCategoryFromPickerSubmit(
        name: 'New Bucket',
        target: CategoryPickerCreateTarget.child(
          parentLocalId: 1,
          parentDisplayName: 'Work',
        ),
      );

      expect(recordedParentId, 1);
    });

    test('root add row records null parent', () async {
      int? recordedParentId;
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        recordedParentId = parentId;
        return true;
      };

      await createCategoryFromPickerSubmit(
        name: 'Top Level',
        target: const CategoryPickerCreateTarget.root(),
      );

      expect(recordedParentId, isNull);
    });

    test('folder-scoped target for Price Reporter matches row plus', () async {
      int? recordedParentId;
      categoryPickerAddNestedCategoryOverride = (parentId, child) async {
        recordedParentId = parentId;
        return true;
      };

      final priceReporter = _node(100, 'Price Reporter');
      await createCategoryFromPickerSubmit(
        name: 'Folder Scoped',
        target: categoryPickerCreateTargetForRow(priceReporter),
      );

      expect(recordedParentId, 100);
    });
  });

  group('categoryPickerCreateTarget dialog titles', () {
    test('root title is localized root string', () {
      expect(
        categoryPickerCreateDialogTitle(
          'en',
          const CategoryPickerCreateTarget.root(),
        ),
        isNotEmpty,
      );
    });

    test('child title includes parent name', () {
      final title = categoryPickerCreateDialogTitle(
        'en',
        const CategoryPickerCreateTarget.child(
          parentLocalId: 100,
          parentDisplayName: 'Price Reporter',
        ),
      );
      expect(title, contains('Price Reporter'));
    });
  });

  testWidgets('picker create list tile is tappable when enabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: categoryPickerCreateListTile(
            key: categoryPickerTopAddKey,
            label: 'Add root category',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Add root category'), findsOneWidget);
    await tester.tap(find.text('Add root category'));
    expect(tapped, isTrue);
  });

  testWidgets('top and bottom root add keys are distinct', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              categoryPickerCreateListTile(
                key: categoryPickerTopAddKey,
                label: 'Top',
                onTap: () {},
              ),
              categoryPickerCreateListTile(
                key: categoryPickerBottomAddKey,
                label: 'Bottom',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(categoryPickerTopAddKey), findsOneWidget);
    expect(find.byKey(categoryPickerBottomAddKey), findsOneWidget);
  });
}
