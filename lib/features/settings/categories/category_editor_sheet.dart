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
    if (mounted && !widget.inline) {
      widget.onSaved();
      Navigator.of(context).pop();
    }
    unawaited(() async {
      try {
        if (primaryChanged) {
          final res = await DatabaseService.instance.updateCategory(
            cid,
            primaryNew,
          );
          if (!res.ok && mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
            );
          }
        }
        final delta = <String, dynamic>{'keywords': keywords};
        if (namesChanged) {
          DatabaseService.instance.updateCategoryLocalizedNames(cid, newNames);
          delta['localized_names'] = newNames;
        }
        if (colorChanged) {
          DatabaseService.instance.updateNestedCategory(
            cid,
            colorValue: _selectedColorValue,
          );
          delta['color_value'] = _selectedColorValue;
        }
        if (iconChanged) {
          delta['icon_code_point'] = _iconCodePoint;
        }
        final patch = await DatabaseService.instance.patchCategoryDelta(
          cid,
          delta,
        );
        if (!patch.ok) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
            );
          }
          return;
        }
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
        );
      }
      if (mounted) {
        setState(() => _saving = false);
        if (widget.inline) widget.onSaved();
      }
    }());
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
                  TextField(
                    controller: _primaryNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: t(locale, 'category_name_label'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildParentPicker(context),
                  const SizedBox(height: 18),
                  Text(
                    t(locale, 'category_section_appearance'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: kCategoryPickerMaterialColors.map((color) {
                        final selected = _selectedPrimary == color;
                        return _compactSwatch(color, selected, () {
                          setState(() {
                            _selectedPrimary = color;
                            _selectedShadeValue = color[500]!.toARGB32();
                            _selectedColorValue = _selectedShadeValue;
                          });
                          HapticFeedback.lightImpact();
                        });
                      }).toList(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => _showShades = !_showShades,
                      ),
                      icon: Icon(
                        _showShades
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                      label: Text(t(locale, 'category_color_shades')),
                    ),
                  ),
                  if (_showShades)
                    Wrap(
                      spacing: 2,
                      runSpacing: 8,
                      children: <int>[50, 100, 200, 300, 400, 500, 600, 700, 800, 900]
                          .map((tone) {
                        final color = _selectedPrimary![tone]!;
                        final value = color.toARGB32();
                        return _compactSwatch(
                          color,
                          _selectedShadeValue == value,
                          () {
                            setState(() {
                              _selectedShadeValue = value;
                              _selectedColorValue = value;
                            });
                            HapticFeedback.lightImpact();
                          },
                          rounded: false,
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    t(locale, 'category_choose_icon'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: kCategoryIconChoices.map((icon) {
                        final selected = icon.codePoint == _iconCodePoint;
                        return Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: InkWell(
                            onTap: () {
                              setState(() => _iconCodePoint = icon.codePoint);
                              HapticFeedback.lightImpact();
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: selected
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Icon(icon, color: selected
                                  ? scheme.primary : scheme.onSurface),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _advancedFields(langs, locale),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: AppButton.primary(
              label: t(locale, 'save'),
              loading: _saving,
              fullWidth: true,
              onPressed: _saving ? null : () => unawaited(_save()),
            ),
          ),
        ],
      ),
    );
  }
}
