import 'dart:io';

import 'package:counter/core/category_icon_system.dart';
import 'package:counter/core/category_icon_catalog_generated.g.dart';
import 'package:counter/features/settings/categories/category_icon_picker.dart';
import 'package:counter/features/settings/categories/category_icon_collection_preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heroicons/heroicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only matched semantic IDs are selectable in both families', () {
    final keys = kMatchedCategoryIcons.keys.toSet();
    expect(keys.length, 103);
    expect(CategoryIconStore.catalogFor(CategoryIconPack.fluent)
        .map((e) => e.key).toSet(), keys);
    expect(CategoryIconStore.catalogFor(CategoryIconPack.heroicons)
        .map((e) => e.key).toSet(), keys);
    expect(keys, containsAll(['home', 'cart', 'cake', 'moon', 'bell', 'book']));
    expect(CategoryIconStore.isValidKey('home'), isTrue);
    expect(CategoryIconStore.isValidKey('academic_cap'), isTrue);
    expect(CategoryIconStore.isValidKey('shopping_cart'), isFalse,
        reason: 'Heroicons-specific names must not leak into saved semantic IDs.');
    expect(CategoryIconStore.isValidKey('unmatched_fluent_icon'), isFalse);
    expect(kMatchedCategoryIcons['cart']!.hero, HeroIcons.shoppingCart);
    expect(kMatchedCategoryIcons['moon']!.hero, HeroIcons.moon);
    expect(kMatchedCategoryIcons['book']!.hero, HeroIcons.bookOpen);
    expect(kMatchedCategoryIcons['lock']!.hero, HeroIcons.lockClosed);
    expect(kMatchedCategoryIcons['home']!.hero, HeroIcons.home);
    for (final entry in kMatchedCategoryIcons.entries) {
      expect(entry.value.fluentOutline, isNot(entry.value.fluentFilled),
          reason: '${entry.key} must have a real Regular/Fill pair');
      expect(CategoryIconStore.isValidKey(entry.key), isTrue);
    }
  });

  test('quick defaults are smaller than the available semantic catalog', () {
    expect(kDefaultCategoryIconKeys, hasLength(26));
    expect(kDefaultCategoryIconKeys.toSet().length, 26);
    expect(kDefaultCategoryIconKeys.every(CategoryIconStore.isValidKey), isTrue);
    expect(kDefaultCategoryIconKeys, containsAll(['home', 'folder', 'heart']));
  });

  test('category manager and Notes use the same semantic renderer', () {
    final manager =
        File('lib/features/settings/categories/category_list_view.dart')
            .readAsStringSync();
    final notes =
        File('lib/features/notes/widgets/notes_library_production_shell.dart')
            .readAsStringSync();
    final folderTabs =
        File('lib/features/notes/widgets/notes_folder_pane.dart')
            .readAsStringSync();
    expect(manager, contains('CategoryGlyph(category: r,'));
    expect(manager, isNot(contains('Icon(categoryManagerIconFor(r)')));
    expect(notes, contains('category: rule,'));
    expect(notes, isNot(contains('IconData(rule.iconCodePoint!')));
    expect(folderTabs, contains('CategoryGlyph('));
  });

  testWidgets('picker offers quick collection and keeps Outline/Fill on choice',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = CategoryIconStore.instance;
    await store.ensureLoaded();
    await store.setQuickKeys(kDefaultCategoryIconKeys);
    CategoryIconSelection? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          picked = await showCategoryIconPicker(context,
            initial: const CategoryIconSelection('heart'));
        },
        child: const Text('OPEN PICKER'),
      ))),
    ));
    await tester.tap(find.text('OPEN PICKER'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-icon-style-toggle')),
        findsOneWidget);
    final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('category-paired-icon-grid')));
    expect((grid.childrenDelegate as SliverChildBuilderDelegate).childCount, 26);
    expect(find.textContaining('My collection'), findsOneWidget);
    await tester.tap(find.text('Fill').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-icon-apply')));
    await tester.pumpAndSettle();
    expect(picked, const CategoryIconSelection('heart', filled: true));
  });

  testWidgets('Appearance can add icons without changing shared identities',
      (tester) async {
    final store = CategoryIconStore.instance;
    await store.ensureLoaded();
    await store.setQuickKeys(kDefaultCategoryIconKeys);
    expect(store.quickKeys.contains('academic_cap'), isFalse);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child:
        CategoryIconCollectionPreference(isRussian: false))),
    ));
    await tester.tap(find.byKey(const ValueKey('manage-category-icons')));
    await tester.pumpAndSettle();
    final search = find.byType(TextField);
    await tester.enterText(search, 'academic cap');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('custom-icon-academic_cap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-icon-collection')));
    await tester.pumpAndSettle();
    expect(store.quickKeys, contains('academic_cap'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('takto.category.icon_quick_collection.v1'),
        contains('academic_cap'));
    await store.setPack(CategoryIconPack.heroicons);
    expect(store.quickKeys, contains('academic_cap'),
        reason: 'Pack switching must preserve the same selected semantic IDs.');
    await store.setPack(CategoryIconPack.fluent);
    await store.setQuickKeys(kDefaultCategoryIconKeys);
  });
}
