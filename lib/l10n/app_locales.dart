import 'package:flutter/material.dart';

/// One selectable UI language: [storageCode] is persisted ([UserSettings.primaryLanguage]).
/// [materialLocale] drives [MaterialApp.locale] and Flutter delegates.
class AppLocaleOption {
  const AppLocaleOption({
    required this.storageCode,
    required this.materialLocale,
    required this.nativeName,
  });

  final String storageCode;
  final Locale materialLocale;
  final String nativeName;
}

/// Major world languages — labels are **native** endonyms for the picker.
const List<AppLocaleOption> kAppLocaleOptions = <AppLocaleOption>[
  AppLocaleOption(
    storageCode: 'en',
    materialLocale: Locale('en', 'US'),
    nativeName: 'English',
  ),
  AppLocaleOption(
    storageCode: 'ru',
    materialLocale: Locale('ru', 'RU'),
    nativeName: 'Русский',
  ),
  AppLocaleOption(
    storageCode: 'es',
    materialLocale: Locale('es', 'ES'),
    nativeName: 'Español',
  ),
  AppLocaleOption(
    storageCode: 'fr',
    materialLocale: Locale('fr', 'FR'),
    nativeName: 'Français',
  ),
  AppLocaleOption(
    storageCode: 'de',
    materialLocale: Locale('de', 'DE'),
    nativeName: 'Deutsch',
  ),
  AppLocaleOption(
    storageCode: 'zh',
    materialLocale: Locale('zh', 'CN'),
    nativeName: '中文',
  ),
  AppLocaleOption(
    storageCode: 'ja',
    materialLocale: Locale('ja', 'JP'),
    nativeName: '日本語',
  ),
  AppLocaleOption(
    storageCode: 'ko',
    materialLocale: Locale('ko', 'KR'),
    nativeName: '한국어',
  ),
  AppLocaleOption(
    storageCode: 'ar',
    materialLocale: Locale('ar'),
    nativeName: 'العربية',
  ),
  AppLocaleOption(
    storageCode: 'pt',
    materialLocale: Locale('pt', 'BR'),
    nativeName: 'Português',
  ),
  AppLocaleOption(
    storageCode: 'hi',
    materialLocale: Locale('hi', 'IN'),
    nativeName: 'हिन्दी',
  ),
  AppLocaleOption(
    storageCode: 'it',
    materialLocale: Locale('it', 'IT'),
    nativeName: 'Italiano',
  ),
  AppLocaleOption(
    storageCode: 'tr',
    materialLocale: Locale('tr', 'TR'),
    nativeName: 'Türkçe',
  ),
  AppLocaleOption(
    storageCode: 'pl',
    materialLocale: Locale('pl', 'PL'),
    nativeName: 'Polski',
  ),
  AppLocaleOption(
    storageCode: 'uk',
    materialLocale: Locale('uk', 'UA'),
    nativeName: 'Українська',
  ),
  AppLocaleOption(
    storageCode: 'nl',
    materialLocale: Locale('nl', 'NL'),
    nativeName: 'Nederlands',
  ),
  AppLocaleOption(
    storageCode: 'vi',
    materialLocale: Locale('vi', 'VN'),
    nativeName: 'Tiếng Việt',
  ),
  AppLocaleOption(
    storageCode: 'th',
    materialLocale: Locale('th', 'TH'),
    nativeName: 'ไทย',
  ),
  AppLocaleOption(
    storageCode: 'id',
    materialLocale: Locale('id', 'ID'),
    nativeName: 'Bahasa Indonesia',
  ),
  AppLocaleOption(
    storageCode: 'ms',
    materialLocale: Locale('ms', 'MY'),
    nativeName: 'Bahasa Melayu',
  ),
  AppLocaleOption(
    storageCode: 'he',
    materialLocale: Locale('he', 'IL'),
    nativeName: 'עברית',
  ),
  AppLocaleOption(
    storageCode: 'el',
    materialLocale: Locale('el', 'GR'),
    nativeName: 'Ελληνικά',
  ),
  AppLocaleOption(
    storageCode: 'cs',
    materialLocale: Locale('cs', 'CZ'),
    nativeName: 'Čeština',
  ),
  AppLocaleOption(
    storageCode: 'sv',
    materialLocale: Locale('sv', 'SE'),
    nativeName: 'Svenska',
  ),
  AppLocaleOption(
    storageCode: 'da',
    materialLocale: Locale('da', 'DK'),
    nativeName: 'Dansk',
  ),
  AppLocaleOption(
    storageCode: 'fi',
    materialLocale: Locale('fi', 'FI'),
    nativeName: 'Suomi',
  ),
  AppLocaleOption(
    storageCode: 'nb',
    materialLocale: Locale('nb', 'NO'),
    nativeName: 'Norsk',
  ),
  AppLocaleOption(
    storageCode: 'ro',
    materialLocale: Locale('ro', 'RO'),
    nativeName: 'Română',
  ),
  AppLocaleOption(
    storageCode: 'hu',
    materialLocale: Locale('hu', 'HU'),
    nativeName: 'Magyar',
  ),
];

/// [MaterialApp.supportedLocales] — order matches catalog above.
final List<Locale> kAppSupportedMaterialLocales =
    kAppLocaleOptions.map((e) => e.materialLocale).toList(growable: false);

/// Picker / menu order: English, Russian, then alphabetical by native name.
List<AppLocaleOption> get appLocaleOptionsForPicker {
  final copy = List<AppLocaleOption>.from(kAppLocaleOptions);
  const top = <String, int>{'en': 0, 'ru': 1};
  copy.sort((a, b) {
    final ta = top[a.storageCode] ?? 100;
    final tb = top[b.storageCode] ?? 100;
    if (ta != tb) return ta.compareTo(tb);
    return a.nativeName.compareTo(b.nativeName);
  });
  return copy;
}

/// Normalizes persisted [language]/[primaryLanguage] to a known [storageCode].
String normalizeUiLanguageCode(String? raw) {
  final t = (raw ?? '').trim().toLowerCase();
  if (t.isEmpty) return 'en';
  for (final o in kAppLocaleOptions) {
    if (o.storageCode == t) return t;
  }
  final sep = RegExp(r'[-_]').firstMatch(t);
  final i = sep?.start ?? -1;
  if (i > 0) {
    final sub = t.substring(0, i);
    for (final o in kAppLocaleOptions) {
      if (o.storageCode == sub) return sub;
    }
  }
  return 'en';
}

/// Maps saved UI code (e.g. [currentLocale]) to a full [Locale] for [MaterialApp].
Locale materialLocaleForUiLanguage(String? raw) {
  final key = normalizeUiLanguageCode(raw);
  for (final o in kAppLocaleOptions) {
    if (o.storageCode == key) return o.materialLocale;
  }
  return const Locale('en', 'US');
}

/// Resolved option for picker subtitles / diagnostics.
AppLocaleOption? appLocaleOptionForStorageCode(String? raw) {
  final key = normalizeUiLanguageCode(raw);
  for (final o in kAppLocaleOptions) {
    if (o.storageCode == key) return o;
  }
  return null;
}
