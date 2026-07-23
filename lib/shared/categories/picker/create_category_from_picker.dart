import 'dart:async';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:counter/shared/categories/picker/category_picker_models.dart';
import 'package:flutter/material.dart';

export 'package:counter/shared/categories/picker/category_picker_contracts.dart'
    show
        categoryCreateFromPickerAllowed,
        categoryCreateFromPickerAllowedOverride,
        categoryPickerAddNestedCategoryOverride;
export 'package:counter/shared/categories/picker/category_picker_models.dart';

@visibleForTesting
int? findCreatedCategoryLocalIdUnderParent({
  required int? parentLocalId,
  required String name,
  int? Function({
    required int? parentLocalId,
    required String displayName,
  })? findFn,
}) {
  final fn = findFn ?? CategoryPickerActions.findCreatedUnderParent;
  assert(
    fn != null || CategoryPickerActions.addNestedCategoryOverride != null,
    'CategoryPickerActions.findCreatedUnderParent not wired',
  );
  return fn?.call(parentLocalId: parentLocalId, displayName: name);
}

/// Creates a category under [target.parentLocalId] (root when null).
Future<int?> createCategoryFromPickerSubmit({
  required String name,
  required CategoryPickerCreateTarget target,
}) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  if (!categoryCreateFromPickerAllowed()) return null;

  final parentId = target.parentLocalId;

  final existingSibling = findCreatedCategoryLocalIdUnderParent(
    parentLocalId: parentId,
    name: trimmed,
  );
  if (existingSibling != null) return existingSibling;

  final newIdFn = CategoryTreeSource.newLocalId;
  final child = CategoryRule(
    id: newIdFn?.call() ?? DateTime.now().microsecondsSinceEpoch,
    name: trimmed,
    colorValue: Colors.grey.toARGB32(),
    iconCodePoint: Icons.folder_rounded.codePoint,
  );

  final createdId = CategoryPickerActions.addNestedCategoryOverride != null
      ? await CategoryPickerActions.addNestedCategoryOverride!(parentId, child)
      : await CategoryPickerActions.addNestedCategory?.call(parentId, child);
  if (createdId == null) return null;
  // Create must return a persistable local id — never `-1` / uncategorized.
  if (isNonPersistableCategoryLocalId(createdId)) return null;

  assert(() {
    if (CategoryPickerActions.addNestedCategoryOverride != null) return true;
    if (parentId != null) {
      final actualParent = CategoryTreeSource.getParentId?.call(createdId);
      assert(
        actualParent == parentId,
        'Category picker create parent mismatch: '
        'requested=$parentId actual=$actualParent name=$trimmed',
      );
    }
    return true;
  }());

  return createdId;
}

/// Compact create dialog stacked above an open category picker / edit sheet.
Future<int?> showCreateCategoryFromPickerDialog(
  BuildContext context, {
  required CategoryPickerCreateTarget target,
  String? initialName,
}) {
  return showDialog<int?>(
    context: context,
    builder: (ctx) => _CreateCategoryFromPickerDialog(
      target: target,
      initialName: initialName,
    ),
  );
}

class _CreateCategoryFromPickerDialog extends StatefulWidget {
  const _CreateCategoryFromPickerDialog({
    required this.target,
    this.initialName,
  });

  final CategoryPickerCreateTarget target;
  final String? initialName;

  @override
  State<_CreateCategoryFromPickerDialog> createState() =>
      _CreateCategoryFromPickerDialogState();
}

class _CreateCategoryFromPickerDialogState
    extends State<_CreateCategoryFromPickerDialog> {
  late final TextEditingController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = currentLocale.value;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      AppSnack.show(t(loc, 'category_name_required'), error: true);
      return;
    }
    if (!categoryCreateFromPickerAllowed()) {
      AppSnack.show(t(loc, 'category_create_requires_connection'), error: true);
      return;
    }

    final existingSibling = findCreatedCategoryLocalIdUnderParent(
      parentLocalId: widget.target.parentLocalId,
      name: name,
    );
    if (existingSibling != null) {
      if (!mounted) return;
      Navigator.of(context).pop(existingSibling);
      return;
    }

    setState(() => _busy = true);
    try {
      final id = await createCategoryFromPickerSubmit(
        name: name,
        target: widget.target,
      );
      if (!mounted) return;
      if (id != null) {
        Navigator.of(context).pop(id);
      } else {
        AppSnack.show(t(loc, 'category_create_failed'), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final canCreate = categoryCreateFromPickerAllowed();
    return AlertDialog(
      title: Text(categoryPickerCreateDialogTitle(loc, widget.target)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: t(loc, 'category_name_label'),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              onSubmitted: (_) => unawaited(_submit()),
            ),
            if (!canCreate) ...[
              const SizedBox(height: 12),
              Text(
                t(loc, 'category_create_requires_connection'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton.ghost(
          label: t(loc, 'cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: t(loc, 'category_create_action'),
          loading: _busy,
          onPressed: _busy || !canCreate ? null : () => unawaited(_submit()),
        ),
      ],
    );
  }
}
