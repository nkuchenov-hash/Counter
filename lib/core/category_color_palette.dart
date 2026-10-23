import 'package:flutter/material.dart';

// LIFE OS semantic color families. Shared by every category screen and by
// the tag creation palette; persisted custom colors always remain authoritative.
//
// New categories: root = 600, child = 500, grandchild+ = 400. The picker
// exposes only those three legible tones (not 50..900 near-white/near-black).
// Existing stored values are still recognized to prevent data migration.

const MaterialColor kNordicWork = MaterialColor(0xFF3978C5, <int, Color>{
  50: Color(0xFFF1F6FC), 100: Color(0xFFE2ECF8), 200: Color(0xFFC7DDF2),
  300: Color(0xFFA2C6E9), 400: Color(0xFF72A5D9), 500: Color(0xFF3978C5),
  600: Color(0xFF326BAF), 700: Color(0xFF2B5C98), 800: Color(0xFF254D7E),
  900: Color(0xFF203F66),
});
const MaterialColor kNordicErrands = MaterialColor(0xFFD97841, <int, Color>{
  50: Color(0xFFFDF5F0), 100: Color(0xFFF9E8DD), 200: Color(0xFFF2D0BB),
  300: Color(0xFFEAB18E), 400: Color(0xFFE09163), 500: Color(0xFFD97841),
  600: Color(0xFFC66A36), 700: Color(0xFFA95730), 800: Color(0xFF8A482B),
  900: Color(0xFF713D27),
});
const MaterialColor kNordicFood = MaterialColor(0xFFD5A62E, <int, Color>{
  50: Color(0xFFFCF8E9), 100: Color(0xFFF7EFCB), 200: Color(0xFFEFE09D),
  300: Color(0xFFE5CC68), 400: Color(0xFFDDB747), 500: Color(0xFFD5A62E),
  600: Color(0xFFBD8F26), 700: Color(0xFF9D7324), 800: Color(0xFF805C24),
  900: Color(0xFF694B22),
});
const MaterialColor kNordicMovement = MaterialColor(0xFF3A9B6F, <int, Color>{
  50: Color(0xFFEEF8F3), 100: Color(0xFFDCEFE5), 200: Color(0xFFBCE0CC),
  300: Color(0xFF91CCAA), 400: Color(0xFF61B386), 500: Color(0xFF3A9B6F),
  600: Color(0xFF338962), 700: Color(0xFF2D7455), 800: Color(0xFF285F49),
  900: Color(0xFF224E3D),
});
const MaterialColor kNordicHealth = MaterialColor(0xFF26A5A1, <int, Color>{
  50: Color(0xFFEDF9F8), 100: Color(0xFFD7F1EF), 200: Color(0xFFAFE2DF),
  300: Color(0xFF7BCDC9), 400: Color(0xFF49B8B4), 500: Color(0xFF26A5A1),
  600: Color(0xFF208F8C), 700: Color(0xFF207674), 800: Color(0xFF205F5E),
  900: Color(0xFF1D4E4D),
});
const MaterialColor kNordicTransport = MaterialColor(0xFF55A6D1, <int, Color>{
  50: Color(0xFFF0F8FC), 100: Color(0xFFDDEFF8), 200: Color(0xFFBDE0F0),
  300: Color(0xFF91CBE5), 400: Color(0xFF69B5DA), 500: Color(0xFF55A6D1),
  600: Color(0xFF418EB8), 700: Color(0xFF39779A), 800: Color(0xFF33627D),
  900: Color(0xFF2D5066),
});
const MaterialColor kNordicStudy = MaterialColor(0xFF725EB5, <int, Color>{
  50: Color(0xFFF5F3FA), 100: Color(0xFFEAE6F5), 200: Color(0xFFD6CEEA),
  300: Color(0xFFB9ACDB), 400: Color(0xFF9685C9), 500: Color(0xFF725EB5),
  600: Color(0xFF6552A3), 700: Color(0xFF55458A), 800: Color(0xFF473A70),
  900: Color(0xFF3B305D),
});
const MaterialColor kNordicEntertainment = MaterialColor(0xFFD64F55, <int, Color>{
  50: Color(0xFFFDF2F2), 100: Color(0xFFF9E1E2), 200: Color(0xFFF3C4C6),
  300: Color(0xFFE99B9F), 400: Color(0xFFDF7277), 500: Color(0xFFD64F55),
  600: Color(0xFFC03F46), 700: Color(0xFFA2353B), 800: Color(0xFF842F34),
  900: Color(0xFF6D2A2E),
});
const MaterialColor kNordicPeople = MaterialColor(0xFFD05C7D, <int, Color>{
  50: Color(0xFFFCF2F5), 100: Color(0xFFF8E2E9), 200: Color(0xFFF0C6D2),
  300: Color(0xFFE49DB1), 400: Color(0xFFD87995), 500: Color(0xFFD05C7D),
  600: Color(0xFFB94C6B), 700: Color(0xFF9B405B), 800: Color(0xFF7F374D),
  900: Color(0xFF693040),
});
const MaterialColor kCategoryNeutral = MaterialColor(0xFF94A3B8, <int, Color>{
  50: Color(0xFFF8FAFC), 100: Color(0xFFF1F5F9), 200: Color(0xFFE2E8F0),
  300: Color(0xFFCBD5E1), 400: Color(0xFFA8B4C5), 500: Color(0xFF94A3B8),
  600: Color(0xFF7C8CA3), 700: Color(0xFF64748B), 800: Color(0xFF4B5D73),
  900: Color(0xFF334155),
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
      family == kNordicFood ? const Color(0xFFF6C500) : family[500]!,
    ),
]);

String _categoryColorHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
