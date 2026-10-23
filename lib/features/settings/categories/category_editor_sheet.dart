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
    widget.onCategoryDeleted?.call();
    widget.onSaved();
    if (!widget.inline) Navigator.of(context).pop();
    final ok = await DatabaseService.instance.deleteCategory(idToDelete);
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(t(loc, 'category_removed'))),
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
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: tap,
        customBorder: rounded
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        child: Container(
          width: 34,
          height: 34,
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

  Widget _iconPanel(bool desktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t(currentLocale.value, 'category_choose_icon'),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final columns = desktop ? 5 : 4;
          final count = columns * 3;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: count,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              mainAxisExtent: 38,
            ),
            itemBuilder: (context, index) {
              if (index == count - 1) {
                return OutlinedButton(
                  onPressed: () => unawaited(_showIconGallery()),
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Icon(Icons.more_horiz_rounded, size: 22),
                );
              }
              return _iconTile(kCategoryIconChoices[index]);
            },
          );
        }),
      ],
    );
  }

  Widget _advancedFields(List<String> langs, String locale) {
    final scheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
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
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t(locale, 'delete_subcategories_warning'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AppButton.danger(
          label: t(locale, 'delete_category'),
          icon: Icons.delete_outline_rounded,
          onPressed: _confirmDelete,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final langs = DatabaseService.instance.settings.effectiveActiveLanguages;
    final locale = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    _selectedPrimary ??= categoryMaterialPrimaryForValue(_selectedColorValue);
    _selectedShadeValue ??=
        (_selectedColorValue != null &&
            categoryMaterialShadeValues(_selectedPrimary!)
                .contains(_selectedColorValue))
        ? _selectedColorValue
        : _selectedPrimary![500]!.toARGB32();

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
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t(locale, 'edit_category_tag')
                        .replaceFirst('%s', widget.category.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
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
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.035),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: widget.category.colorOrDefault.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(IconData(_iconCodePoint, fontFamily: 'MaterialIcons'),
                              color: widget.category.colorOrDefault),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(widget.category.name,
                            style: Theme.of(context).textTheme.titleMedium)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  LayoutBuilder(builder: (context, constraints) {
                    final desktopPicker = constraints.maxWidth >= 540;
                    final colors = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t(locale, 'category_color'),
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(spacing: 4, runSpacing: 8,
                          children: [
                            ...kCategoryPickerMaterialColors.map((color) =>
                              _compactSwatch(color, _selectedPrimary == color, () {
                                setState(() {
                                  _selectedPrimary = color;
                                  _selectedShadeValue = color[500]!.toARGB32();
                                  _selectedColorValue = _selectedShadeValue;
                                });
                              })),
                            IconButton.outlined(
                              onPressed: () => setState(() => _showShades = !_showShades),
                              tooltip: t(locale, 'category_color_shades'),
                              icon: Icon(_showShades ? Icons.remove : Icons.add),
                            ),
                          ],
                        ),
                        if (_showShades) ...[
                          const SizedBox(height: 10),
                          Wrap(spacing: 4, runSpacing: 8,
                            children: <int>[50, 100, 200, 300, 400, 500, 600, 700, 800, 900]
                              .map((tone) {
                                final c = _selectedPrimary![tone]!;
                                final v = c.toARGB32();
                                return _compactSwatch(c, _selectedShadeValue == v, () {
                                  setState(() {
                                    _selectedShadeValue = v;
                                    _selectedColorValue = v;
                                  });
                                }, rounded: false);
                              }).toList(),
                          ),
                        ],
                      ],
                    );
                    if (!desktopPicker) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [colors, const SizedBox(height: 18), _iconPanel(false)],
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.secondary(
                  label: t(locale, 'cancel'),
                  onPressed: _saving ? null : (widget.inline ? widget.onCancel : () => Navigator.of(context).pop()),
                ),
                const SizedBox(width: 10),
                AppButton.primary(
                  label: t(locale, 'save'),
                  icon: Icons.check_rounded,
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
