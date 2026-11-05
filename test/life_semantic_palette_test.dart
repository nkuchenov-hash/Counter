import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final high = a > b ? a : b;
  final low = a > b ? b : a;
  return (high + 0.05) / (low + 0.05);
}

double _hueGap(Color a, Color b) {
  final gap = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs();
  return gap > 180 ? 360 - gap : gap;
}

void main() {
  test('one canonical palette feeds both categories and tag presets', () {
    expect(kCategoryPickerMaterialColors, hasLength(10));
    expect(kLifeTagColorPresets, hasLength(10));
    expect(kCategoryPickerMaterialColors.map((f) => f[500]!.toARGB32()).toSet(),
        hasLength(10));

    for (var i = 0; i < kCategoryPickerMaterialColors.length; i++) {
      final family = kCategoryPickerMaterialColors[i];
      final canonical = '#${(family[500]!.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      expect(kLifeTagColorPresets[i], canonical);
      for (final tone in <int>[400, 500, 600]) {
        expect(family[tone], isNotNull);
        expect(categoryMaterialPrimaryForValue(family[tone]!.toARGB32()),
            family);
      }
    }
    // The compatibility resolver must not remap any NEW canonical shade a
    // second time (including the neutral light end of the scale).
    for (final family in kCategoryPickerMaterialColors) {
      for (final shade in <int>[50, 100, 200, 300, 400, 500, 600, 700, 800, 900]) {
        final argb = family[shade]!.toARGB32();
        expect(canonicalLifeColorValue(argb), argb,
            reason: 'New shades must be stable: ${family[shade]}');
      }
    }
    expect(kLifeTagColorPresets, containsAll(<String>[
      '#286BE3', '#E8700A', '#F6C500', '#56A235', '#008B83',
      '#55BCE7', '#242B5D', '#C82332', '#E65EA5', '#606060',
    ]));
  });

  test('dangerous hue collisions are resolved without purple pink', () {
    expect(_hueGap(kNordicEntertainment[500]!, kNordicPeople[500]!),
        greaterThan(20));
    expect(_hueGap(kNordicEntertainment[500]!, kNordicErrands[500]!),
        greaterThan(20));
    expect(_hueGap(kNordicMovement[500]!, kNordicHealth[500]!),
        greaterThan(25));
    expect(_hueGap(kNordicWork[500]!, kNordicTransport[500]!),
        greaterThan(15));
    expect(kLifeTagColorPresets, isNot(contains('#BD4199')));
  });

  test('all ten previous official base colors use their new family', () {
    final legacyBase = <String, MaterialColor>{
      '#3978C5': kNordicWork,
      '#D97841': kNordicErrands,
      '#D5A62E': kNordicFood,
      '#3A9B6F': kNordicMovement,
      '#26A5A1': kNordicHealth,
      '#55A6D1': kNordicTransport,
      '#725EB5': kNordicStudy,
      '#D64F55': kNordicEntertainment,
      '#D05C7D': kNordicPeople,
      '#949494': kCategoryNeutral,
    };
    for (final entry in legacyBase.entries) {
      expect(parseTagHexColor(entry.key), entry.value[500]);
      final legacyArgb = int.parse(entry.key.substring(1), radix: 16) | 0xFF000000;
      expect(categoryMaterialPrimaryForValue(legacyArgb), entry.value);
      expect(CategoryRule(id: 1, name: 'Historical color',
          colorValue: legacyArgb).colorOrDefault, entry.value[500]);
    }
    expect(categoryNordicChildColorValue(0xFFB94C6B, 0),
        kNordicPeople[500]!.toARGB32());
  });

  test('regular compact chip text meets 4.5 contrast in both themes', () {
    for (final surface in <Color>[
      const Color(0xFFF8FAFC),
      const Color(0xFF121820),
    ]) {
      for (final family in kCategoryPickerMaterialColors) {
        // Yellow is a deliberate older exact-gold text exception.
        if (family == kNordicFood) continue;
        final color = family[500]!;
        final plate = tagLetterChipPlate(color, surface);
        final fg = tagVibrantForeground(color, surface: surface);
        expect(_contrast(fg, plate), greaterThanOrEqualTo(4.5),
            reason: 'Compact text for ${family[500]} on ${surface.toARGB32()}');
      }
    }
  });

  test('solid dots remain visible on both light and dark surfaces', () {
    for (final surface in <Color>[
      const Color(0xFFF8FAFC),
      const Color(0xFF121820),
    ]) {
      for (final family in kCategoryPickerMaterialColors) {
        if (family == kNordicFood) continue; // Preserve original pure gold.
        final fg = tagSolidAccentOnSurface(family[500]!, surface);
        expect(_contrast(fg, surface), greaterThanOrEqualTo(3.0),
            reason: 'Solid accent for ${family[500]} on ${surface.toARGB32()}');
      }
    }
  });

  test('custom colors, exact gold, and saved database values are preserved', () {
    expect(parseTagHexColor('#ABCD12'), const Color(0xFFABCD12));
    expect(parseTagHexColor('#F6C500'), kTagYellowGold);
    expect(tagVibrantForeground(kTagYellowGold,
        surface: const Color(0xFFF8FAFC)), kTagYellowGold);
  });

  testWidgets('grouped settings menu remains functional at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AppSettingsNavigationGroup(
                children: [
                  AppSettingsNavigationRow(
                    title: 'Calendars',
                    leading: const AppSettingsMenuIcon(
                      icon: Icons.calendar_month_outlined,
                    ),
                    onTap: () => taps++,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Calendars'));
    final group = find.byType(AppSettingsNavigationGroup);
    final materials = tester.widgetList<Material>(
      find.descendant(of: group, matching: find.byType(Material)),
    );
    expect(materials.any((material) =>
        material.color == const Color(0xFFFFFFFF)), isTrue);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme previews select both explicit and system modes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final theme in [appLightTheme, appDarkTheme]) {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AppSettingsThemeModePicker(
                  value: 'light',
                  lightLabel: 'Light',
                  darkLabel: 'Dark',
                  systemLabel: 'Use system setting',
                  onChanged: (mode) => selected = mode,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Dark'));
      expect(selected, 'dark');
      await tester.tap(find.text('Use system setting'));
      expect(selected, 'system');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('settings choice rows have selectable accessible actions', (
    tester,
  ) async {
    var picked = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme,
        home: Scaffold(
          body: AppSettingsNavigationGroup(
            children: [
              AppSettingsSelectionRow(
                title: 'Circular tag',
                selected: false,
                onTap: () => picked = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Circular tag'));
    expect(picked, isTrue);
    expect(tester.takeException(), isNull);
  });

}
