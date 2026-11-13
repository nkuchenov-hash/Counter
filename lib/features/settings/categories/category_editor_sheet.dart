import 'package:counter/core/life_color_compat.dart';
import 'dart:async';

import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/category_icon_system.dart';
import 'package:counter/features/settings/categories/category_icon_picker.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/settings/categories/category_tag_input_field.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Unified category editor: names, parent, color, icon, keywords, default, delete.
class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet({
    super.key,
    required this.category,
    required this.onSaved,
    this.onCategoryDeleted,
    this.onCancel,
    this.inline = false,
  });

  final CategoryRule category;
  final VoidCallback onSaved;
  final VoidCallback? onCategoryDeleted;
  final VoidCallback? onCancel;
  final bool inline;

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  final Map<String, List<String>> _keywordsByLang = {};
  bool _saving = false;
  int? _selectedColorValue;
  MaterialColor? _selectedPrimary;
  int? _selectedShadeValue;
  late CategoryIconSelection _choice;
  late CategoryIconSelection _initialChoice;
  late final TextEditingController _primaryNameController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameRuController;
  final FocusNode _primaryNameFocus = FocusNode();
  final FocusNode _nameEnFocus = FocusNode();
  final FocusNode _nameRuFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final langs = DatabaseService.instance.settings.effectiveActiveLanguages;
    for (final lang in langs) {
      _keywordsByLang[lang] = List<String>.from(
        widget.category.keywordsFor(lang),
      );
    }
    _selectedColorValue = widget.category.colorValue;
    _choice = CategoryIconStore.instance.selectionFor(widget.category);
    _initialChoice = _choice;
    unawaited(CategoryIconStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {
        _choice = CategoryIconStore.instance.selectionFor(widget.category);
        _initialChoice = _choice;
      });
    }));
    final names = widget.category.localizedNames ?? const {};
    _primaryNameController = TextEditingController(
      text: widget.category.name.trim(),
    );
    _nameEnController = TextEditingController(text: names['en'] ?? '');
    _nameRuController = TextEditingController(text: names['ru'] ?? '');
  }

  @override
  void dispose() {
    _primaryNameController.dispose();
    _nameEnController.dispose();
    _nameRuController.dispose();
    _primaryNameFocus.dispose();
    _nameEnFocus.dispose();
    _nameRuFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final primaryNew = _primaryNameController.text.trim();
    if (primaryNew.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'category_name_required'))),
      );
      return;
    }

    final db = DatabaseService.instance;
    final id = widget.category.id;
    final beforeColor = widget.category.colorValue;
    final colorChanged =
        _selectedColorValue != null && _selectedColorValue != beforeColor;
    final iconSelectionChanged = _choice != _initialChoice;
    final primaryChanged = primaryNew != widget.category.name.trim();

    final oldNames = widget.category.localizedNames ?? const <String, String>{};
    final names = Map<String, String>.from(oldNames);
    for (final entry in <String, String>{
      'en': _nameEnController.text.trim(),
      'ru': _nameRuController.text.trim(),
    }.entries) {
      if (entry.value.isEmpty) {
        names.remove(entry.key);
      } else {
        names[entry.key] = entry.value;
      }
    }
    final namesChanged = !_sameStrings(names, oldNames);
    final keywords = <String, List<String>>{};
    for (final e in _keywordsByLang.entries) {
      final values = e.value.map((s) => s.trim())
          .where((s) => s.isNotEmpty).toList();
      if (values.isNotEmpty) keywords[e.key] = values;
    }
    final oldKeywords = widget.category.keywords ?? const <String, List<String>>{};
    final keywordsChanged = !_sameKeywords(keywords, oldKeywords);
    final delta = <String, dynamic>{
      if (colorChanged) 'color_value': _selectedColorValue,
      if (namesChanged) 'localized_names': names,
      if (keywordsChanged) 'keywords': keywords,
    };

    if (!primaryChanged && delta.isEmpty && !iconSelectionChanged) {
      if (!widget.inline) Navigator.of(context).pop();
      return;
    }
    if (iconSelectionChanged) {
      try {
        await CategoryIconStore.instance.setSelection(widget.category, _choice);
      } catch (error, stack) {
        debugPrint('Category icon save failed for ${_choice.key}: $error\n$stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is ArgumentError
                ? (currentLocale.value == 'ru'
                    ? 'Эта иконка не поддерживается. Выберите другую.'
                    : 'This icon is not supported. Choose another.')
                : (currentLocale.value == 'ru'
                    ? 'Не удалось записать иконку в локальное хранилище. Изменение не сохранено.'
                    : 'Could not write the icon to local storage. No change was saved.')),
          ));
        }
        return;
      }
      if (!mounted) return;
    }
    if (!primaryChanged && delta.isEmpty) {
      widget.onSaved();
      if (!widget.inline) Navigator.of(context).pop();
      return;
    }

    // Stage synchronously into the canonical Brain, without waiting for
    // PocketBase or reloading the category catalog. The offline queue owns
    // retries. Only local-device persistence failures merit a user warning.
    final messenger = ScaffoldMessenger.of(context);
    final staged = db.stageCategoryDelta(id, <String, dynamic>{
      if (primaryChanged) 'name': primaryNew,
      ...delta,
    });
    widget.onSaved();
    if (!widget.inline && mounted) Navigator.of(context).pop();
    unawaited(staged.catchError((Object error, StackTrace stack) {
      messenger.showSnackBar(SnackBar(
        content: Text(currentLocale.value == 'ru'
            ? 'Не удалось сохранить изменение на устройстве. Повторите действие.'
            : 'Could not save the edit on this device. Retry the action.'),
      ));
    }));
  }

  bool _sameStrings(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length &&
      a.entries.every((entry) => b[entry.key] == entry.value);

  bool _sameKeywords(Map<String, List<String>> a, Map<String, List<String>> b) =>
      a.length == b.length &&
      a.entries.every((entry) {
        final other = b[entry.key];
        return other != null &&
            other.length == entry.value.length &&
            List.generate(other.length, (i) => i).every(
              (i) => other[i] == entry.value[i],
            );
      });

  Future<void> _confirmDelete() async {
    final loc = currentLocale.value;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t(loc, 'delete_category_confirm')),
        content: Text(t(loc, 'delete_subcategories_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(t(loc, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            child: Text(t(loc, 'delete')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final idToDelete = widget.category.id;
    final ok = await DatabaseService.instance.deleteCategory(idToDelete);
    if (!mounted) return;
    if (ok) {
      widget.onCategoryDeleted?.call();
      widget.onSaved();
      messenger.showSnackBar(
        SnackBar(content: Text(t(loc, 'category_removed'))),
      );
      if (!widget.inline && mounted) Navigator.of(context).pop();
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(t(loc, 'sync_failed'))),
      );
    }
  }

  void _setAsDefault() {
    unawaited(() async {
      try {
        await DatabaseService.instance.saveSettings(
          DatabaseService.instance.settings.copyWith(
            defaultCategoryId: widget.category.id,
          ),
        );
      } on AuthenticatedUserIdRequiredException {
        // Auth store empty — cannot PATCH profile; ignore silently here.
      } catch (_) {}
    }());
    widget.onSaved();
    if (mounted && !widget.inline) Navigator.of(context).pop();
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'en':
        return t(currentLocale.value, 'keywords_english');
      case 'ru':
        return t(currentLocale.value, 'keywords_russian');
      default:
        return t(currentLocale.value, 'keywords_lang').replaceFirst('%s', code);
    }
  }

  Color _chipBackgroundColor(String code, BuildContext context) {
    switch (code) {
      case 'en':
        return kNordicWork[100]!;
      case 'ru':
        return kNordicEntertainment[100]!;
      default:
        return Theme.of(context).chipTheme.backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHigh;
    }
  }

  Color _chipTextColor(String code, BuildContext context) {
    switch (code) {
      case 'en':
        return kNordicWork[900]!;
      case 'ru':
        return kNordicEntertainment[900]!;
      default:
        return Theme.of(context).chipTheme.labelStyle?.color ?? Theme.of(context).colorScheme.onSurface;
    }
  }

  void _onTagsChanged(String langCode, List<String> newTags) {
    setState(() => _keywordsByLang[langCode] = newTags);
  }

  Future<void> _translateAndAddRuIfNeeded(
    String langCode,
    String trimmed,
  ) async {
    final settings = DatabaseService.instance.settings;
    final langs = settings.effectiveActiveLanguages;
    if (langCode != 'en' || !langs.contains('ru')) return;
    try {
      final translated = await DatabaseService.instance.translateKeyword(
        trimmed,
        fromLang: 'en',
        toLang: 'ru',
      );
      if (!mounted) return;
      if (translated != null && translated.isNotEmpty) {
        setState(() {
          final ruList = _keywordsByLang.putIfAbsent('ru', () => <String>[]);
          if (!ruList.contains(translated)) ruList.add(translated);
        });
      }
    } catch (_) {}
  }

  Color get _currentAccent => Color(canonicalLifeColorValue(
        _selectedColorValue ?? widget.category.colorOrDefault.toARGB32(),
      ));

  Widget _compactSwatch(Color color, bool selected, VoidCallback tap,
      {bool rounded = true}) {
    final outline = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: tap,
        customBorder: rounded
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: rounded ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: rounded ? null : BorderRadius.circular(7),
            border: Border.all(
              width: selected ? 3 : 1,
              color: selected
                  ? outline
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showIconGallery() async {
    final choice = await showCategoryIconPicker(
      context,
      initial: _choice,
      color: _currentAccent,
    );
    if (!mounted || choice == null) return;
    setState(() => _choice = choice);
  }

  Widget _iconPanel(bool desktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t(currentLocale.value, 'category_choose_icon'),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        AppButton.outlined(
          key: const ValueKey('category-full-icon-picker'),
          onPressed: () => unawaited(_showIconGallery()),
          icon: Icons.category_outlined,
          label: currentLocale.value == 'ru'
              ? (desktop ? 'Выбрать иконку · Контур / Заливка' : 'Выбрать иконку')
              : (desktop ? 'Choose icon · Outline / Filled' : 'Choose icon'),
        ),
      ],
    );
  }

  Widget _advancedFields(List<String> langs, String locale) {
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(side: BorderSide.none),
      collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
      title: Text(t(locale, 'category_advanced')),
      children: [
        Text(t(locale, 'name_en'),
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        AppTextField(
          controller: _nameEnController,
          focusNode: _nameEnFocus,
          hintText: '',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        Text(t(locale, 'name_ru'),
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        AppTextField(
          controller: _nameRuController,
          focusNode: _nameRuFocus,
          hintText: '',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t(locale, 'category_section_keywords'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 8),
        ...langs.map((lang) {
          final keywords = _keywordsByLang[lang] ?? const <String>[];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TagInputField(
              tags: keywords,
              onChanged: (tags) => _onTagsChanged(lang, tags),
              onTagAdded: (tag) => _translateAndAddRuIfNeeded(lang, tag),
              decoration: InputDecoration(
                labelText: _languageLabel(lang),
                hintText: t(locale, 'hint_keyword_add'),
              ),
              chipBackgroundColor: _chipBackgroundColor(lang, context),
              chipLabelColor: _chipTextColor(lang, context),
            ),
          );
        }),
        const SizedBox(height: 12),
        AppButton.secondary(
          label: DatabaseService.instance.defaultCategoryId ==
                  widget.category.id
              ? t(locale, 'default_category')
              : t(locale, 'set_as_default'),
          icon: Icons.check_circle_outline,
          onPressed: _setAsDefault,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final langs = DatabaseService.instance.settings.effectiveActiveLanguages;
    final locale = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final route = DatabaseService.instance.categoryPathFromRootToLocalId(widget.category.id);
    final pathLabel = route.length > 1
        ? route.take(route.length - 1)
            .map((id) => DatabaseService.instance.getCategoryRuleById(id)?.name ?? '')
            .where((name) => name.isNotEmpty).join(' › ')
        : t(locale, 'root_top_level');
    _selectedPrimary ??= categoryMaterialPrimaryForValue(_selectedColorValue);
    _selectedShadeValue ??=
        (_selectedColorValue != null &&
            categoryMaterialShadeValues(_selectedPrimary!)
                .contains(_selectedColorValue))
        ? _selectedColorValue
        : categoryColorAtDepth(_selectedPrimary!, route.length - 1);

    // Both an inline desktop inspector and a bounded mobile sheet have
    // independently scrollable content and a visible Save footer.
    return Padding(
      padding: EdgeInsets.only(
        bottom: widget.inline ? 0 : MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: categoryIconPlateColor(_currentAccent),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(child: CategorySvgIcon(
                    selection: _choice,
                    color: _currentAccent,
                    size: 22,
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _primaryNameController.text.trim().isEmpty
                            ? widget.category.name
                            : _primaryNameController.text.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        pathLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.inline)
                  IconButton(
                    tooltip: t(locale, 'close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t(locale, 'category_name_label'),
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  AppTextField(
                    key: const ValueKey('category-primary-name'),
                    controller: _primaryNameController,
                    focusNode: _primaryNameFocus,
                    hintText: '',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t(locale, 'category_section_appearance'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, constraints) {
                    final desktopPicker = constraints.maxWidth >= 760;
                    final colors = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t(locale, 'category_color'),
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                         // One unbroken horizontal strip of base hues,
                         // including grey. Narrow screens scroll, not wrap.
                         SizedBox(
                           height: 40,
                           child: ListView.separated(
                             key: const ValueKey('category-base-palette-row'),
                             scrollDirection: Axis.horizontal,
                             itemCount: kCategoryPickerMaterialColors.length,
                             separatorBuilder: (_, _) =>
                                 const SizedBox(width: 6),
                             itemBuilder: (context, index) {
                               final color = kCategoryPickerMaterialColors[index];
                               return Tooltip(
                                 message: index == kCategoryPickerMaterialColors.length - 1
                                     ? 'Нейтральный серый' : 'Цветовая группа ${index + 1}',
                                 child: _compactSwatch(
                                   color[500]!, // Always show the base hue in the family palette.
                                   _selectedPrimary == color,
                                   () => setState(() {
                                     _selectedPrimary = color;
                                     _selectedShadeValue =
                                         categoryColorAtDepth(color, route.length - 1);
                                     _selectedColorValue = _selectedShadeValue;
                                   }),
                                 ),
                               );
                             },
                           ),
                         ),
                         const SizedBox(height: 12),
                         // The levels are immediately visible, separated from
                         // the base families by a fine rule.
                         Divider(height: 1, color: scheme.outlineVariant),
                         const SizedBox(height: 10),
                         Text('Интенсивность по уровню',
                             style: Theme.of(context).textTheme.bodyMedium),
                         const SizedBox(height: 8),
                         Row(
                           key: const ValueKey('category-visible-tone-row'),
                           children: [
                             for (var i = 0; i < kCategorySelectableTones.length; i++) ...[
                               if (i > 0)
                                 Container(
                                   margin: const EdgeInsets.symmetric(horizontal: 13),
                                   height: 28,
                                   width: 1,
                                   color: scheme.outlineVariant,
                                 ),
                               Tooltip(
                                 message: switch (i) {
                                   0 => 'Уровень 3 и глубже',
                                   1 => 'Дочерняя категория',
                                   _ => 'Корневая категория',
                                 },
                                 child: _compactSwatch(
                                   _selectedPrimary![kCategorySelectableTones[i]]!,
                                   _selectedShadeValue ==
                                       _selectedPrimary![kCategorySelectableTones[i]]!
                                           .toARGB32(),
                                   () => setState(() {
                                     final v = _selectedPrimary![
                                         kCategorySelectableTones[i]]!.toARGB32();
                                     _selectedShadeValue = v;
                                     _selectedColorValue = v;
                                   }),
                                   rounded: false,
                                 ),
                               ),
                             ],
                           ],
                         ),
                      ],
                    );
                    if (!desktopPicker) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          colors,
                          const SizedBox(height: 18),
                          _iconPanel(false),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: colors),
                        const SizedBox(width: 24),
                        Expanded(child: _iconPanel(true)),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  _advancedFields(langs, locale),
                ],
              ),
            ),
          ),
          Container(
            color: scheme.surface,
            padding: const EdgeInsets.fromLTRB(12, 10, 18, 14),
            child: Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: _saving ? null : () => unawaited(_confirmDelete()),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(t(locale, 'delete')),
                ),
                const Spacer(),
                AppButton.ghost(
                  label: t(locale, 'cancel'),
                  onPressed: _saving
                      ? null
                      : (widget.inline ? widget.onCancel
                          : () => Navigator.of(context).pop()),
                ),
                const SizedBox(width: 8),
                AppButton.primary(
                  label: t(locale, 'save'),
                  loading: _saving,
                  onPressed: _saving ? null : () => unawaited(_save()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
