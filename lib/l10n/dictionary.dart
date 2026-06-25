import 'package:flutter/foundation.dart';

import 'package:counter/l10n/langs/ar.dart' show kArL10n;
import 'package:counter/l10n/langs/de.dart' show kDeL10n;
import 'package:counter/l10n/langs/en.dart' show kEnL10n;
import 'package:counter/l10n/langs/es.dart' show kEsL10n;
import 'package:counter/l10n/langs/fr.dart' show kFrL10n;
import 'package:counter/l10n/langs/it.dart' show kItL10n;
import 'package:counter/l10n/langs/ko.dart' show kKoL10n;
import 'package:counter/l10n/langs/ru.dart' show kRuL10n;
import 'package:counter/l10n/langs/zh.dart' show kZhL10n;

/// Voice Vault: locale state + assembled translation catalog.
/// Canonical EN/RU strings live in [kEnL10n] / [kRuL10n] (`lib/l10n/langs/`).
/// Other locales layer on English via [_layerOnEnglish].

final ValueNotifier<String> currentLocale = ValueNotifier<String>('en');

Map<String, String> _layerOnEnglish(Map<String, String> partial) {
  return Map<String, String>.unmodifiable({...kEnL10n, ...partial});
}

final Map<String, Map<String, String>> l10n =
    Map<String, Map<String, String>>.unmodifiable({
      'en': kEnL10n,
      'ru': kRuL10n,
      'ar': _layerOnEnglish(kArL10n),
      'de': _layerOnEnglish(kDeL10n),
      'es': _layerOnEnglish(kEsL10n),
      'fr': _layerOnEnglish(kFrL10n),
      'it': _layerOnEnglish(kItL10n),
      'ko': _layerOnEnglish(kKoL10n),
      'zh': _layerOnEnglish(kZhL10n),
    });

/// Safe lookup: [locale] then fallback to `en`. Returns key if missing everywhere.
String t(String locale, String key) {
  final map = l10n[locale];
  final hit = map?[key];
  if (hit != null) return hit;
  return l10n['en']?[key] ?? key;
}
