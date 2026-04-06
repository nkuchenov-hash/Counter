import 'package:counter/l10n/dictionary.dart';

/// UI-only labels for [categories.name] values stored in English in PocketBase.
/// Does not alter DB payloads or matching logic — display layer only.

bool _isRussianLocale(String localeCode) {
  final base = localeCode.trim().toLowerCase().split(RegExp(r'[-_]')).first;
  return base == 'ru';
}

const Map<String, String> _enCategoryNameToRu = {
  'Work': 'Работа',
  'Meeting': 'Встречи',
  'Meetings': 'Встречи',
  'Personal': 'Личное',
  'Health': 'Здоровье',
  'Home': 'Дом',
  'Study': 'Учёба',
  'Finance': 'Финансы',
  'Travel': 'Путешествия',
  'Sport': 'Спорт',
  'Sports': 'Спорт',
  'Shopping': 'Покупки',
  'Admin': 'Администрирование',
  'Learning': 'Обучение',
  'Life': 'Жизнь',
  'Rest': 'Отдых',
  'Family': 'Семья',
  'Friends': 'Друзья',
  'Food': 'Еда',
  'Fitness': 'Фитнес',
  'Project': 'Проект',
  'Projects': 'Проекты',
};

/// Localizes one path segment (`categories.name` or leaf title).
String localizeCategoryDbSegment(String segment, String localeCode) {
  final original = segment;
  final s = segment.trim();
  if (s.isEmpty) return original;
  if (!_isRussianLocale(localeCode)) return original;

  if (s.toLowerCase() == 'uncategorized') {
    return t(localeCode, 'uncategorized');
  }

  final direct = _enCategoryNameToRu[s];
  if (direct != null) return direct;

  final lower = s.toLowerCase();
  for (final e in _enCategoryNameToRu.entries) {
    if (e.key.toLowerCase() == lower) return e.value;
  }
  return original;
}

/// Localizes a breadcrumb from [DatabaseService.getCategoryPath] (`A > B > C`).
String localizeCategoryBreadcrumbPath(String path, String localeCode) {
  if (path.trim().isEmpty) return path;
  final sep = RegExp(r'\s*>\s*');
  return path
      .split(sep)
      .map((part) => localizeCategoryDbSegment(part, localeCode))
      .join(' > ');
}
