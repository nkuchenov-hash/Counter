/// Static localization maps. Use with current language to resolve keys.
/// Keys: app_title, tab_timeline, tab_planning, tab_stats, settings, start, stop, add_task, total, logout.
class L10n {
  L10n._();

  static const Map<String, Map<String, String>> _data = {
    'en': {
      'app_title': 'LIFE OS',
      'tab_timeline': 'Timeline',
      'tab_planning': 'Planning',
      'tab_stats': 'Stats',
      'settings': 'Settings',
      'start': 'Start',
      'stop': 'Stop',
      'add_task': 'Add Task',
      'total': 'Total Time',
      'logout': 'Logout',
    },
    'ru': {
      'app_title': 'LIFE OS',
      'tab_timeline': 'Таймлайн',
      'tab_planning': 'План',
      'tab_stats': 'Статистика',
      'settings': 'Настройки',
      'start': 'Старт',
      'stop': 'Стоп',
      'add_task': 'Новая задача',
      'total': 'Всего',
      'logout': 'Выйти',
    },
  };

  /// Returns the string for [key] in [language], or fallback to 'en', or the key itself.
  static String get(String language, String key) {
    final lang = _data[language] ?? _data['en']!;
    return lang[key] ?? key;
  }

  /// All supported locale codes.
  static List<String> get supportedLocales => _data.keys.toList();
}
