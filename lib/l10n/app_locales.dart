import 'package:flutter/material.dart';

import 'package:counter/l10n/dictionary.dart' as app_dictionary;

const _nativeNameKey = 'locale_native_name';

/// Every language with a `l10n` entry under [app_dictionary.l10n]. Order is stable for pickers and tests.
const List<String> kRegisteredUiLanguageCodes = <String>[
  'ar',
  'de',
  'en',
  'es',
  'fr',
  'it',
  'ko',
  'ru',
  'zh',
];

/// Locales backed by [app_dictionary.l10n]; must match [kRegisteredUiLanguageCodes].
List<String> supportedUiLanguageCodes() {
  assert(() {
    for (final code in kRegisteredUiLanguageCodes) {
      if (!app_dictionary.l10n.containsKey(code)) return false;
    }
    return app_dictionary.l10n.length == kRegisteredUiLanguageCodes.length;
  }());
  return List<String>.unmodifiable(kRegisteredUiLanguageCodes);
}

/// Display name from the locale's own dictionary entry (e.g. Русский for `ru`).
String nativeUiLanguageLabel(String code) {
  final map = app_dictionary.l10n[code];
  final n = map?[_nativeNameKey];
  if (n != null && n.isNotEmpty) return n;
  return code;
}

/// Material [Locale] list for [MaterialApp.supportedLocales] and intl formatting.
final List<Locale> kAppSupportedMaterialLocales = List<Locale>.unmodifiable(
  kRegisteredUiLanguageCodes.map(materialLocaleForUiLanguageCode).toList(),
);

/// Single stable [Locale] for a storage language code (`en`/`ru`/…).
Locale materialLocaleForUiLanguageCode(String code) {
  switch (code) {
    case 'en':
      return const Locale('en', 'US');
    case 'ru':
      return const Locale('ru', 'RU');
    case 'ar':
      return const Locale('ar');
    case 'zh':
      return const Locale('zh', 'CN');
    case 'ko':
      return const Locale('ko', 'KR');
    case 'fr':
      return const Locale('fr', 'FR');
    case 'de':
      return const Locale('de', 'DE');
    case 'es':
      return const Locale('es', 'ES');
    case 'it':
      return const Locale('it', 'IT');
    default:
      return Locale(code);
  }
}

/// Alias for [materialLocaleForUiLanguageCode] (storage/UI language code → Material [Locale]).
Locale materialLocaleForUiLanguage(String code) =>
    materialLocaleForUiLanguageCode(code);

/// First supported code from [normalizeUiLanguageCode], else first locale in [l10n], else `en`.
String resolvedUiLanguageCode(String? raw) {
  final n = normalizeUiLanguageCode(raw);
  if (n != null) return n;
  final codes = supportedUiLanguageCodes();
  if (codes.isNotEmpty) return codes.first;
  return 'en';
}

/// Normalize persisted or user-entered codes to a key in [app_dictionary.l10n], or `null`.
String? normalizeUiLanguageCode(String? raw) {
  if (raw == null) return null;
  final t = raw.trim().toLowerCase();
  if (t.isEmpty) return null;
  final base = t.split(RegExp('[-_]')).first;
  final supported = supportedUiLanguageCodes();
  if (supported.contains(base)) return base;
  for (final code in supported) {
    if (base.startsWith(code) || code.startsWith(base)) return code;
  }
  return null;
}
