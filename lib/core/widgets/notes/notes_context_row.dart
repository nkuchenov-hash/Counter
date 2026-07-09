// Canonical notes editor context row.
//
// Compact, single-row meta strip shown under the title: category chip + tag
// chips + trailing save status. Pure UI; no Brain/PocketBase logic.

import 'package:counter/core/widgets/notes/notes_save_status.dart';
import 'package:flutter/material.dart';

/// View-model used by [AppNotesContextRow]. Strings must already be localized
/// by the composing feature surface.
class AppNotesContextRowData {
  const AppNotesContextRowData({
    this.categoryLabel,
    this.categoryColor,
    this.tags = const <AppNotesContextTag>[],
    this.saveStatus = const AppNotesSaveStatusData(
      kind: NotesSaveStatusKind.idle,
    ),
  });

  /// When null or empty, the chip shows an "uncategorized" label provided by
  /// the caller via [fallbackCategoryLabel] on the widget.
  final String? categoryLabel;
  final Color? categoryColor;

  final List<AppNotesContextTag> tags;
  final AppNotesSaveStatusData saveStatus;
}

class AppNotesContextTag {
  const AppNotesContextTag({
    required this.label,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;
}

/// Compact meta row for the notes editor: category chip + tag chips + status.
class AppNotesContextRow extends StatelessWidget {
  const AppNotesContextRow({
    super.key,
    required this.data,
    this.onTap,
    this.onRetry,
    this.fallbackCategoryLabel = 'Uncategorized',
    this.showStatus = true,
  });

  final AppNotesContextRowData data;

  /// Tap target for the whole row (category picker).
  final VoidCallback? onTap;

  /// Retry handler surfaced only when status is error.
  final VoidCallback? onRetry;

  final String fallbackCategoryLabel;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catLabel = (data.categoryLabel ?? '').trim().isEmpty
        ? fallbackCategoryLabel
        : data.categoryLabel!.trim();
    final catColor = data.categoryColor ?? scheme.outline;

    final status = showStatus
        ? AppNotesSaveStatus(
            data: data.saveStatus,
            onRetry: onRetry,
          )
        : const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: catColor.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 13,
                    color: catColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    catLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (data.tags.isNotEmpty)
              Flexible(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    for (final t in data.tags.take(3))
                      _ContextTagChip(tag: t),
                  ],
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 8),
            status,
          ],
        ),
      ),
    );
  }
}

class _ContextTagChip extends StatelessWidget {
  const _ContextTagChip({required this.tag});

  final AppNotesContextTag tag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tag.color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.icon != null) ...[
            Icon(tag.icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            tag.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
