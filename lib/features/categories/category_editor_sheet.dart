import 'dart:async';

import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/categories/category_helpers.dart';
import 'package:counter/features/categories/category_tag_input_field.dart';
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
  });

  final CategoryRule category;
  final VoidCallback onSaved;
  final VoidCallback? onCategoryDeleted;

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  final Map<String, List<String>> _keywordsByLang = {};
  bool _saving = false;
  int? _parentId;
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
    _parentId = DatabaseService.instance.getParentId(widget.category.id);
    _selectedColorValue = widget.category.colorValue;
    _iconCodePoint =
        widget.category.iconCodePoint ?? Icons.folder_rounded.codePoint;
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
    final currentParent = DatabaseService.instance.getParentId(cid);
    final newParent = _parentId;
    final currentEffective = currentParent;
    final primaryNew = _primaryNameController.text.trim();
    final primaryChanged =
        primaryNew.isNotEmpty && primaryNew != widget.category.name.trim();
    if (mounted) {
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
        if (currentEffective != newParent) {
          await DatabaseService.instance.updateCategoryParent(cid, newParent);
        }
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
        );
      }
      if (mounted) setState(() => _saving = false);
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
    Navigator.of(context).pop();
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
    if (mounted) Navigator.of(context).pop();
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

  Widget _buildParentPicker(BuildContext context) {
    final db = DatabaseService.instance;
    final forbidden = {
      widget.category.id,
      ...db.getRecordIdsInSubtree(widget.category.id),
    };
    final pairs = db.allCategoryIdPathPairs
        .where((p) => !forbidden.contains(p.id))
        .toList();
    return DropdownButtonFormField<int?>(
      initialValue: _parentId,
      decoration: InputDecoration(
        labelText: t(currentLocale.value, 'parent_category'),
      ),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text(t(currentLocale.value, 'root_top_level')),
        ),
        ...pairs.map(
          (p) => DropdownMenuItem<int?>(
            value: p.id,
            child: Text(p.path, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _parentId = v),
    );
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

  @override
  Widget build(BuildContext context) {
    final langs = DatabaseService.instance.settings.effectiveActiveLanguages;
    final locale = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;

    _selectedPrimary ??= categoryMaterialPrimaryForValue(_selectedColorValue);
    _selectedShadeValue ??=
        (_selectedColorValue != null &&
            categoryMaterialShadeValues(
              _selectedPrimary!,
            ).contains(_selectedColorValue))
        ? _selectedColorValue
        : _selectedPrimary![500]!.toARGB32();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(
                locale,
                'edit_category_tag',
              ).replaceFirst('%s', widget.category.name),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text(
              t(locale, 'category_primary_tag_name'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            TextField(
              controller: _primaryNameController,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text(t(locale, 'name_en')),
            TextField(
              controller: _nameEnController,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Text(t(locale, 'name_ru')),
            TextField(
              controller: _nameRuController,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            _buildParentPicker(context),
            const SizedBox(height: 24),
            Text(
              t(locale, 'category_section_appearance'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              t(locale, 'category_color'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategoryPickerMaterialColors.map((p) {
                final sel = _selectedPrimary == p;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPrimary = p;
                      _selectedShadeValue = p[500]!.toARGB32();
                      _selectedColorValue = _selectedShadeValue;
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: p,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? scheme.primary : Colors.transparent,
                        width: sel ? 3 : 0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>[50, 100, 200, 300, 400, 500, 600, 700, 800, 900]
                  .map((tone) {
                    final c = _selectedPrimary![tone]!;
                    final v = c.toARGB32();
                    final sel = _selectedShadeValue == v;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedShadeValue = v;
                          _selectedColorValue = v;
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? scheme.primary : Colors.transparent,
                            width: sel ? 3 : 0,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              t(locale, 'category_choose_icon'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategoryIconChoices.map((ic) {
                final cp = ic.codePoint;
                final sel = _iconCodePoint == cp;
                return InkWell(
                  onTap: () {
                    setState(() => _iconCodePoint = cp);
                    HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? scheme.primary : scheme.outlineVariant,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      ic,
                      color: sel ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              t(locale, 'category_section_keywords'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...langs.map((lang) {
              final keywords = _keywordsByLang[lang] ?? const <String>[];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _languageLabel(lang),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    TagInputField(
                      tags: keywords,
                      onChanged: (newTags) => _onTagsChanged(lang, newTags),
                      onTagAdded: (tag) =>
                          _translateAndAddRuIfNeeded(lang, tag),
                      decoration: InputDecoration(
                        labelText: t(locale, 'add_keyword_label'),
                        hintText: t(locale, 'hint_keyword_add'),
                      ),
                      chipBackgroundColor: _chipBackgroundColor(lang, context),
                      chipLabelColor: _chipTextColor(lang, context),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(
              t(locale, 'category_section_more'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _setAsDefault,
              icon: const Icon(Icons.check_circle_outline, size: 22),
              label: Text(
                DatabaseService.instance.defaultCategoryId == widget.category.id
                    ? t(locale, 'default_category')
                    : t(locale, 'set_as_default'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(locale, 'delete_subcategories_warning'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _confirmDelete,
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              child: Text(t(locale, 'delete')),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: AppLoading(size: AppLoadingSize.small),
                    )
                  : Text(t(locale, 'save')),
            ),
          ],
        ),
      ),
    );
  }
}
