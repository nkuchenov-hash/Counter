import 'dart:io';

import 'package:counter/core/category_icon_system.dart';
import 'package:counter/core/category_icon_catalog_generated.g.dart';
import 'package:counter/core/fluent_full_catalog_generated.g.dart';
import 'package:counter/features/settings/categories/category_icon_collection_preference.dart';
import 'package:counter/features/settings/categories/category_icon_picker.dart';
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

  test('starter collection is small and focused on everyday subjects', () {
    expect(kDefaultCategoryIconKeys.length, inInclusiveRange(25, 50));
    expect(kDefaultCategoryIconKeys.every(CategoryIconStore.isValidKey), isTrue);
    expect(kDefaultCategoryIconKeys, containsAll([
      'dog', 'cat', 'tree', 'car', 'taxi', 'bicycle', 'tv', 'fridge',
      'dumbbell', 'clothes_hanger', 'book_open',
    ]));
    expect(kDefaultCategoryIconKeys, isNot(contains('arrow_left')));
    expect(kDefaultCategoryIconKeys, isNot(contains('banknotes')));
  });

  test('complete pinned Fluent library is available only on request', () {
    expect(kFullFluentCategoryIcons.length, greaterThan(2000));
    expect(CategoryIconStore.fullFluentCount, kFullFluentCategoryIcons.length);
    expect(CategoryIconStore.catalogFor(includeFullFluent: true).length,
        CategoryIconStore.catalogFor().length + kFullFluentCategoryIcons.length);
    expect(CategoryIconStore.catalogFor().any(
        (entry) => entry.key.startsWith('fluent__')), isFalse);
    expect(CategoryIconStore.isValidKey('fluent__animal_dog'), isTrue);
    expect(CategoryIconStore.isValidKey('fluent__vehicle_car'), isTrue);
  });

  test('old auto-selected giant libraries migrate, custom collections do not', () {
    expect(isLegacyAutoSelectedCollection(
        kMatchedCategoryIcons.keys.take(103).toList()), isTrue);
    expect(isLegacyAutoSelectedCollection(
        kMatchedCategoryIcons.keys.take(144).toList()), isTrue);
    expect(isLegacyAutoSelectedCollection(['home', 'dog', 'taxi']), isFalse);
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
    expect(picker, contains("final catalog = switch (_view)"));
    expect(picker, contains('category-icon-all-fluent'));
    expect(picker, contains('category-icon-my-icons'));
    expect(picker, contains('category-icon-favorite-toggle'));
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
    expect(screen, contains('clear-icon-collection'));
    expect(screen, contains('selected-icon-catalog'));
    expect(screen, contains('everyday-icon-catalog'));
  });

  testWidgets('My icons edits selected icons in one unified grid',
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
    final everydayGrid = tester.widget<GridView>(grid);
    expect((everydayGrid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        CategoryIconStore.catalogFor().length);
    final dog = find.byKey(const ValueKey('custom-icon-dog'));
    expect(dog, findsOneWidget);
    await tester.tap(dog); // One tap adds.
    await tester.pump();
    expect(find.textContaining('4 selected'), findsOneWidget);
    await tester.tap(dog); // Second tap removes.
    await tester.pump();
    expect(find.textContaining('3 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-icon-catalog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('selected-icon-catalog')));
    await tester.pumpAndSettle();
    final selectedGrid = tester.widget<GridView>(grid);
    expect((selectedGrid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        3);
    expect(find.byKey(const ValueKey('toggle-icon-catalog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-icon-catalog')));
    await tester.pumpAndSettle();
    final fluentGrid = tester.widget<GridView>(grid);
    expect((fluentGrid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        CategoryIconStore.catalogFor(includeFullFluent: true).length);
    expect(find.textContaining('shown'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear-icon-collection')));
    await tester.pump();
    expect(find.textContaining('0 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reset-default-icons')));
    await tester.pump();
    expect(find.textContaining('${kDefaultCategoryIconKeys.length} selected'),
        findsOneWidget);
  });

  test('human-first catalog covers everyday life and keeps legacy art', () {
    expect(kHumanCategorySubjects.length, greaterThanOrEqualTo(110));
    expect(kDefaultCategoryIconKeys.take(5),
        ['dog', 'cat', 'tree', 'car', 'taxi']);
    expect(kDefaultCategoryIconKeys.indexOf('dog'),
        lessThan(kDefaultCategoryIconKeys.indexOf('work')));
    expect(isSelectableCategoryIconKey('arrow_left'), isFalse);
    expect(CategoryIconStore.isValidKey('arrow_left'), isTrue,
        reason: 'Previously saved controls must remain renderable.');
  });

  testWidgets('actual category picker shows dogs and cars before technical art',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showCategoryIconPicker(context,
              initial: const CategoryIconSelection('home')),
          child: const Text('Open icon picker'),
        ),
      )),
    ));
    await tester.tap(find.text('Open icon picker'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-icon-dog')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-icon-car')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-icon-all-fluent')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-icon-all-fluent')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'animal_dog');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-icon-fluent__animal_dog')),
        findsOneWidget);
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
    expect(collection, contains('showCategoryIconCollectionEditor'));
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
