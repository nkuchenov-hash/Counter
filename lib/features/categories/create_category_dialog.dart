import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:counter/core/widgets/app_loading.dart';

/// Interactive create flow: archive-aware hints, restore / duplicate / go-to.
Future<void> showCreateCategoryDialog({
  required BuildContext context,
  required int? parentId,
  required void Function(int localCategoryId) onGoToActiveCategory,
  required Future<void> Function() onDone,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _CreateCategoryDialog(
      parentId: parentId,
      onGoToActiveCategory: onGoToActiveCategory,
      onDone: onDone,
    ),
  );
}

class _CreateCategoryDialog extends StatefulWidget {
  const _CreateCategoryDialog({
    required this.parentId,
    required this.onGoToActiveCategory,
    required this.onDone,
  });

  final int? parentId;
  final void Function(int localCategoryId) onGoToActiveCategory;
  final Future<void> Function() onDone;

  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  late final TextEditingController _controller;
  StreamSubscription<List<CategoryRule>>? _catSub;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() => setState(() {}));
    unawaited(DatabaseService.instance.refreshCategoryRulesFromServer());
    _catSub = DatabaseService.instance.categoryStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _catSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitCreate() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final child = CategoryRule(
        id: DatabaseService.instance.newId(),
        name: name,
        colorValue: Colors.grey.toARGB32(),
        iconCodePoint: Icons.folder_rounded.codePoint,
      );
      final ok =
          await DatabaseService.instance.addNestedCategory(widget.parentId, child);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        await widget.onDone();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'category_exists'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(String pbRowId) async {
    setState(() => _busy = true);
    try {
      final localId = await DatabaseService.instance.restoreArchivedCategory(pbRowId);
      if (!mounted) return;
      if (localId != null) {
        Navigator.of(context).pop();
        await widget.onDone();
        widget.onGoToActiveCategory(localId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'sync_failed_retry'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final status = DatabaseService.instance
        .classifyCategoryDisplayNameInput(_controller.text);

    Widget hintNonActive() {
      switch (status.kind) {
        case CategoryNameInputKind.empty:
          return const SizedBox.shrink();
        case CategoryNameInputKind.available:
          return Text(
            t(loc, 'category_name_available'),
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
            ),
          );
        case CategoryNameInputKind.archived:
          return Text(
            t(loc, 'category_name_in_archive'),
            style: TextStyle(
              color: Colors.amber.shade900,
              fontWeight: FontWeight.w600,
            ),
          );
        case CategoryNameInputKind.active:
          return const SizedBox.shrink();
      }
    }

    final nameNonEmpty = _controller.text.trim().isNotEmpty;
    final canSubmitNew = status.kind == CategoryNameInputKind.available &&
        nameNonEmpty;
    final canSubmitDuplicate = status.kind == CategoryNameInputKind.archived &&
        nameNonEmpty;
    final archivedPb = status.archivedPbRowId;
    final activeId = status.activeLocalId;

    return AlertDialog(
      title: Text(t(loc, 'category_create_dialog_title')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: t(loc, 'name_label'),
                hintText: t(loc, 'hint_work_health'),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            if (status.kind == CategoryNameInputKind.active)
              Text(
                t(loc, 'category_name_already_active'),
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              hintNonActive(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(t(loc, 'cancel')),
        ),
        if (status.kind == CategoryNameInputKind.active && activeId != null)
          FilledButton(
            onPressed: _busy
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onGoToActiveCategory(activeId);
                  },
            child: Text(t(loc, 'category_go_to_category')),
          ),
        if (status.kind == CategoryNameInputKind.archived &&
            archivedPb != null) ...[
          TextButton(
            onPressed: _busy || !canSubmitDuplicate ? null : _submitCreate,
            child: Text(t(loc, 'category_create_duplicate')),
          ),
          FilledButton(
            onPressed: _busy ? null : () => unawaited(_restore(archivedPb)),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: AppLoading(size: AppLoadingSize.small),
                  )
                : Text(t(loc, 'category_restore_and_use')),
          ),
        ],
        if (status.kind != CategoryNameInputKind.archived &&
            status.kind != CategoryNameInputKind.active)
          FilledButton(
            onPressed: _busy || !canSubmitNew ? null : _submitCreate,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: AppLoading(size: AppLoadingSize.small),
                  )
                : Text(t(loc, 'category_create_action')),
          ),
      ],
    );
  }
}
