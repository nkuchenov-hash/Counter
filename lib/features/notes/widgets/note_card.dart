// Note card for the Notes library (grid + list views).
// Visual port of LIFE_OS_Notes_MVP_v32_gapfix5.html. Pure UI: all mutations
// are emitted through callbacks and remain owned by the existing Brain paths.

import 'dart:ui' show FontFeature;

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
  Widget build(BuildContext context) => view == NotesLibraryView.grid
      ? _GridCard(
          data: data,
          checkboxesOn: checkboxesOn,
          selected: selected,
          onOpen: onOpen,
          onToggleDone: onToggleDone,
          onLongPress: onLongPress,
          onOpenMenu: onOpenMenu,
        )
      : _ListRow(
          data: data,
          checkboxesOn: checkboxesOn,
          selected: selected,
          onOpen: onOpen,
          onToggleDone: onToggleDone,
          onLongPress: onLongPress,
          onOpenMenu: onOpenMenu,
        );
}

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.data,
    required this.checkboxesOn,
    required this.selected,
    required this.onOpen,
    required this.onToggleDone,
    required this.onLongPress,
    required this.onOpenMenu,
  });

  final NoteCardData data;
  final bool checkboxesOn;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onToggleDone;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final isDone = data.task.isDone;
    final title = data.task.title.trim().isEmpty
        ? t(loc, 'notes_v3_untitled')
        : data.task.title.trim();
    final preview = _plainPreview(data);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: notesGlmGlassCardDecoration(
          radius: 14,
          context: context,
          selected: selected,
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Opacity(
          opacity: isDone ? 0.60 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (checkboxesOn) ...[
                    _DoneCheck(isDone: isDone, onToggle: onToggleDone, size: 25),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: _CategoryBadge(data: data)),
                  _NoteCardMenuButton(onPressed: onOpenMenu),
                ],
              ),
              const SizedBox(height: 14),
              _LifeSelectableText(
                title,
                onTap: onOpen,
                maxLines: 3,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.22,
                  letterSpacing: -0.2,
                  fontWeight: FontWeight.w700,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: ClipRect(
                  child: _LifeSelectableText(
                    preview.isEmpty ? t(loc, 'notes_library_no_text') : preview,
                    onTap: onOpen,
                    maxLines: 4,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                      fontStyle: preview.isEmpty ? FontStyle.italic : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (data.stats.hasDrawing)
                    _TinyMediaIcon(icon: Icons.draw_outlined),
                  if (data.stats.hasImage)
                    _TinyMediaIcon(icon: Icons.image_outlined),
                  _StatusMeta(data: data),
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
    required this.onToggleDone,
    required this.onLongPress,
    required this.onOpenMenu,
  });

  final NoteCardData data;
  final bool checkboxesOn;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onToggleDone;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final loc = currentLocale.value;
    final isDone = data.task.isDone;
    final title = data.task.title.trim().isEmpty
        ? t(loc, 'notes_v3_untitled')
        : data.task.title.trim();
    final preview = _plainPreview(data);
    final rowColor = dark
        ? scheme.surfaceContainerHigh.withValues(alpha: selected ? 0.96 : 0.72)
        : selected
            ? const Color(0xFFF3F7FB)
            : Colors.white.withValues(alpha: 0.56);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: const BoxConstraints(minHeight: 76),
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(
              color: dark
                  ? scheme.outlineVariant.withValues(alpha: 0.60)
                  : const Color(0xFFDAE1EA).withValues(alpha: 0.90),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Opacity(
          opacity: isDone ? 0.60 : 1,
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: checkboxesOn
                      ? _DoneCheck(
                          isDone: isDone,
                          onToggle: onToggleDone,
                          size: 36,
                        )
                      : _CategoryTile(data: data),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 16,
                child: _LifeSelectableText(
                  title,
                  onTap: onOpen,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 12,
                child: _LifeSelectableText(
                  preview.isEmpty ? t(loc, 'notes_library_no_text') : preview,
                  onTap: onOpen,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                    fontStyle: preview.isEmpty ? FontStyle.italic : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 100,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _StatusMeta(data: data),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 34,
                child: _NoteCardMenuButton(onPressed: onOpenMenu),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.data});
  final NoteCardData data;

  @override
  Widget build(BuildContext context) {
    final name = data.categoryName?.trim() ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 25,
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: notesTintBackground(data.categoryColor),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.categoryIconCodePoint != null) ...[
              Icon(
                IconData(data.categoryIconCodePoint!, fontFamily: 'MaterialIcons'),
                size: 13,
                color: data.categoryColor,
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: data.categoryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.data});
  final NoteCardData data;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: notesTintBackground(data.categoryColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: data.categoryIconCodePoint == null
            ? null
            : Icon(
                IconData(data.categoryIconCodePoint!, fontFamily: 'MaterialIcons'),
                size: 20,
                color: data.categoryColor,
              ),
      );
}

class _DoneCheck extends StatelessWidget {
  const _DoneCheck({
    required this.isDone,
    required this.onToggle,
    required this.size,
  });

  final bool isDone;
  final VoidCallback onToggle;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        checked: isDone,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isDone ? kNotesInk : Colors.white,
              borderRadius: BorderRadius.circular(size >= 30 ? 8 : 7),
              border: Border.all(
                color: isDone ? kNotesInk : const Color(0xFFB8C3D1),
                width: 1.5,
              ),
            ),
            child: isDone
                ? Icon(
                    Icons.check_rounded,
                    size: size >= 30 ? 18 : 13,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
      );
}

class _StatusMeta extends StatelessWidget {
  const _StatusMeta({required this.data});
  final NoteCardData data;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final color = notesGlmMetaColor(context);
    if (data.stats.hasChecklist) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '${data.stats.checklistChecked}/${data.stats.checklistTotal}',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    }
    return Text(
      data.task.isDone ? _doneLabel(loc) : _relative(data.task.updatedAt ?? data.task.createdAt),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: color),
    );
  }
}

class _TinyMediaIcon extends StatelessWidget {
  const _TinyMediaIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Icon(icon, size: 13, color: notesGlmMetaColor(context)),
      );
}

String _plainPreview(NoteCardData data) {
  final chunks = <String>[];
  for (final block in data.doc.blocks) {
    final text = block.text.trim();
    if (text.isEmpty) continue;
    chunks.add(text);
    if (chunks.length == 4) break;
  }
  return chunks.join('\n');
}

String _doneLabel(String locale) {
  switch (locale) {
    case 'ru':
      return 'Выполнено';
    case 'de':
      return 'Erledigt';
    case 'fr':
      return 'Terminé';
    case 'es':
      return 'Hecho';
    case 'it':
      return 'Fatto';
    default:
      return 'Done';
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
  Widget build(BuildContext context) => Tooltip(
        message: t(currentLocale.value, 'notes_editor_more_tooltip'),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _open,
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              key: _anchorKey,
              width: 28,
              height: 26,
              child: Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
}

/// Lists-specific selectable text with the large Life OS droplet handle.
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
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) =>
      const Offset(_handleWidth / 2, 2);

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
      child: const SizedBox(width: _handleWidth, height: _handleHeight),
    ).buildWithChild(
      CustomPaint(painter: _LifeSelectionDropPainter(color: color)),
    );
  }
}

extension on Widget {
  Widget buildWithChild(Widget child) => Stack(
        fit: StackFit.passthrough,
        children: [this, Positioned.fill(child: IgnorePointer(child: child))],
      );
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
  bool shouldRepaint(covariant _LifeSelectionDropPainter oldDelegate) =>
      oldDelegate.color != color;
}
