import 'dart:async';
import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/category_icon_system.dart';
import 'package:counter/features/settings/categories/category_icon_picker.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Quick color + icon picker (edit mode: tap category icon). Uses same PATCH path as full editor.
class CategoryAppearanceSheet extends StatefulWidget {
  const CategoryAppearanceSheet({
    super.key,
    required this.category,
    required this.onSaved,
  });

  final CategoryRule category;
  final VoidCallback onSaved;

  @override
  State<CategoryAppearanceSheet> createState() =>
      _CategoryAppearanceSheetState();
}

class _CategoryAppearanceSheetState extends State<CategoryAppearanceSheet> {
  late int? _colorValue;
  late CategoryIconSelection _choice;
  late CategoryIconSelection _initialChoice;
  MaterialColor? _selectedPrimary;
  int? _selectedShadeValue;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _colorValue = widget.category.colorValue == null
        ? null
        : canonicalLifeColorValue(widget.category.colorValue!);
    _choice = CategoryIconStore.instance.selectionFor(widget.category);
    _initialChoice = _choice;
    unawaited(CategoryIconStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {
        _choice = CategoryIconStore.instance.selectionFor(widget.category);
        _initialChoice = _choice;
      });
    }));
  }

  MaterialColor _primaryForValue(int? v) => categoryMaterialPrimaryForValue(v);

  Future<void> _apply() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_choice != _initialChoice) {
        await CategoryIconStore.instance.setSelection(widget.category, _choice);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(
          content: Text(currentLocale.value == 'ru'
              ? 'Не удалось сохранить иконку на устройстве.'
              : 'Could not save the icon on this device.'),
        ));
      }
      return;
    }
    if (!mounted) return;
    final staged = DatabaseService.instance.stageCategoryDelta(
      widget.category.id,
      <String, dynamic>{'color_value': _colorValue ?? 0},
    );
    widget.onSaved();
    Navigator.of(context).pop();
    unawaited(staged.catchError((Object _, StackTrace __) {
      messenger.showSnackBar(SnackBar(
        content: Text(currentLocale.value == 'ru'
            ? 'Не удалось сохранить цвет на устройстве.'
            : 'Could not save the color on this device.'),
      ));
    }));
  }

  Future<void> _pickIcon() async {
    final selection = await showCategoryIconPicker(
      context,
      initial: _choice,
      color: Color(_colorValue ?? widget.category.colorOrDefault.toARGB32()),
    );
    if (!mounted || selection == null) return;
    setState(() => _choice = selection);
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    _selectedPrimary ??= _primaryForValue(_colorValue);
    final depth = DatabaseService.instance
        .categoryPathFromRootToLocalId(widget.category.id).length - 1;
    _selectedShadeValue ??=
        (_colorValue != null &&
            categoryMaterialShadeValues(_selectedPrimary!).contains(_colorValue))
        ? _colorValue
        : categoryColorAtDepth(_selectedPrimary!, depth);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(loc, 'category_section_appearance'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              t(loc, 'category_color'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                key: const ValueKey('category-quick-base-palette-row'),
                scrollDirection: Axis.horizontal,
                itemCount: kCategoryPickerMaterialColors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, i) {
                  final p = kCategoryPickerMaterialColors[i];
                  final selected = _selectedPrimary == p;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPrimary = p;
                        _selectedShadeValue = categoryColorAtDepth(p, depth);
                        _colorValue = _selectedShadeValue;
                      });
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 10),
            Text('Интенсивность по уровню',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              key: const ValueKey('category-quick-tone-row'),
              children: [
                for (var i = 0; i < kCategorySelectableTones.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1, height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  GestureDetector(
                    onTap: () {
                      final v = _selectedPrimary![
                          kCategorySelectableTones[i]]!.toARGB32();
                      setState(() {
                        _selectedShadeValue = v;
                        _colorValue = v;
                      });
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _selectedPrimary![kCategorySelectableTones[i]]!,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedShadeValue ==
                                  _selectedPrimary![
                                    kCategorySelectableTones[i]]!.toARGB32()
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: _selectedShadeValue ==
                                  _selectedPrimary![
                                    kCategorySelectableTones[i]]!.toARGB32()
                              ? 2.5 : 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              t(loc, 'category_choose_icon'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey('category-quick-icon-picker'),
              onPressed: _busy ? null : () => unawaited(_pickIcon()),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
              child: Row(children: [
                CategorySvgIcon(
                  selection: _choice, size: 28,
                  color: Color(_colorValue ?? widget.category.colorOrDefault.toARGB32()),
                ),
                const SizedBox(width: 13),
                Expanded(child: Text(
                  currentLocale.value == 'ru' ? 'Выбрать иконку · Контур / Заливка'
                      : 'Choose icon · Outline / Filled',
                )),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _apply,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: AppLoading(size: AppLoadingSize.small),
                    )
                  : Text(t(loc, 'category_appearance_apply')),
            ),
          ],
        ),
      ),
    );
  }
}
