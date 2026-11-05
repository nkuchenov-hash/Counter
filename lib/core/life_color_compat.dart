import 'package:flutter/material.dart';

/// Canonical red, orange and pink families, shared between category and tag
/// presets. These three are spaced apart perceptually on both solid swatches
/// and translucent planner chips. Pink is pink, not magenta/purple.
const MaterialColor kNordicErrands = MaterialColor(0xFFE8700A, <int, Color>{
  50: Color(0xFFFEF7EE), 100: Color(0xFFFCE8D2), 200: Color(0xFFF9CE9F),
  300: Color(0xFFF3AC6A), 400: Color(0xFFED903A), 500: Color(0xFFE8700A),
  600: Color(0xFFCC6309), 700: Color(0xFFAA5207), 800: Color(0xFF8A4306),
  900: Color(0xFF663105),
});

const MaterialColor kNordicEntertainment = MaterialColor(0xFFC82332, <int, Color>{
  50: Color(0xFFFDF1F2), 100: Color(0xFFF9DFE2), 200: Color(0xFFF2BDC3),
  300: Color(0xFFE88F99), 400: Color(0xFFDC5F70), 500: Color(0xFFC82332),
  600: Color(0xFFB3202E), 700: Color(0xFF961F2A), 800: Color(0xFF7A1F27),
  900: Color(0xFF621D24),
});

const MaterialColor kNordicPeople = MaterialColor(0xFFE65EA5, <int, Color>{
  50: Color(0xFFFEF3F9), 100: Color(0xFFFCE4F0), 200: Color(0xFFF8C9E1),
  300: Color(0xFFF1A1CA), 400: Color(0xFFEB7CB6), 500: Color(0xFFE65EA5),
  600: Color(0xFFC9438D), 700: Color(0xFFA93476), 800: Color(0xFF892C63),
  900: Color(0xFF702653),
});

/// Official previous semantic-family shades. Compatibility is visual only:
/// old records keep their stored HEX/ARGB values, while tags, categories and
/// color pickers all display the corresponding current family shade.
/// Unrelated custom colors and exact gold #F6C500 are unaffected.
const Map<int, int> _legacyOrangeTones = <int, int>{
  0xFFFDF5F0: 50, 0xFFF9E8DD: 100, 0xFFF2D0BB: 200,
  0xFFEAB18E: 300, 0xFFE09163: 400, 0xFFD97841: 500,
  0xFFC66A36: 600, 0xFFA95730: 700, 0xFF8A482B: 800,
  0xFF713D27: 900,
};

const Map<int, int> _legacyRedTones = <int, int>{
  0xFFFDF2F2: 50, 0xFFF9E1E2: 100, 0xFFF3C4C6: 200,
  0xFFE99B9F: 300, 0xFFDF7277: 400, 0xFFD64F55: 500,
  0xFFC03F46: 600, 0xFFA2353B: 700, 0xFF842F34: 800,
  0xFF6D2A2E: 900,
};

const Map<int, int> _legacyPinkTones = <int, int>{
  0xFFFCF2F5: 50, 0xFFF8E2E9: 100, 0xFFF0C6D2: 200,
  0xFFE49DB1: 300, 0xFFD87995: 400, 0xFFD05C7D: 500,
  0xFFB94C6B: 600, 0xFF9B405B: 700, 0xFF7F374D: 800,
  0xFF693040: 900,
};

// Historical official shades from all remaining Nordic families are mapped
// to the current shared palette without changing persisted values.
const Map<int, int> _legacyNordicWorkTones = <int, int>{
  0xFFF1F6FC: 50, 0xFFE2ECF8: 100, 0xFFC7DDF2: 200,
  0xFFA2C6E9: 300, 0xFF72A5D9: 400, 0xFF3978C5: 500,
  0xFF326BAF: 600, 0xFF2B5C98: 700, 0xFF254D7E: 800,
  0xFF203F66: 900
};

const Map<int, int> _legacyNordicFoodTones = <int, int>{
  0xFFFCF8E9: 50, 0xFFF7EFCB: 100, 0xFFEFE09D: 200,
  0xFFE5CC68: 300, 0xFFDDB747: 400, 0xFFD5A62E: 500,
  0xFFBD8F26: 600, 0xFF9D7324: 700, 0xFF805C24: 800,
  0xFF694B22: 900
};

const Map<int, int> _legacyNordicMovementTones = <int, int>{
  0xFFEEF8F3: 50, 0xFFDCEFE5: 100, 0xFFBCE0CC: 200,
  0xFF91CCAA: 300, 0xFF61B386: 400, 0xFF3A9B6F: 500,
  0xFF338962: 600, 0xFF2D7455: 700, 0xFF285F49: 800,
  0xFF224E3D: 900
};

const Map<int, int> _legacyNordicHealthTones = <int, int>{
  0xFFEDF9F8: 50, 0xFFD7F1EF: 100, 0xFFAFE2DF: 200,
  0xFF7BCDC9: 300, 0xFF49B8B4: 400, 0xFF26A5A1: 500,
  0xFF208F8C: 600, 0xFF207674: 700, 0xFF205F5E: 800,
  0xFF1D4E4D: 900
};

const Map<int, int> _legacyNordicTransportTones = <int, int>{
  0xFFF0F8FC: 50, 0xFFDDEFF8: 100, 0xFFBDE0F0: 200,
  0xFF91CBE5: 300, 0xFF69B5DA: 400, 0xFF55A6D1: 500,
  0xFF418EB8: 600, 0xFF39779A: 700, 0xFF33627D: 800,
  0xFF2D5066: 900
};

const Map<int, int> _legacyNordicStudyTones = <int, int>{
  0xFFF5F3FA: 50, 0xFFEAE6F5: 100, 0xFFD6CEEA: 200,
  0xFFB9ACDB: 300, 0xFF9685C9: 400, 0xFF725EB5: 500,
  0xFF6552A3: 600, 0xFF55458A: 700, 0xFF473A70: 800,
  0xFF3B305D: 900
};

const Map<int, int> _legacyCategoryNeutralTones = <int, int>{
  0xFFFAFAFA: 50, 0xFFF5F5F5: 100, 0xFFEBEBEB: 200,
  0xFFD9D9D9: 300, 0xFFB8B8B8: 400, 0xFF949494: 500,
  0xFF737373: 600, 0xFF5E5E5E: 700, 0xFF484848: 800,
  0xFF333333: 900
};

int canonicalLifeColorValue(int savedArgb) {
  final tonekNordicWork = _legacyNordicWorkTones[savedArgb];
  if (tonekNordicWork != null) return kNordicWork[tonekNordicWork]!.toARGB32();
  final tonekNordicFood = _legacyNordicFoodTones[savedArgb];
  if (tonekNordicFood != null) return kNordicFood[tonekNordicFood]!.toARGB32();
  final tonekNordicMovement = _legacyNordicMovementTones[savedArgb];
  if (tonekNordicMovement != null) return kNordicMovement[tonekNordicMovement]!.toARGB32();
  final tonekNordicHealth = _legacyNordicHealthTones[savedArgb];
  if (tonekNordicHealth != null) return kNordicHealth[tonekNordicHealth]!.toARGB32();
  final tonekNordicTransport = _legacyNordicTransportTones[savedArgb];
  if (tonekNordicTransport != null) return kNordicTransport[tonekNordicTransport]!.toARGB32();
  final tonekNordicStudy = _legacyNordicStudyTones[savedArgb];
  if (tonekNordicStudy != null) return kNordicStudy[tonekNordicStudy]!.toARGB32();
  final tonekCategoryNeutral = _legacyCategoryNeutralTones[savedArgb];
  if (tonekCategoryNeutral != null) return kCategoryNeutral[tonekCategoryNeutral]!.toARGB32();
  final orangeTone = _legacyOrangeTones[savedArgb];
  if (orangeTone != null) return kNordicErrands[orangeTone]!.toARGB32();
  final redTone = _legacyRedTones[savedArgb];
  if (redTone != null) return kNordicEntertainment[redTone]!.toARGB32();
  final pinkTone = _legacyPinkTones[savedArgb];
  if (pinkTone != null) return kNordicPeople[pinkTone]!.toARGB32();
  return savedArgb;
}
