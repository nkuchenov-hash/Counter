import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _node(int id, String name, {List<CategoryRule>? children}) {
  return CategoryRule(
    id: id,
    name: name,
    backendRowId: 'pb$id',
    children: children,
  );
}

void main() {
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

    test('matches root label', () {
      final out = filterCategoryRootsForPickerSearch(
        roots,
        'health',
        (r) => r.name,
      );
      expect(out.length, 1);
      expect(out.first.id, 4);
    });

    test('matches descendant and keeps branch', () {
      final out = filterCategoryRootsForPickerSearch(
        roots,
        'meet',
        (r) => r.name,
      );
      expect(out.length, 1);
      expect(out.first.id, 1);
      expect(out.first.children?.length, 1);
      expect(out.first.children?.first.id, 2);
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

    test('row add key is stable per category id', () {
      expect(categoryPickerRowAddKey(42), categoryPickerRowAddKey(42));
      expect(categoryPickerRowAddKey(42), isNot(categoryPickerRowAddKey(43)));
    });
  });

  testWidgets('picker create list tile is tappable when enabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: categoryPickerCreateListTile(
            key: categoryPickerTopAddKey,
            label: 'Add category',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Add category'), findsOneWidget);
    await tester.tap(find.text('Add category'));
    expect(tapped, isTrue);
  });

  testWidgets('picker bottom add key is distinct from top add key', (tester) async {
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
