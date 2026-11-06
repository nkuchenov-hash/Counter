import 'dart:io';

import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/category_icon_system.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all selected yellow tones belong to one canonical family', () {
    for (final tone in kCategorySelectableTones) {
      final color = kNordicFood[tone]!;
      expect(
        categoryMaterialPrimaryForValue(color.toARGB32()),
        same(kNordicFood),
      );
    }
    expect(kNordicFood[500]!.toARGB32(), 0xFFFFD000);
  });

  testWidgets('row selection never changes category icon style',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await CategoryIconStore.instance.ensureLoaded();
    final category = CategoryRule(
      id: 470123,
      name: 'Movies',
      colorValue: kNordicFood[500]!.toARGB32(),
    );

    Future<IconData?> iconFor(bool selected) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CategoryGlyph(
            category: category,
            color: kNordicFood[500],
            selected: selected,
          ),
        ),
      ));
      await tester.pump();
      return tester.widget<Icon>(find.byType(Icon)).icon;
    }

    expect(await iconFor(true), await iconFor(false));
  });

  test('category manager selection does not double-tint accent plates', () {
    final manager =
        File('lib/features/settings/categories/category_list_view.dart')
            .readAsStringSync();
    expect(manager, contains('scheme.onSurface.withValues(alpha: 0.055)'));
    expect(manager, isNot(contains(
      'selected ? tint.withValues(alpha: 0.07) : scheme.surface',
    )));
  });

  test('full and quick editor show the category hue instead of UI primary', () {
    final full =
        File('lib/features/settings/categories/category_editor_sheet.dart')
            .readAsStringSync();
    final quick =
        File('lib/features/settings/categories/category_appearance_sheet.dart')
            .readAsStringSync();

    expect(full, contains('Color get _currentAccent => Color(canonicalLifeColorValue('));
    expect(full, contains('color[500]!, // Always show the base hue'));
    expect(quick, contains(
      'color: Color(_colorValue ?? widget.category.colorOrDefault.toARGB32()),',
    ));
  });
}
