import 'package:flutter/material.dart';

import 'package:counter/l10n/dictionary.dart' as app_dictionary;

const _nativeNameKey = 'locale_native_name';

/// Locales backed by full `l10n` maps in [app_dictionary.l10n] (not a hardcoded global list).
List<String> supportedUiLanguageCodes() {
  final codes = app_dictionary.l10n.keys.toList();
  _sortUiLanguageCodes(codes);
  return codes;
}

void _sortUiLanguageCodes(List<String> codes) {
  const order = <String, int>{'en': 0, 'ru': 1};
  codes.sort((a, b) {
    final oa = order[a] ?? 99;
    final ob = order[b] ?? 99;
    if (oa != ob) return oa.compareTo(ob);
    return a.compareTo(b);
  });
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
  supportedUiLanguageCodes().map(materialLocaleForUiLanguageCode).toList(),
);

/// Single stable [Locale] for a storage language code (`en`/`ru`/…).
Locale materialLocaleForUiLanguageCode(String code) {
  switch (code) {
    case 'en':
      return const Locale('en', 'US');
    case 'ru':
      return const Locale('ru', 'RU');
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
