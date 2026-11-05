import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/category_icon_system.dart';
import 'package:flutter/material.dart';

/// User-controlled quick icon collection. The full picker offers only semantic
/// intersections that exist in both icon families.
class CategoryIconCollectionPreference extends StatelessWidget {
  const CategoryIconCollectionPreference({super.key, required this.isRussian});
  final bool isRussian;

  @override
  Widget build(BuildContext context) {
    final store = CategoryIconStore.instance;
    unawaited(store.ensureLoaded());
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(
              isRussian ? 'Мои иконки' : 'My icons',
              style: Theme.of(context).textTheme.titleMedium,
            )),
            Text('${store.quickKeys.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 5),
          Text(
            isRussian
                ? 'Только выбранные значки отображаются в категориях. Все доступны в обоих стилях.'
                : 'Only your chosen icons appear in the category picker. Every choice exists in both icon families.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 9, children: [
            for (final key in store.quickKeys.take(16))
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(child: CategorySvgIcon(
                    selection: CategoryIconSelection(key), size: 22)),
              ),
            if (store.quickKeys.length > 16)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text('+${store.quickKeys.length - 16}'),
              ),
          ]),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('manage-category-icons'),
              onPressed: () => showCategoryIconCollectionEditor(context),
              icon: const Icon(Icons.tune_rounded),
              label: Text(isRussian ? 'Настроить набор' : 'Customize icon set'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showCategoryIconCollectionEditor(BuildContext context) async {
  final russian = Localizations.localeOf(context).languageCode == 'ru';
  if (MediaQuery.sizeOf(context).width < 700) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .88,
        child: _IconCollectionEditor(isRussian: russian),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: SizedBox(
        width: 740, height: math.min(760, MediaQuery.sizeOf(ctx).height - 70),
        child: _IconCollectionEditor(isRussian: russian),
      ),
    ),
  );
}

class _IconCollectionEditor extends StatefulWidget {
  const _IconCollectionEditor({required this.isRussian});
  final bool isRussian;
  @override
  State<_IconCollectionEditor> createState() => _IconCollectionEditorState();
}

class _IconCollectionEditorState extends State<_IconCollectionEditor> {
  late final Set<String> _picked;
  final TextEditingController _search = TextEditingController();
  bool _saving = false;
  String _group = 'Все';
  static const groups = [
    'Все', 'Личное', 'Работа', 'Организация',
    'Учёба', 'Творчество', 'Финансы', 'Прочее'
  ];

  @override
  void initState() {
    super.initState();
    _picked = CategoryIconStore.instance.quickKeys.toSet();
    _search.addListener(_redraw);
    unawaited(CategoryIconStore.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      setState(() {
        _picked
          ..clear()
          ..addAll(CategoryIconStore.instance.quickKeys);
      });
    }));
  }

  void _redraw() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _search.removeListener(_redraw);
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_picked.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final existing = CategoryIconStore.instance.quickKeys;
      // Preserve the user's existing order and append newly chosen concepts.
      final order = [
        ...existing.where(_picked.contains),
        ...CategoryIconStore.catalogFor(CategoryIconStore.instance.pack)
            .map((e) => e.key).where((key) =>
                _picked.contains(key) && !existing.contains(key)),
      ];
      await CategoryIconStore.instance.setQuickKeys(order);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isRussian
              ? 'Не удалось сохранить набор иконок.'
              : 'Could not save icon collection.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = CategoryIconStore.instance;
    final cs = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final entries = CategoryIconStore.catalogFor(store.pack).where((item) {
      if (_group != 'Все' && item.group != _group) return false;
      return query.isEmpty || [
        item.key, item.en, item.ru, item.synonyms
      ].join(' ').toLowerCase().contains(query);
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isRussian ? 'Мой набор иконок' : 'My icon collection',
                style: Theme.of(context).textTheme.titleLarge),
              Text(widget.isRussian
                  ? 'Выбрано ${_picked.length} из ${CategoryIconStore.catalogFor(store.pack).length}'
                  : '${_picked.length} selected · ${CategoryIconStore.catalogFor(store.pack).length} verified pairs',
                style: Theme.of(context).textTheme.bodySmall),
            ],
          )),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
        child: TextField(
          controller: _search,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            hintText: widget.isRussian
                ? 'Поиск по совпадающим иконкам'
                : 'Search matched icons',
            border: const OutlineInputBorder(),
            suffixIcon: query.isEmpty ? null : IconButton(
              onPressed: _search.clear,
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ),
      SizedBox(height: 49, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 7, 18, 0),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => ChoiceChip(
          label: Text(groups[i]),
          selected: groups[i] == _group,
          showCheckmark: false,
          onSelected: (_) => setState(() => _group = groups[i]),
        ),
      )),
      Expanded(child: GridView.builder(
        key: const ValueKey('matched-icon-collection-grid'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 122,
          mainAxisExtent: 94,
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final item = entries[index];
          final picked = _picked.contains(item.key);
          return InkWell(
            key: ValueKey('custom-icon-${item.key}'),
            onTap: () => setState(() {
              if (picked) {
                _picked.remove(item.key);
              } else {
                _picked.add(item.key);
              }
            }),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              decoration: BoxDecoration(
                color: picked
                    ? cs.primaryContainer.withValues(alpha: .2)
                    : cs.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: picked ? cs.primary : cs.outlineVariant,
                  width: picked ? 2 : 1,
                ),
              ),
              child: Stack(children: [
                Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CategorySvgIcon(
                      selection: CategoryIconSelection(item.key),
                      size: 28,
                    ),
                    const SizedBox(height: 7),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.isRussian ? item.ru : item.en,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                )),
                if (picked) Positioned(
                  top: 5, right: 5,
                  child: Icon(Icons.check_circle, size: 17, color: cs.primary),
                ),
              ]),
            ),
          );
        },
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: SafeArea(top: false, child: Row(children: [
          TextButton(
            key: const ValueKey('reset-default-icons'),
            onPressed: _saving ? null : () => setState(() {
              _picked
                ..clear()
                ..addAll(kDefaultCategoryIconKeys);
            }),
            child: Text(widget.isRussian ? 'По умолчанию' : 'Reset defaults'),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.isRussian ? 'Отмена' : 'Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const ValueKey('save-icon-collection'),
            onPressed: _picked.isEmpty || _saving ? null : _save,
            child: Text(widget.isRussian ? 'Сохранить' : 'Save'),
          ),
        ])),
      ),
    ]);
  }
}
