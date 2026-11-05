import 'dart:io';

import 'package:counter/core/category_icon_system.dart';
import 'package:counter/core/category_icon_catalog_generated.g.dart';
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

  test('picker uses the quick collection and preserves Outline/Fill', () {
    final picker = File(
      'lib/features/settings/categories/category_icon_picker.dart',
    ).readAsStringSync();
    expect(picker, contains('store.quickCatalog'));
    expect(picker, contains('CategoryIconStore.isValidKey'));
    expect(picker, contains('category-icon-style-toggle'));
    expect(picker, contains('category-icon-apply'));
    expect(picker, isNot(contains('kCompleteFluentCategoryIcons')));
    expect(picker, isNot(contains('kCompleteHeroCategoryIcons')));
  });

  testWidgets('Appearance collection persistence keeps stable semantic IDs',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      final store = CategoryIconStore.instance;
      await store.ensureLoaded();
      await store.setQuickKeys(kDefaultCategoryIconKeys);
      expect(store.quickKeys.contains('academic_cap'), isFalse);
      await store.setQuickKeys([...kDefaultCategoryIconKeys, 'academic_cap']);
      expect(store.quickKeys, contains('academic_cap'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('takto.category.icon_quick_collection.v1'),
          contains('academic_cap'));
      await store.setPack(CategoryIconPack.heroicons);
      expect(store.quickKeys, contains('academic_cap'));
      await store.setPack(CategoryIconPack.fluent);
      await store.setQuickKeys(kDefaultCategoryIconKeys);
    });
  });

  test('Appearance exposes searchable collection controls', () {
    final screen = File(
      'lib/features/settings/categories/category_icon_collection_preference.dart',
    ).readAsStringSync();
    final profile = File('lib/features/profile/profile_view.dart')
        .readAsStringSync();
    expect(profile, contains('CategoryIconCollectionPreference'));
    expect(screen, contains('showCategoryIconCollectionEditor'));
    expect(screen, contains('matched-icon-collection-grid'));
    expect(screen, contains('reset-default-icons'));
    expect(screen, contains('save-icon-collection'));
  });

  testWidgets('Settings initially shows only user icons, never all matched icons',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await CategoryIconStore.instance.ensureLoaded();
      await CategoryIconStore.instance.setQuickKeys(kDefaultCategoryIconKeys);
      await CategoryIconStore.instance.setPack(CategoryIconPack.fluent);
    });
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: CategoryIconCollectionPreference(isRussian: false),
      )),
    ));
    await tester.tap(find.byKey(const ValueKey('manage-category-icons')));
    await tester.pumpAndSettle();
    final grid = find.byKey(const ValueKey('matched-icon-collection-grid'));
    final defaultGrid = tester.widget<GridView>(grid);
    expect((defaultGrid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        kDefaultCategoryIconKeys.length);
    expect(find.textContaining('in my collection'), findsOneWidget);
    expect(find.byKey(const ValueKey('toggle-icon-catalog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-icon-catalog')));
    await tester.pumpAndSettle();
    final availableGrid = tester.widget<GridView>(grid);
    expect((availableGrid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        kMatchedCategoryIcons.length - kDefaultCategoryIconKeys.length);
    expect(find.textContaining('matching icons available'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-icon-catalog')));
    await tester.pumpAndSettle();
    final restoredGrid = tester.widget<GridView>(grid);
    expect((restoredGrid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        kDefaultCategoryIconKeys.length);
  });

  test('published picker exposes actual build and selected icon count', () {
    final picker = File(
      'lib/features/settings/categories/category_icon_picker.dart',
    ).readAsStringSync();
    final collection = File(
      'lib/features/settings/categories/category_icon_collection_preference.dart',
    ).readAsStringSync();
    final html = File('web/index.html').readAsStringSync();
    final deploy = File('.github/workflows/deploy.yml').readAsStringSync();
    expect(picker, contains('icon-picker-build-and-count'));
    expect(picker, contains('AppBuildInfo.gitCommit'));
    expect(collection, contains('AppBuildInfo.gitCommit'));
    expect(html, contains('lifeos-legacy-sw-upgraded'));
    expect(deploy, contains('Retire obsolete Flutter cache-first service worker'));
  });

  test('old family-specific keys map to shared semantics safely', () {
    final migrated = CategoryIconSelection.fromJson(
      {'key': 'shopping_cart', 'filled': true});
    expect(migrated, const CategoryIconSelection('cart', filled: true));
    expect(CategoryIconStore.canonicalKey('food_cake'), 'cake');
    expect(CategoryIconStore.canonicalKey('weather_moon'), 'moon');
    expect(CategoryIconStore.canonicalKey('book_open'), 'book');
    expect(CategoryIconStore.canonicalKey('unmapped_icon'), isNull);
    // Unsupported old choices are not discarded from local storage.
    expect(CategoryIconSelection.fromJson({'key': 'unmapped_icon'})?.key,
        'unmapped_icon');
  });
}
