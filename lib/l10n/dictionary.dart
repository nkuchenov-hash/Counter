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

const Map<String, String> _planningAutoPlacementEn = {
  'plan_auto_placement_title': 'New plans without a time',
  'plan_auto_placement_subtitle':
      'Choose how a plan is scheduled when you do not enter a time.',
  'plan_auto_placement_nearest': 'Nearest free slot',
  'plan_auto_placement_after_last': 'After the last plan',
  'plan_auto_placement_nearest_helper':
      'Today the search starts from the current time. On another date it starts from the beginning of the visible day.',
  'plan_auto_placement_after_last_helper':
      'Keeps the previous behavior. On an empty day the category default time is used when configured.',
};

const Map<String, String> _planningAutoPlacementRu = {
  'plan_auto_placement_title': 'Новые планы без времени',
  'plan_auto_placement_subtitle':
      'Выберите, куда ставить план, если время не указано.',
  'plan_auto_placement_nearest': 'Ближайшее свободное окно',
  'plan_auto_placement_after_last': 'После последнего плана',
  'plan_auto_placement_nearest_helper':
      'Сегодня поиск начинается с текущего времени. На другой дате — с начала видимого дня.',
  'plan_auto_placement_after_last_helper':
      'Сохраняет прежнее поведение. На пустом дне используется время категории, если оно настроено.',
};

/// Voice Vault: locale state + assembled translation catalog.
/// Canonical EN/RU strings live in [kEnL10n] / [kRuL10n] (`lib/l10n/langs/`).
/// Other locales layer on English via [_layerOnEnglish].

final ValueNotifier<String> currentLocale = ValueNotifier<String>('en');

final Map<String, String> _englishCatalog = Map<String, String>.unmodifiable({
  ...kEnL10n,
  ..._planningAutoPlacementEn,
});

final Map<String, String> _russianCatalog = Map<String, String>.unmodifiable({
  ...kRuL10n,
  ..._planningAutoPlacementRu,
});

Map<String, String> _layerOnEnglish(Map<String, String> partial) {
  return Map<String, String>.unmodifiable({..._englishCatalog, ...partial});
}

final Map<String, Map<String, String>> l10n =
    Map<String, Map<String, String>>.unmodifiable({
      'en': _englishCatalog,
      'ru': _russianCatalog,
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
