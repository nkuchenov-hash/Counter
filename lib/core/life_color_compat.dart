import 'package:flutter/material.dart';

/// LIFE OS canonical color system. All eleven families are declared here.
/// The category and tag palettes use these same MaterialColor instances.
/// Existing persisted colors are translated for display without data migration.

const MaterialColor kNordicWork = MaterialColor(0xFF286BE3, <int, Color>{
  50: Color(0xFFF2F6FD),   100: Color(0xFFE3ECFB),   200: Color(0xFFC7D9F8),
  300: Color(0xFF9EBCF2),   400: Color(0xFF6B99EC),   500: Color(0xFF286BE3),
  600: Color(0xFF235EC8),   700: Color(0xFF1D4EA6),   800: Color(0xFF183F86),
  900: Color(0xFF122F64),
});

const MaterialColor kNordicFood = MaterialColor(0xFFFFD000, <int, Color>{
  50: Color(0xFFFFFDF0),
  100: Color(0xFFFFF8D9),
  200: Color(0xFFFFF0AB),
  300: Color(0xFFFFE978),
  400: Color(0xFFFFDF40),
  500: Color(0xFFFFD000),
  600: Color(0xFFE5BB00),
  700: Color(0xFFC49E00),
  800: Color(0xFF997B00),
  900: Color(0xFF745C00),
});

const MaterialColor kNordicMovement = MaterialColor(0xFF48A130, <int, Color>{
  50: Color(0xFFF4F9F1),
  100: Color(0xFFE6F2E0),
  200: Color(0xFFCDE7C4),
  300: Color(0xFFA9D49C),
  400: Color(0xFF7CBE68),
  500: Color(0xFF48A130),
  600: Color(0xFF3D8D28),
  700: Color(0xFF327221),
  800: Color(0xFF285C1B),
  900: Color(0xFF204716),
});

const MaterialColor kNordicHealth = MaterialColor(0xFF008F87, <int, Color>{
  50: Color(0xFFF0F9F8),
  100: Color(0xFFD8F0EE),
  200: Color(0xFFB0E0DD),
  300: Color(0xFF80CEC9),
  400: Color(0xFF45B6AF),
  500: Color(0xFF008F87),
  600: Color(0xFF007B74),
  700: Color(0xFF006660),
  800: Color(0xFF00534E),
  900: Color(0xFF00403C),
});

const MaterialColor kNordicTransport = MaterialColor(0xFF47BCE9, <int, Color>{
  50: Color(0xFFF2FBFE),
  100: Color(0xFFE0F4FC),
  200: Color(0xFFBFE9F9),
  300: Color(0xFF96DCF4),
  400: Color(0xFF71CEEF),
  500: Color(0xFF47BCE9),
  600: Color(0xFF3BA4CD),
  700: Color(0xFF3086A9),
  800: Color(0xFF286B87),
  900: Color(0xFF20556B),
});

const MaterialColor kNordicStudy = MaterialColor(0xFF725EB5, <int, Color>{
  50: Color(0xFFF5F3FA),
  100: Color(0xFFEAE6F5),
  200: Color(0xFFD6CEEA),
  300: Color(0xFFB9ACDB),
  400: Color(0xFF9685C9),
  500: Color(0xFF725EB5),
  600: Color(0xFF6552A3),
  700: Color(0xFF55458A),
  800: Color(0xFF473A70),
  900: Color(0xFF3B305D),
});

const MaterialColor kCategoryNeutral = MaterialColor(0xFF9A9A9A, <int, Color>{
  50: Color(0xFFFBFBFB),
  100: Color(0xFFF6F6F6),
  200: Color(0xFFECECEC),
  300: Color(0xFFD5D5D5),
  400: Color(0xFFB9B9B9),
  500: Color(0xFF9A9A9A),
  600: Color(0xFF828282),
  700: Color(0xFF686868),
  800: Color(0xFF505050),
  900: Color(0xFF3B3B3B),
});

const MaterialColor kNordicErrands = MaterialColor(0xFFFF7900, <int, Color>{
  50: Color(0xFFFFF8EF),
  100: Color(0xFFFFEBD4),
  200: Color(0xFFFFD7A6),
  300: Color(0xFFFFBF7A),
  400: Color(0xFFFFA048),
  500: Color(0xFFFF7900),
  600: Color(0xFFE56D00),
  700: Color(0xFFBD5900),
  800: Color(0xFF964700),
  900: Color(0xFF763700),
});

const MaterialColor kNordicEntertainment = MaterialColor(0xFFEF3B3B, <int, Color>{
  50: Color(0xFFFFF3F3),
  100: Color(0xFFFFE0E0),
  200: Color(0xFFFFC0C0),
  300: Color(0xFFFF9696),
  400: Color(0xFFF66A6A),
  500: Color(0xFFEF3B3B),
  600: Color(0xFFD52F2F),
  700: Color(0xFFB62626),
  800: Color(0xFF942020),
  900: Color(0xFF731B1B),
});

const MaterialColor kNordicPeople = MaterialColor(0xFFFF79AA, <int, Color>{
  50: Color(0xFFFFF4F8),
  100: Color(0xFFFFE5EF),
  200: Color(0xFFFFCBDE),
  300: Color(0xFFFFAAC8),
  400: Color(0xFFFF92B8),
  500: Color(0xFFFF79AA),
  600: Color(0xFFE65E91),
  700: Color(0xFFBD4978),
  800: Color(0xFF963B61),
  900: Color(0xFF752E4B),
});


/// User-defined urgent/critical identity. Unlike neutral gray, its 500 tone
/// is pure black and should be available explicitly in the tag color picker.
const MaterialColor kCategoryBlack = MaterialColor(0xFF000000, <int, Color>{
  50: Color(0xFFF3F3F3), 100: Color(0xFFE2E2E2),
  200: Color(0xFFBDBDBD), 300: Color(0xFF888888),
  400: Color(0xFF424242), 500: Color(0xFF000000),
  600: Color(0xFF000000), 700: Color(0xFF000000),
  800: Color(0xFF000000), 900: Color(0xFF000000),
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

const Map<int, int> _legacyNovemberNordicErrandsTones = <int, int>{
  0xFFFEF7EE: 50,
  0xFFFCE8D2: 100,
  0xFFF9CE9F: 200,
  0xFFF3AC6A: 300,
  0xFFED903A: 400,
  0xFFE8700A: 500,
  0xFFCC6309: 600,
  0xFFAA5207: 700,
  0xFF8A4306: 800,
  0xFF663105: 900,
};

const Map<int, int> _legacyNovemberNordicFoodTones = <int, int>{
  0xFFFEFCF0: 50,
  0xFFFEF7DE: 100,
  0xFFFDF0BD: 200,
  0xFFFBE58C: 300,
  0xFFF9D74F: 400,
  0xFFF6C500: 500,
  0xFFD8AD00: 600,
  0xFFB49000: 700,
  0xFF917400: 800,
  0xFF6C5700: 900,
};

const Map<int, int> _legacyNovemberNordicMovementTones = <int, int>{
  0xFFF5F9F3: 50,
  0xFFE9F3E5: 100,
  0xFFD3E7CA: 200,
  0xFFB3D5A4: 300,
  0xFF8ABF74: 400,
  0xFF56A235: 500,
  0xFF4C8F2F: 600,
  0xFF3F7627: 700,
  0xFF33601F: 800,
  0xFF264717: 900,
};

const Map<int, int> _legacyNovemberNordicHealthTones = <int, int>{
  0xFFF0F8F8: 50,
  0xFFDEF0EF: 100,
  0xFFBDE1DF: 200,
  0xFF8CCBC7: 300,
  0xFF4FAFA9: 400,
  0xFF008B83: 500,
  0xFF007A73: 600,
  0xFF006560: 700,
  0xFF00524D: 800,
  0xFF003D3A: 900,
};

const Map<int, int> _legacyNovemberNordicTransportTones = <int, int>{
  0xFFF5FBFE: 50,
  0xFFE9F6FC: 100,
  0xFFD3EEF9: 200,
  0xFFB3E1F4: 300,
  0xFF8AD1EE: 400,
  0xFF55BCE7: 500,
  0xFF4BA5CB: 600,
  0xFF3E89A9: 700,
  0xFF326F88: 800,
  0xFF255366: 900,
};

const Map<int, int> _legacyNovemberNordicStudyTones = <int, int>{
  0xFFF2F2F5: 50,
  0xFFE3E3EA: 100,
  0xFFC6C8D5: 200,
  0xFF9CA0B6: 300,
  0xFF686D8F: 400,
  0xFF242B5D: 500,
  0xFF202652: 600,
  0xFF1A1F44: 700,
  0xFF151937: 800,
  0xFF101329: 900,
};

const Map<int, int> _legacyNovemberNordicPeopleTones = <int, int>{
  0xFFFEF3F9: 50,
  0xFFFCE4F0: 100,
  0xFFF8C9E1: 200,
  0xFFF1A1CA: 300,
  0xFFEB7CB6: 400,
  0xFFE65EA5: 500,
  0xFFC9438D: 600,
  0xFFA93476: 700,
  0xFF892C63: 800,
  0xFF702653: 900,
};

const Map<int, int> _legacyNovemberCategoryNeutralTones = <int, int>{
  0xFFF7F7F7: 50,
  0xFFEAEAEA: 100,
  0xFFD6D6D6: 200,
  0xFFB7B7B7: 300,
  0xFF919191: 400,
  0xFF606060: 500,
  0xFF545454: 600,
  0xFF464646: 700,
  0xFF393939: 800,
  0xFF2A2A2A: 900,
};

const Map<int, int> _priorScarletTones = <int, int>{
  0xFFFDF1F2: 50,
  0xFFF9DFE2: 100,
  0xFFF2BDC3: 200,
  0xFFE88F99: 300,
  0xFFDC5F70: 400,
  0xFFC82332: 500,
  0xFFB3202E: 600,
  0xFF961F2A: 700,
  0xFF7A1F27: 800,
  0xFF621D24: 900,
};

const Map<int, int> _priorPinkTones = <int, int>{
  0xFFFFF3FC: 50,
  0xFFFDE6F7: 100,
  0xFFFBC9EE: 200,
  0xFFF6A7E0: 300,
  0xFFF382D4: 400,
  0xFFF75CC5: 500,
  0xFFD647A7: 600,
  0xFFAD3585: 700,
  0xFF8D2B6C: 800,
  0xFF702459: 900,
};

/// Previous official orange shades (November palette). Persisted HEXs
/// resolve to the new vivid-orange family at display time only.
const Map<int, int> _priorOrangeTones = <int, int>{
  0xFFFFF7EF: 50,
  0xFFFFE8CF: 100,
  0xFFFFD0A1: 200,
  0xFFFFAE66: 300,
  0xFFFF8E35: 400,
  0xFFF26900: 500,
  0xFFD95C00: 600,
  0xFFB34C00: 700,
  0xFF913D00: 800,
  0xFF6E2E00: 900,
};

int canonicalLifeColorValue(int savedArgb) {

  // Current values must be stable. Exact-match historical remapping never
  // changes a freshly selected current preset or descendant shade.
  for (final family in <MaterialColor>[
    kNordicWork,
    kNordicErrands,
    kNordicFood,
    kNordicMovement,
    kNordicHealth,
    kNordicTransport,
    kNordicStudy,
    kNordicEntertainment,
    kNordicPeople,
    kCategoryBlack,
    kCategoryNeutral,
  ]) {
    for (final tone in <int>[50, 100, 200, 300, 400, 500, 600, 700, 800, 900]) {
      if (family[tone]!.toARGB32() == savedArgb) return savedArgb;
    }
  }
  final historicalNordicErrands = _legacyNovemberNordicErrandsTones[savedArgb];
  if (historicalNordicErrands != null) return kNordicErrands[historicalNordicErrands]!.toARGB32();
  final historicalNordicFood = _legacyNovemberNordicFoodTones[savedArgb];
  if (historicalNordicFood != null) return kNordicFood[historicalNordicFood]!.toARGB32();
  final historicalNordicMovement = _legacyNovemberNordicMovementTones[savedArgb];
  if (historicalNordicMovement != null) return kNordicMovement[historicalNordicMovement]!.toARGB32();
  final historicalNordicHealth = _legacyNovemberNordicHealthTones[savedArgb];
  if (historicalNordicHealth != null) return kNordicHealth[historicalNordicHealth]!.toARGB32();
  final historicalNordicTransport = _legacyNovemberNordicTransportTones[savedArgb];
  if (historicalNordicTransport != null) return kNordicTransport[historicalNordicTransport]!.toARGB32();
  final historicalNordicStudy = _legacyNovemberNordicStudyTones[savedArgb];
  if (historicalNordicStudy != null) return kNordicStudy[historicalNordicStudy]!.toARGB32();
  final historicalNordicPeople = _legacyNovemberNordicPeopleTones[savedArgb];
  if (historicalNordicPeople != null) return kNordicPeople[historicalNordicPeople]!.toARGB32();
  final historicalCategoryNeutral = _legacyNovemberCategoryNeutralTones[savedArgb];
  if (historicalCategoryNeutral != null) return kCategoryNeutral[historicalCategoryNeutral]!.toARGB32();

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
  // Official colors from the previous palette revision, not arbitrary HEX.
  final prevRedTone = _priorScarletTones[savedArgb];
  if (prevRedTone != null) return kNordicEntertainment[prevRedTone]!.toARGB32();
  final prevPinkTone = _priorPinkTones[savedArgb];
  if (prevPinkTone != null) return kNordicPeople[prevPinkTone]!.toARGB32();
  final previousOrangeTone = _priorOrangeTones[savedArgb];
  if (previousOrangeTone != null) {
    return kNordicErrands[previousOrangeTone]!.toARGB32();
  }
  final orangeTone = _legacyOrangeTones[savedArgb];
  if (orangeTone != null) return kNordicErrands[orangeTone]!.toARGB32();
  final redTone = _legacyRedTones[savedArgb];
  if (redTone != null) return kNordicEntertainment[redTone]!.toARGB32();
  final pinkTone = _legacyPinkTones[savedArgb];
  if (pinkTone != null) return kNordicPeople[pinkTone]!.toARGB32();
  return savedArgb;
}
