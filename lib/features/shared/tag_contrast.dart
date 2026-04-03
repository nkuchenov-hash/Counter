import 'package:flutter/material.dart';

/// Exact yellow-tag palette (text, icon, stroke). No black/grey/orange overrides.
const Color kTagYellowGold = Color(0xFFFDCF00);

/// Pale plate tint for yellow tags (same hex, 15% alpha, blended onto [surface]).
const double kTagYellowPlateOpacity = 0.15;

/// Yellow tag: preset hexes (#FDD835, #FDCF00), or saturated hue ~gold (45°–60°).
bool tagColorIsYellowFamily(Color tagColor) {
  final rgb = tagColor.toARGB32() & 0xFFFFFF;
  if (rgb == 0xFDCF00 || rgb == 0xFDD835) return true;
  final hsl = HSLColor.fromColor(tagColor);
  if (hsl.saturation < 0.12) return false;
  final h = hsl.hue;
  return h >= 45.0 && h < 60.0;
}

/// Timeline breadcrumb stadium: default ~13% accent; yellow → 15% [kTagYellowGold].
Color tagRecordCategoryHeaderPlate(Color accentColor, Color surface) {
  if (tagColorIsYellowFamily(accentColor)) {
    return Color.alphaBlend(
      kTagYellowGold.withValues(alpha: kTagYellowPlateOpacity),
      surface,
    );
  }
  return Color.alphaBlend(
    accentColor.withValues(alpha: 0.13),
    surface,
  );
}

/// Tag manager list avatar background: default 20% tag; yellow → 15% gold.
Color tagManagerAvatarPlate(Color tagColor, Color surface) {
  if (tagColorIsYellowFamily(tagColor)) {
    return Color.alphaBlend(
      kTagYellowGold.withValues(alpha: kTagYellowPlateOpacity),
      surface,
    );
  }
  return Color.alphaBlend(tagColor.withValues(alpha: 0.2), surface);
}

/// Vibrant text/icon on pale plates & avatars: full [tagBaseColor], except yellow → [kTagYellowGold].
Color tagVibrantForeground(Color tagBaseColor) {
  if (tagColorIsYellowFamily(tagBaseColor)) return kTagYellowGold;
  return tagBaseColor;
}

/// Icon/glyph without a filled tag circle.
Color tagGlyphOnCanvas(Color tagColor) {
  if (tagColorIsYellowFamily(tagColor)) return kTagYellowGold;
  return tagColor;
}

/// Icon on a solid tag-colored disk (yellow → gold glyph, never black/grey).
Color tagIconOnFilledTagColor(Color tagFill) {
  if (tagColorIsYellowFamily(tagFill)) return kTagYellowGold;
  if (tagFill.computeLuminance() < 0.45) return Colors.white;
  return tagFill;
}

/// Letter chip plate: yellow uses [kTagYellowGold] @ [kTagYellowPlateOpacity]; else prior behavior.
Color tagLetterChipPlate(Color tagColor, Color surface) {
  if (tagColorIsYellowFamily(tagColor)) {
    return Color.alphaBlend(
      kTagYellowGold.withValues(alpha: kTagYellowPlateOpacity),
      surface,
    );
  }
  return Color.alphaBlend(tagColor.withValues(alpha: 0.16), surface);
}

/// Letter chip border: yellow → solid [kTagYellowGold]; else tinted category stroke.
Color tagLetterChipBorder(Color tagColor, Color surface) {
  if (tagColorIsYellowFamily(tagColor)) return kTagYellowGold;
  return Color.alphaBlend(tagColor.withValues(alpha: 0.42), surface);
}

/// Empty chip stadium fill: yellow → 15% gold blended on [surface]; else legacy translucent tag.
Color tagEmptyChipFill(Color tagColor, Color surface) {
  if (tagColorIsYellowFamily(tagColor)) {
    return Color.alphaBlend(
      kTagYellowGold.withValues(alpha: kTagYellowPlateOpacity),
      surface,
    );
  }
  return tagColor.withValues(alpha: 0.16);
}

Color tagEmptyChipBorderColor(Color tagColor) {
  if (tagColorIsYellowFamily(tagColor)) return kTagYellowGold;
  return tagColor.withValues(alpha: 0.42);
}
