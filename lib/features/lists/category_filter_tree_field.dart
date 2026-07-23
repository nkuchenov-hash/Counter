import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:flutter/material.dart';

/// Lists filter: nullable category; includes "All categories" row in the tree sheet.
class CategoryFilterTreeField extends StatelessWidget {
  const CategoryFilterTreeField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final pathText = value == null
        ? t(loc, 'lists_filter_all')
        : CategoryTreeSource.pathLabel(value!);

    return InkWell(
      onTap: () async {
        final r = await showCategoryTreeSheet(
          context,
          initialCategoryId: value,
          showAllCategoriesRow: true,
        );
        if (r is CategoryTreeSheetAll) {
          onChanged(null);
        } else if (r is CategoryTreeSheetPicked) {
          onChanged(r.id);
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: decoration,
        isEmpty: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                pathText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
