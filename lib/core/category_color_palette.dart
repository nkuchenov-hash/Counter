// ---------------------------------------------------------------------------
// Extended Material ramps for category [color_value] (Flutter Color.value → PB number).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Custom neutral → true black ramp (Material-style keys 50–900).
const MaterialColor kCategoryBlackMaterial = MaterialColor(
  0xFF424242,
  <int, Color>{
    50: Color(0xFFF7F7F7),
    100: Color(0xFFE8E8E8),
    200: Color(0xFFD0D0D0),
    300: Color(0xFFB0B0B0),
    400: Color(0xFF888888),
    500: Color(0xFF424242),
    600: Color(0xFF383838),
    700: Color(0xFF2C2C2C),
    800: Color(0xFF1A1A1A),
    900: Color(0xFF000000),
  },
);

/// All hues shown in category color pickers (primaries + grey, brown, pink, black ramp).
final List<MaterialColor> kCategoryPickerMaterialColors = <MaterialColor>[
  ...Colors.primaries,
  Colors.grey,
  Colors.brown,
  Colors.pink,
  kCategoryBlackMaterial,
];

List<int> categoryMaterialShadeValues(MaterialColor c) => <int>[
      c[50]!.value,
      c[100]!.value,
      c[200]!.value,
      c[300]!.value,
      c[400]!.value,
      c[500]!.value,
      c[600]!.value,
      c[700]!.value,
      c[800]!.value,
      c[900]!.value,
    ];

MaterialColor categoryMaterialPrimaryForValue(int? v) {
  if (v == null) return Colors.blue;
  for (final p in kCategoryPickerMaterialColors) {
    if (categoryMaterialShadeValues(p).contains(v)) return p;
  }
  return Colors.blue;
}
