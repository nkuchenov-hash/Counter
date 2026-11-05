import 'package:flutter/material.dart';
import 'package:counter/core/life_color_compat.dart' show canonicalLifeColorValue;

/// Exact yellow-tag palette (text, icon, stroke). No black/grey/orange overrides.
const Color kTagYellowGold = Color(0xFFF6C500);
/// Pale plate tint for yellow tags (same hex, 15% alpha, blended onto [surface]).
const double kTagYellowPlateOpacity = 0.15;

/// Yellow tag: preset hexes (#FDD835, legacy #FDCF00, #F6C500), or saturated hue ~gold (45°–60°).
bool tagColorIsYellowFamily(Color tagColor) {
  final rgb = tagColor.toARGB32() & 0xFFFFFF;
  if (rgb == 0xF6C500 || rgb == 0xFDCF00 || rgb == 0xFDD835) return true;
  final hsl = HSLColor.fromColor(tagColor);
  if (hsl.saturation < 0.12) return false;
  final h = hsl.hue;
  return h >= 45.0 && h < 60.0;
}

/// Timeline breadcrumb stadium: default ~13% accent; yellow → 15% [kTagYellowGold].
Color tagCategoryBreadcrumbPlate(Color accentColor, Color surface) {
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

/// Shared foreground for translucent category/tag chips.
///
/// When [surface] is supplied, maintain the original hue but select enough
/// lightness contrast for small text on that surface (light *or* dark mode).
/// Solid color icons/rings still use the unmodified family color when
/// [surface] is omitted. Yellow retains its existing exact-gold policy.
Color tagVibrantForeground(Color tagBaseColor, {Color? surface}) {
  if (tagColorIsYellowFamily(tagBaseColor)) return kTagYellowGold;
  if (surface == null) return tagBaseColor;

  final background = tagLetterChipPlate(tagBaseColor, surface);
  final backgroundLuminance = background.computeLuminance();
  final useDarkerText = backgroundLuminance > 0.35;
  var hsl = HSLColor.fromColor(tagBaseColor);
  var foreground = tagBaseColor;
  for (var step = 0; step <= 20; step++) {
    final a = foreground.computeLuminance();
    final higher = a > backgroundLuminance ? a : backgroundLuminance;
    final lower = a > backgroundLuminance ? backgroundLuminance : a;
    if ((higher + 0.05) / (lower + 0.05) >= 4.5) return foreground;
    final nextLightness =
        (hsl.lightness + (useDarkerText ? -0.025 : 0.025)).clamp(0.0, 1.0);
    if (nextLightness == hsl.lightness) break;
    hsl = hsl.withLightness(nextLightness);
    foreground = hsl.toColor();
  }
  return foreground;
}

/// Icon/glyph without a filled tag circle.
Color tagGlyphOnCanvas(Color tagColor) {
  if (tagColorIsYellowFamily(tagColor)) return kTagYellowGold;
  return tagColor;
}

/// Icon on a solid tag-colored disk (yellow → gold glyph, never black/grey).
/// Hard pure B/W glyph inversion applies **only** to the synthetic “No Tags” chip
/// ([syntheticNoTags]); user tags with #000000 / #FFFFFF use luminance / fill color.
Color tagIconOnFilledTagColor(Color tagFill, {bool syntheticNoTags = false}) {
  if (tagColorIsYellowFamily(tagFill)) return kTagYellowGold;
  final rgb = tagFill.toARGB32() & 0xFFFFFF;
  if (syntheticNoTags) {
    if (rgb == 0x000000) return Colors.white;
    if (rgb == 0xFFFFFF) return Colors.black;
  }
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

/// Ten Material icon keys (`tags.icon`).
const List<String> kTagManagerIconKeys = [
  'label',
  'star',
  'bookmark',
  'flag',
  'home',
  'work',
  'favorite',
  'event',
  'local_offer',
  'sell',
];

IconData iconForTagKey(String? key) {
  switch (key) {
    case 'star':
      return Icons.star_rounded;
    case 'bookmark':
      return Icons.bookmark_rounded;
    case 'flag':
      return Icons.flag_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'work':
      return Icons.work_rounded;
    case 'favorite':
      return Icons.favorite_rounded;
    case 'event':
      return Icons.event_rounded;
    case 'local_offer':
      return Icons.local_offer_rounded;
    case 'sell':
      return Icons.sell_rounded;
    case 'label':
    default:
      return Icons.label_rounded;
  }
}

Color? parseTagHexColor(String? hex) {
  if (hex == null || hex.length < 7) return null;
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  // Old official presets paint using the updated canonical palette.
  // The persisted HEX remains intact until the tag is explicitly edited.
  return Color(canonicalLifeColorValue(0xFF000000 | v));
}