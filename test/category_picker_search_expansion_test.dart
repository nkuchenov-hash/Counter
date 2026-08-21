import 'package:counter/data/models.dart';
import 'package:counter/shared/categories/tree/category_tree_body.dart';
import 'package:counter/shared/categories/tree/category_tree_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CategoryRule _node(
  int id,
  String name, {
  List<CategoryRule>? children,
}) {
  return CategoryRule(
    id: id,
    name: name,
    backendRowId: 'pb$id',
    children: children,
  );
}

void main() {
  testWidgets('picker search reveals the exact deeply nested match',
      (tester) async {
    const query = 'Target Category';
    final roots = <CategoryRule>[
      _node(
        1,
        'Parent Folder',
        children: <CategoryRule>[
          _node(
            2,
            'Nested Folder',
            children: <CategoryRule>[
              _node(3, 'Target Category'),
            ],
          ),
        ],
      ),
    ];
    final filtered = filterCategoryRootsForPickerSearch(
      roots,
      query,
      (rule) => rule.name,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryTreeBody(
            roots: filtered,
            selectedCategoryId: null,
            expandSelectionPath: false,
            expandAll: categoryPickerSearchExpandsFilteredTree(query),
            onSelect: (_) {},
            showEditChrome: false,
          ),
        ),
      ),
    );

    expect(find.text('Parent Folder'), findsOneWidget);
    expect(find.text('Nested Folder'), findsOneWidget);
    expect(find.text('Target Category'), findsOneWidget);
  });

  test('blank picker search does not force tree expansion', () {
    expect(categoryPickerSearchExpandsFilteredTree(''), isFalse);
    expect(categoryPickerSearchExpandsFilteredTree('   '), isFalse);
    expect(categoryPickerSearchExpandsFilteredTree('target'), isTrue);
  });
}
