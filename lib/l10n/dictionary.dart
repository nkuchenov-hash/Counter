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

const Map<String, String> _healthAndGapEn = {
  'health_connect_title': 'Sleep synchronization',
  'health_connect_subtitle':
      'Import completed sleep into Timeline from server and device sources.',
  'sleep_cloud_title': 'Server synchronization',
  'sleep_cloud_subtitle':
      'Runs on the Life OS server even when web, desktop and mobile apps are closed.',
  'sleep_cloud_google_fit': 'Google Fit',
  'sleep_cloud_connect_google': 'Connect Google Fit',
  'sleep_cloud_enable': 'Automatic server synchronization',
  'sleep_cloud_enable_hint':
      'PocketBase checks for completed sleep every evening.',
  'sleep_cloud_daily_time_hint':
      'Server time in your Life OS profile timezone. Default: 21:00.',
  'sleep_cloud_disconnect': 'Disconnect',
  'sleep_cloud_status_disconnected': 'Not connected',
  'sleep_cloud_status_connecting': 'Waiting for Google authorization',
  'sleep_cloud_status_active': 'Automatic synchronization active',
  'sleep_cloud_status_paused': 'Connected, automatic synchronization paused',
  'sleep_cloud_status_syncing': 'Server is synchronizing sleep…',
  'sleep_cloud_status_error': 'Server synchronization failed',
  'sleep_cloud_server_not_deployed':
      'The server sleep-sync module has not been deployed yet.',
  'sleep_local_title': 'Device synchronization',
  'sleep_local_subtitle':
      'Optional local source for Health Connect on Android or Apple Health on iPhone.',
  'health_connect_enable': 'Synchronize sleep from this device',
  'health_connect_sync_now': 'Sync now',
  'health_connect_enable_background': 'Enable scheduled device sync',
  'sleep_sync_daily_time': 'Daily synchronization time',
  'sleep_sync_daily_time_hint':
      'Runs without opening the app. The operating system may delay it to save battery.',
  'sleep_sync_device_source': 'Device source: %s',
  'sleep_sync_cloud_note':
      'Connected cloud providers can use the server scheduler.',
  'health_connect_status_disabled': 'Disabled',
  'health_connect_status_unavailable':
      'No supported local sleep source on this device',
  'health_connect_status_permission': 'Sleep permission is required',
  'health_connect_status_idle': 'Ready to synchronize',
  'health_connect_status_syncing': 'Synchronizing sleep…',
  'health_connect_status_synced': 'Synchronized',
  'health_connect_status_no_data':
      'No completed sleep sessions found in connected sources',
  'health_connect_status_error': 'Synchronization failed',
  'health_connect_background_active': 'Daily device sync active',
  'health_connect_background_permission':
      'Scheduled device access has not been granted',
  'health_connect_result': '%s found · %s imported',
  'health_connect_source': 'Source: %s',
  'health_sleep_record_title': 'Sleep',
  'unfilled_time_notifications_title': 'Unfilled time',
  'unfilled_time_notifications_subtitle':
      'Optional notifications for gaps anywhere in the timeline.',
  'unfilled_time_notifications_enable': 'Notify about unfilled gaps',
  'unfilled_time_min_gap': 'Minimum gap',
  'unfilled_time_delay': 'Notification delay',
  'unfilled_time_delay_immediately': 'Immediately',
  'unfilled_time_minutes': '%s min',
  'unfilled_time_banner': 'Unfilled time',
  'unfilled_time_fill': 'Fill',
  'unfilled_time_sheet_title': 'What happened during this time?',
  'unfilled_time_activity_hint': 'Activity or event',
  'unfilled_time_notification_title': 'Life OS: unfilled time',
  'unfilled_time_notification_body':
      '%s minutes are missing from your timeline.',
};

const Map<String, String> _healthAndGapRu = {
  'health_connect_title': 'Синхронизация сна',
  'health_connect_subtitle':
      'Импорт завершённого сна в Timeline из серверных и локальных источников.',
  'sleep_cloud_title': 'Серверная синхронизация',
  'sleep_cloud_subtitle':
      'Работает на сервере Life OS, даже когда web, desktop и мобильное приложение закрыты.',
  'sleep_cloud_google_fit': 'Google Fit',
  'sleep_cloud_connect_google': 'Подключить Google Fit',
  'sleep_cloud_enable': 'Автоматическая серверная синхронизация',
  'sleep_cloud_enable_hint':
      'PocketBase каждый вечер проверяет завершённые сессии сна.',
  'sleep_cloud_daily_time_hint':
      'Сервер использует часовой пояс профиля Life OS. По умолчанию — 21:00.',
  'sleep_cloud_disconnect': 'Отключить',
  'sleep_cloud_status_disconnected': 'Не подключено',
  'sleep_cloud_status_connecting': 'Ожидание авторизации Google',
  'sleep_cloud_status_active': 'Автоматическая синхронизация включена',
  'sleep_cloud_status_paused':
      'Источник подключён, автоматическая синхронизация приостановлена',
  'sleep_cloud_status_syncing': 'Сервер синхронизирует сон…',
  'sleep_cloud_status_error': 'Ошибка серверной синхронизации',
  'sleep_cloud_server_not_deployed':
      'Серверный модуль синхронизации сна ещё не развёрнут.',
  'sleep_local_title': 'Синхронизация через устройство',
  'sleep_local_subtitle':
      'Дополнительный локальный источник: Health Connect на Android или Apple Health на iPhone.',
  'health_connect_enable': 'Синхронизировать сон с этого устройства',
  'health_connect_sync_now': 'Синхронизировать сейчас',
  'health_connect_enable_background':
      'Включить синхронизацию устройства по расписанию',
  'sleep_sync_daily_time': 'Время ежедневной синхронизации',
  'sleep_sync_daily_time_hint':
      'Запускается без открытия приложения. ОС может выполнить задачу позже для экономии батареи.',
  'sleep_sync_device_source': 'Локальный источник: %s',
  'sleep_sync_cloud_note':
      'Подключённые облачные провайдеры могут использовать серверный планировщик.',
  'health_connect_status_disabled': 'Выключено',
  'health_connect_status_unavailable':
      'На этом устройстве нет поддерживаемого локального источника сна',
  'health_connect_status_permission': 'Нужно разрешение на чтение сна',
  'health_connect_status_idle': 'Готово к синхронизации',
  'health_connect_status_syncing': 'Синхронизация сна…',
  'health_connect_status_synced': 'Синхронизировано',
  'health_connect_status_no_data':
      'В подключённых источниках нет завершённых сессий сна',
  'health_connect_status_error': 'Ошибка синхронизации',
  'health_connect_background_active':
      'Ежедневная синхронизация устройства включена',
  'health_connect_background_permission':
      'Нет разрешения на синхронизацию устройства по расписанию',
  'health_connect_result': 'Найдено: %s · импортировано: %s',
  'health_connect_source': 'Источник: %s',
  'health_sleep_record_title': 'Сон',
  'unfilled_time_notifications_title': 'Незаполненное время',
  'unfilled_time_notifications_subtitle':
      'Необязательные уведомления о любых пробелах в Timeline.',
  'unfilled_time_notifications_enable': 'Уведомлять о пробелах',
  'unfilled_time_min_gap': 'Минимальный промежуток',
  'unfilled_time_delay': 'Задержка уведомления',
  'unfilled_time_delay_immediately': 'Сразу',
  'unfilled_time_minutes': '%s мин',
  'unfilled_time_banner': 'Не заполнено',
  'unfilled_time_fill': 'Заполнить',
  'unfilled_time_sheet_title': 'Что происходило в это время?',
  'unfilled_time_activity_hint': 'Действие или событие',
  'unfilled_time_notification_title': 'Life OS: время не заполнено',
  'unfilled_time_notification_body': 'В Timeline пропущено %s минут.',
};

/// Voice Vault: locale state + assembled translation catalog.
/// Canonical EN/RU strings live in [kEnL10n] / [kRuL10n] (`lib/l10n/langs/`).
/// Other locales layer on English via [_layerOnEnglish].

final ValueNotifier<String> currentLocale = ValueNotifier<String>('en');

final Map<String, String> _englishCatalog = Map<String, String>.unmodifiable({
  ...kEnL10n,
  ..._planningAutoPlacementEn,
  ..._healthAndGapEn,
});

final Map<String, String> _russianCatalog = Map<String, String>.unmodifiable({
  ...kRuL10n,
  ..._planningAutoPlacementRu,
  ..._healthAndGapRu,
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
