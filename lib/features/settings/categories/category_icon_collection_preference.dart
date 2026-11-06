import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/category_icon_system.dart';
import 'package:counter/core/app_build_info.dart';
import 'package:flutter/material.dart';

/// Preferred category subjects. All selectable icons are available in the
/// picker regardless of whether they belong to the quick collection.
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
                ? 'Выбранные значки — в начале списка после основных повседневных тем.'
                : 'Favorites follow everyday essentials; every category icon remains available.',
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
  bool _showFullFluent = false;
  bool _selectedOnly = false;
  String _group = 'Все';

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
    }).catchError((Object error) {
      debugPrint('Unable to read saved icon favorites: $error');
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
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final existing = CategoryIconStore.instance.quickKeys;
      final all = CategoryIconStore.catalogFor(includeFullFluent: true);
      final order = <String>[
        ...existing.where(_picked.contains),
        ...all.map((e) => e.key).where(
            (key) => _picked.contains(key) && !existing.contains(key)),
        ..._picked.where((key) => !existing.contains(key) &&
            !all.any((e) => e.key == key)),
      ];
      await CategoryIconStore.instance.setQuickKeys(order);
      if (mounted) Navigator.of(context).pop();
    } catch (error, stack) {
      debugPrint('Could not persist chosen category icons: $error\n$stack');
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
    final approved =
        CategoryIconStore.catalogFor(includeFullFluent: _showFullFluent);
    final labels = <String, CategoryIconChoice>{
      for (final item in CategoryIconStore.catalogFor(includeFullFluent: true))
        item.key: item,
    };
    final entries = _selectedOnly
        ? <CategoryIconChoice>[
            for (final key in _picked)
              if (labels.containsKey(key))
                labels[key]!
              else
                CategoryIconChoice(key, key.replaceAll('_', ' '),
                    key.replaceAll('_', ' '), 'Прочее', ''),
          ]
        : approved;
    final visible = entries.where((item) {
      if (!_selectedOnly && !_showFullFluent &&
          _group != 'Все' && _group != item.group) return false;
      return query.isEmpty ||
          [item.key, item.en, item.ru, item.synonyms]
              .join(' ').toLowerCase().contains(query);
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 5),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isRussian ? 'Мои иконки' : 'My icons',
                  style: Theme.of(context).textTheme.titleLarge),
              Text(widget.isRussian
                  ? 'Выбрано: ${_picked.length} · нажмите значок, чтобы добавить или убрать'
                  : '${_picked.length} selected · tap an icon to add or remove',
                style: Theme.of(context).textTheme.bodySmall),
            ],
          )),
          IconButton(onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 7),
        child: Wrap(spacing: 7, runSpacing: 6, children: [
          ChoiceChip(
            key: const ValueKey('everyday-icon-catalog'),
            label: Text(widget.isRussian ? 'Повседневные' : 'Everyday'),
            selected: !_showFullFluent && !_selectedOnly,
            onSelected: (_) => setState(() {
              _showFullFluent = false;
              _selectedOnly = false;
              _group = 'Все';
            }),
          ),
          ChoiceChip(
            key: const ValueKey('selected-icon-catalog'),
            label: Text(widget.isRussian
                ? 'Мои (${_picked.length})'
                : 'Selected (${_picked.length})'),
            selected: _selectedOnly,
            onSelected: (_) => setState(() {
              _selectedOnly = !_selectedOnly;
              _group = 'Все';
            }),
          ),
          ChoiceChip(
            key: const ValueKey('toggle-icon-catalog'),
            label: Text(widget.isRussian
                ? 'Вся Fluent (${CategoryIconStore.fullFluentCount})'
                : 'All Fluent (${CategoryIconStore.fullFluentCount})'),
            selected: _showFullFluent && !_selectedOnly,
            onSelected: (_) => setState(() {
              _showFullFluent = true;
              _selectedOnly = false;
              _group = 'Все';
            }),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 3, 18, 3),
        child: TextField(
          controller: _search,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            hintText: widget.isRussian
                ? 'Поиск: собака, машина, спорт…'
                : 'Search: dog, car, sports…',
            border: const OutlineInputBorder(),
            suffixIcon: query.isEmpty ? null : IconButton(
              onPressed: _search.clear,
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ),
      if (!_showFullFluent && !_selectedOnly)
        SizedBox(height: 50, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 7, 18, 2),
          itemCount: kCategorySubjectGroups.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) => ChoiceChip(
            label: Text(categorySubjectGroupName(kCategorySubjectGroups[i],
                russian: widget.isRussian)),
            selected: kCategorySubjectGroups[i] == _group,
            showCheckmark: false,
            onSelected: (_) => setState(
                () => _group = kCategorySubjectGroups[i]),
          ),
        )),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
        child: Text(widget.isRussian
            ? 'Показано ${visible.length} · выбранные отмечены галочкой'
            : '${visible.length} shown · checkmark means selected',
            style: Theme.of(context).textTheme.bodySmall),
      ),
      Expanded(child: visible.isEmpty
          ? Center(child: Text(widget.isRussian
              ? 'Нет иконок по этому запросу'
              : 'No icons match this filter'))
          : GridView.builder(
        key: const ValueKey('matched-icon-collection-grid'),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 58, mainAxisExtent: 54,
          mainAxisSpacing: 5, crossAxisSpacing: 5,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final item = visible[index];
          final picked = _picked.contains(item.key);
          final label = widget.isRussian ? item.ru : item.en;
          return Tooltip(
            message: label,
            child: Semantics(
              label: label, selected: picked, button: true,
              child: InkWell(
                key: ValueKey('custom-icon-${item.key}'),
                onTap: () => setState(() {
                  if (picked) {
                    _picked.remove(item.key);
                  } else {
                    _picked.add(item.key);
                  }
                }),
                borderRadius: BorderRadius.circular(10),
                child: Center(child: Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(
                    color: picked
                        ? cs.primaryContainer.withValues(alpha: .35)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: picked
                        ? Border.all(color: cs.primary, width: 1.5)
                        : null,
                  ),
                  child: Stack(children: [
                    Center(child: CategorySvgIcon(
                      selection: CategoryIconSelection(item.key),
                      size: 26,
                    )),
                    if (picked) Positioned(
                      right: 0, bottom: 0,
                      child: Icon(Icons.check_circle, color: cs.primary,
                          size: 13),
                    ),
                  ]),
                )),
              ),
            ),
          );
        },
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 7, 18, 14),
        child: SafeArea(top: false, child: Row(children: [
          TextButton(
            key: const ValueKey('clear-icon-collection'),
            onPressed: _saving ? null : () => setState(_picked.clear),
            child: Text(widget.isRussian ? 'Убрать все' : 'Clear all'),
          ),
          TextButton(
            key: const ValueKey('reset-default-icons'),
            onPressed: _saving ? null : () => setState(() {
              _picked
                ..clear()
                ..addAll(kDefaultCategoryIconKeys);
            }),
            child: Text(widget.isRussian ? 'Стандартные' : 'Starter set'),
          ),
          const Spacer(),
          FilledButton(
            key: const ValueKey('save-icon-collection'),
            onPressed: _saving ? null : _save,
            child: Text(widget.isRussian ? 'Готово' : 'Done'),
          ),
        ])),
      ),
    ]);
  }
}
