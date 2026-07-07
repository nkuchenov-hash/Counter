import 'dart:async';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Explicit parent for picker create — never inferred from selection/search UI.
@immutable
class CategoryPickerCreateTarget {
  const CategoryPickerCreateTarget._({
    required this.parentLocalId,
    this.parentDisplayName,
  });

  const CategoryPickerCreateTarget.root()
      : parentLocalId = null,
        parentDisplayName = null;

  const CategoryPickerCreateTarget.child({
    required int parentLocalId,
    required String parentDisplayName,
  }) : parentLocalId = parentLocalId,
       parentDisplayName = parentDisplayName;

  final int? parentLocalId;
  final String? parentDisplayName;

  bool get isRoot => parentLocalId == null;

  @override
  bool operator ==(Object other) =>
      other is CategoryPickerCreateTarget &&
      other.parentLocalId == parentLocalId &&
      other.parentDisplayName == parentDisplayName;

  @override
  int get hashCode => Object.hash(parentLocalId, parentDisplayName);
}

@visibleForTesting
CategoryPickerCreateTarget categoryPickerCreateTargetForRow(CategoryRule rule) {
  return CategoryPickerCreateTarget.child(
    parentLocalId: rule.id,
    parentDisplayName: rule.name.trim(),
  );
}

/// Whether category creation from a picker is allowed (online + authed).
@visibleForTesting
bool Function()? categoryCreateFromPickerAllowedOverride;

bool categoryCreateFromPickerAllowed() {
  if (categoryCreateFromPickerAllowedOverride != null) {
    return categoryCreateFromPickerAllowedOverride!();
  }
  final db = DatabaseService.instance;
  if (!db.isInitialized) return false;
  if (db.offlineSync.isOffline) return false;
  final ownerPbId = db.currentProfileId;
  return ownerPbId?.isNotEmpty ?? false;
}

@immutable
class CategoryPickerCreateResult {
  const CategoryPickerCreateResult({
    required this.localCategoryId,
    required this.displayName,
    this.parentLocalId,
    this.pocketBaseSystemId,
  });

  final int localCategoryId;
  final String displayName;
  final int? parentLocalId;
  final String? pocketBaseSystemId;
}

@visibleForTesting
int? findCreatedCategoryLocalIdUnderParent({
  required DatabaseService db,
  required int? parentLocalId,
  required String name,
}) {
  return db.findCreatedCategoryLocalIdUnderParent(
    parentLocalId: parentLocalId,
    displayName: name,
  );
}

@visibleForTesting
Future<int?> Function(int? parentLocalId, CategoryRule child)?
    categoryPickerAddNestedCategoryOverride;

/// Resolves category id for edit fields — prefer in-memory tree over stale pair lists.
@visibleForTesting
int resolveEditFieldCategoryIdValues({
  required int categoryId,
  required bool existsInTree,
  required Iterable<int> knownPairIds,
}) {
  if (existsInTree) return categoryId;
  if (knownPairIds.contains(categoryId)) return categoryId;
  // Keep explicit picker/create handoff id — never substitute pairs.first.
  return categoryId;
}

@visibleForTesting
int resolveEditFieldCategoryId({
  required DatabaseService db,
  required int categoryId,
}) {
  return resolveEditFieldCategoryIdValues(
    categoryId: categoryId,
    existsInTree: db.categoryExists(categoryId),
    knownPairIds: db.allCategoryIdPathPairs.map((p) => p.id),
  );
}

/// Creates a category under [target.parentLocalId] (root when null).
Future<int?> createCategoryFromPickerSubmit({
  required String name,
  required CategoryPickerCreateTarget target,
}) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  final db = DatabaseService.instance;
  if (!categoryCreateFromPickerAllowed()) return null;

  final parentId = target.parentLocalId;

  final existingSibling = findCreatedCategoryLocalIdUnderParent(
    db: db,
    parentLocalId: parentId,
    name: trimmed,
  );
  if (existingSibling != null) return existingSibling;

  final child = CategoryRule(
    id: db.newId(),
    name: trimmed,
    colorValue: Colors.grey.toARGB32(),
    iconCodePoint: Icons.folder_rounded.codePoint,
  );

  final createdId = categoryPickerAddNestedCategoryOverride != null
      ? await categoryPickerAddNestedCategoryOverride!(parentId, child)
      : await db.addNestedCategory(parentId, child);
  if (createdId == null) return null;

  assert(() {
    if (categoryPickerAddNestedCategoryOverride != null) return true;
    if (parentId != null) {
      final actualParent = db.getParentId(createdId);
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

String categoryPickerCreateDialogTitle(String loc, CategoryPickerCreateTarget target) {
  if (target.isRoot) {
    return t(loc, 'category_create_root_title');
  }
  final parentName = (target.parentDisplayName ?? '').trim();
  return t(loc, 'category_create_inside_title').replaceFirst('%s', parentName);
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

    final db = DatabaseService.instance;
    final existingSibling = findCreatedCategoryLocalIdUnderParent(
      db: db,
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
