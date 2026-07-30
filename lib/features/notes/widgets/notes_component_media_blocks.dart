part of 'notes_canonical_components.dart';

class NotesMediaBlock extends StatelessWidget {
  const NotesMediaBlock({
    super.key,
    required this.kind,
    required this.media,
    this.state = NotesBlockState.defaultState,
    this.captionController,
    this.captionHint,
    this.onCaptionChanged,
    this.onTap,
  });

  final NotesMediaKind kind;
  final Widget media;
  final NotesBlockState state;
  final TextEditingController? captionController;
  final String? captionHint;
  final ValueChanged<String>? onCaptionChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = state == NotesBlockState.active;
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
            child: DecoratedBox(
              key: const ValueKey('notes-media-frame'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? scheme.outline : scheme.outlineVariant,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: media,
              ),
            ),
          ),
          if (captionController != null) ...[
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('notes-media-caption'),
              controller: captionController,
              minLines: 1,
              maxLines: null,
              onChanged: onCaptionChanged,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: scheme.onSurfaceVariant,
              ),
              decoration: InputDecoration(
                hintText: captionHint,
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
}

class NotesAudioBlock extends StatelessWidget {
  const NotesAudioBlock({
    super.key,
    required this.state,
    required this.title,
    required this.statusLabel,
    required this.playTooltip,
    required this.pauseTooltip,
    required this.transcriptTooltip,
    this.durationLabel,
    this.onPlayPause,
    this.onOpenTranscript,
  });

  final NotesAudioState state;
  final String title;
  final String statusLabel;
  final String playTooltip;
  final String pauseTooltip;
  final String transcriptTooltip;
  final String? durationLabel;
  final VoidCallback? onPlayPause;
  final VoidCallback? onOpenTranscript;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = state == NotesAudioState.transcribing;
    final playing = state == NotesAudioState.playing;
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                tooltip: playing ? pauseTooltip : playTooltip,
                onPressed: onPlayPause,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: state == NotesAudioState.transcriptError
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (durationLabel != null)
                Text(
                  durationLabel!,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              if (onOpenTranscript != null)
                IconButton(
                  tooltip: transcriptTooltip,
                  onPressed: onOpenTranscript,
                  icon: const Icon(Icons.notes_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
