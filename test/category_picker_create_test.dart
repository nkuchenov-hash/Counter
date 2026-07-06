import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
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
}
