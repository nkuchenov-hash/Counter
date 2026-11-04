import 'package:flutter/material.dart';

/// The canonical People / Meeting color family for Life OS.
/// Used by both category presets and tag presets. Its magenta hue is deliberately
/// separated from the red Entertainment / Task family.
const MaterialColor kNordicPeople = MaterialColor(0xFFBD4199, <int, Color>{
  50: Color(0xFFFCF2F9), 100: Color(0xFFF7E2F1), 200: Color(0xFFECC1DF),
  300: Color(0xFFE099C9), 400: Color(0xFFD06EB2), 500: Color(0xFFBD4199),
  600: Color(0xFFA93689), 700: Color(0xFF8E2F73), 800: Color(0xFF72295C),
  900: Color(0xFF5D234B),
});

/// Only the official historical People family values are mapped. This is a
/// display-layer compatibility mapping: it does not mutate stored data and
/// leaves other user-selected/custom hex colors unchanged.
const Map<int, int> _legacyPeopleShadeTones = <int, int>{
  0xFFFCF2F5: 50,
  0xFFF8E2E9: 100,
  0xFFF0C6D2: 200,
  0xFFE49DB1: 300,
  0xFFD87995: 400,
  0xFFD05C7D: 500,
  0xFFB94C6B: 600,
  0xFF9B405B: 700,
  0xFF7F374D: 800,
  0xFF693040: 900,
};

/// Shared for category rendering, tag chip rendering, and color pickers.
int canonicalLifeColorValue(int savedArgb) {
  final tone = _legacyPeopleShadeTones[savedArgb];
  return tone == null ? savedArgb : kNordicPeople[tone]!.toARGB32();
}
