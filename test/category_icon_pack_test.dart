import 'dart:io';
import 'package:counter/core/category_icon_system.dart';
import 'package:counter/core/category_icon_svg_data.dart';
import 'package:counter/core/category_icon_catalog_generated.g.dart';
import 'package:counter/features/settings/categories/category_icon_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('strict gate: every selectable icon is a native pair in both packs', () {
    final keys = kCategoryIconCatalog.map((e) => e.key).toSet();
    expect(keys, hasLength(kCategoryIconCatalog.length),
        reason: 'Duplicate keys break stable category icon identifiers.');
    expect(kFluentCategorySvgs.keys.toSet(), keys);
    expect(kHeroCategorySvgs.keys.toSet(), keys);
    for (final family in CategoryIconPack.values) {
      for (final key in keys) {
        expect(CategoryIconStore.isValidKey(key), isTrue,
            reason: 'The same symbol must exist in both variants and packs.');
        final pair = CategoryIconStore.iconsFor(family)[key]!;
        expect(pair.regular, contains('<svg'));
        expect(pair.filled, contains('<svg'));
        expect(pair.regular, isNot(equals(pair.filled)),
            reason: 'A style toggle must not display identical artwork.');
      }
    }
  });

  test('complete families are selectable independently, not limited to 14', () {
    expect(kCompleteFluentCategoryIcons.length, greaterThan(2200));
    expect(kCompleteHeroCategoryIcons.length, greaterThan(300));
    final fluent = CategoryIconStore.catalogFor(CategoryIconPack.fluent);
    final hero = CategoryIconStore.catalogFor(CategoryIconPack.heroicons);
    expect(fluent.length, greaterThan(2200));
    expect(hero.length, greaterThan(300));
    expect(fluent.map((v) => v.key).toSet().length, fluent.length);
    expect(hero.map((v) => v.key).toSet().length, hero.length);
    expect(fluent.any((e) => e.key == 'accessibility_checkmark'), isTrue);
    expect(hero.any((e) => e.key == 'academic_cap'), isTrue);
    expect(CategoryIconStore.isValidKey('accessibility_checkmark'), isTrue);
    expect(CategoryIconStore.isValidKey('academic_cap'), isTrue);
  });

  test('category manager and Notes must use shared glyph renderer', () {
    final manager = File(
      'lib/features/settings/categories/category_list_view.dart',
    ).readAsStringSync();
    final notes = File(
      'lib/features/notes/widgets/notes_library_production_shell.dart',
    ).readAsStringSync();
    final folderTabs = File(
      'lib/features/notes/widgets/notes_folder_pane.dart',
    ).readAsStringSync();
    expect(manager, contains('CategoryGlyph(category: r,'));
    expect(manager, isNot(contains('Icon(categoryManagerIconFor(r)')),
        reason: 'Main Categories manager must not revert to Material Icons.');
    expect(notes, contains('category: rule,'));
    expect(notes, isNot(contains("IconData(rule.iconCodePoint!")));
    expect(folderTabs, contains('CategoryGlyph('));
  });

  testWidgets('picker preserves symbol while changing Outline to Fill',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    CategoryIconSelection? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            picked = await showCategoryIconPicker(context,
              initial: const CategoryIconSelection('heart'));
          },
          child: const Text('OPEN PICKER'),
        ),
      )),
    ));
    await tester.tap(find.text('OPEN PICKER'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-icon-style-toggle')), findsOneWidget);
    await tester.tap(find.text('Fill').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-icon-apply')));
    await tester.pumpAndSettle();
    expect(picked, const CategoryIconSelection('heart', filled: true));
  });
}
