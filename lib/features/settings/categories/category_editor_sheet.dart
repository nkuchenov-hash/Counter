import 'dart:async';

import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/settings/categories/category_helpers.dart';
import 'package:counter/features/settings/categories/category_tag_input_field.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _showShades = false;
  int? _selectedColorValue;
  MaterialColor? _selectedPrimary;
  int? _selectedShadeValue;
  late int _iconCodePoint;
  late final TextEditingController _primaryNameController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameRuController;

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
    _iconCodePoint = categoryManagerIconFor(widget.category).codePoint;
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
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_primaryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'category_name_required'))),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final cid = widget.category.id;
    final currentColor = widget.category.colorValue;
    final colorChanged =
        _selectedColorValue != null && _selectedColorValue != currentColor;
    final iconChanged =
        _iconCodePoint !=
        (widget.category.iconCodePoint ?? Icons.folder_rounded.codePoint);
    if (colorChanged) {
      DatabaseService.instance.updateNestedCategory(
        cid,
        colorValue: _selectedColorValue,
      );
    }
    if (iconChanged) {
      DatabaseService.instance.updateNestedCategory(
        cid,
        iconCodePoint: _iconCodePoint,
      );
    }
    final newNames = <String, String>{};
    final enName = _nameEnController.text.trim();
    final ruName = _nameRuController.text.trim();
    if (enName.isNotEmpty) newNames['en'] = enName;
    if (ruName.isNotEmpty) newNames['ru'] = ruName;
    final bool namesChanged = newNames.isNotEmpty;
    final Map<String, List<String>> keywords = {};
    for (final e in _keywordsByLang.entries) {
      final parts = e.value
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) keywords[e.key] = parts;
    }
    final primaryNew = _primaryNameController.text.trim();
    final primaryChanged =
        primaryNew.isNotEmpty && primaryNew != widget.category.name.trim();
    try {
      if (primaryChanged) {
        final result = await DatabaseService.instance.updateCategory(cid, primaryNew);
        if (!result.ok) throw StateError('Rename failed');
      }
      final delta = <String, dynamic>{'keywords': keywords};
      if (namesChanged) {
        DatabaseService.instance.updateCategoryLocalizedNames(cid, newNames);
        delta['localized_names'] = newNames;
      }
      if (colorChanged) delta['color_value'] = _selectedColorValue;
      if (iconChanged) delta['icon_code_point'] = _iconCodePoint;
      final patch = await DatabaseService.instance.patchCategoryDelta(cid, delta);
      if (!patch.ok) throw StateError('Category patch failed');
      if (!mounted) return;
      widget.onSaved();
      if (!widget.inline && mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(t(currentLocale.value, 'sync_failed')),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
        return Colors.blue.shade100;
      case 'ru':
        return Colors.red.shade100;
      default:
        return Theme.of(context).chipTheme.backgroundColor ??
            Colors.grey.shade300;
    }
  }

  Color _chipTextColor(String code, BuildContext context) {
    switch (code) {
      case 'en':
        return Colors.blue.shade900;
      case 'ru':
        return Colors.red.shade900;
      default:
        return Theme.of(context).chipTheme.labelStyle?.color ?? Colors.black87;
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

  Widget _compactSwatch(Color color, bool selected, VoidCallback tap,
      {bool rounded = true}) {
    final outline = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 5, bottom: 5),
      child: InkWell(
        onTap: tap,
        customBorder: rounded
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        child: Container(
          width: 27,
          height: 27,
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 590),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: Text(t(currentLocale.value, 'category_choose_icon'),
                        style: Theme.of(ctx).textTheme.titleLarge)),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 64,
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                    mainAxisExtent: 48,
                  ),
                  itemCount: kCategoryMoreIconChoices.length,
                  itemBuilder: (context, index) {
                    final icon = kCategoryMoreIconChoices[index];
                    return _iconTile(icon, closeGallery: () => Navigator.of(ctx).pop());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconTile(IconData icon, {VoidCallback? closeGallery}) {
    final scheme = Theme.of(context).colorScheme;
    final active = _iconCodePoint == icon.codePoint;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () {
        setState(() => _iconCodePoint = icon.codePoint);
        HapticFeedback.selectionClick();
        closeGallery?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: active ? scheme.onSurface.withValues(alpha: 0.05) : scheme.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? scheme.onSurface : scheme.outlineVariant,
            width: active ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: scheme.onSurface),
      ),
    );
  }

  /// HTML-parity picker: a real bounded three-row icon panel, never an
  /// unbounded shrink-wrap GridView inside the editor scroll view.
  Widget _iconPanel(bool desktop) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t(currentLocale.value, 'category_choose_icon'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = desktop ? 5 : 4;
            const gap = 6.0;
            const tileHeight = 34.0;
            final tileWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            final visibleCount = columns * 3 - 1;
            final visibleIcons = kCategoryIconChoices
                .take(visibleCount)
                .toList(growable: false);
            return SizedBox(
              key: const Key('category_icon_grid'),
              height: tileHeight * 3 + gap * 2,
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final icon in visibleIcons)
                    SizedBox(
                      width: tileWidth,
                      height: tileHeight,
                      child: _iconTile(icon),
                    ),
                  SizedBox(
                    width: tileWidth,
                    height: tileHeight,
                    child: OutlinedButton(
                      key: const Key('category_more_icons'),
                      onPressed: () => unawaited(_showIconGallery()),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: const Icon(Icons.more_horiz_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            );
          },
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
        TextField(
          controller: _nameEnController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: t(locale, 'name_en')),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameRuController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: t(locale, 'name_ru')),
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
                    color: Color(_selectedColorValue ?? widget.category.colorOrDefault.toARGB32())
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    IconData(_iconCodePoint, fontFamily: 'MaterialIcons'),
                    color: Color(_selectedColorValue ?? widget.category.colorOrDefault.toARGB32()),
                    size: 22,
                  ),
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
                  TextField(
                    controller: _primaryNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: t(locale, 'category_name_label'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t(locale, 'category_section_appearance'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Keep colors and icons alongside each other even in a
                      // mobile editor. The color palette is a deliberately
                      // narrow column, so it cannot swallow the icon picker.
                      final wide = constraints.maxWidth >= 470;
                      final colorWidth = constraints.maxWidth >= 680
                          ? 190.0
                          : wide
                              ? 150.0
                              : 116.0;
                      final gap = wide ? 22.0 : 12.0;
                      final colors = Column(
                        key: const Key('category_color_column'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(locale, 'category_color'),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 0,
                            runSpacing: 2,
                            children: [
                              for (final color in kCategoryPickerMaterialColors)
                                _compactSwatch(
                                  color,
                                  _selectedPrimary == color,
                                  () {
                                    setState(() {
                                      _selectedPrimary = color;
                                      _selectedShadeValue = categoryColorAtDepth(
                                        color, route.length - 1,
                                      );
                                      _selectedColorValue = _selectedShadeValue;
                                    });
                                  },
                                ),
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  onPressed: () => setState(
                                    () => _showShades = !_showShades,
                                  ),
                                  tooltip: t(locale, 'category_color_shades'),
                                  icon: Icon(
                                    _showShades
                                        ? Icons.remove_circle_outline
                                        : Icons.add_circle_outline,
                                    size: 24,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_showShades) ...[
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 0,
                              runSpacing: 2,
                              children: [
                                for (final tone in kCategorySelectableTones)
                                  _compactSwatch(
                                    _selectedPrimary![tone]!,
                                    _selectedShadeValue ==
                                        _selectedPrimary![tone]!.toARGB32(),
                                    () {
                                      setState(() {
                                        _selectedShadeValue =
                                            _selectedPrimary![tone]!.toARGB32();
                                        _selectedColorValue =
                                            _selectedShadeValue;
                                      });
                                    },
                                    rounded: false,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      );
                      return Row(
                        key: const Key('category_appearance_columns'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: colorWidth, child: colors),
                          SizedBox(width: gap),
                          Expanded(child: _iconPanel(wide)),
                        ],
                      );
                    },
                  ),
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
