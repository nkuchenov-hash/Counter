import 'dart:async';
import 'dart:convert';

import 'package:counter/core/category_icon_catalog_generated.g.dart';
import 'package:counter/core/fluent_full_catalog_generated.g.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryIconChoice {
  const CategoryIconChoice(this.key, this.ru, this.en, this.group, this.synonyms);
  final String key, ru, en, group, synonyms;
}

const List<CategoryIconChoice> _legacyCategoryIconCatalog = [
  CategoryIconChoice('heart', 'Сердце', 'Heart', 'Личное', 'здоровье жизнь love health'),
  CategoryIconChoice('cake', 'Торт', 'Cake', 'Личное', 'еда праздник food birthday'),
  CategoryIconChoice('home', 'Дом', 'Home', 'Личное', 'жилье семья house'),
  CategoryIconChoice('moon', 'Луна', 'Moon', 'Личное', 'сон ночь sleep'),
  CategoryIconChoice('book', 'Книга', 'Book', 'Учёба', 'учеба школа read education'),
  CategoryIconChoice('briefcase', 'Работа', 'Briefcase', 'Работа', 'офис дело проект work'),
  CategoryIconChoice('calendar', 'Календарь', 'Calendar', 'Организация', 'дата план date'),
  CategoryIconChoice('folder', 'Папка', 'Folder', 'Организация', 'список категория directory'),
  CategoryIconChoice('clock', 'Время', 'Clock', 'Организация', 'часы расписание time'),
  CategoryIconChoice('bell', 'Уведомление', 'Bell', 'Организация', 'напоминание alert'),
  CategoryIconChoice('star', 'Звезда', 'Star', 'Организация', 'избранное важное favorite'),
  CategoryIconChoice('camera', 'Камера', 'Camera', 'Творчество', 'фото photography'),
  CategoryIconChoice('cart', 'Покупки', 'Shopping cart', 'Финансы', 'магазин расходы shopping'),
  CategoryIconChoice('lock', 'Замок', 'Lock', 'Организация', 'пароль безопасность security'),
  CategoryIconChoice('archive_box', 'Архив', 'Archive', 'Организация', 'хранение архив'),
  CategoryIconChoice('banknotes', 'Деньги', 'Cash', 'Финансы', 'наличные доход зарплата деньги'),
  CategoryIconChoice('bell_alert', 'Тревога', 'Alert bell', 'Организация', 'уведомление сигнал'),
  CategoryIconChoice('bell_snooze', 'Отложенное уведомление', 'Snoozed bell', 'Организация', 'напоминание'),
  CategoryIconChoice('bolt', 'Энергия', 'Energy', 'Личное', 'электричество молния'),
  CategoryIconChoice('bug_ant', 'Ошибка', 'Bug', 'Работа', 'насекомое баг разработка'),
  CategoryIconChoice('building_office', 'Офис', 'Office building', 'Работа', 'здание бизнес'),
  CategoryIconChoice('building_office_2', 'Небоскрёб', 'Skyscraper', 'Работа', 'город офис'),
  CategoryIconChoice('building_storefront', 'Магазин', 'Storefront', 'Финансы', 'торговля покупки'),
  CategoryIconChoice('calendar_date_range', 'Период', 'Date range', 'Организация', 'календарь даты'),
  CategoryIconChoice('calendar_days', 'День', 'Calendar day', 'Организация', 'расписание'),
  CategoryIconChoice('check_badge', 'Достижение', 'Verified badge', 'Организация', 'успех награда выполнено'),
  CategoryIconChoice('code_bracket', 'Код', 'Code', 'Работа', 'разработка программирование'),
  CategoryIconChoice('computer_desktop', 'Компьютер', 'Computer', 'Работа', 'пк ноутбук техника'),
  CategoryIconChoice('credit_card', 'Банковская карта', 'Credit card', 'Финансы', 'оплата платеж'),
  CategoryIconChoice('device_tablet', 'Планшет', 'Tablet', 'Работа', 'устройство техника'),
  CategoryIconChoice('document_chart_bar', 'Отчёт', 'Report', 'Работа', 'аналитика диаграмма'),
  CategoryIconChoice('document_check', 'Подписанный документ', 'Approved document', 'Работа', 'проверка документ'),
  CategoryIconChoice('envelope_open', 'Прочитанное письмо', 'Read mail', 'Организация', 'почта письма'),
  CategoryIconChoice('exclamation_triangle', 'Предупреждение', 'Warning', 'Организация', 'опасность ошибка'),
  CategoryIconChoice('eye_dropper', 'Пипетка', 'Eyedropper', 'Творчество', 'цвет дизайн'),
  CategoryIconChoice('face_frown', 'Грусть', 'Sad face', 'Личное', 'настроение эмоции'),
  CategoryIconChoice('film', 'Кино', 'Film', 'Творчество', 'фильм видео'),
  CategoryIconChoice('finger_print', 'Отпечаток', 'Fingerprint', 'Личное', 'биометрия безопасность'),
  CategoryIconChoice('hand_raised', 'Рука', 'Raised hand', 'Личное', 'волонтёр помощь'),
  CategoryIconChoice('hand_thumb_up', 'Нравится', 'Thumbs up', 'Личное', 'одобрение'),
  CategoryIconChoice('hand_thumb_down', 'Не нравится', 'Thumbs down', 'Личное', 'отзыв'),
  CategoryIconChoice('home_modern', 'Жилой дом', 'Residential building', 'Личное', 'дом жильё недвижимость'),
  CategoryIconChoice('inbox', 'Входящие', 'Inbox', 'Организация', 'почта'),
  CategoryIconChoice('language', 'Языки', 'Languages', 'Учёба', 'перевод иностранные'),
  CategoryIconChoice('newspaper', 'Новости', 'News', 'Организация', 'газета статьи'),
  CategoryIconChoice('paper_airplane', 'Отправка', 'Send', 'Организация', 'сообщения'),
  CategoryIconChoice('paper_clip', 'Вложения', 'Attachments', 'Организация', 'файлы скрепка'),
  CategoryIconChoice('presentation_chart_line', 'График', 'Line chart', 'Работа', 'рост статистика'),
  CategoryIconChoice('receipt_percent', 'Чек', 'Receipt', 'Финансы', 'скидка процент'),
  CategoryIconChoice('receipt_refund', 'Возврат', 'Refund', 'Финансы', 'покупки чек'),
  CategoryIconChoice('shield_exclamation', 'Безопасность', 'Security alert', 'Работа', 'защита'),
  CategoryIconChoice('sparkles', 'Идеи', 'Sparkles', 'Творчество', 'творчество магия'),
  CategoryIconChoice('speaker_wave', 'Звук', 'Audio', 'Творчество', 'музыка колонка'),
  CategoryIconChoice('ticket', 'Билет', 'Ticket', 'Личное', 'кино поездка'),
  CategoryIconChoice('wifi', 'Wi-Fi', 'Wi-Fi', 'Работа', 'сеть интернет'),
];

/// Everyday objects and activities are the primary category vocabulary.
/// Legacy icon keys remain renderable, but controls are hidden from selection.
final List<CategoryIconChoice> kCategoryIconCatalog =
    List<CategoryIconChoice>.unmodifiable([
  ..._legacyCategoryIconCatalog,
  for (final item in kHumanCategorySubjects)
    CategoryIconChoice(item.key, item.ru, item.en, item.group, item.synonyms),
]);
String _iconLabel(String key) => key.split('_')
    .map((part) => part.isEmpty ? part
        : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');

String _iconGroup(String key) {
  if (RegExp(r'work|briefcase|building|person|people|team|office').hasMatch(key)) return 'Работа';
  if (RegExp(r'money|wallet|credit|cash|coin|payment|cart|shopping|bank').hasMatch(key)) return 'Финансы';
  if (RegExp(r'book|school|academic|education|library|notebook').hasMatch(key)) return 'Учёба';
  if (RegExp(r'camera|photo|paint|brush|music|video|film|color').hasMatch(key)) return 'Творчество';
  if (RegExp(r'calendar|date|clock|folder|list|check|search|filter|archive').hasMatch(key)) return 'Организация';
  if (RegExp(r'heart|home|moon|cake|health|food|sleep').hasMatch(key)) return 'Личное';
  return 'Прочее';
}

/// Safe migration from previous family-specific icon keys to stable semantic IDs.
/// Unknown older choices are kept in local storage without a misleading remap.
const Map<String, String> kPreviousIconAliases = {
  'add': 'plus',
  'alert': 'bell',
  'book_open': 'book',
  'chat': 'chat_bubble_left',
  'checkmark_circle': 'check_circle',
  'data_bar_vertical': 'chart_bar',
  'data_pie': 'chart_pie',
  'delete': 'trash',
  'dismiss': 'x_mark',
  'document_copy': 'document_duplicate',
  'edit': 'pencil',
  'emoji_smile_slight': 'face_smile',
  'food_cake': 'cake',
  'globe': 'globe_alt',
  'hat_graduation': 'academic_cap',
  'image': 'photo',
  'lightbulb': 'light_bulb',
  'location': 'map_pin',
  'lock_closed': 'lock',
  'mail': 'envelope',
  'mic': 'microphone',
  'music_note_1': 'musical_note',
  'people': 'users',
  'person': 'user',
  'print': 'printer',
  'question_circle': 'question_mark_circle',
  'rocket': 'rocket_launch',
  'search': 'magnifying_glass',
  'settings': 'cog',
  'shield_checkmark': 'shield_check',
  'shopping_cart': 'cart',
  'text_bullet_list': 'list_bullet',
  'vehicle_truck': 'truck',
  'video': 'video_camera',
  'weather_moon': 'moon',
  'weather_sunny': 'sun',
};

/// Explicit subject whitelist: toolbar/navigation symbols cannot leak into
/// the category picker just because a backing icon exists.
const List<String> kLegacyCategorySubjectKeys = [
  // Familiar objects only. More specialized/business and UI controls
  // remain renderable for existing categories, not added to Everyday.
  'home', 'heart', 'briefcase', 'calendar', 'folder', 'clock', 'star',
  'book', 'cart', 'cake', 'moon', 'bell', 'lock', 'camera', 'wallet',
  'gift', 'phone', 'document', 'cloud', 'tag', 'trophy', 'map',
  'key', 'light_bulb', 'musical_note', 'sun', 'photo', 'paint_brush',
  'map_pin', 'shopping_bag', 'tv', 'food', 'fire', 'face_smile',
];

// Every entry presented by the picker must be a genuine Fluent UI glyph.
// Material fallback artwork remains renderable for old saved categories only.
typedef _CategoryGlyphPair = (IconData, IconData);

_CategoryGlyphPair _glyphPair(MatchedCategoryIcon icon) =>
    (icon.fluentOutline, icon.fluentFilled);

final Set<_CategoryGlyphPair> _officialFluentPairs = <_CategoryGlyphPair>{
  for (final icon in kFullFluentCategoryIcons.values) _glyphPair(icon),
};

final List<String> _everydayCandidateKeys = <String>[
  for (final item in kHumanCategorySubjects) item.key,
  ...kLegacyCategorySubjectKeys,
];

final Map<_CategoryGlyphPair, String> _everydayRepresentatives = () {
  final selected = <_CategoryGlyphPair, String>{};
  for (final key in _everydayCandidateKeys) {
    final icon = kMatchedCategoryIcons[key];
    if (icon == null) continue;
    final glyph = _glyphPair(icon);
    if (_officialFluentPairs.contains(glyph)) {
      selected.putIfAbsent(glyph, () => key);
    }
  }
  return Map<_CategoryGlyphPair, String>.unmodifiable(selected);
}();

bool isSelectableCategoryIconKey(String key) {
  final icon = kMatchedCategoryIcons[key];
  if (icon == null) return false;
  return _everydayRepresentatives[_glyphPair(icon)] == key;
}

/// The canonical *picker* ID for an old alias/full-Fluent ID, by exact
/// Regular+Filled artwork identity. Never rewrite existing category records.
final Map<_CategoryGlyphPair, String> _fluentRepresentativeKeys = {
  for (final entry in kFullFluentCategoryIcons.entries)
    _glyphPair(entry.value): entry.key,
};

String? categoryPickerRepresentative(String key) {
  final icon = kMatchedCategoryIcons[key] ?? kFullFluentCategoryIcons[key];
  if (icon == null) return null;
  final glyph = _glyphPair(icon);
  if (!_officialFluentPairs.contains(glyph)) return null;
  return _everydayRepresentatives[glyph] ??
      _fluentRepresentativeKeys[glyph];
}

/// Deliberately small human-first starter collection. The old v1 defaults
/// unintentionally selected the entire technical catalog (~100+ icons).
const List<String> kStarterCategoryIcons = [
  'dog', 'cat', 'tree', 'car', 'taxi', 'bicycle', 'person', 'family',
  'house', 'couch', 'bed', 'tv', 'washer', 'fridge', 'clothes_hanger',
  'dumbbell', 'soccer', 'sports', 'game', 'movie', 'coffee', 'pizza',
  'book_open', 'notebook', 'camera_photo', 'music', 'beach', 'mountain',
  'flowers', 'heart_health', 'walking', 'shopping_bag', 'suitcase',
  'calendar_date', 'wallet_money', 'work', 'gift_box', 'pet',
];

final List<String> kDefaultCategoryIconKeys = List<String>.unmodifiable(
  <String>{
    for (final key in kStarterCategoryIcons)
      if (categoryPickerRepresentative(key) case final String canonical)
        if (canonical.isNotEmpty) canonical,
  },
);

/// The default collections from older builds are recognizable by exact ID
/// set. Only those autogenerated sets are migrated; user-custom sets survive.
bool isLegacyAutoSelectedCollection(Iterable<String> source) {
  final keys = source.toSet();
  if (keys.isEmpty || keys.length != source.length) return false;
  const firstDefault = <String>[
    'home', 'heart', 'briefcase', 'calendar', 'folder', 'clock', 'star',
    'book', 'cart', 'cake', 'moon', 'bell', 'lock', 'camera', 'wallet',
    'gift', 'phone', 'document', 'cloud', 'tag', 'trophy', 'map',
    'key', 'light_bulb', 'pencil', 'musical_note',
  ];
  final oldIntersection = kMatchedCategoryIcons.keys.take(103).toSet();
  final oldExpanded = kMatchedCategoryIcons.keys.take(144).toSet();
  final oldAll = <String>{
    for (final item in kHumanCategorySubjects) item.key,
    ...kLegacyCategorySubjectKeys.where(kMatchedCategoryIcons.containsKey),
    ...<String>[
      'user', 'users', 'truck', 'beaker', 'globe_alt', 'house',
      'building_office', 'building_storefront', 'banknotes',
      'credit_card', 'calendar_days', 'calendar_date_range',
      'check_badge', 'computer_desktop', 'device_tablet', 'film',
      'inbox', 'newspaper', 'ticket', 'wifi', 'archive_box',
    ].where(kMatchedCategoryIcons.containsKey),
  };
  return (keys.length == firstDefault.length &&
          keys.containsAll(firstDefault)) ||
      (keys.length == oldIntersection.length &&
          keys.containsAll(oldIntersection)) ||
      (keys.length == oldExpanded.length && keys.containsAll(oldExpanded)) ||
      (keys.length == oldAll.length && keys.containsAll(oldAll));
}

const List<String> kCategorySubjectGroups = [
  'Все', 'Люди', 'Животные', 'Природа', 'Транспорт', 'Дом', 'Спорт',
  'Одежда', 'Еда', 'Увлечения', 'Учёба', 'Здоровье', 'Работа',
  'Финансы', 'Организация', 'Личное', 'Творчество', 'Прочее',
];

const Map<String, String> _groupNamesEn = {
  'Все': 'All', 'Люди': 'People', 'Животные': 'Animals',
  'Природа': 'Nature', 'Транспорт': 'Transport', 'Дом': 'Home',
  'Спорт': 'Sports', 'Одежда': 'Clothing', 'Еда': 'Food',
  'Увлечения': 'Hobbies', 'Учёба': 'Learning',
  'Здоровье': 'Health', 'Работа': 'Work', 'Финансы': 'Finance',
  'Организация': 'Planning', 'Личное': 'Personal',
  'Творчество': 'Creative', 'Прочее': 'Other',
};
String categorySubjectGroupName(String group, {required bool russian}) =>
    russian ? group : (_groupNamesEn[group] ?? group);

List<CategoryIconChoice> _buildSharedCatalog() {
  final metadata = {for (final item in kCategoryIconCatalog) item.key: item};
  return List<CategoryIconChoice>.unmodifiable([
    for (final key in _everydayCandidateKeys)
      if (isSelectableCategoryIconKey(key))
        if (metadata.containsKey(key))
          metadata[key]!
        else
          CategoryIconChoice(key, _iconLabel(key), _iconLabel(key),
              _iconGroup(key), key.replaceAll('_', ' ')),
  ]);
}

class CategoryIconSelection {
  const CategoryIconSelection(this.key, {this.filled = false});
  final String key;
  final bool filled;
  Map<String, dynamic> toJson() => {'key': key, 'filled': filled};
  static CategoryIconSelection? fromJson(dynamic value) {
    if (value is! Map || value['key'] is! String) return null;
    final key = value['key'] as String;
    // Retain older device-local keys. Unmatched artwork renders as a folder,
    // but the original saved value is not silently replaced or deleted.
    return CategoryIconSelection(CategoryIconStore.canonicalKey(key) ?? key,
        filled: value['filled'] == true);
  }
  @override
  bool operator ==(Object other) =>
      other is CategoryIconSelection && key == other.key && filled == other.filled;
  @override
  int get hashCode => Object.hash(key, filled);
}

/// Local-first. The old icon_code_point is deliberately left intact.
/// A separate PocketBase schema/outbox migration is required for cross-device sync.
class CategoryIconStore extends ChangeNotifier {
  CategoryIconStore._();
  static final instance = CategoryIconStore._();
  static const _selectionKey = 'takto.category.icon_selection.v1';
  static const _selectionItemPrefix = 'takto.category.icon_selection_item.v1.';
  final Map<String, CategoryIconSelection> _values = {};
  Future<void>? _loadFuture;
  static final List<CategoryIconChoice> _selectableCatalog =
      _buildSharedCatalog();

  // Only one tile per exact Fluent Regular/Filled pair. The curated
  // everyday name wins over a second fluent__ alias for the same artwork.
  static final List<CategoryIconChoice> _fullFluentCatalog =
      _buildUniqueFullFluentCatalog();

  static List<CategoryIconChoice> _buildUniqueFullFluentCatalog() {
    final choices = List<CategoryIconChoice>.from(_selectableCatalog);
    final seen = <_CategoryGlyphPair>{
      for (final choice in _selectableCatalog)
        _glyphPair(kMatchedCategoryIcons[choice.key]!),
    };
    for (final entry in kFullFluentCategoryIcons.entries) {
      if (!seen.add(_glyphPair(entry.value))) continue;
      final key = entry.key;
      final label = _iconLabel(key.substring('fluent__'.length));
      choices.add(CategoryIconChoice(key, label, label, 'Fluent',
          key.substring('fluent__'.length).replaceAll('_', ' ')));
    }
    return List<CategoryIconChoice>.unmodifiable(choices);
  }

  static List<CategoryIconChoice> catalogFor({bool includeFullFluent = false}) =>
      includeFullFluent ? _fullFluentCatalog : _selectableCatalog;

  static int get fullFluentCount => _fullFluentCatalog.length;
  static bool isValidKey(String key) =>
      kMatchedCategoryIcons.containsKey(key) ||
      kFullFluentCategoryIcons.containsKey(key);
  static String? canonicalKey(String key) => isValidKey(key)
      ? key : kPreviousIconAliases[key];

  static const _quickKey = 'takto.category.icon_quick_collection.v1';
  List<String> _quickKeys = List<String>.from(kDefaultCategoryIconKeys);
  List<String> get quickKeys => List<String>.unmodifiable(_quickKeys);
  List<CategoryIconChoice> get quickCatalog {
    final byKey = {for (final icon in _fullFluentCatalog) icon.key: icon};
    return List<CategoryIconChoice>.unmodifiable([
      for (final key in _quickKeys)
        if (byKey.containsKey(key)) byKey[key]!,
    ]);
  }

  static List<String> _uniqueFavoriteKeys(Iterable<String> keys) =>
      <String>{
        for (final key in keys)
          if (categoryPickerRepresentative(key) case final String canonical)
            if (canonical.isNotEmpty) canonical,
      }.toList();

  Future<void> setQuickKeys(Iterable<String> values) async {
    await ensureLoaded();
    // Only one favorite per icon image, including older aliases.
    // Material fallbacks remain renderable in old categories, not in pickers.
    final next = _uniqueFavoriteKeys(values);
    if (_sameStrings(_quickKeys, next)) return;
    final previous = List<String>.from(_quickKeys);
    _quickKeys = next;
    notifyListeners();
    try {
      if (!await (await SharedPreferences.getInstance())
          .setString(_quickKey, jsonEncode(next))) {
        throw StateError('Could not save quick icon collection');
      }
    } catch (_) {
      _quickKeys = previous;
      notifyListeners();
      rethrow;
    }
  }

  static bool _sameStrings(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((same) => same);

  /// A transient browser/device storage error must not poison every later
  /// save attempt with the same cached failed Future.
  Future<void> ensureLoaded() {
    if (_loadFuture != null) return _loadFuture!;
    final pending = _load().catchError((Object error, StackTrace stack) {
      _loadFuture = null;
      Error.throwWithStackTrace(error, stack);
    });
    _loadFuture = pending;
    return pending;
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedQuick = prefs.getString(_quickKey);
    if (savedQuick != null) {
      try {
        final raw = jsonDecode(savedQuick);
        if (raw is List) {
          final keys = raw.whereType<String>().where(isValidKey).toSet().toList();
          _quickKeys = isLegacyAutoSelectedCollection(keys)
              ? List<String>.from(kDefaultCategoryIconKeys)
              : _uniqueFavoriteKeys(keys);
        }
      } on FormatException {
        // Keep the sensible defaults when local data is malformed.
      }
    }
    // Read the legacy aggregate once for backwards compatibility. Modern
    // changes are saved per category, avoiding a growing all-icons JSON write.
    final json = prefs.getString(_selectionKey);
    if (json != null) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is String) {
              final parsed = CategoryIconSelection.fromJson(entry.value);
              if (parsed != null) _values[entry.key as String] = parsed;
            }
          }
        }
      } on FormatException {
        // Ignore malformed legacy preferences without changing category data.
      }
    }
    for (final prefKey in prefs.getKeys()) {
      if (!prefKey.startsWith(_selectionItemPrefix)) continue;
      final value = prefs.getString(prefKey);
      if (value == null) continue;
      try {
        final parsed = CategoryIconSelection.fromJson(jsonDecode(value));
        if (parsed != null) {
          _values[prefKey.substring(_selectionItemPrefix.length)] = parsed;
        }
      } on FormatException {
        // One damaged entry must not hide the remaining category icons.
      }
    }
    notifyListeners();
  }

  static String keyFor(CategoryRule rule) {
    final backendId = rule.backendRowId;
    if (backendId != null && backendId.isNotEmpty) {
      // PocketBase IDs survive category renames and reordering.
      return 'pb:' + backendId;
    }
    return 'local:' + rule.id.toString() + ':' +
        (rule.normalizedId ?? rule.categoryKey);
  }
  CategoryIconSelection? explicitFor(CategoryRule rule) => _values[keyFor(rule)];
  CategoryIconSelection selectionFor(CategoryRule rule) =>
      explicitFor(rule) ?? CategoryIconSelection(_legacyKey(rule));

  Future<void> setSelection(CategoryRule category, CategoryIconSelection choice) async {
    if (!isValidKey(choice.key)) throw ArgumentError.value(choice.key);
    await ensureLoaded();
    final key = keyFor(category);
    final previous = _values[key];
    _values[key] = choice;
    notifyListeners();
    try {
      // Only write the edited category. The previous aggregate was rewritten
      // on every selection and could grow until browser storage refused it.
      if (!await (await SharedPreferences.getInstance()).setString(
          '$_selectionItemPrefix$key', jsonEncode(choice.toJson()))) {
        throw StateError('Could not save category icon');
      }
    } catch (_) {
      if (previous == null) {
        _values.remove(key);
      } else {
        _values[key] = previous;
      }
      notifyListeners();
      rethrow;
    }
  }

  /// Best-effort initial mapping; never overwrites the original Material codepoint.
  static String _legacyKey(CategoryRule rule) {
    final cp = rule.iconCodePoint;
    if (cp == Icons.work_rounded.codePoint ||
        cp == Icons.work_outline_rounded.codePoint) return 'briefcase';
    if (cp == Icons.home_rounded.codePoint) return 'home';
    if (cp == Icons.favorite_rounded.codePoint ||
        cp == Icons.favorite_border_rounded.codePoint ||
        cp == Icons.fitness_center_rounded.codePoint) return 'heart';
    if (cp == Icons.restaurant_rounded.codePoint ||
        cp == Icons.local_cafe_rounded.codePoint) return 'cake';
    if (cp == Icons.bedtime_outlined.codePoint ||
        cp == Icons.bed_rounded.codePoint) return 'moon';
    if (cp == Icons.book_rounded.codePoint ||
        cp == Icons.school_rounded.codePoint ||
        cp == Icons.menu_book_outlined.codePoint) return 'book';
    if (cp == Icons.schedule_rounded.codePoint ||
        cp == Icons.access_time_rounded.codePoint) return 'clock';
    if (cp == Icons.shopping_cart_outlined.codePoint ||
        cp == Icons.account_balance_wallet_outlined.codePoint) return 'cart';
    if (cp == Icons.camera_alt_outlined.codePoint) return 'camera';
    if (cp == Icons.star_outline_rounded.codePoint) return 'star';
    final n = rule.name.toLowerCase();
    if (n.contains('работ') || n.contains('work') || n.contains('office')) return 'briefcase';
    if (n.contains('дом') || n.contains('home')) return 'home';
    if (n.contains('сон') || n.contains('sleep')) return 'moon';
    if (n.contains('здоров') || n.contains('health') ||
        n.contains('жизн') || n.contains('life')) return 'heart';
    if (n.contains('еда') || n.contains('food')) return 'cake';
    if (n.contains('учеб') || n.contains('книг') || n.contains('school')) return 'book';
    if (n.contains('финанс') || n.contains('покуп') || n.contains('money')) return 'cart';
    if (n.contains('время') || n.contains('time')) return 'clock';
    return 'folder';
  }
}

class CategorySvgIcon extends StatelessWidget {
  const CategorySvgIcon({super.key, required this.selection,
    this.size = 24, this.color, this.semanticLabel});
  final CategoryIconSelection selection;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.onSurface;
    // A removed/unknown old key renders neutrally until the user reselects.
    final canonical = CategoryIconStore.canonicalKey(selection.key);
    final artwork = kMatchedCategoryIcons[canonical] ??
        kFullFluentCategoryIcons[canonical] ??
        kMatchedCategoryIcons['folder']!;
    return Icon(selection.filled ? artwork.fluentFilled : artwork.fluentOutline,
        size: size, color: tint, semanticLabel: semanticLabel);
  }
}

class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({super.key, required this.category,
    this.size = 24, this.color, this.selected = false});
  final CategoryRule category;
  final double size;
  final Color? color;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final store = CategoryIconStore.instance;
    unawaited(store.ensureLoaded());
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final explicit = store.explicitFor(category);
        final choice = explicit ?? CategoryIconSelection(
          store.selectionFor(category).key, filled: selected,
        );
        return CategorySvgIcon(
          selection: choice,
          size: size, color: color, semanticLabel: category.name,
        );
      },
    );
  }
}

