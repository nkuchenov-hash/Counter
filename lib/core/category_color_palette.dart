import 'package:flutter/material.dart';
import 'package:counter/core/tag_contrast.dart' show kTagYellowGold;
import 'package:counter/core/life_color_compat.dart';
export 'package:counter/core/life_color_compat.dart' show kNordicErrands, kNordicEntertainment, kNordicPeople, canonicalLifeColorValue;

// LIFE OS semantic color families. Shared by every category screen and by
// the tag creation palette; persisted custom colors always remain authoritative.
//
// New categories: root = 600, child = 500, grandchild+ = 400. The picker
// exposes only those three legible tones (not 50..900 near-white/near-black).
// Existing stored values are still recognized to prevent data migration.

const MaterialColor kNordicWork = MaterialColor(0xFF286BE3, <int, Color>{
  50: Color(0xFFF2F6FD),   100: Color(0xFFE3ECFB),   200: Color(0xFFC7D9F8),
  300: Color(0xFF9EBCF2),   400: Color(0xFF6B99EC),   500: Color(0xFF286BE3),
  600: Color(0xFF235EC8),   700: Color(0xFF1D4EA6),   800: Color(0xFF183F86),
  900: Color(0xFF122F64),
});
const MaterialColor kNordicFood = MaterialColor(0xFFF6C500, <int, Color>{
  50: Color(0xFFFEFCF0),   100: Color(0xFFFEF7DE),   200: Color(0xFFFDF0BD),
  300: Color(0xFFFBE58C),   400: Color(0xFFF9D74F),   500: Color(0xFFF6C500),
  600: Color(0xFFD8AD00),   700: Color(0xFFB49000),   800: Color(0xFF917400),
  900: Color(0xFF6C5700),
});
const MaterialColor kNordicMovement = MaterialColor(0xFF56A235, <int, Color>{
  50: Color(0xFFF5F9F3),   100: Color(0xFFE9F3E5),   200: Color(0xFFD3E7CA),
  300: Color(0xFFB3D5A4),   400: Color(0xFF8ABF74),   500: Color(0xFF56A235),
  600: Color(0xFF4C8F2F),   700: Color(0xFF3F7627),   800: Color(0xFF33601F),
  900: Color(0xFF264717),
});
const MaterialColor kNordicHealth = MaterialColor(0xFF008B83, <int, Color>{
  50: Color(0xFFF0F8F8),   100: Color(0xFFDEF0EF),   200: Color(0xFFBDE1DF),
  300: Color(0xFF8CCBC7),   400: Color(0xFF4FAFA9),   500: Color(0xFF008B83),
  600: Color(0xFF007A73),   700: Color(0xFF006560),   800: Color(0xFF00524D),
  900: Color(0xFF003D3A),
});
const MaterialColor kNordicTransport = MaterialColor(0xFF55BCE7, <int, Color>{
  50: Color(0xFFF5FBFE),   100: Color(0xFFE9F6FC),   200: Color(0xFFD3EEF9),
  300: Color(0xFFB3E1F4),   400: Color(0xFF8AD1EE),   500: Color(0xFF55BCE7),
  600: Color(0xFF4BA5CB),   700: Color(0xFF3E89A9),   800: Color(0xFF326F88),
  900: Color(0xFF255366),
});
const MaterialColor kNordicStudy = MaterialColor(0xFF242B5D, <int, Color>{
  50: Color(0xFFF2F2F5),   100: Color(0xFFE3E3EA),   200: Color(0xFFC6C8D5),
  300: Color(0xFF9CA0B6),   400: Color(0xFF686D8F),   500: Color(0xFF242B5D),
  600: Color(0xFF202652),   700: Color(0xFF1A1F44),   800: Color(0xFF151937),
  900: Color(0xFF101329),
});
// Achromatic neutral: R == G == B at every tone (no blue or beige cast).
const MaterialColor kCategoryNeutral = MaterialColor(0xFF606060, <int, Color>{
  50: Color(0xFFF5F5F5),   100: Color(0xFFEAEAEA),   200: Color(0xFFD6D6D6),
  300: Color(0xFFB7B7B7),   400: Color(0xFF919191),   500: Color(0xFF606060),
  600: Color(0xFF545454),   700: Color(0xFF464646),   800: Color(0xFF393939),
  900: Color(0xFF2A2A2A),
});

/// Ordered for category creation and the appearance picker.
/// Grey is intentionally last: it is neutral/list/system, not a life-domain hue.
const List<MaterialColor> kCategoryPickerMaterialColors = <MaterialColor>[
  kNordicWork,
  kNordicErrands,
  kNordicFood,
  kNordicMovement,
  kNordicHealth,
  kNordicTransport,
  kNordicStudy,
  kNordicEntertainment,
  kNordicPeople,
  kCategoryNeutral,
];

/// The only user-selectable intensities. More levels reuse 400 rather than
/// fading into invisible pastel against white cards.
const List<int> kCategorySelectableTones = <int>[400, 500, 600];

/// Existing older category values stay valid and retain their hue/family.
const List<int> _categoryTones = <int>[
  50, 100, 200, 300, 400, 500, 600, 700, 800, 900,
];

/// [depth] is zero for a root, one for its direct children, etc.
/// Never use sibling order to determine intensity: siblings share a level.
int categoryToneForDepth(int depth) {
  if (depth <= 0) return 600;
  if (depth == 1) return 500;
  return 400;
}

int categoryColorAtDepth(MaterialColor family, int depth) =>
    family[categoryToneForDepth(depth)]!.toARGB32();

List<int> categoryMaterialShadeValues(MaterialColor c) =>
    _categoryTones.map((tone) => c[tone]!.toARGB32()).toList(growable: false);

MaterialColor categoryMaterialPrimaryForValue(int? v) {
  if (v == null) return kNordicWork;
  v = canonicalLifeColorValue(v);
  for (final family in kCategoryPickerMaterialColors) {
    if (categoryMaterialShadeValues(family).contains(v)) return family;
  }

  // An older custom color may not be a literal Nordic shade. Respect its
  // semantic hue when a NEW child is created; never turn it blue by default.
  final saved = HSLColor.fromColor(Color(v));
  if (saved.saturation < 0.12) return kCategoryNeutral;
  var closest = kNordicWork;
  var bestDistance = double.infinity;
  for (final family in kCategoryPickerMaterialColors) {
    if (family == kCategoryNeutral) continue;
    final candidate = HSLColor.fromColor(family[500]!);
    final difference = (candidate.hue - saved.hue).abs();
    final hueDistance = difference > 180 ? 360 - difference : difference;
    if (hueDistance < bestDistance) {
      bestDistance = hueDistance;
      closest = family;
    }
  }
  return closest;
}

/// Root categories cycle through semantic families. Neutral is reserved for
/// lists/system/uncategorized; it is not assigned as a new root automatically.
int categoryNordicRootColorValue(int siblingIndex) {
  final families = kCategoryPickerMaterialColors.sublist(
    0,
    kCategoryPickerMaterialColors.length - 1,
  );
  return categoryColorAtDepth(families[siblingIndex % families.length], 0);
}

/// Inherit the parent hue and descend ONE step of visible intensity; sibling
/// position no longer alters color. At 400 we stop: lighter is illegible.
int categoryNordicChildColorValue(int? parentColorValue, int siblingIndex) {
  final family = categoryMaterialPrimaryForValue(parentColorValue);
  if (parentColorValue != null) {
    parentColorValue = canonicalLifeColorValue(parentColorValue);
  }
  final shade = _categoryTones.firstWhere(
    (tone) => family[tone]!.toARGB32() == parentColorValue,
    orElse: () => 600,
  );
  final childTone = shade >= 600 ? 500 : 400;
  return family[childTone]!.toARGB32();
}

/// Used by tag pickers. Preserves exact gold (#F6C500), its special contrast
/// treatment, and the existing tag hex strings in PocketBase. Other presets
/// use the SAME canonical families as category creation. Old tag colors remain
/// valid; this list only controls NEW color choices.
List<String> get kLifeTagColorPresets => List<String>.unmodifiable([
  for (final family in kCategoryPickerMaterialColors)
    _categoryColorHex(
      family == kNordicFood ? kTagYellowGold : family[500]!,
    ),
]);

String _categoryColorHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
