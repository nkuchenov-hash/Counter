import 'package:flutter/material.dart';
import 'package:counter/core/app_colors.dart';
import 'package:counter/core/life_color_compat.dart' show canonicalLifeColorValue, kNordicEntertainment, kNordicPeople, kNordicErrands, kNordicFood;

/// Approved sunny-yellow tag identity. These values come from the yellow
/// preview controls; they are shared by every tag display mode and screen.
final Color kTagYellowGold = kNordicFood[500]!;
const Color kTagYellowText = AppColors.yellowTagText;
const double kTagYellowPlateOpacity = 0.16;
const double kTagYellowBorderOpacity = 0.74;

/// Approved warm-pink tag style: independent from neighboring red/purple.
/// All pink tag surfaces use the canonical #FF79AA hue, but a lighter plate.
const Color kTagPinkText = AppColors.pinkTagText;
const double kTagPinkPlateOpacity = 0.16;
const double kTagPinkBorderOpacity = 0.60;

/// Vivid orange remains orange even on transparent light-theme pills.
const Color kTagOrangeText = AppColors.orangeTagText;
const double kTagOrangePlateOpacity = 0.22;
const double kTagOrangeBorderOpacity = 0.78;

bool tagColorIsCanonicalOrange(Color color) =>
    color.toARGB32() == kNordicErrands[500]!.toARGB32();

bool tagColorIsBlack(Color color) =>
    (color.toARGB32() & 0xFFFFFF) == 0x000000;

bool tagColorIsCanonicalPink(Color color) =>
    color.toARGB32() == kNordicPeople[500]!.toARGB32();

/// Current/previous yellow presets, plus saturated gold hue (45°–60°).
bool tagColorIsYellowFamily(Color tagColor) {
  final rgb = tagColor.toARGB32() & 0xFFFFFF;
  if (rgb == 0xFFD000 || rgb == 0xF6C500 || rgb == 0xFDCF00 || rgb == 0xFDD835) return true;
  final hsl = HSLColor.fromColor(tagColor);
  if (hsl.saturation < 0.12) return false;
  final h = hsl.hue;
  return h >= 45.0 && h < 60.0;
}

/// Timeline category breadcrumbs and planning tag chips use the same
/// semantic surface recipe from the single Life OS design system.
/// Keep this name for existing callers; never implement a separate tint.
Color tagCategoryBreadcrumbPlate(Color accentColor, Color surface) =>
    tagLetterChipPlate(accentColor, surface);

/// Tag manager avatar: black solid; yellow 16%, pink 16%, orange 22%.
Color tagManagerAvatarPlate(Color tagColor, Color surface) {
  if (tagColorIsBlack(tagColor)) return Colors.black;
  if (tagColorIsYellowFamily(tagColor)) {
    return Color.alphaBlend(
      kTagYellowGold.withValues(alpha: kTagYellowPlateOpacity),
      surface,
    );
  }
  if (tagColorIsCanonicalPink(tagColor)) {
    return Color.alphaBlend(
      tagColor.withValues(alpha: kTagPinkPlateOpacity), surface,
    );
  }
  if (tagColorIsCanonicalOrange(tagColor)) {
    return Color.alphaBlend(
      tagColor.withValues(alpha: kTagOrangePlateOpacity), surface,
    );
  }
  return Color.alphaBlend(tagColor.withValues(alpha: 0.26), surface);
}

/// Shared foreground for translucent category/tag chips.
///
/// When [surface] is supplied, maintain the original hue but select enough
/// lightness contrast for small text on that surface (light *or* dark mode).
/// Solid color icons/rings still use the unmodified family color when
/// [surface] is omitted. Yellow uses the explicitly approved text color.
Color tagVibrantForeground(Color tagBaseColor, {Color? surface}) {
  if (tagColorIsBlack(tagBaseColor)) return Colors.white;
  if (tagColorIsYellowFamily(tagBaseColor)) return kTagYellowText;
  if (surface == null) return tagBaseColor;
  if (tagColorIsCanonicalPink(tagBaseColor)) return kTagPinkText;
  if (tagColorIsCanonicalOrange(tagBaseColor)) {
    return surface.computeLuminance() > 0.35
        ? kTagOrangeText : kNordicErrands[400]!;
  }

  // Keep official red RED and official warm pink PINK in small chips.
  // The generic 4.5:1 automatic darkening turns their text into burgundy
  // and purple-red respectively. Their approved chromatic typography targets
  // at least 3:1 on pale tint plates, with stronger contrast in dark mode.
  final lightSurface = surface.computeLuminance() > 0.35;
  if (tagBaseColor.toARGB32() == kNordicEntertainment[500]!.toARGB32()) {
    return lightSurface ? kNordicEntertainment[600]! : kNordicEntertainment[400]!;
  }

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
        (hsl.lightness + (useDarkerText ? -0.025 : 0.025))
            .clamp(0.0, 1.0).toDouble();
    if (nextLightness == hsl.lightness) break;
    hsl = hsl.withLightness(nextLightness);
    foreground = hsl.toColor();
  }
  return foreground;
}

/// Color for solid 12px dots and colored icons, preserving the hue but
/// ensuring sufficient separation from a dark or light app surface.
/// Tag fills and colors stored in PocketBase are not modified.
Color tagSolidAccentOnSurface(Color base, Color surface) {
  // Solid category identity must be the actual saved/canonical palette value.
  // Contrast is applied to text and plate roles, never by silently changing
  // the icon or stripe into a different shade (especially yellow).
  return Color(canonicalLifeColorValue(base.toARGB32()));
}

/// Icon/glyph without a filled tag circle.
Color tagGlyphOnCanvas(Color tagColor) {
  if (tagColorIsYellowFamily(tagColor)) return kTagYellowText;
  return tagColor;
}

/// Icon on a solid tag-colored disk (yellow → gold glyph, never black/grey).
/// Hard pure B/W glyph inversion applies **only** to the synthetic “No Tags” chip
/// ([syntheticNoTags]); user tags with #000000 / #FFFFFF use luminance / fill color.
Color tagIconOnFilledTagColor(Color tagFill, {bool syntheticNoTags = false}) {
  if (tagColorIsYellowFamily(tagFill)) return kTagYellowText;
  final rgb = tagFill.toARGB32() & 0xFFFFFF;
  if (syntheticNoTags) {
    if (rgb == 0x000000) return Colors.white;
    if (rgb == 0xFFFFFF) return Colors.black;
  }
  if (tagFill.computeLuminance() < 0.45) return Colors.white;
  return tagFill;
}

/// Letter chip plate: black solid, yellow 16%, pink 16%, orange 22%.
Color tagLetterChipPlate(Color tagColor, Color surface) {
  if (tagColorIsBlack(tagColor)) return Colors.black;
  if (tagColorIsYellowFamily(tagColor)) {
    return Color.alphaBlend(
      kTagYellowGold.withValues(alpha: kTagYellowPlateOpacity),
      surface,
    );
  }
  if (tagColorIsCanonicalPink(tagColor)) {
    return Color.alphaBlend(
      tagColor.withValues(alpha: kTagPinkPlateOpacity), surface,
    );
  }
  if (tagColorIsCanonicalOrange(tagColor)) {
    return Color.alphaBlend(
      tagColor.withValues(alpha: kTagOrangePlateOpacity), surface,
    );
  }
  return Color.alphaBlend(tagColor.withValues(alpha: 0.26), surface);
}

/// Letter chip border: black solid; yellow 74%; pink 60%; orange 78%; others 55%.
Color tagLetterChipBorder(Color tagColor, Color surface) {
  if (tagColorIsBlack(tagColor)) return Colors.black;
  if (tagColorIsYellowFamily(tagColor)) {
    return Color.alphaBlend(
      kTagYellowGold.withValues(alpha: kTagYellowBorderOpacity), surface,
    );
  }
  if (tagColorIsCanonicalPink(tagColor)) {
    return Color.alphaBlend(
      tagColor.withValues(alpha: kTagPinkBorderOpacity), surface,
    );
  }
  if (tagColorIsCanonicalOrange(tagColor)) {
    return Color.alphaBlend(
      tagColor.withValues(alpha: kTagOrangeBorderOpacity), surface,
    );
  }
  return Color.alphaBlend(tagColor.withValues(alpha: 0.55), surface);
}

/// Empty chip stadium fill: black solid; yellow 16%; pink 16%; orange 22%; others 26%.
Color tagEmptyChipFill(Color tagColor, Color surface) {
  if (tagColorIsBlack(tagColor)) return Colors.black;
  if (tagColorIsYellowFamily(tagColor)) {
    return Color.alphaBlend(
      kTagYellowGold.withValues(alpha: kTagYellowPlateOpacity),
      surface,
    );
  }
  if (tagColorIsCanonicalPink(tagColor)) {
    return tagColor.withValues(alpha: kTagPinkPlateOpacity);
  }
  if (tagColorIsCanonicalOrange(tagColor)) {
    return tagColor.withValues(alpha: kTagOrangePlateOpacity);
  }
  return tagColor.withValues(alpha: 0.26);
}

Color tagEmptyChipBorderColor(Color tagColor) {
  if (tagColorIsBlack(tagColor)) return Colors.black;
  if (tagColorIsYellowFamily(tagColor)) {
    return kTagYellowGold.withValues(alpha: kTagYellowBorderOpacity);
  }
  if (tagColorIsCanonicalPink(tagColor)) {
    return tagColor.withValues(alpha: kTagPinkBorderOpacity);
  }
  if (tagColorIsCanonicalOrange(tagColor)) {
    return tagColor.withValues(alpha: kTagOrangeBorderOpacity);
  }
  return tagColor.withValues(alpha: 0.55);
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
/// Color displayed for an existing Tag. Old planning "urgent" records were
/// frequently saved as neutral gray before black was a selectable preset.
/// Restore black only for those neutral/empty values, never for a custom
/// colored urgent tag. This does not mutate user data in PocketBase.
Color? parseTagDisplayColor(String? savedHex, {required String tagName}) {
  final saved = parseTagHexColor(savedHex);
  if (tagName.trim().toLowerCase() != 'urgent') return saved;
  if (saved == null) return Colors.black;
  final argb = saved.toARGB32();
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  final neutral = (r - g).abs() <= 2 && (g - b).abs() <= 2;
  return neutral && r < 215 ? Colors.black : saved;
}
