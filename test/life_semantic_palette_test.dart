import 'package:counter/core/app_colors.dart';
import 'package:counter/core/app_colors.dart';
import 'package:counter/features/notes/notes_visual_tokens.dart';
import 'package:counter/features/notes/drawing_canvas_page.dart';
import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/core/widgets/app_menu_icons.dart';
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
  test('Notes category and drawing palettes use global semantic families', () {
    expect(NotesSectionPalette.all.accent, kNordicWork[500]);
    expect(NotesSectionPalette.forCategory('книги', kNordicWork).accent,
        kNordicStudy[500]);
    expect(NotesSectionPalette.forCategory('идеи', kNordicWork).accent,
        kNordicHealth[500]);
    expect(NotesSectionPalette.forCategory('личное', kNordicWork).accent,
        kNordicPeople[500]);
    expect(NotesSectionPalette.forCategory('работа', kNordicPeople).accent,
        kNordicWork[500]);
    expect(NotesSectionPalette.forCategory('игры', kNordicPeople).accent,
        kNordicEntertainment[500]);
    expect(NotesSectionPalette.forCategory('my custom note', kNordicPeople).accent,
        kNordicPeople);
    final drawing = kNotesDrawingColors.take(kCategoryPickerMaterialColors.length)
        .map((item) => item.color).toList();
    final expected = kCategoryPickerMaterialColors.map((f) => f[500]!).toList();
    expect(drawing, expected);
    expect(kNotesDrawingColors.last.color, AppNeutralTones.white);
  });

  test('complete neutral ramp has only true grays, white and black', () {
    const grays = <Color>[
      AppNeutralTones.white, AppNeutralTones.gray50,
      AppNeutralTones.gray100, AppNeutralTones.gray200,
      AppNeutralTones.gray300, AppNeutralTones.gray400,
      AppNeutralTones.gray500, AppNeutralTones.gray600,
      AppNeutralTones.gray700, AppNeutralTones.gray800,
      AppNeutralTones.gray900, AppNeutralTones.gray950,
      AppNeutralTones.black,
    ];
    for (final color in grays) {
      final rgb = color.toARGB32();
      expect((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF);
      expect((rgb >> 8) & 0xFF, rgb & 0xFF);
    }
    expect(grays.first, Colors.white);
    expect(grays.last, Colors.black);
  });

  test('one canonical palette feeds both categories and tag presets', () {
    expect(kCategoryPickerMaterialColors, hasLength(11));
    expect(kLifeTagColorPresets, hasLength(11));
    expect(kCategoryPickerMaterialColors.map((f) => f[500]!.toARGB32()).toSet(),
        hasLength(11));

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
      '#286BE3', '#FF7900', '#FFD000', '#48A130', '#008F87',
      '#47BCE9', '#725EB5', '#EF3B3B', '#FF79AA', '#000000', '#9A9A9A',
    ]));
  });

  test('picker swatches follow rainbow order without changing root defaults', () {
    const ordered = <MaterialColor>[
      kNordicEntertainment, // red
      kNordicErrands,       // orange
      kNordicFood,          // yellow
      kNordicMovement,      // green
      kNordicHealth,        // teal
      kNordicTransport,     // sky
      kNordicWork,          // blue
      kNordicStudy,         // purple
      kNordicPeople,        // pink
      kCategoryNeutral,     // gray
      kCategoryBlack,       // black
    ];
    expect(kCategoryPickerMaterialColors, ordered);
    expect(kLifeTagColorPresets, <String>[
      '#EF3B3B', '#FF7900', '#FFD000', '#48A130', '#008F87',
      '#47BCE9', '#286BE3', '#725EB5', '#FF79AA', '#9A9A9A',
      '#000000',
    ]);

    // A change in the swatch layout must not change automatically assigned
    // colors for new root categories (or recolor existing categories).
    const previousDefaultRootSequence = <MaterialColor>[
      kNordicWork, kNordicErrands, kNordicFood,
      kNordicMovement, kNordicHealth, kNordicTransport,
      kNordicStudy, kNordicEntertainment, kNordicPeople,
    ];
    for (var i = 0; i < previousDefaultRootSequence.length * 2; i++) {
      final family = previousDefaultRootSequence[i % previousDefaultRootSequence.length];
      expect(categoryNordicRootColorValue(i), family[600]!.toARGB32());
    }
    expect(categoryNordicChildColorValue(kNordicPeople[600]!.toARGB32(), 0),
        kNordicPeople[500]!.toARGB32());
  });

  test('pink and red are visually separated without replacing purple or black', () {
    expect(_hueGap(kNordicEntertainment[500]!, kNordicPeople[500]!),
        greaterThan(18));
    expect((kNordicEntertainment[500]!.computeLuminance() -
            kNordicPeople[500]!.computeLuminance()).abs(), greaterThan(0.08));
    expect(kNordicStudy[500], const Color(0xFF725EB5));
    expect(kCategoryBlack[500], Colors.black);
    expect(_hueGap(kNordicEntertainment[500]!, kNordicErrands[500]!),
        greaterThan(20));
    expect(_hueGap(kNordicMovement[500]!, kNordicHealth[500]!),
        greaterThan(25));
    expect(_hueGap(kNordicWork[500]!, kNordicTransport[500]!),
        greaterThan(15));
    expect(kLifeTagColorPresets, isNot(contains('#BD4199')));
  });

  test('pink and red remain different even on translucent tag plates', () {
    final pink = kNordicPeople[500]!;
    final red = kNordicEntertainment[500]!;
    final surface = const Color(0xFFF8FAFC);
    final pinkPlate = tagLetterChipPlate(pink, surface);
    final redPlate = tagLetterChipPlate(red, surface);
    expect(pinkPlate, isNot(redPlate));
    final pinkFg = tagVibrantForeground(pink, surface: surface);
    final redFg = tagVibrantForeground(red, surface: surface);
    expect(_hueGap(pinkFg, redFg), greaterThan(18));
    expect((pinkPlate.b - redPlate.b).abs(), greaterThan(0.07));
    expect(pinkFg, kTagPinkText);
    expect(redFg, kNordicEntertainment[600]);
    expect(_contrast(pinkFg, pinkPlate), greaterThanOrEqualTo(3.0));
    expect(_contrast(redFg, redPlate), greaterThanOrEqualTo(3.0));
  });

  test('warm pink and red retain their identity on dark surfaces', () {
    const dark = Color(0xFF121820);
    final pink = kNordicPeople[500]!;
    final red = kNordicEntertainment[500]!;
    expect(tagVibrantForeground(pink, surface: dark), kTagPinkText);
    expect(tagVibrantForeground(red, surface: dark), kNordicEntertainment[400]);
    expect(_contrast(kTagPinkText, tagLetterChipPlate(pink, dark)),
        greaterThanOrEqualTo(3.0));
    expect(_contrast(kNordicEntertainment[400]!, tagLetterChipPlate(red, dark)),
        greaterThanOrEqualTo(4.5));
  });

  test('approved pink parameters apply across shared tag presentations', () {
    const light = Color(0xFFF8FAFC);
    const dark = Color(0xFF121820);
    final pink = kNordicPeople[500]!;
    expect(pink, const Color(0xFFFF79AA));
    expect(kTagPinkText, const Color(0xFFD25888));
    expect(kTagPinkPlateOpacity, 0.16);
    expect(kTagPinkBorderOpacity, 0.60);
    for (final surface in <Color>[light, dark]) {
      final plate = Color.alphaBlend(pink.withValues(alpha: 0.16), surface);
      final border = Color.alphaBlend(pink.withValues(alpha: 0.60), surface);
      expect(tagLetterChipPlate(pink, surface), plate);
      expect(tagManagerAvatarPlate(pink, surface), plate);
      expect(tagLetterChipBorder(pink, surface), border);
      expect(tagEmptyChipFill(pink, surface), pink.withValues(alpha: 0.16));
      expect(tagEmptyChipBorderColor(pink), pink.withValues(alpha: 0.60));
      expect(tagVibrantForeground(pink, surface: surface), kTagPinkText);
      expect(_contrast(kTagPinkText, plate), greaterThanOrEqualTo(3.0));
    }
    // Red keeps its original tint settings and chromatic text.
    final red = kNordicEntertainment[500]!;
    expect(tagLetterChipPlate(red, light),
        Color.alphaBlend(red.withValues(alpha: 0.26), light));
    expect(tagLetterChipBorder(red, light),
        Color.alphaBlend(red.withValues(alpha: 0.55), light));
    expect(tagVibrantForeground(red, surface: light), kNordicEntertainment[600]);
    // User-approved yellow remains independent of pink settings.
    expect(kTagYellowGold, const Color(0xFFFFD000));
    expect(kTagYellowPlateOpacity, 0.16);
    expect(kTagYellowText, const Color(0xFFB18900));
    expect(kTagYellowBorderOpacity, 0.74);
  });

  test('urgent remains truly black, but custom urgent colors are respected', () {
    const light = Color(0xFFF8FAFC);
    for (final oldGray in <String?>[
      null, '#606060', '#949494', '#9A9A9A', '#9E9E9E',
    ]) {
      expect(parseTagDisplayColor(oldGray, tagName: ' urgent '), Colors.black);
    }
    expect(parseTagDisplayColor('#9A9A9A', tagName: 'admin'),
        kCategoryNeutral[500]);
    expect(parseTagDisplayColor('#FF79AA', tagName: 'urgent'),
        kNordicPeople[500]);
    expect(tagLetterChipPlate(Colors.black, light), Colors.black);
    expect(tagLetterChipBorder(Colors.black, light), Colors.black);
    expect(tagVibrantForeground(Colors.black, surface: light), Colors.white);
    expect(tagManagerAvatarPlate(Colors.black, light), Colors.black);
    expect(tagEmptyChipFill(Colors.black, light), Colors.black);
    expect(tagEmptyChipBorderColor(Colors.black), Colors.black);
    expect(_contrast(Colors.white, Colors.black), greaterThan(20));
  });

  test('orange is saturated and readable, not peach or brown', () {
    const light = Color(0xFFF8FAFC);
    const dark = Color(0xFF121820);
    final orange = kNordicErrands[500]!;
    expect(orange, const Color(0xFFFF7900));
    expect(kTagOrangeText, const Color(0xFFD95400));
    expect(kTagOrangePlateOpacity, 0.22);
    expect(kTagOrangeBorderOpacity, 0.78);
    expect(tagVibrantForeground(orange, surface: light), kTagOrangeText);
    expect(tagVibrantForeground(orange, surface: dark),
        kNordicErrands[400]);
    for (final surface in <Color>[light, dark]) {
      expect(tagLetterChipPlate(orange, surface),
          Color.alphaBlend(orange.withValues(alpha: 0.22), surface));
      expect(tagLetterChipBorder(orange, surface),
          Color.alphaBlend(orange.withValues(alpha: 0.78), surface));
      expect(tagManagerAvatarPlate(orange, surface),
          tagLetterChipPlate(orange, surface));
      expect(tagEmptyChipFill(orange, surface),
          orange.withValues(alpha: 0.22));
      expect(tagEmptyChipBorderColor(orange),
          orange.withValues(alpha: 0.78));
    }
    expect(_contrast(kTagOrangeText, tagLetterChipPlate(orange, light)),
        greaterThanOrEqualTo(3.0));
    expect(_contrast(kNordicErrands[400]!, tagLetterChipPlate(orange, dark)),
        greaterThanOrEqualTo(4.5));
    expect(parseTagHexColor('#F26900'), orange);
    // Other user-approved colors remain intact.
    expect(kNordicEntertainment[500], const Color(0xFFEF3B3B));
    expect(kNordicPeople[500], const Color(0xFFFF79AA));
    expect(kTagPinkPlateOpacity, 0.16);
    expect(kTagYellowPlateOpacity, 0.16);
  });

  test('previous official base colors resolve to new families', () {
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
        // Yellow has user-approved exact text; red and pink deliberately
        // prioritize chromatic fidelity with 3:1 minimum for chips.
        if (family == kNordicFood ||
            family == kNordicEntertainment ||
            family == kNordicPeople ||
            family == kNordicErrands) {
          continue;
        }
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
        if (family == kNordicFood) continue; // Preserve special user-approved yellow foreground.
        final fg = tagSolidAccentOnSurface(family[500]!, surface);
        expect(_contrast(fg, surface), greaterThanOrEqualTo(3.0),
            reason: 'Solid accent for ${family[500]} on ${surface.toARGB32()}');
      }
    }
  });

  test('custom colors, approved yellow parameters and saved values are preserved', () {
    expect(parseTagHexColor('#ABCD12'), const Color(0xFFABCD12));
    expect(parseTagHexColor('#F6C500'), kTagYellowGold);
    expect(parseTagHexColor('#FFD000'), kTagYellowGold);
    expect(kTagYellowGold, const Color(0xFFFFD000));
    expect(kTagYellowText, const Color(0xFFB18900));
    expect(kTagYellowPlateOpacity, 0.16);
    expect(kTagYellowBorderOpacity, 0.74);
    for (final background in <Color>[Colors.white, const Color(0xFF121820)]) {
      expect(tagLetterChipPlate(kTagYellowGold, background),
          Color.alphaBlend(kTagYellowGold.withValues(alpha: 0.16), background));
      expect(tagLetterChipBorder(kTagYellowGold, background),
          Color.alphaBlend(kTagYellowGold.withValues(alpha: 0.74), background));
      expect(tagVibrantForeground(kTagYellowGold, surface: background),
          kTagYellowText);
    }
    expect(parseTagHexColor('#F26900'), kNordicErrands[500]);
    expect(parseTagHexColor('#000000'), Colors.black);
    expect(kLifeTagColorPresets, contains('#000000'));
    // Old families remain visually compatible without modifying DB records.
    expect(parseTagHexColor('#E65EA5'), kNordicPeople[500]);
    expect(parseTagHexColor('#F75CC5'), kNordicPeople[500]);
    expect(parseTagHexColor('#C82332'), kNordicEntertainment[500]);
    expect(parseTagHexColor('#242B5D'), kNordicStudy[500]);
    expect(parseTagHexColor('#606060'), kCategoryNeutral[500]);
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

  test('all LIFE OS menu icon roles resolve through the canonical collection', () {
    for (final role in AppMenuIconRole.values) {
      final icon = AppMenuIcons.icon(role);
      expect(icon.codePoint, greaterThan(0), reason: role.name);
      expect(icon.fontFamily, isNotNull, reason: role.name);
    }
  });

  testWidgets('near-white Settings canvas keeps white cards distinct',
      (tester) async {
    late Color background;
    late Color card;
    await tester.pumpWidget(MaterialApp(
      theme: appLightTheme,
      home: Builder(builder: (ctx) => Theme(
        data: settingsNeutralTheme(ctx),
        child: Builder(builder: (settingsContext) {
          final scheme = Theme.of(settingsContext).colorScheme;
          background = scheme.surfaceContainerLowest;
          card = scheme.surfaceContainerHigh;
          return Scaffold(
            body: AppSettingsNavigationGroup(children: [
              AppSettingsNavigationRow(
                title: 'Notes',
                leading: AppSettingsMenuIcon(
                  icon: AppMenuIcons.icon(AppMenuIconRole.notes)),
                onTap: () {},
              ),
            ]),
          );
        }),
      )),
    ));
    expect(background, AppColors.appBackground);
    expect(card, AppColors.cardSurface);
    expect(background, isNot(card));
    expect(tester.takeException(), isNull);
  });

}
