import 'dart:convert';
import 'dart:typed_data';

import 'package:counter/data/models.dart';
import 'package:counter/features/notes/notes_audio_controller.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Production block row composed from canonical Notes components.
///
/// Text input stays outside delayed reorder listeners so typing and selection
/// remain on the direct gesture path. Structural/media blocks retain long-press
/// reorder behavior.
class NotesEditorBlockItem extends StatelessWidget {
  const NotesEditorBlockItem({
    super.key,
    required this.block,
    required this.index,
    required this.numberedOrdinal,
    required this.active,
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
  });

  final NoteBlock block;
  final int index;
  final int numberedOrdinal;
  final bool active;
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
    final child = _buildCanonicalBlock(context, state);

    Widget interactive = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onTap(),
      child: editable
          ? Focus(onKeyEvent: (_, event) => onKeyEvent(event), child: child)
          : child,
    );

    if (editable && block.effectiveText.isEmpty && onEmptyLongPress != null) {
      interactive = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: onEmptyLongPress,
        child: interactive,
      );
    } else if (!editable && _isVisibleProductionBlock(block.type)) {
      interactive = ReorderableDelayedDragStartListener(
        index: index,
        child: interactive,
      );
    }

    return KeyedSubtree(key: ValueKey(block.id), child: interactive);
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
        return NotesMediaBlock(
          kind: block.type == NoteBlockType.drawing
              ? NotesMediaKind.drawing
              : NotesMediaKind.image,
          media: _mediaContent(context),
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

  Widget _mediaContent(BuildContext context) {
    final raw = block.type == NoteBlockType.drawing
        ? block.drawingData
        : block.imageData;
    final bytes = _decodeImagePayload(raw);
    if (bytes == null) return _mediaPlaceholder(context);
    return RepaintBoundary(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: Image.memory(
          bytes,
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
      height: 88,
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

NotesTextBlockStyle _textStyleFor(NoteBlock block) {
  if (block.type != NoteBlockType.heading) return NotesTextBlockStyle.body;
  if (block.level == 1) return NotesTextBlockStyle.h1;
  if (block.level == 3) return NotesTextBlockStyle.h3;
  return NotesTextBlockStyle.h2;
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
