import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double hueGap(Color a, Color b) {
  final gap = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs();
  return gap > 180 ? 360 - gap : gap;
}

void main() {
  test('shared red, orange and pink identities have distinct hues', () {
    final red = kNordicEntertainment[500]!;
    final orange = kNordicErrands[500]!;
    final pink = kNordicPeople[500]!;
    expect(hueGap(red, orange), greaterThan(25));
    expect(hueGap(red, pink), greaterThan(25));
    expect(hueGap(orange, kTagYellowGold), greaterThan(15));
    expect(kLifeTagColorPresets, containsAll(<String>[
      '#C82332', '#E77A10', '#E65EA5',
    ]));
    expect(kLifeTagColorPresets, isNot(contains('#BD4199')));
  });

  test('old official shades render as current tag and category colors', () {
    expect(parseTagHexColor('#D05C7D'), kNordicPeople[500]);
    expect(parseTagHexColor('#D64F55'), kNordicEntertainment[500]);
    expect(parseTagHexColor('#D97841'), kNordicErrands[500]);

    final category = CategoryRule(
      id: 1, name: 'Legacy meeting', colorValue: 0xFFD05C7D,
    );
    expect(category.colorOrDefault, kNordicPeople[500]);
    expect(categoryMaterialPrimaryForValue(0xFFD05C7D), kNordicPeople);
    expect(categoryMaterialPrimaryForValue(0xFFD97841), kNordicErrands);
    expect(categoryMaterialPrimaryForValue(0xFFD64F55), kNordicEntertainment);
    expect(
      categoryNordicChildColorValue(0xFFB94C6B, 0),
      kNordicPeople[500]!.toARGB32(),
    );
  });

  test('custom tag colors and exact gold stay untouched', () {
    expect(parseTagHexColor('#ABCD12'), const Color(0xFFABCD12));
    expect(parseTagHexColor('#F6C500'), kTagYellowGold);
  });
}
