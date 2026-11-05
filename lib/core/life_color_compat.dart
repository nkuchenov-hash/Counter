import 'package:flutter/material.dart';

/// Canonical red, orange and pink families, shared between category and tag
/// presets. These three are spaced apart perceptually on both solid swatches
/// and translucent planner chips. Pink is pink, not magenta/purple.
const MaterialColor kNordicErrands = MaterialColor(0xFFE77A10, <int, Color>{
  50: Color(0xFFFEF7EE), 100: Color(0xFFFCE9D4), 200: Color(0xFFF8D0A6),
  300: Color(0xFFF3AD6C), 400: Color(0xFFED923B), 500: Color(0xFFE77A10),
  600: Color(0xFFC56A0D), 700: Color(0xFFA45813), 800: Color(0xFF834916),
  900: Color(0xFF693B17),
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

int canonicalLifeColorValue(int savedArgb) {
  final orangeTone = _legacyOrangeTones[savedArgb];
  if (orangeTone != null) return kNordicErrands[orangeTone]!.toARGB32();
  final redTone = _legacyRedTones[savedArgb];
  if (redTone != null) return kNordicEntertainment[redTone]!.toARGB32();
  final pinkTone = _legacyPinkTones[savedArgb];
  if (pinkTone != null) return kNordicPeople[pinkTone]!.toARGB32();
  return savedArgb;
}
