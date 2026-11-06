import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/category_icon_system.dart';
import 'package:counter/core/app_build_info.dart';
import 'package:flutter/material.dart';

Future<CategoryIconSelection?> showCategoryIconPicker(
  BuildContext context, {
  required CategoryIconSelection initial,
  Color? color,
}) {
  if (MediaQuery.sizeOf(context).width < 700) {
    return showModalBottomSheet<CategoryIconSelection>(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.78,
          child: _IconPicker(initial: initial, color: color)),
      ),
    );
  }
  return showDialog<CategoryIconSelection>(
    context: context,
    builder: (ctx) => Dialog(child: SizedBox(
      width: 710, height: math.min(690, MediaQuery.sizeOf(ctx).height - 70),
      child: _IconPicker(initial: initial, color: color),
    )),
  );
}

class _IconPicker extends StatefulWidget {
  const _IconPicker({required this.initial, this.color});
  final CategoryIconSelection initial;
  final Color? color;
  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  late CategoryIconSelection _selection;
  final TextEditingController _search = TextEditingController();
  String _group = 'Все';
  String _view = 'favorites';
  bool _changingFavorites = false;

  @override
  void initState() {
    super.initState();
    _selection = CategoryIconSelection(
      CategoryIconStore.canonicalKey(widget.initial.key) ?? widget.initial.key,
      filled: widget.initial.filled,
    );
    _search.addListener(_changed);
    unawaited(CategoryIconStore.instance.ensureLoaded());
  }

  void _changed() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _search.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    if (_changingFavorites) return;
    final store = CategoryIconStore.instance;
    final key = _selection.key;
    final next = store.quickKeys.toList();
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.insert(0, key);
    }
    setState(() => _changingFavorites = true);
    try {
      await store.setQuickKeys(next);
    } catch (error, stack) {
      debugPrint('Could not change icon favorite $key: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Localizations.localeOf(context).languageCode == 'ru'
              ? 'Не удалось обновить избранные иконки'
              : 'Unable to update favorite icons'),
        ));
      }
    } finally {
      if (mounted) setState(() => _changingFavorites = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = CategoryIconStore.instance;
    final cs = Theme.of(context).colorScheme;
    final ru = Localizations.localeOf(context).languageCode == 'ru';

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final curated = CategoryIconStore.catalogFor();
        final all = CategoryIconStore.catalogFor(includeFullFluent: true);
        // Searching is global, even if My icons contains only a few favorites.
        // Everyday matches are first; the full Fluent catalog follows.
        final catalog = query.isNotEmpty ? all : switch (_view) {
          'favorites' => store.quickCatalog,
          'full' => all,
          _ => curated,
        };
        final byKey = {for (final entry in all) entry.key: entry};
        final current = byKey[_selection.key] ??
            CategoryIconChoice(_selection.key,
                _selection.key.replaceAll('_', ' '),
                _selection.key.replaceAll('_', ' '), 'Прочее', '');
        final icons = catalog.where((item) {
          if (query.isEmpty && _view == 'everyday' &&
              _group != 'Все' && item.group != _group) return false;
          return query.isEmpty ||
              (item.key + ' ' + item.ru + ' ' + item.en + ' ' + item.synonyms)
                  .toLowerCase().contains(query);
        }).toList();
        final favorite = store.quickKeys.contains(_selection.key);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 0),
              child: Row(children: [
                Expanded(child: Text(
                  ru ? 'Иконка категории' : 'Category icon',
                  style: Theme.of(context).textTheme.titleLarge,
                )),
                IconButton(onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 9),
              child: Row(children: [
                CategorySvgIcon(selection: _selection,
                    color: widget.color ?? cs.primary, size: 30),
                const SizedBox(width: 10),
                Expanded(child: Text(ru ? current.ru : current.en,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  key: const ValueKey('category-icon-favorite-toggle'),
                  tooltip: ru
                      ? (favorite ? 'Убрать из моих иконок' : 'Добавить в мои иконки')
                      : (favorite ? 'Remove from My icons' : 'Add to My icons'),
                  onPressed: _changingFavorites ? null : _toggleFavorite,
                  icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border,
                      color: favorite ? cs.primary : cs.onSurfaceVariant),
                ),
                const SizedBox(width: 6),
                SegmentedButton<bool>(
                  key: const ValueKey('category-icon-style-toggle'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false,
                        label: Text(ru ? 'Контур' : 'Outline')),
                    ButtonSegment(value: true,
                        label: Text(ru ? 'Заливка' : 'Fill')),
                  ],
                  selected: {_selection.filled},
                  onSelectionChanged: (value) => setState(() {
                    _selection = CategoryIconSelection(_selection.key,
                        filled: value.first);
                  }),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 7),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                ChoiceChip(
                  key: const ValueKey('category-icon-everyday'),
                  label: Text(ru ? 'Повседневные' : 'Everyday'),
                  showCheckmark: false,
                  selected: _view == 'everyday',
                  onSelected: (_) => setState(() => _view = 'everyday'),
                ),
                ChoiceChip(
                  key: const ValueKey('category-icon-my-icons'),
                  label: Text(ru
                      ? 'Мои (${store.quickKeys.length})'
                      : 'My icons (${store.quickKeys.length})'),
                  showCheckmark: false,
                  selected: _view == 'favorites',
                  onSelected: (_) => setState(() => _view = 'favorites'),
                ),
                ChoiceChip(
                  key: const ValueKey('category-icon-all-fluent'),
                  label: Text(ru
                      ? 'Вся Fluent (${CategoryIconStore.fullFluentCount})'
                      : 'All Fluent (${CategoryIconStore.fullFluentCount})'),
                  showCheckmark: false,
                  selected: _view == 'full',
                  onSelected: (_) => setState(() => _view = 'full'),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: ru ? 'Поиск по всем иконкам: собака, машина…'
                      : 'Search all icons: dog, car, sports…',
                  isDense: true, border: const OutlineInputBorder(),
                  suffixIcon: query.isEmpty ? null : IconButton(
                    onPressed: _search.clear,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
            if (_view == 'everyday')
              SizedBox(height: 50, child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 7, 18, 2),
                itemCount: kCategorySubjectGroups.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(categorySubjectGroupName(
                      kCategorySubjectGroups[i], russian: ru)),
                  selected: _group == kCategorySubjectGroups[i],
                  showCheckmark: false,
                  onSelected: (_) => setState(
                      () => _group = kCategorySubjectGroups[i]),
                ),
              )),
            Expanded(child: icons.isEmpty
                ? Center(child: Text(ru
                    ? 'Ничего не найдено'
                    : 'No matching icons'))
                : GridView.builder(
                  key: const ValueKey('category-paired-icon-grid'),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 15),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 58, mainAxisExtent: 52,
                    mainAxisSpacing: 5, crossAxisSpacing: 5,
                  ),
                  itemCount: icons.length,
                  itemBuilder: (_, i) {
                    final item = icons[i];
                    final active = item.key == _selection.key;
                    final label = ru ? item.ru : item.en;
                    return Tooltip(
                      message: label,
                      child: Semantics(
                        label: label, button: true, selected: active,
                        child: InkWell(
                          key: ValueKey('category-icon-' + item.key),
                          onTap: () => setState(() {
                            _selection = CategoryIconSelection(item.key,
                                filled: _selection.filled);
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: Center(child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: active
                                  ? cs.primaryContainer.withValues(alpha: .5)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: active
                                  ? Border.all(color: cs.primary, width: 2)
                                  : null,
                            ),
                            child: Center(child: CategorySvgIcon(
                              selection: CategoryIconSelection(item.key,
                                  filled: _selection.filled),
                              size: 26,
                              color: active ? cs.primary : cs.onSurface,
                            )),
                          )),
                        ),
                      ),
                    );
                  },
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: SafeArea(top: false, child: Row(children: [
                Expanded(child: Text(
                  '${icons.length} / ${catalog.length} · ${AppBuildInfo.gitCommit}',
                  key: const ValueKey('icon-picker-build-and-count'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                )),
                TextButton(onPressed: () => Navigator.pop(context),
                    child: Text(ru ? 'Отмена' : 'Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('category-icon-apply'),
                  onPressed: CategoryIconStore.isValidKey(_selection.key)
                      ? () => Navigator.pop(context, _selection) : null,
                  child: Text(ru ? 'Применить' : 'Apply'),
                ),
              ])),
            ),
          ],
        );
      },
    );
  }
}
