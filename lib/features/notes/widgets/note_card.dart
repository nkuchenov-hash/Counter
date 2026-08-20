// Note card for the Notes library (grid + list views).
// Faithful Flutter port of the NoteCard component in NotesScreen (1).tsx.
//
// Pure UI: receives a [PlanningTask] + parsed [NoteDocument] + [NoteDocumentStats]
// and emits tap / pin / done / radial callbacks. No Brain imports.

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/notes_visual_tokens.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

enum NotesLibraryView { grid, list }

class NoteCardData {
  const NoteCardData({
    required this.task,
    required this.doc,
    required this.stats,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIconCodePoint,
    required this.pinned,
  });

  final PlanningTask task;
  final NoteDocument doc;
  final NoteDocumentStats stats;
  final String? categoryName;
  final Color categoryColor;
  final int? categoryIconCodePoint;
  final bool pinned;
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.data,
    required this.view,
    required this.checkboxesOn,
    required this.onOpen,
    required this.onTogglePin,
    required this.onToggleDone,
    required this.onLongPress,
    this.selected = false,
  });

  final NoteCardData data;
  final NotesLibraryView view;
  final bool checkboxesOn;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleDone;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return view == NotesLibraryView.grid
        ? _GridCard(
            data: data,
            checkboxesOn: checkboxesOn,
            selected: selected,
            onOpen: onOpen,
            onTogglePin: onTogglePin,
            onToggleDone: onToggleDone,
            onLongPress: onLongPress,
          )
        : _ListRow(
            data: data,
            checkboxesOn: checkboxesOn,
            selected: selected,
            onOpen: onOpen,
            onTogglePin: onTogglePin,
            onToggleDone: onToggleDone,
            onLongPress: onLongPress,
          );
  }
}

// ---- Grid card -----------------------------------------------------------

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.data,
    required this.checkboxesOn,
    required this.selected,
    required this.onOpen,
    required this.onTogglePin,
    required this.onToggleDone,
    required this.onLongPress,
  });

  final NoteCardData data;
  final bool checkboxesOn;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleDone;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final isDone = data.task.isDone;

    return GestureDetector(
      onTap: onOpen,
      onLongPress: onLongPress,
      child: AnimatedOpacity(
        opacity: isDone ? 0.62 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          decoration: notesGlmGlassCardDecoration(
            radius: 16,
            context: context,
            selected: selected,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CategoryTile(data: data),
                  const SizedBox(width: 10),
                  Expanded(child: _BadgesRow(data: data, loc: loc)),
                  if (data.pinned)
                    Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                  _DoneCheck(
                    isDone: isDone,
                    checkboxesOn: checkboxesOn,
                    onToggle: onToggleDone,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                data.task.title.isEmpty
                    ? t(loc, 'notes_v3_untitled')
                    : data.task.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.2,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.78)
                      : scheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _BlockPreview(data: data, loc: loc, isDone: isDone),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CategoryBadge(data: data),
                  const Spacer(),
                  Text(
                    _relative(data.task.updatedAt ?? data.task.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: notesGlmMetaColor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- List row ------------------------------------------------------------

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.data,
    required this.checkboxesOn,
    required this.selected,
    required this.onOpen,
    required this.onTogglePin,
    required this.onToggleDone,
    required this.onLongPress,
  });

  final NoteCardData data;
  final bool checkboxesOn;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleDone;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final isDone = data.task.isDone;
    final color = data.categoryColor;
    final secondary = scheme.onSurfaceVariant.withValues(alpha: 0.94);
    final meta = scheme.onSurfaceVariant.withValues(alpha: 0.82);

    return GestureDetector(
      onTap: onOpen,
      onLongPress: onLongPress,
      child: AnimatedOpacity(
        opacity: isDone ? 0.62 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          decoration: notesGlmGlassCardDecoration(
            radius: 12,
            context: context,
            selected: selected,
          ),
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
          child: Row(
            children: [
              // Accent rail
              Container(
                width: 3,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (checkboxesOn)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _LargeDoneCheck(
                    isDone: isDone,
                    onToggle: onToggleDone,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _CategoryTile(data: data),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.task.title.isEmpty
                                ? t(loc, 'notes_v3_untitled')
                                : data.task.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isDone
                                  ? scheme.onSurfaceVariant.withValues(
                                      alpha: 0.78,
                                    )
                                  : scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (data.pinned)
                          Icon(
                            Icons.push_pin_rounded,
                            size: 12,
                            color: scheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _listPreview(data, loc),
                      style: TextStyle(fontSize: 12, color: secondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (data.categoryName != null) ...[
                          Text(
                            data.categoryName!,
                            style: TextStyle(fontSize: 10, color: meta),
                          ),
                        ],
                        if (data.stats.hasChecklist) ...[
                          Text(
                            ' · ${t(loc, 'notes_v3_checklist_progress').replaceAll('{done}', '${data.stats.checklistChecked}').replaceAll('{total}', '${data.stats.checklistTotal}')}',
                            style: TextStyle(fontSize: 10, color: meta),
                          ),
                        ],
                        Text(
                          ' · ${_relative(data.task.updatedAt ?? data.task.createdAt)}',
                          style: TextStyle(fontSize: 10, color: meta),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: data.pinned
                    ? t(loc, 'notes_v3_editor_unpin')
                    : t(loc, 'notes_v3_editor_pin'),
                icon: Icon(
                  data.pinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: onTogglePin,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 14,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _listPreview(NoteCardData d, String loc) {
    if (d.stats.isEmpty) return t(loc, 'notes_v3_checklist_badge');
    final first = d.doc.blocks
        .where((b) => b.hasText && b.text.trim().isNotEmpty)
        .firstOrNull;
    return first != null ? first.text : t(loc, 'notes_v3_untitled');
  }
}

// ---- Badges + previews ---------------------------------------------------

class _BadgesRow extends StatelessWidget {
  const _BadgesRow({required this.data, required this.loc});
  final NoteCardData data;
  final String loc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    if (data.stats.hasChecklist) {
      children.add(
        _Badge(
          icon: Icons.checklist_rounded,
          label: t(loc, 'notes_v3_checklist_progress')
              .replaceAll('{done}', '${data.stats.checklistChecked}')
              .replaceAll('{total}', '${data.stats.checklistTotal}'),
          color: scheme.primary,
        ),
      );
    }
    if (data.stats.hasDrawing) {
      children.add(
        _Badge(
          icon: Icons.draw_outlined,
          label: t(loc, 'notes_v3_draw_badge'),
          color: Colors.amber.shade700,
        ),
      );
    }
    if (data.stats.hasImage) {
      children.add(
        _Badge(
          icon: Icons.image_outlined,
          label: t(loc, 'notes_v3_image_badge'),
          color: Colors.green,
        ),
      );
    }
    if (data.stats.isEmpty) {
      children.add(
        _Badge(
          icon: Icons.checklist_rounded,
          label: t(loc, 'notes_v3_checklist_badge'),
          color: scheme.primary,
        ),
      );
    }
    return Wrap(spacing: 4, runSpacing: 2, children: children);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: notesTintBackground(color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockPreview extends StatelessWidget {
  const _BlockPreview({
    required this.data,
    required this.loc,
    required this.isDone,
  });
  final NoteCardData data;
  final String loc;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = data.doc.blocks.take(5).toList();
    if (preview.isEmpty) {
      return Text(
        t(loc, 'notes_v3_untitled'),
        style: TextStyle(
          fontSize: 13,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.94),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in preview) _PreviewLine(block: b, isDone: isDone),
        if (data.doc.blocks.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              t(loc, 'notes_v3_more_count')
                  .replaceAll('{n}', '${data.doc.blocks.length - 5}'),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.84),
              ),
            ),
          ),
      ],
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.block, required this.isDone});
  final NoteBlock block;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = scheme.onSurfaceVariant.withValues(alpha: 0.94);
    if (block.type == NoteBlockType.heading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Text(
          block.text,
          style: TextStyle(
            fontSize: block.level == 1 ? 14 : 13,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (block.type == NoteBlockType.checklist) {
      return Row(
        children: [
          Container(
            width: 11,
            height: 11,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: block.checked ? scheme.primary : scheme.outlineVariant,
                width: 1.5,
              ),
              color: block.checked ? scheme.primary : null,
            ),
            child: block.checked
                ? const Icon(Icons.check_rounded, size: 7, color: Colors.white)
                : null,
          ),
          Expanded(
            child: Text(
              block.text,
              style: TextStyle(
                fontSize: 13,
                decoration: (block.checked || isDone)
                    ? TextDecoration.lineThrough
                    : null,
                color: secondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    if (block.type == NoteBlockType.image ||
        block.type == NoteBlockType.drawing) {
      return Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Row(
          children: [
            Icon(
              block.type == NoteBlockType.drawing
                  ? Icons.draw_outlined
                  : Icons.image_outlined,
              size: 11,
              color: secondary,
            ),
            const SizedBox(width: 3),
            Text(
              block.type == NoteBlockType.drawing
                  ? t(currentLocale.value, 'notes_v3_draw_badge')
                  : t(currentLocale.value, 'notes_v3_image_badge'),
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: secondary,
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      block.text,
      style: TextStyle(fontSize: 13, color: secondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---- Done checkbox + category tile --------------------------------------

class _DoneCheck extends StatelessWidget {
  const _DoneCheck({
    required this.isDone,
    required this.checkboxesOn,
    required this.onToggle,
  });

  final bool isDone;
  final bool checkboxesOn;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (checkboxesOn) {
      return _LargeDoneCheck(
        isDone: isDone,
        onToggle: onToggle,
      );
    }
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDone ? scheme.primary : scheme.outlineVariant,
            width: 2,
          ),
          color: isDone ? scheme.primary : null,
        ),
        child: isDone
            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
            : null,
      ),
    );
  }
}

class _LargeDoneCheck extends StatelessWidget {
  const _LargeDoneCheck({
    required this.isDone,
    required this.onToggle,
  });

  final bool isDone;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: kNotesLargeCheckSize,
        height: kNotesLargeCheckSize,
        decoration: BoxDecoration(
borderRadius: BorderRadius.circular(8),
border: Border.all(
  color: isDone
      ? scheme.primary
      : scheme.outlineVariant.withValues(alpha: 0.7),
  width: 2,
),
color: isDone ? scheme.primary : Colors.transparent,
        ),
        child: isDone
  ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
  : null,
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.data});
  final NoteCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kNotesLargeCheckSize,
      height: kNotesLargeCheckSize,
      decoration: BoxDecoration(
        color: notesTintBackground(data.categoryColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: data.categoryIconCodePoint != null
          ? Icon(
              IconData(
                data.categoryIconCodePoint!,
                fontFamily: 'MaterialIcons',
              ),
              size: 16,
              color: data.categoryColor,
            )
          : null,
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.data});
  final NoteCardData data;

  @override
  Widget build(BuildContext context) {
    if (data.categoryName == null || data.categoryName!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: data.categoryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        data.categoryName!,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: data.categoryColor,
        ),
      ),
    );
  }
}

String _relative(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  final loc = currentLocale.value;
  final min = diff.inMinutes;
  if (min < 1) return t(loc, 'notes_v3_just_now');
  if (min < 60) return t(loc, 'notes_v3_min_ago').replaceAll('{n}', '$min');
  final hr = diff.inHours;
  if (hr < 24) return t(loc, 'notes_v3_hr_ago').replaceAll('{n}', '$hr');
  final day = diff.inDays;
  if (day < 7) return t(loc, 'notes_v3_day_ago').replaceAll('{n}', '$day');
  return '${dt.month}/${dt.day}';
}
