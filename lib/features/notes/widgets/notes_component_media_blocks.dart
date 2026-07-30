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
              AppIconButton(
                tooltip: playing ? pauseTooltip : playTooltip,
                onPressed: busy ? null : onPlayPause,
                size: AppIconButtonSize.s,
                variant: AppIconButtonVariant.subtle,
                selected: playing,
                icon: playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
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
                AppIconButton(
                  tooltip: transcriptTooltip,
                  onPressed: onOpenTranscript,
                  size: AppIconButtonSize.s,
                  variant: AppIconButtonVariant.subtle,
                  icon: Icons.notes_rounded,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum NotesDrawingTool { pen, highlighter, eraser, lasso }

enum NotesRecorderState { ready, recording, paused, permissionBlocked }

class NotesDrawingColorOption {
  const NotesDrawingColorOption({required this.color, required this.label});

  final Color color;
  final String label;
}

class NotesDrawingControls extends StatelessWidget {
  const NotesDrawingControls({
    super.key,
    required this.selectedTool,
    required this.onToolSelected,
    required this.selectedColor,
    required this.colors,
    required this.onColorSelected,
    required this.strokeWidth,
    required this.onStrokeWidthChanged,
    required this.penTooltip,
    required this.highlighterTooltip,
    required this.eraserTooltip,
    required this.lassoTooltip,
    required this.undoTooltip,
    required this.redoTooltip,
    required this.strokeWidthLabel,
    this.canUndo = false,
    this.canRedo = false,
    this.onUndo,
    this.onRedo,
  });

  final NotesDrawingTool selectedTool;
  final ValueChanged<NotesDrawingTool> onToolSelected;
  final Color selectedColor;
  final List<NotesDrawingColorOption> colors;
  final ValueChanged<Color> onColorSelected;
  final double strokeWidth;
  final ValueChanged<double> onStrokeWidthChanged;
  final String penTooltip;
  final String highlighterTooltip;
  final String eraserTooltip;
  final String lassoTooltip;
  final String undoTooltip;
  final String redoTooltip;
  final String strokeWidthLabel;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _drawingToolButton(
                    tool: NotesDrawingTool.pen,
                    icon: Icons.edit_rounded,
                    tooltip: penTooltip,
                  ),
                  _drawingToolButton(
                    tool: NotesDrawingTool.highlighter,
                    icon: Icons.border_color_rounded,
                    tooltip: highlighterTooltip,
                  ),
                  _drawingToolButton(
                    tool: NotesDrawingTool.eraser,
                    icon: Icons.auto_fix_off_rounded,
                    tooltip: eraserTooltip,
                  ),
                  _drawingToolButton(
                    tool: NotesDrawingTool.lasso,
                    icon: Icons.gesture_rounded,
                    tooltip: lassoTooltip,
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icons.undo_rounded,
                    tooltip: undoTooltip,
                    size: AppIconButtonSize.s,
                    variant: AppIconButtonVariant.subtle,
                    onPressed: canUndo ? onUndo : null,
                  ),
                  AppIconButton(
                    icon: Icons.redo_rounded,
                    tooltip: redoTooltip,
                    size: AppIconButtonSize.s,
                    variant: AppIconButtonVariant.subtle,
                    onPressed: canRedo ? onRedo : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final option in colors)
                  _NotesDrawingColorButton(
                    option: option,
                    selected: option.color == selectedColor,
                    onPressed: () => onColorSelected(option.color),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label: strokeWidthLabel,
              value: strokeWidth.toStringAsFixed(1),
              slider: true,
              child: Row(
                children: [
                  Text(
                    strokeWidthLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Expanded(
                    child: Slider(
                      value: strokeWidth.clamp(1.0, 24.0).toDouble(),
                      min: 1,
                      max: 24,
                      divisions: 23,
                      label: strokeWidth.toStringAsFixed(0),
                      onChanged: onStrokeWidthChanged,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawingToolButton({
    required NotesDrawingTool tool,
    required IconData icon,
    required String tooltip,
  }) {
    return AppIconButton(
      icon: icon,
      tooltip: tooltip,
      size: AppIconButtonSize.s,
      variant: AppIconButtonVariant.subtle,
      selected: selectedTool == tool,
      onPressed: () => onToolSelected(tool),
    );
  }
}

class NotesRecorderControls extends StatelessWidget {
  const NotesRecorderControls({
    super.key,
    required this.state,
    required this.statusLabel,
    required this.startLabel,
    required this.pauseLabel,
    required this.resumeLabel,
    required this.stopLabel,
    required this.discardLabel,
    required this.openSettingsLabel,
    this.durationLabel,
    this.levelIndicator,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onStop,
    this.onDiscard,
    this.onOpenSettings,
  });

  final NotesRecorderState state;
  final String statusLabel;
  final String startLabel;
  final String pauseLabel;
  final String resumeLabel;
  final String stopLabel;
  final String discardLabel;
  final String openSettingsLabel;
  final String? durationLabel;
  final Widget? levelIndicator;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  final VoidCallback? onDiscard;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = state == NotesRecorderState.permissionBlocked;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: blocked ? scheme.error : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  blocked ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: blocked ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (durationLabel != null)
                  Text(
                    durationLabel!,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
              ],
            ),
            if (levelIndicator != null) ...[
              const SizedBox(height: 12),
              levelIndicator!,
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _actionsForState(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actionsForState() {
    return switch (state) {
      NotesRecorderState.ready => [
          AppButton.primary(
            label: startLabel,
            icon: Icons.mic_rounded,
            size: AppButtonSize.s,
            onPressed: onStart,
          ),
        ],
      NotesRecorderState.recording => [
          AppButton.secondary(
            label: pauseLabel,
            icon: Icons.pause_rounded,
            size: AppButtonSize.s,
            onPressed: onPause,
          ),
          AppButton.primary(
            label: stopLabel,
            icon: Icons.stop_rounded,
            size: AppButtonSize.s,
            onPressed: onStop,
          ),
          AppButton.ghost(
            label: discardLabel,
            icon: Icons.delete_outline_rounded,
            size: AppButtonSize.s,
            onPressed: onDiscard,
          ),
        ],
      NotesRecorderState.paused => [
          AppButton.secondary(
            label: resumeLabel,
            icon: Icons.play_arrow_rounded,
            size: AppButtonSize.s,
            onPressed: onResume,
          ),
          AppButton.primary(
            label: stopLabel,
            icon: Icons.stop_rounded,
            size: AppButtonSize.s,
            onPressed: onStop,
          ),
          AppButton.ghost(
            label: discardLabel,
            icon: Icons.delete_outline_rounded,
            size: AppButtonSize.s,
            onPressed: onDiscard,
          ),
        ],
      NotesRecorderState.permissionBlocked => [
          AppButton.outlined(
            label: openSettingsLabel,
            icon: Icons.settings_rounded,
            size: AppButtonSize.s,
            onPressed: onOpenSettings,
          ),
        ],
    };
  }
}

class NotesTranscriptSurface extends StatelessWidget {
  const NotesTranscriptSurface({
    super.key,
    required this.title,
    required this.transcript,
    required this.copyLabel,
    required this.doneLabel,
    required this.onCopy,
    required this.onDone,
    this.playbackContext,
    this.emptyLabel,
  });

  final String title;
  final String transcript;
  final String copyLabel;
  final String doneLabel;
  final VoidCallback onCopy;
  final VoidCallback onDone;
  final Widget? playbackContext;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleTranscript = transcript.trim().isEmpty
        ? (emptyLabel ?? '')
        : transcript;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.close_rounded,
                    tooltip: doneLabel,
                    size: AppIconButtonSize.s,
                    variant: AppIconButtonVariant.subtle,
                    onPressed: onDone,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            if (playbackContext != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: playbackContext!,
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  visibleTranscript,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    height: 1.55,
                    color: transcript.trim().isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton.secondary(
                    label: copyLabel,
                    icon: Icons.copy_rounded,
                    size: AppButtonSize.s,
                    onPressed: transcript.trim().isEmpty ? null : onCopy,
                  ),
                  AppButton.primary(
                    label: doneLabel,
                    size: AppButtonSize.s,
                    onPressed: onDone,
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

class _NotesDrawingColorButton extends StatelessWidget {
  const _NotesDrawingColorButton({
    required this.option,
    required this.selected,
    required this.onPressed,
  });

  final NotesDrawingColorOption option;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: option.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: option.label,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
