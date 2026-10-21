import 'package:counter/data/ai/viktor_plan_category.dart';
import 'package:counter/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final category = CategoryRule(
    id: 42,
    name: 'Russian Culture Club',
    keywords: {'en': ['RCC']},
  );
  final fallback = CategoryRule(id: 8, name: 'General');

  CategoryRule? match(String title) =>
      category.categoryExactMatchScoreForTitle(title) > 0 ? category : null;
  CategoryRule? fromId(int id) {
    if (id == 42) return category;
    if (id == 8) return fallback;
    return null;
  }

  test('Uses original category keyword matching before default category', () {
    const title = 'RCC Meeting Failover Bar';
    expect(category.categoryExactMatchScoreForTitle(title), greaterThan(0));
    final selected = resolveViktorPlanCategory(
      title: title, identifyCategory: match, categoryById: fromId,
      defaultCategoryId: fallback.id, rootCategories: [fallback, category]);
    expect(selected.id, 42);
  });

  test('Falls back for a title without category keywords', () {
    final selected = resolveViktorPlanCategory(
      title: 'Read a book', identifyCategory: match, categoryById: fromId,
      defaultCategoryId: fallback.id, rootCategories: [fallback, category]);
    expect(selected.id, 8);
  });

  test('Never selects archived or nonexistent matched category', () {
    final archive = CategoryRule(id: 12, name: 'Archived', isArchived: true);
    final selected = resolveViktorPlanCategory(
      title: 'Archived task', identifyCategory: (_) => archive,
      categoryById: (id) => id == 12 ? archive : fromId(id),
      defaultCategoryId: fallback.id, rootCategories: [archive, fallback]);
    expect(selected.id, 8);
  });

  test('Rejects creation if no active category is available', () {
    expect(() => resolveViktorPlanCategory(
      title: 'RCC Meeting Failover Bar',
      identifyCategory: (_) => null, categoryById: (_) => null,
      defaultCategoryId: null, rootCategories: const [],
    ), throwsStateError);
  });
}
