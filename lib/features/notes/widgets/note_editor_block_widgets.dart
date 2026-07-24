// Notes editor block widgets — visual block rows and add-block chrome.
//
// Receives [NoteBlock] data + callbacks from [NoteEditorPage]. Does not own
// document state, autosave, or DatabaseService calls.

import 'dart:convert';
import 'dart:typed_data';

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_glm_surface.dart';
import 'package:counter/features/notes/notes_visual_tokens.dart';
import 'package:counter/features/notes/widgets/notes_special_block_widgets.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Partial update for a single [NoteBlock], applied by the editor page.
class NoteEditorBlockPatch {
  const NoteEditorBlockPatch({
    this.type,
    this.text,
    this.checked,
    this.level,
    this.bold,
    this.italic,
    this.underline,
    this.color = _unset,
    this.imageData = _unset,
    this.drawingData = _unset,
    this.runs,
    this.callout = _unset,
    this.table = _unset,
    this.linkData = _unset,
    this.reference = _unset,
    this.codeLanguage = _unset,
    this.collapsed,
  });

  static const Object _unset = Object();

  final NoteBlockType? type;
  final String? text;
  final bool? checked;
  final int? level;
  final bool? bold;
  final bool? italic;
  final bool? underline;
  final Object? color;
  final Object? imageData;
  final Object? drawingData;
  final List<NoteTextRun>? runs;
  final Object? callout;
  final Object? table;
  final Object? linkData;
  final Object? reference;
  final Object? codeLanguage;
  final bool? collapsed;

  NoteBlock applyTo(NoteBlock b) => b.copyWith(
    type: type ?? b.type,
    text: text ?? b.text,
    checked: checked ?? b.checked,
    level: level ?? b.level,
    bold: bold ?? b.bold,
    italic: italic ?? b.italic,
    underline: underline ?? b.underline,
    color: identical(color, _unset) ? b.color : color as String?,
    imageData: identical(imageData, _unset)
        ? b.imageData
        : imageData as String?,
    drawingData: identical(drawingData, _unset)
        ? b.drawingData
        : drawingData as String?,
    runs: runs ?? b.runs,
    callout: identical(callout, _unset)
        ? b.callout
        : callout as NoteCalloutData?,
    table: identical(table, _unset) ? b.table : table as NoteTableData?,
    linkData: identical(linkData, _unset)
        ? b.linkData
        : linkData as NoteLinkData?,
    reference: identical(reference, _unset)
        ? b.reference
        : reference as NoteReferenceData?,
    codeLanguage: identical(codeLanguage, _unset)
        ? b.codeLanguage
        : codeLanguage as String?,
    collapsed: collapsed ?? b.collapsed,
  );
}

/// One note block in the editor scroll body (text / checklist / heading / media).
class NoteEditorBlockRow extends StatefulWidget {
  const NoteEditorBlockRow({
    super.key,
    required this.block,
    required this.isActive,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onActivate,
    required this.onUpdate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEditDrawing,
    required this.onEnter,
    required this.loc,
  });

  final NoteBlock block;
  final bool isActive;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onActivate;
  final void Function(NoteEditorBlockPatch) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEditDrawing;
  final VoidCallback onEnter;
  final String loc;

  @override
  State<NoteEditorBlockRow> createState() => _NoteEditorBlockRowState();
}

class _NoteEditorBlockRowState extends State<NoteEditorBlockRow> {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.block.effectiveText);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) widget.onActivate();
    });
  }

  @override
  void didUpdateWidget(covariant NoteEditorBlockRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.block.effectiveText;
    final oldText = oldWidget.block.effectiveText;
    if (oldWidget.block.id != widget.block.id) {
      _textController.text = nextText;
    } else if (nextText != _textController.text && nextText != oldText) {
      _textController.text = nextText;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final scheme = Theme.of(context).colorScheme;
    final loc = widget.loc;

    if (block.type == NoteBlockType.image && block.imageData != null) {
      return _NoteEditorImageBlock(
        block: block,
        isActive: widget.isActive,
        onActivate: widget.onActivate,
        onDelete: widget.onDelete,
      );
    }
    if (block.type == NoteBlockType.drawing && block.drawingData != null) {
      return _NoteEditorDrawingBlock(
        block: block,
        isActive: widget.isActive,
        onActivate: widget.onActivate,
        onEditDrawing: widget.onEditDrawing,
        onDelete: widget.onDelete,
      );
    }
    if (!block.hasText) {
      return NotesSpecialBlockView(
        block: block,
        isActive: widget.isActive,
        loc: loc,
        onActivate: widget.onActivate,
        onDelete: widget.onDelete,
        onTableChanged: (table) =>
            widget.onUpdate(NoteEditorBlockPatch(table: table)),
      );
    }

    final isChecklist = block.type == NoteBlockType.checklist;
    final isHeading = block.type == NoteBlockType.heading;
    final isBullet = block.type == NoteBlockType.bulletedList;
    final isNumbered = block.type == NoteBlockType.numberedList;
    final isQuote = block.type == NoteBlockType.quote;
    final isCallout = block.type == NoteBlockType.callout;
    final isCode = block.type == NoteBlockType.codeBlock;
    final isCollapsible = block.type == NoteBlockType.collapsible;
    final hasStrike = block.effectiveRuns.any((run) => run.marks.strike);
    final headingSize = block.level == 1
        ? 24.0
        : block.level == 3
        ? 18.0
        : 20.0;
    final headingWeight = block.level == 3 ? FontWeight.w600 : FontWeight.w700;
    final textStyle = TextStyle(
      fontSize: isHeading ? headingSize : kGlmBodySize,
      fontWeight: isHeading
          ? headingWeight
          : (block.bold ? FontWeight.w700 : FontWeight.w400),
      fontStyle: block.italic ? FontStyle.italic : null,
      decoration: hasStrike
          ? TextDecoration.lineThrough
          : block.underline
          ? TextDecoration.underline
          : null,
      color:
          _parseHexColor(block.color) ??
          (isChecklist && block.checked
              ? kGlmMetaColor
              : const Color(0xFF1E293B)),
      height: isHeading ? 1.25 : 1.45,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onActivate,
      child: Container(
        decoration: widget.isActive
            ? BoxDecoration(
                color: notesBlockActiveFill(scheme),
                borderRadius: BorderRadius.circular(8),
              )
            : isQuote
            ? BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.24),
                border: Border(
                  left: BorderSide(color: scheme.primary, width: 3),
                ),
                borderRadius: BorderRadius.circular(8),
              )
            : isCallout
            ? BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              )
            : isCode
            ? BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isChecklist)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 0),
                child: InkWell(
                  onTap: () => widget.onUpdate(
                    NoteEditorBlockPatch(checked: !block.checked),
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: kNotesCheckCircleSize,
                    height: kNotesCheckCircleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: block.checked
                            ? const Color(0xFF6366F1)
                            : const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                      color: block.checked ? const Color(0xFF6366F1) : null,
                    ),
                    child: block.checked
                        ? const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            if (isChecklist) const SizedBox(width: 8),
            if (isBullet || isNumbered || isQuote || isCallout || isCollapsible)
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 8),
                child: Icon(
                  isBullet
                      ? Icons.circle
                      : isNumbered
                      ? Icons.format_list_numbered_rounded
                      : isQuote
                      ? Icons.format_quote_rounded
                      : isCallout
                      ? Icons.lightbulb_outline_rounded
                      : block.collapsed
                      ? Icons.chevron_right_rounded
                      : Icons.expand_more_rounded,
                  size: isBullet ? 7 : 16,
                  color: isCallout ? scheme.tertiary : scheme.primary,
                ),
              ),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: textStyle.copyWith(
                  decoration: (isChecklist && block.checked)
                      ? TextDecoration.lineThrough
                      : textStyle.decoration,
                  color: (isChecklist && block.checked)
                      ? kGlmMetaColor
                      : textStyle.color,
                ),
                decoration: InputDecoration(
                  hintText: isChecklist
                      ? t(loc, 'notes_v3_editor_list_item_hint')
                      : isHeading
                      ? t(loc, 'notes_v3_editor_heading_hint')
                      : t(loc, 'notes_v3_editor_start_writing'),
                  hintStyle: TextStyle(
                    fontSize: isHeading ? headingSize : kNotesBodySize,
                    fontWeight: isHeading ? headingWeight : FontWeight.w400,
                    color: kGlmMetaColor.withValues(alpha: 0.65),
                    height: isHeading ? 1.25 : 1.45,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
                onChanged: (v) =>
                    widget.onUpdate(NoteEditorBlockPatch(text: v)),
                onSubmitted: (_) => widget.onEnter(),
              ),
            ),
            if (widget.isActive)
              _NoteEditorBlockActiveControls(
                canMoveUp: widget.canMoveUp,
                canMoveDown: widget.canMoveDown,
                onMoveUp: widget.onMoveUp,
                onMoveDown: widget.onMoveDown,
                onDelete: widget.onDelete,
                loc: loc,
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteEditorBlockActiveControls extends StatelessWidget {
  const _NoteEditorBlockActiveControls({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.loc,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final String loc;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canMoveUp)
          _NoteEditorBlockControlBtn(
            icon: Icons.keyboard_arrow_up_rounded,
            tooltip: t(loc, 'notes_v3_editor_move_up'),
            onTap: onMoveUp,
          ),
        if (canMoveDown)
          _NoteEditorBlockControlBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: t(loc, 'notes_v3_editor_move_down'),
            onTap: onMoveDown,
          ),
        _NoteEditorBlockControlBtn(
          icon: Icons.delete_outline_rounded,
          tooltip: t(loc, 'notes_v3_editor_delete_block'),
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _NoteEditorBlockControlBtn extends StatelessWidget {
  const _NoteEditorBlockControlBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Icon(icon, size: 14, color: kGlmMetaColor),
          ),
        ),
      ),
    );
  }
}

class _NoteEditorImageBlock extends StatelessWidget {
  const _NoteEditorImageBlock({
    required this.block,
    required this.isActive,
    required this.onActivate,
    required this.onDelete,
  });

  final NoteBlock block;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onActivate,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _bytesFromDataUrl(block.imageData)!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  color: scheme.errorContainer.withValues(alpha: 0.3),
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: scheme.error),
                ),
              ),
            ),
            if (isActive)
              Positioned(
                top: 8,
                right: 8,
                child: _NoteEditorMediaOverlayBtn(
                  icon: Icons.close_rounded,
                  onTap: onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteEditorDrawingBlock extends StatelessWidget {
  const _NoteEditorDrawingBlock({
    required this.block,
    required this.isActive,
    required this.onActivate,
    required this.onEditDrawing,
    required this.onDelete,
  });

  final NoteBlock block;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onEditDrawing;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onActivate,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.white,
                child: Image.memory(
                  _bytesFromDataUrl(block.drawingData)!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    color: scheme.errorContainer.withValues(alpha: 0.3),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.error,
                    ),
                  ),
                ),
              ),
            ),
            if (isActive)
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NoteEditorMediaOverlayBtn(
                      icon: Icons.edit_rounded,
                      onTap: onEditDrawing,
                    ),
                    const SizedBox(width: 4),
                    _NoteEditorMediaOverlayBtn(
                      icon: Icons.close_rounded,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteEditorMediaOverlayBtn extends StatelessWidget {
  const _NoteEditorMediaOverlayBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

Uint8List? _bytesFromDataUrl(String? dataUrl) {
  if (dataUrl == null) return null;
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

Color? _parseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim();
  if (h.isEmpty) return null;
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// Add Text / Checklist / Heading / Image / Drawing row under the block list.
class NoteEditorAddBlockRow extends StatelessWidget {
  const NoteEditorAddBlockRow({
    super.key,
    required this.loc,
    required this.onAdd,
    required this.onImage,
    required this.onDraw,
  });

  final String loc;
  final void Function(NoteBlockType) onAdd;
  final VoidCallback onImage;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _NoteEditorAddButton(
          icon: Icons.add_rounded,
          label: t(loc, 'notes_v3_editor_add_text'),
          onTap: () => onAdd(NoteBlockType.paragraph),
        ),
        _NoteEditorAddButton(
          icon: Icons.checklist_rounded,
          label: t(loc, 'notes_v3_editor_add_checklist'),
          onTap: () => onAdd(NoteBlockType.checklist),
        ),
        _NoteEditorAddButton(
          icon: Icons.title_rounded,
          label: t(loc, 'notes_v3_editor_add_heading'),
          onTap: () => onAdd(NoteBlockType.heading),
        ),
        _NoteEditorAddButton(
          icon: Icons.image_outlined,
          label: t(loc, 'notes_v3_editor_add_image'),
          onTap: onImage,
        ),
        _NoteEditorAddButton(
          icon: Icons.draw_outlined,
          label: t(loc, 'notes_v3_editor_add_draw'),
          onTap: onDraw,
        ),
      ],
    );
  }
}

class _NoteEditorAddButton extends StatelessWidget {
  const _NoteEditorAddButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = kGlmPillTextColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: notesGlmGlassPillDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
