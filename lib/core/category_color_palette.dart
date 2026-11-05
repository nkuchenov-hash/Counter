import 'package:flutter/material.dart';
import 'package:counter/core/tag_contrast.dart' show kTagYellowGold;
import 'package:counter/core/life_color_compat.dart';
export 'package:counter/core/life_color_compat.dart' show kNordicWork, kNordicErrands, kNordicFood, kNordicMovement, kNordicHealth, kNordicTransport, kNordicStudy, kNordicEntertainment, kNordicPeople, kCategoryNeutral, canonicalLifeColorValue;

// LIFE OS semantic color families. Shared by every category screen and by
// the tag creation palette; persisted custom colors always remain authoritative.
//
// New categories: root = 600, child = 500, grandchild+ = 400. The picker
// exposes only those three legible tones (not 50..900 near-white/near-black).
// Existing stored values are still recognized to prevent data migration.

// Achromatic neutral: R == G == B at every tone (no blue or beige cast).

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
