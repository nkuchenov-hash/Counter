import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('People magenta is distinct from Task red in the shared palette', () {
    final people = kNordicPeople[500]!;
    final taskRed = kNordicEntertainment[500]!;
    final peopleHue = HSVColor.fromColor(people).hue;
    final redHue = HSVColor.fromColor(taskRed).hue;
    final difference = (peopleHue - redHue).abs();
    final shortestDifference = difference > 180 ? 360 - difference : difference;

    expect(shortestDifference, greaterThan(30));
    expect(kLifeTagColorPresets, contains('#BD4199'));
    expect(kLifeTagColorPresets, isNot(contains('#D05C7D')));
  });

  test('old official People colors render as the new shared family', () {
    expect(parseTagHexColor('#D05C7D'), kNordicPeople[500]);
    const category = Category(
      id: 'legacy-people',
      userId: 1,
      colorValue: 0xFFD05C7D,
    );
    expect(category.colorOrDefault, kNordicPeople[500]);
    expect(categoryMaterialPrimaryForValue(0xFFD05C7D), kNordicPeople);
    expect(
      categoryNordicChildColorValue(0xFFB94C6B, 0),
      kNordicPeople[500]!.toARGB32(),
    );
  });

  test('other custom colors and the special bright gold remain untouched', () {
    expect(parseTagHexColor('#ABCD12'), const Color(0xFFABCD12));
    expect(parseTagHexColor('#F6C500'), kTagYellowGold);
  });
}
