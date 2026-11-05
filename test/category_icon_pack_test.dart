import 'dart:io';

import 'package:counter/core/category_icon_system.dart';
import 'package:counter/core/category_icon_catalog_generated.g.dart';
import 'package:counter/features/settings/categories/category_icon_collection_preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('human category subjects are curated independently of UI icons', () {
    final keys = kMatchedCategoryIcons.keys.toSet();
    expect(keys.length, greaterThan(200));
    final selectable = keys.where(isSelectableCategoryIconKey).toSet();
    expect(CategoryIconStore.catalogFor().map((e) => e.key).toSet(),
        selectable);
    expect(selectable, containsAll([
      'person', 'dog', 'cat', 'tree', 'bicycle', 'car', 'taxi', 'bed',
      'couch', 'washer', 'dishwasher', 'tv', 'dumbbell', 'soccer',
      'clothes_hanger', 'chair', 'fridge', 'microwave', 'book_open',
    ]));
    expect(selectable, isNot(contains('arrow_down')));
    expect(selectable, isNot(contains('chevron_left')));
    expect(selectable, isNot(contains('plus')));
    expect(selectable, isNot(contains('currency_euro')));
    for (final entry in kMatchedCategoryIcons.entries) {
      expect(entry.value.fluentOutline, isNot(entry.value.fluentFilled),
          reason: '${entry.key} must have separate Outline/Fill styles');
      expect(CategoryIconStore.isValidKey(entry.key), isTrue);
    }
  });

  test('default category library excludes navigation controls', () {
    final keys = kMatchedCategoryIcons.keys.where(isSelectableCategoryIconKey);
    expect(kDefaultCategoryIconKeys.toSet(), keys.toSet());
    expect(kDefaultCategoryIconKeys.every(CategoryIconStore.isValidKey), isTrue);
    expect(kDefaultCategoryIconKeys, containsAll(
        ['home', 'folder', 'heart', 'banknotes', 'film']));
    expect(kDefaultCategoryIconKeys, isNot(contains('arrow_left')));
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

  test('picker prioritizes real-life subjects and preserves Outline/Fill', () {
    final picker = File(
      'lib/features/settings/categories/category_icon_picker.dart',
    ).readAsStringSync();
    expect(picker, contains('store.quickCatalog'));
    expect(picker, contains('final essentials = approved.take(47)'));
    expect(picker, contains('Tooltip('));
    expect(picker, contains('maxCrossAxisExtent: 58'));
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
      await store.setQuickKeys(['home', 'tree', 'dog']);
      expect(store.quickKeys, ['home', 'tree', 'dog']);
      await store.setQuickKeys(['home', 'tree', 'dog', 'taxi']);
      expect(store.quickKeys, contains('taxi'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('takto.category.icon_quick_collection.v1'),
          contains('taxi'));
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

  testWidgets('Settings respects custom icon favorites and offers other icons',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await CategoryIconStore.instance.ensureLoaded();
      await CategoryIconStore.instance.setQuickKeys(['home', 'folder', 'heart']);
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
        3);
    expect(find.textContaining('in my collection'), findsOneWidget);
    expect(find.byKey(const ValueKey('toggle-icon-catalog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-icon-catalog')));
    await tester.pumpAndSettle();
    final availableGrid = tester.widget<GridView>(grid);
    expect((availableGrid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        CategoryIconStore.catalogFor().length - 3);
    expect(find.textContaining('category icons available'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-icon-catalog')));
    await tester.pumpAndSettle();
    final restoredGrid = tester.widget<GridView>(grid);
    expect((restoredGrid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        3);
  });

  test('human-first catalog covers everyday life and keeps legacy art', () {
    expect(kHumanCategorySubjects.length, greaterThanOrEqualTo(110));
    expect(kDefaultCategoryIconKeys.take(5),
        ['person', 'family', 'friends', 'coworkers', 'walking']);
    expect(kDefaultCategoryIconKeys.indexOf('dog'),
        lessThan(kDefaultCategoryIconKeys.indexOf('wallet')));
    expect(isSelectableCategoryIconKey('arrow_left'), isFalse);
    expect(CategoryIconStore.isValidKey('arrow_left'), isTrue,
        reason: 'Previously saved controls must remain renderable.');
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
    expect(CategoryIconStore.canonicalKey('book_open'), 'book_open');
    expect(CategoryIconStore.canonicalKey('unmapped_icon'), isNull);
    // Unsupported old choices are not discarded from local storage.
    expect(CategoryIconSelection.fromJson({'key': 'unmapped_icon'})?.key,
        'unmapped_icon');
  });
}
