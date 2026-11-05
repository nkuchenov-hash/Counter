import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/category_icon_system.dart';
import 'package:counter/core/app_build_info.dart';
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
                ? 'Выбранные иконки отображаются первыми. Остальные доступны в полном каталоге.'
                : 'Your chosen icons appear first. The complete icon library remains available.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 9, children: [
            for (final key in store.quickKeys.take(16))
              Tooltip(
                message: key.replaceAll('_', ' '),
                child: SizedBox(
                  width: 30, height: 30,
                  child: Center(child: CategorySvgIcon(
                    selection: CategoryIconSelection(key), size: 22)),
                ),
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
  bool _browsing = false; // Start with the user's preferred collection.
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
    final approved = CategoryIconStore.catalogFor(store.pack);
    final byKey = {for (final icon in approved) icon.key: icon};
    final selectedOrder = <String>[
      ...store.quickKeys.where(_picked.contains),
      ..._picked.where((key) => !store.quickKeys.contains(key)),
    ];
    // This preference editor shows the selected favorites; the category
    // picker separately exposes every approved icon, favorites first.
    final entries = _browsing
        ? approved.where((icon) => !_picked.contains(icon.key)).where((item) {
            if (_group != 'Все' && item.group != _group) return false;
            return query.isEmpty ||
                [item.key, item.en, item.ru, item.synonyms]
                    .join(' ').toLowerCase().contains(query);
          }).toList()
        : <CategoryIconChoice>[
            for (final key in selectedOrder)
              if (byKey.containsKey(key)) byKey[key]!,
          ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_browsing
                  ? (widget.isRussian ? 'Добавить иконки' : 'Add icons')
                  : (widget.isRussian ? 'Мой набор иконок' : 'My icon collection'),
                style: Theme.of(context).textTheme.titleLarge),
              Text(_browsing
                  ? (widget.isRussian
                      ? 'Доступно ${entries.length} парных иконок'
                      : '${entries.length} matching icons available')
                  : (widget.isRussian
                      ? 'В моём наборе: ${_picked.length} · build ${AppBuildInfo.gitCommit}'
                      : '${_picked.length} in my collection · build ${AppBuildInfo.gitCommit}'),
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
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey('toggle-icon-catalog'),
            onPressed: _saving ? null : () => setState(() {
              _browsing = !_browsing;
              _group = 'Все';
              _search.clear();
            }),
            icon: Icon(_browsing ? Icons.arrow_back_rounded : Icons.add_rounded),
            label: Text(_browsing
                ? (widget.isRussian ? 'Мои иконки' : 'Back to my icons')
                : (widget.isRussian ? 'Добавить иконки' : 'Add icons')),
          ),
        ),
      ),
      if (_browsing) ...[
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
      ],
      Expanded(child: entries.isEmpty
          ? Center(child: Text(_browsing
              ? (widget.isRussian ? 'Все доступные иконки уже добавлены' : 'All matching icons added')
              : (widget.isRussian ? 'Нет иконок' : 'No icons')))
          : GridView.builder(
        key: const ValueKey('matched-icon-collection-grid'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 58,
          mainAxisExtent: 52,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final item = entries[index];
          final picked = _picked.contains(item.key);
          final label = widget.isRussian ? item.ru : item.en;
          return Tooltip(
            message: label,
            child: Semantics(
              label: label, selected: picked, button: true,
              child: InkWell(
                key: ValueKey('custom-icon-${item.key}'),
                onTap: () => setState(() {
                  if (_browsing) {
                    _picked.add(item.key);
                  } else if (_picked.length > 1) {
                    _picked.remove(item.key);
                  }
                }),
                borderRadius: BorderRadius.circular(10),
                child: Center(child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: picked
                        ? cs.primaryContainer.withValues(alpha: .35)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: picked
                        ? Border.all(color: cs.primary, width: 2) : null,
                  ),
                  child: Center(child: CategorySvgIcon(
                    selection: CategoryIconSelection(item.key),
                    size: 26,
                  )),
                )),
              ),
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
