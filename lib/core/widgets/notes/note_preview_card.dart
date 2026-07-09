// Canonical notes preview card.
//
// Used by the Notes library / Lists screen to show notes as cards rather than
// task rows. Renders title + notes_plain preview + checklist progress + meta.
// Pure presentational widget — no Brain/PocketBase imports.

import 'package:flutter/material.dart';

/// View-model for a notes-library preview card.
class AppNotePreviewData {
  const AppNotePreviewData({
    required this.title,
    this.notesPreview = '',
    this.categoryLabel,
    this.categoryColor,
    this.isDone = false,
    this.checklistTotal = 0,
    this.checklistDoneCount = 0,
    this.hasNotes = false,
    this.hasChecklist = false,
    this.modifiedLabel,
    this.shared = false,
  });

  final String title;
  final String notesPreview;
  final String? categoryLabel;
  final Color? categoryColor;
  final bool isDone;

  final int checklistTotal;
  final int checklistDoneCount;

  /// Surfaces a small "Note" indicator when the row has rich text body but
  /// no checklist items.
  final bool hasNotes;
  final bool hasChecklist;

  /// Optional localized "Modified · 5m ago" label.
  final String? modifiedLabel;

  /// When true, renders a subtle "Shared" badge. Caller must only set this
  /// when a real share relation exists; do not fake it.
  final bool shared;
}

/// Apple-Notes-inspired card preview for a note/plan row.
class AppNotePreviewCard extends StatelessWidget {
  const AppNotePreviewCard({
    super.key,
    required this.data,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.showSelection = false,
    this.onToggleSelection,
  });

  final AppNotePreviewData data;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool showSelection;

  /// Only invoked when [showSelection] is true.
  final VoidCallback? onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catColor = data.categoryColor ?? scheme.outline;

    final previewLines = _previewLines(data.notesPreview);

    final meta = <Widget>[];
    if (data.hasChecklist && data.checklistTotal > 0) {
      meta.add(_MetaPill(
        icon: Icons.checklist_rounded,
        text: '${data.checklistDoneCount}/${data.checklistTotal}',
        color: data.checklistDoneCount == data.checklistTotal
            ? scheme.primary
            : scheme.onSurfaceVariant,
      ));
    } else if (data.hasNotes) {
      meta.add(_MetaPill(
        icon: Icons.notes_rounded,
        text: 'Note',
        color: scheme.onSurfaceVariant,
      ));
    }
    if (data.shared) {
      meta.add(_MetaPill(
        icon: Icons.people_outline_rounded,
        text: 'Shared',
        color: scheme.tertiary,
      ));
    }
    if (data.modifiedLabel != null && data.modifiedLabel!.isNotEmpty) {
      meta.add(_MetaPill(
        icon: Icons.schedule_rounded,
        text: data.modifiedLabel!,
        color: scheme.onSurfaceVariant,
        subtle: true,
      ));
    }

    final selectionControl = showSelection
        ? Checkbox(
            value: selected,
            onChanged: (_) => onToggleSelection?.call(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          )
        : null;

    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectionControl != null) selectionControl,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        data.title.isEmpty ? 'Untitled' : data.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration:
                              data.isDone ? TextDecoration.lineThrough : null,
                          color: data.isDone
                              ? scheme.onSurface.withValues(alpha: 0.55)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (previewLines.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final l in previewLines)
                    Text(
                      l,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                ],
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: meta,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: body,
      ),
    );
  }

  List<String> _previewLines(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return const [];
    final lines = s.split(RegExp(r'[\r\n]+'));
    final out = <String>[];
    for (final l in lines) {
      final t = l.trim();
      if (t.isEmpty) continue;
      out.add(t);
      if (out.length >= 3) break;
    }
    return out;
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.text,
    required this.color,
    this.subtle = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = subtle
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
        : color.withValues(alpha: 0.12);
    final fg = subtle ? scheme.onSurfaceVariant : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: subtle
            ? null
            : Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
