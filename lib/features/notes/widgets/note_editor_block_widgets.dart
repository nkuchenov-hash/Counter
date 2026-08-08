import 'dart:convert';
import 'dart:typed_data';

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_audio_controller.dart';
import 'package:counter/features/notes/notes_figma_tokens.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const Duration _notesBlockHoldToDragDuration = Duration(milliseconds: 320);

/// Matches the Plans Time View hold-to-move timing: a short mouse drag remains
/// available for text selection, while holding still for 320 ms arms reorder.
class _NotesBlockHoldDragStartListener extends ReorderableDragStartListener {
  const _NotesBlockHoldDragStartListener({
    required super.index,
    required super.child,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: _notesBlockHoldToDragDuration,
      debugOwner: this,
    );
  }
}

/// Production block row composed from canonical Notes components.
///
/// Only the block that currently owns keyboard focus is an EditableText. Other
/// text blocks render as normal RichText inside the page SelectionArea, so a
/// desktop mouse drag can select continuously across paragraphs/list items.
class NotesEditorBlockItem extends StatelessWidget {
  NotesEditorBlockItem({
    Key? key,
    required this.block,
    required this.index,
    required this.numberedOrdinal,
    required this.active,
    required this.editing,
    required this.onTap,
    required this.onKeyEvent,
    this.textController,
    this.focusNode,
    this.captionController,
    this.onTextChanged,
    this.onCheckedChanged,
    this.onTableChanged,
    this.onCaptionChanged,
    this.onEmptyLongPress,
    this.audioState = NotesAudioState.ready,
    this.onAudioPlayPause,
    this.onOpenTranscript,
  }) : super(key: key ?? ValueKey<String>(block.id));

  final NoteBlock block;
  final int index;
  final int numberedOrdinal;
  final bool active;
  final bool editing;
  final VoidCallback onTap;
  final KeyEventResult Function(KeyEvent event) onKeyEvent;
  final TextEditingController? textController;
  final FocusNode? focusNode;
  final TextEditingController? captionController;
  final ValueChanged<String>? onTextChanged;
  final ValueChanged<bool>? onCheckedChanged;
  final ValueChanged<NoteTableData>? onTableChanged;
  final ValueChanged<String>? onCaptionChanged;
  final VoidCallback? onEmptyLongPress;
  final NotesAudioState audioState;
  final VoidCallback? onAudioPlayPause;
  final VoidCallback? onOpenTranscript;

  @override
  Widget build(BuildContext context) {
    final state = active
        ? NotesBlockState.active
        : NotesBlockState.defaultState;
    final editable = _isEditableText(block.type);
    final selectable = editable && !editing;
    final child = selectable
        ? _buildSelectableTextBlock(context)
        : _buildCanonicalBlock(context, state);

    Widget interactive;
    if (selectable) {
      interactive = child;
    } else if (editable) {
      interactive = Focus(
        onKeyEvent: (_, event) => onKeyEvent(event),
        child: child,
      );
    } else {
      interactive = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => onTap(),
        child: child,
      );
    }

    if (!selectable &&
        editable &&
        block.effectiveText.isEmpty &&
        onEmptyLongPress != null) {
      interactive = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: onEmptyLongPress,
        child: interactive,
      );
    }

    if (_isVisibleProductionBlock(block.type)) {
      interactive = _NotesBlockHoldDragStartListener(
        index: index,
        child: interactive,
      );
    }

    return interactive;
  }

  Widget _buildSelectableTextBlock(BuildContext context) {
    final style = _selectableTextStyle(context, block);
    final text = block.effectiveText;
    final hint = switch (block.type) {
      NoteBlockType.heading when block.level == 1 => 'Heading',
      NoteBlockType.bulletedList || NoteBlockType.numberedList => 'List item',
      NoteBlockType.checklist => 'Checklist item',
      NoteBlockType.quote => 'Quote',
      _ => 'Write something',
    };

    Widget selectableText({TextStyle? overrideStyle}) {
      final effectiveStyle = overrideStyle ?? style;
      final textKey = GlobalKey();
      final span = text.isEmpty
          ? TextSpan(
              text: hint,
              style: effectiveStyle.copyWith(
                color: NotesFigmaTokens.textSecondary(
                  context,
                ).withValues(alpha: 0.55),
              ),
            )
          : _selectableSpan(context, effectiveStyle);
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          final current = FocusManager.instance.primaryFocus;
          if (current != null && current != focusNode) current.unfocus();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            if (text.isNotEmpty) {
              final render = textKey.currentContext?.findRenderObject();
              if (render is RenderParagraph) {
                final local = render.globalToLocal(details.globalPosition);
                final position = render.getPositionForOffset(local);
                final controller = textController;
                if (controller != null) {
                  final offset = position.offset
                      .clamp(0, controller.text.length)
                      .toInt();
                  controller.selection = TextSelection.collapsed(offset: offset);
                }
              }
            } else {
              final controller = textController;
              if (controller != null) {
                controller.selection = const TextSelection.collapsed(offset: 0);
              }
            }
            onTap();
          },
          onLongPress: text.isEmpty ? onEmptyLongPress : null,
          child: Text.rich(
            span,
            key: textKey,
            softWrap: true,
          ),
        ),
      );
    }

    switch (block.type) {
      case NoteBlockType.paragraph:
      case NoteBlockType.heading:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kNotesContentInset,
            vertical: kNotesBlockVerticalPadding,
          ),
          child: selectableText(),
        );
      case NoteBlockType.bulletedList:
      case NoteBlockType.numberedList:
        final marker = block.type == NoteBlockType.numberedList
            ? Text(
                '$numberedOrdinal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: NotesFigmaTokens.textPrimary(context),
                ),
              )
            : Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: NotesFigmaTokens.textPrimary(context),
                  shape: BoxShape.circle,
                ),
              );
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            kNotesContentInset,
            10,
            kNotesContentInset,
            10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: kNotesLeadingSize,
                height: 24,
                child: Center(child: marker),
              ),
              const SizedBox(width: kNotesLeadingGap),
              Expanded(child: selectableText()),
            ],
          ),
        );
      case NoteBlockType.checklist:
        final checkedStyle = block.checked
            ? style.copyWith(
                color: NotesFigmaTokens.textSecondary(context),
                decoration: TextDecoration.lineThrough,
              )
            : style;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            kNotesContentInset,
            10,
            kNotesContentInset,
            10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: kNotesLeadingSize,
                height: 24,
                child: Center(
                  child: InkWell(
                    onTap: onCheckedChanged == null
                        ? null
                        : () => onCheckedChanged!(!block.checked),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: block.checked
                            ? NotesFigmaTokens.selectedSurface(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: block.checked
                            ? null
                            : Border.all(
                                color: NotesFigmaTokens.textPrimary(
                                  context,
                                ).withValues(alpha: 0.15),
                              ),
                      ),
                      child: block.checked
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: NotesFigmaTokens.selectedIcon(context),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: kNotesLeadingGap),
              Expanded(child: selectableText(overrideStyle: checkedStyle)),
            ],
          ),
        );
      case NoteBlockType.quote:
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kNotesContentInset,
            vertical: kNotesBlockVerticalPadding,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: selectableText(
                overrideStyle: style.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  TextSpan _selectableSpan(BuildContext context, TextStyle style) {
    final controller = textController;
    if (controller is NotesTextEditingController) {
      controller.linkColor = Theme.of(context).colorScheme.primary;
      return controller.buildTextSpan(
        context: context,
        style: style,
        withComposing: false,
      );
    }
    return TextSpan(text: block.effectiveText, style: style);
  }

  Widget _buildCanonicalBlock(BuildContext context, NotesBlockState state) {
    switch (block.type) {
      case NoteBlockType.paragraph:
      case NoteBlockType.heading:
        return NotesTextBlock(
          controller: textController!,
          focusNode: focusNode,
          style: _textStyleFor(block),
          state: state,
          hintText: block.type == NoteBlockType.heading && block.level == 1
              ? 'Heading'
              : 'Write something',
          onChanged: onTextChanged,
          onTap: onTap,
          textFieldKey: ValueKey('notes-block-field-${block.id}'),
        );
      case NoteBlockType.bulletedList:
      case NoteBlockType.numberedList:
        return NotesListBlock(
          controller: textController!,
          focusNode: focusNode,
          listStyle: block.type == NoteBlockType.numberedList
              ? NotesListStyle.numbered
              : NotesListStyle.bulleted,
          ordinal: numberedOrdinal,
          state: state,
          hintText: 'List item',
          onChanged: onTextChanged,
          onTap: onTap,
          textFieldKey: ValueKey('notes-block-field-${block.id}'),
        );
      case NoteBlockType.checklist:
        return NotesChecklistBlock(
          controller: textController!,
          focusNode: focusNode,
          checked: block.checked,
          state: state,
          hintText: 'Checklist item',
          onCheckedChanged: onCheckedChanged!,
          onChanged: onTextChanged,
          onTap: onTap,
          textFieldKey: ValueKey('notes-block-field-${block.id}'),
        );
      case NoteBlockType.quote:
        return NotesQuoteBlock(
          textController: textController!,
          state: state,
          textHint: 'Quote',
          onTextChanged: onTextChanged,
        );
      case NoteBlockType.divider:
        return const NotesDividerBlock();
      case NoteBlockType.table:
        return NotesTableBlock(
          data: block.table ?? NoteTableData.empty(),
          state: state,
          onChanged: onTableChanged!,
        );
      case NoteBlockType.image:
      case NoteBlockType.drawing:
        if (MediaQuery.sizeOf(context).width >= 768) {
          return _desktopMediaBlock(context);
        }
        return NotesMediaBlock(
          kind: block.type == NoteBlockType.drawing
              ? NotesMediaKind.drawing
              : NotesMediaKind.image,
          media: _mobileMediaContent(context),
          state: state,
          captionController: captionController,
          captionHint: 'Caption',
          onCaptionChanged: onCaptionChanged,
          onTap: onTap,
        );
      case NoteBlockType.audio:
        final loc = currentLocale.value;
        final audio = block.audio;
        final statusLabel = switch (audioState) {
          NotesAudioState.playing => t(loc, 'notes_audio_playing'),
          NotesAudioState.transcribing => t(loc, 'notes_audio_transcribing'),
          NotesAudioState.transcriptError => t(
            loc,
            'notes_audio_transcript_error',
          ),
          NotesAudioState.ready =>
            audio?.transcriptStatus == NoteAudioTranscriptStatus.ready
                ? t(loc, 'notes_audio_transcript_ready')
                : t(loc, 'notes_audio_ready'),
        };
        return NotesAudioBlock(
          state: audioState,
          title: t(loc, 'notes_audio_title'),
          statusLabel: statusLabel,
          playTooltip: t(loc, 'notes_audio_play'),
          pauseTooltip: t(loc, 'notes_audio_pause'),
          transcriptTooltip: t(loc, 'notes_audio_transcript_title'),
          durationLabel: formatNotesAudioDuration(audio?.durationMs ?? 0),
          onPlayPause: onAudioPlayPause,
          onOpenTranscript: onOpenTranscript,
        );
      case NoteBlockType.callout:
      case NoteBlockType.linkCard:
      case NoteBlockType.codeBlock:
      case NoteBlockType.collapsible:
      case NoteBlockType.planReference:
      case NoteBlockType.recordReference:
      case NoteBlockType.noteReference:
      case NoteBlockType.categoryReference:
        return const SizedBox.shrink();
    }
  }

  Widget _desktopMediaBlock(BuildContext context) {
    final raw = block.type == NoteBlockType.drawing
        ? block.drawingData
        : block.imageData;
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final hasPayload = raw?.trim().isNotEmpty ?? false;
    final kindLabel = block.type == NoteBlockType.drawing
        ? t(loc, 'notes_v3_draw_badge')
        : t(loc, 'notes_v3_image_badge');
    final title = hasPayload
        ? kindLabel
        : t(loc, 'notes_v3_editor_load_failed');
    final sizeLabel = hasPayload
        ? _formatNotesAssetBytes(_estimatedAssetBytes(raw!))
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kNotesContentInset,
        vertical: kNotesBlockVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              key: const ValueKey('notes-desktop-media-file-row'),
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SizedBox.square(
                          dimension: 42,
                          child: Icon(
                            hasPayload
                                ? (block.type == NoteBlockType.drawing
                                      ? Icons.draw_rounded
                                      : Icons.image_outlined)
                                : Icons.broken_image_outlined,
                            size: 21,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (sizeLabel != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                sizeLabel,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (captionController != null &&
              captionController!.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            TextField(
              controller: captionController,
              minLines: 1,
              maxLines: null,
              onChanged: onCaptionChanged,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: scheme.onSurfaceVariant,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mobileMediaContent(BuildContext context) {
    final raw = block.type == NoteBlockType.drawing
        ? block.drawingData
        : block.imageData;
    final bytes = _decodeImagePayload(raw);
    if (bytes == null) return _mediaPlaceholder(context);
    const previewHeight = 240.0;
    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        height: previewHeight,
        child: Image.memory(
          bytes,
          width: double.infinity,
          height: previewHeight,
          alignment: Alignment.topCenter,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _mediaPlaceholder(context),
        ),
      ),
    );
  }

  Widget _mediaPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                block.type == NoteBlockType.drawing
                    ? Icons.draw_rounded
                    : Icons.broken_image_outlined,
                size: 24,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t(currentLocale.value, 'notes_v3_editor_load_failed'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _estimatedAssetBytes(String raw) {
  final value = raw.trim();
  final comma = value.indexOf(',');
  final encoded = value.startsWith('data:') && comma >= 0
      ? value.substring(comma + 1)
      : value;
  if (encoded.isEmpty) return 0;
  final padding = encoded.endsWith('==') ? 2 : (encoded.endsWith('=') ? 1 : 0);
  return ((encoded.length * 3) ~/ 4 - padding).clamp(0, 1 << 30);
}

String _formatNotesAssetBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 10 ? 1 : 2)} MB';
}

NotesTextBlockStyle _textStyleFor(NoteBlock block) {
  if (block.type != NoteBlockType.heading) return NotesTextBlockStyle.body;
  if (block.level == 1) return NotesTextBlockStyle.h1;
  if (block.level == 3) return NotesTextBlockStyle.h3;
  return NotesTextBlockStyle.h2;
}

TextStyle _selectableTextStyle(BuildContext context, NoteBlock block) {
  final color = NotesFigmaTokens.textPrimary(context);
  final style = _textStyleFor(block);
  return switch (style) {
    NotesTextBlockStyle.body => TextStyle(
        fontSize: NotesFigmaTokens.bodySize,
        height: NotesFigmaTokens.bodyLineHeight / NotesFigmaTokens.bodySize,
        fontWeight: FontWeight.w400,
        color: color,
      ),
    NotesTextBlockStyle.h1 => TextStyle(
        fontSize: NotesFigmaTokens.h1Size,
        height: NotesFigmaTokens.h1LineHeight / NotesFigmaTokens.h1Size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: color,
      ),
    NotesTextBlockStyle.h2 => TextStyle(
        fontSize: NotesFigmaTokens.h2Size,
        height: NotesFigmaTokens.h2LineHeight / NotesFigmaTokens.h2Size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        color: color,
      ),
    NotesTextBlockStyle.h3 => TextStyle(
        fontSize: NotesFigmaTokens.h3Size,
        height: NotesFigmaTokens.h3LineHeight / NotesFigmaTokens.h3Size,
        fontWeight: FontWeight.w600,
        color: color,
      ),
  };
}

bool _isEditableText(NoteBlockType type) {
  return type == NoteBlockType.paragraph ||
      type == NoteBlockType.heading ||
      type == NoteBlockType.bulletedList ||
      type == NoteBlockType.numberedList ||
      type == NoteBlockType.checklist ||
      type == NoteBlockType.quote;
}

bool _isVisibleProductionBlock(NoteBlockType type) {
  return _isEditableText(type) ||
      type == NoteBlockType.divider ||
      type == NoteBlockType.table ||
      type == NoteBlockType.image ||
      type == NoteBlockType.drawing ||
      type == NoteBlockType.audio;
}

Uint8List? _decodeImagePayload(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  final comma = value.indexOf(',');
  final encoded = value.startsWith('data:') && comma >= 0
      ? value.substring(comma + 1)
      : value;
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}
