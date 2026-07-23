import 'package:counter/core/category_color_palette.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/settings/categories/category_helpers.dart';
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
  late int _iconCodePoint;
  MaterialColor? _selectedPrimary;
  int? _selectedShadeValue;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _colorValue = widget.category.colorValue;
    _iconCodePoint =
        widget.category.iconCodePoint ?? Icons.folder_rounded.codePoint;
  }

  MaterialColor _primaryForValue(int? v) => categoryMaterialPrimaryForValue(v);

  Future<void> _apply() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final id = widget.category.id;
    final cv = _colorValue ?? 0;
    DatabaseService.instance.updateNestedCategory(
      id,
      colorValue: cv,
      iconCodePoint: _iconCodePoint,
    );
    if (mounted) {
      widget.onSaved();
      Navigator.of(context).pop();
    }
    try {
      final patch = await DatabaseService.instance.patchCategoryDelta(
        id,
        <String, dynamic>{'color_value': cv, 'icon_code_point': _iconCodePoint},
      );
      if (!patch.ok && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'sync_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    _selectedPrimary ??= _primaryForValue(_colorValue);
    _selectedShadeValue ??=
        (_colorValue != null &&
            categoryMaterialShadeValues(
              _selectedPrimary!,
            ).contains(_colorValue))
        ? _colorValue
        : _selectedPrimary![500]!.toARGB32();

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
                      _colorValue = _selectedShadeValue;
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
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
                          _colorValue = v;
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: sel ? 3 : 0,
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              t(loc, 'category_choose_icon'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      ic,
                      color: sel
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
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
