import 'package:counter/core/category_color_palette.dart';
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
      '#286BE3', '#F26900', '#FFD000', '#48A130', '#008F87',
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
      '#EF3B3B', '#F26900', '#FFD000', '#48A130', '#008F87',
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
    expect(kTagYellowPlateOpacity, 0.13);
    expect(kTagYellowText, const Color(0xFFE1B400));
    expect(kTagYellowBorderOpacity, 0.74);
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
            family == kNordicPeople) {
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
    expect(kTagYellowText, const Color(0xFFE1B400));
    expect(kTagYellowPlateOpacity, 0.13);
    expect(kTagYellowBorderOpacity, 0.74);
    for (final background in <Color>[Colors.white, const Color(0xFF121820)]) {
      expect(tagLetterChipPlate(kTagYellowGold, background),
          Color.alphaBlend(kTagYellowGold.withValues(alpha: 0.13), background));
      expect(tagLetterChipBorder(kTagYellowGold, background),
          Color.alphaBlend(kTagYellowGold.withValues(alpha: 0.74), background));
      expect(tagVibrantForeground(kTagYellowGold, surface: background),
          kTagYellowText);
    }
    expect(parseTagHexColor('#000000'), Colors.black);
    expect(kLifeTagColorPresets, contains('#000000'));
    // Old families remain visually compatible without modifying DB records.
    expect(parseTagHexColor('#E65EA5'), kNordicPeople[500]);
    expect(parseTagHexColor('#F75CC5'), kNordicPeople[500]);
    expect(parseTagHexColor('#C82332'), kNordicEntertainment[500]);
    expect(parseTagHexColor('#242B5D'), kNordicStudy[500]);
    expect(parseTagHexColor('#606060'), kCategoryNeutral[500]);
  });
}
