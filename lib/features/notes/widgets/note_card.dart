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
    required this.onOpenMenu,
    this.selected = false,
  });

  final NoteCardData data;
  final NotesLibraryView view;
  final bool checkboxesOn;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleDone;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onOpenMenu;
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
            onOpenMenu: onOpenMenu,
          )
        : _ListRow(
            data: data,
            checkboxesOn: checkboxesOn,
            selected: selected,
            onOpen: onOpen,
            onTogglePin: onTogglePin,
            onToggleDone: onToggleDone,
            onLongPress: onLongPress,
            onOpenMenu: onOpenMenu,
          );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.data,
    required this.checkboxesOn,
    required this.selected,
    required this.onOpen,
    required this.onTogglePin,
    required this.onToggleDone,
    required this.onLongPress,
    required this.onOpenMenu,
  });

  final NoteCardData data;
  final bool checkboxesOn;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleDone;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final isDone = data.task.isDone;
    final title = data.task.title.isEmpty
        ? t(loc, 'notes_v3_untitled')
        : data.task.title;

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
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (checkboxesOn)
                    _LargeDoneCheck(isDone: isDone, onToggle: onToggleDone)
                  else
                    _CategoryTile(data: data),
                  const SizedBox(width: 10),
                  Expanded(child: _BadgesRow(data: data, loc: loc)),
                  _NoteCardMenuButton(onPressed: onOpenMenu),
                ],
              ),
              const SizedBox(height: 10),
              _LifeSelectableText(
                title,
                onTap: onOpen,
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
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ClipRect(
                  child: _BlockPreview(
                    data: data,
                    loc: loc,
                    isDone: isDone,
                    onTap: onOpen,
                  ),
                ),
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

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.data,
    required this.checkboxesOn,
    required this.selected,
    required this.onOpen,
    required this.onTogglePin,
    required this.onToggleDone,
    required this.onLongPress,
    required this.onOpenMenu,
  });

  final NoteCardData data;
  final bool checkboxesOn;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleDone;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final isDone = data.task.isDone;
    final color = data.categoryColor;
    final secondary = scheme.onSurfaceVariant.withValues(alpha: 0.94);
    final meta = scheme.onSurfaceVariant.withValues(alpha: 0.82);
    final title = data.task.title.isEmpty
        ? t(loc, 'notes_v3_untitled')
        : data.task.title;

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
                    _LifeSelectableText(
                      title,
                      onTap: onOpen,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : null,
                        color: isDone
                            ? scheme.onSurfaceVariant.withValues(alpha: 0.78)
                            : scheme.onSurface,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    _LifeSelectableText(
                      _listPreview(data, loc),
                      onTap: onOpen,
                      style: TextStyle(fontSize: 12, color: secondary),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (data.categoryName != null)
                          Text(
                            data.categoryName!,
                            style: TextStyle(fontSize: 10, color: meta),
                          ),
                        if (data.stats.hasChecklist)
                          Text(
                            ' · ${t(loc, 'notes_v3_checklist_progress').replaceAll('{done}', '${data.stats.checklistChecked}').replaceAll('{total}', '${data.stats.checklistTotal}')}',
                            style: TextStyle(fontSize: 10, color: meta),
                          ),
                        Text(
                          ' · ${_relative(data.task.updatedAt ?? data.task.createdAt)}',
                          style: TextStyle(fontSize: 10, color: meta),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _NoteCardMenuButton(onPressed: onOpenMenu),
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
    required this.onTap,
  });

  final NoteCardData data;
  final String loc;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = data.doc.blocks.take(5).toList();
    if (preview.isEmpty) {
      return _LifeSelectableText(
        t(loc, 'notes_v3_untitled'),
        onTap: onTap,
        style: TextStyle(
          fontSize: 13,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.94),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in preview)
          _PreviewLine(block: b, isDone: isDone, onTap: onTap),
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
  const _PreviewLine({
    required this.block,
    required this.isDone,
    required this.onTap,
  });

  final NoteBlock block;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = scheme.onSurfaceVariant.withValues(alpha: 0.94);
    if (block.type == NoteBlockType.heading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: _LifeSelectableText(
          block.text,
          onTap: onTap,
          style: TextStyle(
            fontSize: block.level == 1 ? 14 : 13,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          maxLines: 1,
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
            child: _LifeSelectableText(
              block.text,
              onTap: onTap,
              style: TextStyle(
                fontSize: 13,
                decoration: (block.checked || isDone)
                    ? TextDecoration.lineThrough
                    : null,
                color: secondary,
              ),
              maxLines: 1,
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
    return _LifeSelectableText(
      block.text,
      onTap: onTap,
      style: TextStyle(fontSize: 13, color: secondary),
      maxLines: 1,
    );
  }
}

class _NoteCardMenuButton extends StatefulWidget {
  const _NoteCardMenuButton({required this.onPressed});

  final ValueChanged<Offset> onPressed;

  @override
  State<_NoteCardMenuButton> createState() => _NoteCardMenuButtonState();
}

class _NoteCardMenuButtonState extends State<_NoteCardMenuButton> {
  final GlobalKey _anchorKey = GlobalKey();

  void _open() {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    widget.onPressed(rect.center);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'More',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox.square(
            key: _anchorKey,
            dimension: 32,
            child: Icon(
              Icons.more_horiz_rounded,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _LargeDoneCheck extends StatelessWidget {
  const _LargeDoneCheck({required this.isDone, required this.onToggle});

  final bool isDone;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      checked: isDone,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
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

/// Lists-specific selectable text with a deliberately oversized Life OS
/// droplet handle. Keeping this implementation beside NoteCard avoids adding
/// another shared primitive for behavior that currently only exists in Lists.
class _LifeSelectableText extends StatelessWidget {
  const _LifeSelectableText(
    this.data, {
    this.style,
    this.maxLines,
    this.onTap,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final VoidCallback? onTap;

  static final TextSelectionControls _controls = _LifeTextSelectionControls();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextSelectionTheme(
      data: TextSelectionTheme.of(context).copyWith(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: scheme.primary,
      ),
      child: SelectableText(
        data,
        style: style,
        maxLines: maxLines,
        onTap: onTap,
        selectionControls: _controls,
        contextMenuBuilder: (context, editableTextState) =>
            AdaptiveTextSelectionToolbar.editableText(
          editableTextState: editableTextState,
        ),
      ),
    );
  }
}

class _LifeTextSelectionControls extends MaterialTextSelectionControls {
  static const double _handleWidth = 44;
  static const double _handleHeight = 52;

  @override
  Size getHandleSize(double textLineHeight) =>
      const Size(_handleWidth, _handleHeight);

  @override
  Offset getHandleAnchor(
    TextSelectionHandleType type,
    double textLineHeight,
  ) {
    return const Offset(_handleWidth / 2, 2);
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: const SizedBox(
        width: _handleWidth,
        height: _handleHeight,
      ),
    ).buildWithChild(
      CustomPaint(painter: _LifeSelectionDropPainter(color: color)),
    );
  }
}

extension on Widget {
  Widget buildWithChild(Widget child) {
    return Stack(
      fit: StackFit.passthrough,
      children: [this, Positioned.fill(child: IgnorePointer(child: child))],
    );
  }
}

class _LifeSelectionDropPainter extends CustomPainter {
  const _LifeSelectionDropPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx, 2)
      ..cubicTo(cx - 2.5, 7, cx - 9, 12, cx - 10.5, 20)
      ..cubicTo(cx - 13, 32, cx - 7, 42, cx, 46)
      ..cubicTo(cx + 7, 42, cx + 13, 32, cx + 10.5, 20)
      ..cubicTo(cx + 9, 12, cx + 2.5, 7, cx, 2)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(cx, 29), 11.5, paint);
  }

  @override
  bool shouldRepaint(covariant _LifeSelectionDropPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
