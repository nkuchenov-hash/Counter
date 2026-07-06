import 'dart:async';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Whether category creation from a picker is allowed (online + authed).
bool categoryCreateFromPickerAllowed() {
  final db = DatabaseService.instance;
  if (!db.isInitialized) return false;
  if (db.offlineSync.isOffline) return false;
  final ownerPbId = db.currentProfileId;
  return ownerPbId?.isNotEmpty ?? false;
}

/// Creates a root category from picker context. Returns local [CategoryRule.id].
Future<int?> createCategoryFromPickerSubmit({
  required String name,
  int? parentId,
}) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  final db = DatabaseService.instance;
  if (!categoryCreateFromPickerAllowed()) return null;

  final status = db.classifyCategoryDisplayNameInput(trimmed);
  switch (status.kind) {
    case CategoryNameInputKind.empty:
      return null;
    case CategoryNameInputKind.active:
      return status.activeLocalId;
    case CategoryNameInputKind.archived:
      return null;
    case CategoryNameInputKind.available:
      break;
  }

  final child = CategoryRule(
    id: db.newId(),
    name: trimmed,
    colorValue: Colors.grey.toARGB32(),
    iconCodePoint: Icons.folder_rounded.codePoint,
  );
  final ok = await db.addNestedCategory(parentId, child);
  if (!ok) return null;
  return db.findActiveLocalCategoryIdByDisplayName(trimmed);
}

/// Compact create dialog stacked above an open category picker / edit sheet.
Future<int?> showCreateCategoryFromPickerDialog(
  BuildContext context, {
  String? initialName,
  int? parentId,
}) {
  return showDialog<int?>(
    context: context,
    builder: (ctx) => _CreateCategoryFromPickerDialog(
      initialName: initialName,
      parentId: parentId,
    ),
  );
}

class _CreateCategoryFromPickerDialog extends StatefulWidget {
  const _CreateCategoryFromPickerDialog({
    this.initialName,
    this.parentId,
  });

  final String? initialName;
  final int? parentId;

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

    final status =
        DatabaseService.instance.classifyCategoryDisplayNameInput(name);
    if (status.kind == CategoryNameInputKind.archived) {
      AppSnack.show(t(loc, 'category_name_in_archive'), error: true);
      return;
    }
    if (status.kind == CategoryNameInputKind.active &&
        status.activeLocalId != null) {
      if (!mounted) return;
      Navigator.of(context).pop(status.activeLocalId);
      return;
    }

    setState(() => _busy = true);
    try {
      final id = await createCategoryFromPickerSubmit(
        name: name,
        parentId: widget.parentId,
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
      title: Text(t(loc, 'category_create_title')),
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
