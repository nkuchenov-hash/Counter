import 'dart:async';
import 'dart:convert';

import 'package:counter/core/category_icon_svg_data.dart';
import 'package:counter/core/category_icon_catalog_generated.g.dart';
import 'package:heroicons/heroicons.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CategoryIconPack { fluent, heroicons }

class CategoryIconChoice {
  const CategoryIconChoice(this.key, this.ru, this.en, this.group, this.synonyms);
  final String key, ru, en, group, synonyms;
}

const List<CategoryIconChoice> kCategoryIconCatalog = [
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
];

/// Each family independently offers its complete native paired catalog.
/// Legacy 14-key aliases stay available so older saved categories do not break.
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

List<CategoryIconChoice> _buildPackCatalog(CategoryIconPack family) {
  final names = <String>{
    ...(family == CategoryIconPack.fluent
        ? kCompleteFluentCategoryIcons.keys
        : kCompleteHeroCategoryIcons.keys),
    ...kCategoryIconCatalog.map((item) => item.key),
  }.toList()..sort();
  final legacy = {for (final item in kCategoryIconCatalog) item.key: item};
  return List<CategoryIconChoice>.unmodifiable([
    for (final key in names)
      legacy[key] ?? CategoryIconChoice(key, _iconLabel(key),
          _iconLabel(key), _iconGroup(key), key.replaceAll('_', ' ')),
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
    if (!CategoryIconStore.isValidKey(key)) return null;
    return CategoryIconSelection(key, filled: value['filled'] == true);
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
  static const _packKey = 'takto.category.icon_pack.v1';
  static const _selectionKey = 'takto.category.icon_selection.v1';
  CategoryIconPack _pack = CategoryIconPack.fluent;
  final Map<String, CategoryIconSelection> _values = {};
  Future<void>? _loadFuture;
  CategoryIconPack get pack => _pack;
  static Map<String, CategorySvgPair> iconsFor(CategoryIconPack family) =>
      family == CategoryIconPack.fluent ? kFluentCategorySvgs : kHeroCategorySvgs;
  static final List<CategoryIconChoice> _fluentCatalog =
      _buildPackCatalog(CategoryIconPack.fluent);
  static final List<CategoryIconChoice> _heroCatalog =
      _buildPackCatalog(CategoryIconPack.heroicons);
  static List<CategoryIconChoice> catalogFor(CategoryIconPack family) =>
      family == CategoryIconPack.fluent ? _fluentCatalog : _heroCatalog;
  static bool isValidKey(String key) {
    if (kCompleteFluentCategoryIcons.containsKey(key) ||
        kCompleteHeroCategoryIcons.containsKey(key)) return true;
    final a = kFluentCategorySvgs[key], b = kHeroCategorySvgs[key];
    return a != null && b != null &&
        a.regular != a.filled && b.regular != b.filled &&
        a.regular.contains('<svg') && a.filled.contains('<svg') &&
        b.regular.contains('<svg') && b.filled.contains('<svg');
  }

  Future<void> ensureLoaded() => _loadFuture ??= _load();
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_packKey) == 'heroicons') _pack = CategoryIconPack.heroicons;
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
        // Ignore a malformed local preference, without touching server records.
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

  Future<void> setPack(CategoryIconPack next) async {
    await ensureLoaded();
    if (_pack == next) return;
    final previous = _pack;
    _pack = next;
    notifyListeners();
    try {
      if (!await (await SharedPreferences.getInstance()).setString(_packKey, next.name)) {
        throw StateError('Could not save icon pack');
      }
    } catch (_) {
      _pack = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setSelection(CategoryRule category, CategoryIconSelection choice) async {
    if (!isValidKey(choice.key)) throw ArgumentError.value(choice.key);
    await ensureLoaded();
    final key = keyFor(category);
    final previous = _values[key];
    _values[key] = choice;
    notifyListeners();
    try {
      final values = _values.map((key, value) => MapEntry(key, value.toJson()));
      if (!await (await SharedPreferences.getInstance())
          .setString(_selectionKey, jsonEncode(values))) {
        throw StateError('Could not save icon');
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
    this.size = 24, this.color, this.pack, this.semanticLabel});
  final CategoryIconSelection selection;
  final double size;
  final Color? color;
  final CategoryIconPack? pack;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final family = pack ?? CategoryIconStore.instance.pack;
    final fallbackColor = color ?? Theme.of(context).colorScheme.onSurface;
    if (family == CategoryIconPack.fluent) {
      final fullPair = kCompleteFluentCategoryIcons[selection.key];
      if (fullPair != null) {
        return Icon(selection.filled ? fullPair.$2 : fullPair.$1,
          size: size, color: fallbackColor, semanticLabel: semanticLabel);
      }
    } else {
      final hero = kCompleteHeroCategoryIcons[selection.key];
      if (hero != null) {
        return HeroIcon(hero,
          style: selection.filled ? HeroIconStyle.solid : HeroIconStyle.outline,
          size: size, color: fallbackColor, semanticLabel: semanticLabel);
      }
    }
    final pair = CategoryIconStore.iconsFor(family)[selection.key] ??
        CategoryIconStore.iconsFor(family)['folder']!;
    return SvgPicture.string(
      selection.filled ? pair.filled : pair.regular,
      width: size, height: size, fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(
        color ?? Theme.of(context).colorScheme.onSurface,
        BlendMode.srcIn,
      ),
      semanticsLabel: semanticLabel,
    );
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
          selection: choice, pack: store.pack,
          size: size, color: color, semanticLabel: category.name,
        );
      },
    );
  }
}

/// Shared Profile > Appearance picker on desktop and mobile.
class CategoryIconPackPreference extends StatelessWidget {
  const CategoryIconPackPreference({super.key, required this.isRussian});
  final bool isRussian;
  @override
  Widget build(BuildContext context) {
    final store = CategoryIconStore.instance;
    unawaited(store.ensureLoaded());
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isRussian ? 'Набор иконок' : 'Icon family',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(isRussian
              ? 'Для категорий. У каждой иконки есть контур и заливка.'
              : 'For categories. Every icon has Outline and Filled versions.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final cards = CategoryIconPack.values.map((family) {
              final active = store.pack == family;
              return InkWell(
                key: ValueKey('icon-pack-' + family.name),
                onTap: active ? null : () async {
                  try {
                    await store.setPack(family);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isRussian
                            ? 'Не удалось сохранить набор.'
                            : 'Could not save icon family.')));
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: active ? cs.primaryContainer.withValues(alpha: 0.3) : cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? cs.primary : cs.outlineVariant,
                        width: active ? 2 : 1),
                  ),
                  child: Row(children: [
                    CategorySvgIcon(pack: family, size: 22,
                      selection: const CategoryIconSelection('heart')),
                    const SizedBox(width: 6),
                    CategorySvgIcon(pack: family, size: 22,
                      selection: const CategoryIconSelection('folder', filled: true)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(family == CategoryIconPack.fluent
                        ? 'Fluent UI' : 'Heroicons',
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                    Icon(active ? Icons.check_circle : Icons.circle_outlined,
                        size: 18, color: active ? cs.primary : cs.outline),
                  ]),
                ),
              );
            }).toList();
            return constraints.maxWidth < 420
                ? Column(children: [cards[0], const SizedBox(height: 8), cards[1]])
                : Row(children: [
                    Expanded(child: cards[0]), const SizedBox(width: 10),
                    Expanded(child: cards[1]),
                  ]);
          }),
        ],
      ),
    );
  }
}
