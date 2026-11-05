import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/category_icon_system.dart';
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
  static const groups = ['Все', 'Личное', 'Работа', 'Организация', 'Учёба', 'Творчество', 'Финансы', 'Прочее'];

  @override
  void initState() {
    super.initState();
    _selection = widget.initial;
    _search.addListener(_changed);
    unawaited(CategoryIconStore.instance.ensureLoaded());
  }
  void _changed() => setState(() {});
  @override
  void dispose() {
    _search.removeListener(_changed);
    _search.dispose();
    super.dispose();
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
        final approved = CategoryIconStore.catalogFor(store.pack);
        final catalog = store.quickCatalog;
        final current = approved.where((e) => e.key == _selection.key)
            .firstOrNull ?? CategoryIconChoice(
              _selection.key, _selection.key, _selection.key, 'Прочее', '');
        final choices = [...catalog];
        // Keep the current category icon visible for editing even if it
        // was removed from the user's preferred quick collection.
        if (CategoryIconStore.isValidKey(_selection.key) &&
            !choices.any((item) => item.key == _selection.key)) {
          choices.insert(0, current);
        }
        final icons = choices.where((item) {
          if (_group != 'Все' && item.group != _group) return false;
          return query.isEmpty ||
              (item.key + ' ' + item.ru + ' ' + item.en + ' ' + item.synonyms)
                  .toLowerCase().contains(query);
        }).toList();

        return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 0),
            child: Row(children: [
              Expanded(child: Text(ru ? 'Выбор иконки' : 'Choose an icon',
                  style: Theme.of(context).textTheme.titleLarge)),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CategorySvgIcon(selection: _selection, color: widget.color ?? cs.primary, size: 37),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ru ? current.ru : current.en,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(store.pack == CategoryIconPack.fluent ? 'Fluent UI' : 'Heroicons',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                )),
                SegmentedButton<bool>(
                  key: const ValueKey('category-icon-style-toggle'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, label: Text(ru ? 'Контур' : 'Outline')),
                    ButtonSegment(value: true, label: Text(ru ? 'Заливка' : 'Fill')),
                  ],
                  selected: {_selection.filled},
                  onSelectionChanged: (value) => setState(() {
                    _selection = CategoryIconSelection(_selection.key, filled: value.first);
                  }),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: ru ? 'Поиск иконок (RU / EN)' : 'Search icons (RU / EN)',
                isDense: true, border: const OutlineInputBorder(),
                suffixIcon: query.isEmpty ? null : IconButton(
                  onPressed: _search.clear, icon: const Icon(Icons.close)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
            child: Text(ru
                ? 'Мой набор · изменяется в Настройках → Оформление'
                : 'My collection · edit in Settings → Appearance',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant)),
          ),
          SizedBox(height: 52, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(groups[i]), selected: _group == groups[i],
              showCheckmark: false,
              onSelected: (_) => setState(() => _group = groups[i]),
            ),
          )),
          Expanded(child: icons.isEmpty
              ? Center(child: Text(ru ? 'Ничего не найдено' : 'No matching icons'))
              : GridView.builder(
                key: const ValueKey('category-paired-icon-grid'),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 15),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 93, mainAxisExtent: 81,
                  mainAxisSpacing: 9, crossAxisSpacing: 9,
                ),
                itemCount: icons.length,
                itemBuilder: (_, i) {
                  final item = icons[i];
                  final active = item.key == _selection.key;
                  return InkWell(
                    key: ValueKey('category-icon-' + item.key),
                    onTap: () => setState(() {
                      _selection = CategoryIconSelection(item.key, filled: _selection.filled);
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: active ? cs.primaryContainer.withValues(alpha: 0.3) : cs.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? cs.primary : cs.outlineVariant,
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        CategorySvgIcon(
                          selection: CategoryIconSelection(
                            item.key, filled: _selection.filled),
                          size: 27, color: active ? cs.primary : cs.onSurface),
                        const SizedBox(height: 7),
                        Text(ru ? item.ru : item.en,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  );
                },
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: SafeArea(top: false, child: Row(children: [
              Text(icons.length.toString() + ' / ' +
                  catalog.length.toString(),
                  style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
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
