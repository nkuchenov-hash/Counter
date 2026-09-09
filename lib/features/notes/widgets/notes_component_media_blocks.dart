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
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
enum NotesDrawingTool {
  pencil,
  pen,
  fineliner,
  marker,
  highlighter,
  brush,
  fountainPen,
  eraser,
  lasso,
}
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
    this.pencilTooltip = 'Pencil',
    this.finelinerTooltip = 'Fineliner',
    this.markerTooltip = 'Marker',
    this.brushTooltip = 'Brush',
    this.fountainPenTooltip = 'Fountain Pen',
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
  final String pencilTooltip;
  final String penTooltip;
  final String finelinerTooltip;
  final String markerTooltip;
  final String highlighterTooltip;
  final String brushTooltip;
  final String fountainPenTooltip;
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
    final erasing = selectedTool == NotesDrawingTool.eraser;
    final sliderMax = erasing ? 96.0 : 24.0;
    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolTray(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                          value: strokeWidth.clamp(1.0, sliderMax).toDouble(),
                          min: 1,
                          max: sliderMax,
                          divisions: erasing ? 95 : 23,
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
        ],
      ),
    );
  }
  Widget _buildToolTray(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 104,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surfaceContainerHighest.withValues(alpha: 0.96),
            scheme.surfaceContainerLow.withValues(alpha: 0.98),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _physicalTool(NotesDrawingTool.pencil, pencilTooltip),
                  _physicalTool(NotesDrawingTool.pen, penTooltip),
                  _physicalTool(NotesDrawingTool.fineliner, finelinerTooltip),
                  _physicalTool(NotesDrawingTool.marker, markerTooltip),
                  _physicalTool(NotesDrawingTool.highlighter, highlighterTooltip),
                  _physicalTool(NotesDrawingTool.brush, brushTooltip),
                  _physicalTool(NotesDrawingTool.fountainPen, fountainPenTooltip),
                  _physicalTool(NotesDrawingTool.eraser, eraserTooltip),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
                    child: Container(
                      width: 1,
                      height: 40,
                      color: scheme.outlineVariant,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AppIconButton(
                      icon: Icons.gesture_rounded,
                      tooltip: lassoTooltip,
                      size: AppIconButtonSize.s,
                      variant: AppIconButtonVariant.subtle,
                      selected: selectedTool == NotesDrawingTool.lasso,
                      onPressed: () => onToolSelected(NotesDrawingTool.lasso),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AppIconButton(
                      icon: Icons.undo_rounded,
                      tooltip: undoTooltip,
                      size: AppIconButtonSize.s,
                      variant: AppIconButtonVariant.subtle,
                      onPressed: canUndo ? onUndo : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AppIconButton(
                      icon: Icons.redo_rounded,
                      tooltip: redoTooltip,
                      size: AppIconButtonSize.s,
                      variant: AppIconButtonVariant.subtle,
                      onPressed: canRedo ? onRedo : null,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 12,
              child: IgnorePointer(
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _physicalTool(NotesDrawingTool tool, String tooltip) {
    return _NotesPhysicalToolButton(
      tool: tool,
      color: selectedColor,
      tooltip: tooltip,
      selected: selectedTool == tool,
      onPressed: () => onToolSelected(tool),
    );
  }
}
class _NotesPhysicalToolButton extends StatelessWidget {
  const _NotesPhysicalToolButton({
    required this.tool,
    required this.color,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });
  final NotesDrawingTool tool;
  final Color color;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: InkResponse(
          onTap: onPressed,
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          radius: 30,
          child: SizedBox(
            width: 50,
            height: 104,
            child: AnimatedSlide(
              offset: Offset(0, selected ? -0.045 : 0),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  if (selected)
                    Positioned(
                      bottom: 12,
                      child: Container(
                        width: 36,
                        height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.30),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  CustomPaint(
                    size: const Size(35, 102),
                    painter: _NotesPhysicalToolPainter(
                      tool: tool,
                      ink: color,
                      scheme: scheme,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _NotesPhysicalToolPainter extends CustomPainter {
  const _NotesPhysicalToolPainter({
    required this.tool,
    required this.ink,
    required this.scheme,
  });
  final NotesDrawingTool tool;
  final Color ink;
  final ColorScheme scheme;
  static const double _w = 30;
  static const double _h = 88;
  static const double _shoulder = 31;
  static const double _bandTop = 32.6;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _w, size.height / _h);
    final barrel = Paint()
      ..shader = LinearGradient(
        colors: [
          scheme.surfaceContainerHighest,
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.outlineVariant.withValues(alpha: 0.72),
        ],
        stops: const [0, 0.32, 0.68, 1],
      ).createShader(const Rect.fromLTWH(5, 0, 20, _h));
    final metal = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xff777b82), Color(0xffedf0f2), Color(0xffa7abb1), Color(0xff62666d)],
        stops: [0, 0.3, 0.7, 1],
      ).createShader(const Rect.fromLTWH(5, 0, 20, _h));
    final collar = Paint()..color = const Color(0xff3f4147);
    final inkPaint = Paint()..color = ink;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..color = Colors.black.withValues(alpha: 0.14);
    void barrelBody({double top = _shoulder}) {
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(5, top, 25, 92),
        topLeft: const Radius.circular(1.8),
        topRight: const Radius.circular(1.8),
      );
      canvas.drawRRect(rect, barrel);
    }
    void band() {
      final r = Rect.fromLTRB(5, _bandTop, 25, 37.6);
      canvas.drawRect(r, inkPaint);
      canvas.drawRect(r, Paint()..shader = _shine(r));
    }
    switch (tool) {
      case NotesDrawingTool.pencil:
        barrelBody();
        band();
        _pencil(canvas, inkPaint, edge);
        break;
      case NotesDrawingTool.pen:
        barrelBody();
        band();
        _pen(canvas, inkPaint, collar, edge);
        break;
      case NotesDrawingTool.fineliner:
        barrelBody();
        band();
        _fineliner(canvas, inkPaint, collar, edge);
        break;
      case NotesDrawingTool.marker:
        barrelBody();
        band();
        _marker(canvas, inkPaint, collar, edge);
        break;
      case NotesDrawingTool.highlighter:
        barrelBody();
        band();
        _highlighter(canvas, inkPaint, collar, edge);
        break;
      case NotesDrawingTool.brush:
        barrelBody();
        band();
        _brush(canvas, inkPaint, metal, edge);
        break;
      case NotesDrawingTool.fountainPen:
        barrelBody();
        band();
        _fountain(canvas, collar, edge);
        break;
      case NotesDrawingTool.eraser:
        barrelBody(top: 35);
        _eraser(canvas, metal, edge);
        break;
      case NotesDrawingTool.lasso:
        break;
    }
    canvas.restore();
  }
  Shader _shine(Rect rect) => const LinearGradient(
    colors: [Color(0x33000000), Color(0x44ffffff), Color(0x00000000), Color(0x33000000)],
    stops: [0, 0.28, 0.62, 1],
  ).createShader(rect);
  void _shade(Canvas canvas, Path path, Paint base, Paint edge) {
    canvas.drawPath(path, base);
    canvas.drawPath(path, Paint()..shader = _shine(path.getBounds()));
    canvas.drawPath(path, edge);
  }
  void _pencil(Canvas canvas, Paint inkPaint, Paint edge) {
    final left = Path()..moveTo(5, _bandTop)..lineTo(15, 4)..lineTo(11.6, _bandTop)..close();
    final mid = Path()..moveTo(11.6, _bandTop)..lineTo(15, 4)..lineTo(18.4, _bandTop)..close();
    final right = Path()..moveTo(18.4, _bandTop)..lineTo(15, 4)..lineTo(25, 30)..lineTo(25, _bandTop)..close();
    canvas.drawPath(left, Paint()..color = const Color(0xffead6b2));
    canvas.drawPath(mid, Paint()..color = const Color(0xfff2e4c5));
    canvas.drawPath(right, Paint()..color = const Color(0xffe1c79c));
    final graphite = Path()..moveTo(15, 4)..lineTo(19.4, 17.2)..lineTo(10.6, 17.2)..close();
    _shade(canvas, graphite, inkPaint, edge);
  }
  void _pen(Canvas canvas, Paint inkPaint, Paint collar, Paint edge) {
    final tip = Path()..moveTo(15, 4)..lineTo(19.4, 25)..lineTo(10.6, 25)..close();
    _shade(canvas, tip, inkPaint, edge);
    final neck = Path()..moveTo(5, 33.6)..lineTo(5, 30)..lineTo(9.4, 21.4)..lineTo(20.6, 21.4)..lineTo(25, 30)..lineTo(25, 33.6)..close();
    _shade(canvas, neck, collar, edge);
  }
  void _fineliner(Canvas canvas, Paint inkPaint, Paint collar, Paint edge) {
    final tip = RRect.fromRectAndRadius(const Rect.fromLTRB(13.75, 5.25, 16.25, 24), const Radius.circular(1.25));
    canvas.drawRRect(tip, inkPaint);
    canvas.drawRRect(tip, edge);
    final shoulder = Path()..moveTo(11.6, 24)..lineTo(18.4, 24)..lineTo(19.4, 27.4)..lineTo(10.6, 27.4)..close();
    canvas.drawPath(shoulder, Paint()..color = const Color(0xff57534e));
    final neck = Path()..moveTo(5, 33.6)..lineTo(5, 30)..lineTo(10.4, 27)..lineTo(19.6, 27)..lineTo(25, 30)..lineTo(25, 33.6)..close();
    _shade(canvas, neck, collar, edge);
  }
  void _marker(Canvas canvas, Paint inkPaint, Paint collar, Paint edge) {
    final tip = Path()..moveTo(10.6, 25)..lineTo(11.5, 6)..quadraticBezierTo(11.7, 4, 13.5, 4)..lineTo(16.5, 4)..quadraticBezierTo(18.3, 4, 18.5, 6)..lineTo(19.4, 25)..close();
    _shade(canvas, tip, inkPaint, edge);
    final neck = Path()..moveTo(5, 33.6)..lineTo(5, 30)..lineTo(9.6, 22.6)..lineTo(20.4, 22.6)..lineTo(25, 30)..lineTo(25, 33.6)..close();
    _shade(canvas, neck, collar, edge);
  }
  void _highlighter(Canvas canvas, Paint inkPaint, Paint collar, Paint edge) {
    final tip = Path()..moveTo(8.4, 24)..lineTo(8.4, 12.6)..quadraticBezierTo(8.4, 11.7, 9.2, 11.5)..lineTo(20.4, 7.4)..quadraticBezierTo(21.6, 7, 21.6, 8.5)..lineTo(21.6, 24)..close();
    _shade(canvas, tip, inkPaint, edge);
    final neck = Path()..moveTo(5, 33.6)..lineTo(5, 30)..lineTo(8.2, 22)..lineTo(21.8, 22)..lineTo(25, 30)..lineTo(25, 33.6)..close();
    _shade(canvas, neck, collar, edge);
  }
  void _brush(Canvas canvas, Paint inkPaint, Paint metal, Paint edge) {
    final bristles = Path()..moveTo(15, 4)..cubicTo(17.4, 8.6, 19.9, 13.4, 20.6, 17.6)..cubicTo(21.2, 21, 20.8, 23.8, 20, 26.4)..lineTo(10, 26.4)..cubicTo(9.2, 23.8, 8.8, 21, 9.4, 17.6)..cubicTo(10.1, 13.4, 12.6, 8.6, 15, 4)..close();
    _shade(canvas, bristles, inkPaint, edge);
    final ferrule = RRect.fromRectAndCorners(const Rect.fromLTRB(5, 25.2, 25, 33.6), topLeft: const Radius.circular(1.4), topRight: const Radius.circular(1.4));
    canvas.drawRRect(ferrule, metal);
    canvas.drawLine(const Offset(5, 28.4), const Offset(25, 28.4), Paint()..color = Colors.black.withValues(alpha: 0.16)..strokeWidth = 0.6);
  }
  void _fountain(Canvas canvas, Paint collar, Paint edge) {
    final nib = Path()..moveTo(11, 25)..lineTo(11.7, 11)..lineTo(15, 4)..lineTo(18.3, 11)..lineTo(19, 25)..close();
    final gold = Paint()..shader = const LinearGradient(
      colors: [Color(0xff9d761c), Color(0xffffeaa0), Color(0xffd0a233), Color(0xff8f6b16)],
      stops: [0, 0.34, 0.72, 1],
    ).createShader(const Rect.fromLTRB(11, 4, 19, 25));
    _shade(canvas, nib, gold, edge);
    final slit = Paint()..color = Colors.black.withValues(alpha: 0.36)..strokeWidth = 0.65;
    canvas.drawLine(const Offset(15, 7.5), const Offset(15, 15.2), slit);
    canvas.drawCircle(const Offset(15, 14.5), 1.25, Paint()..color = Colors.black.withValues(alpha: 0.30));
    final neck = Path()..moveTo(5, 33.6)..lineTo(5, 30)..lineTo(10.2, 23.4)..lineTo(19.8, 23.4)..lineTo(25, 30)..lineTo(25, 33.6)..close();
    _shade(canvas, neck, collar, edge);
  }
  void _eraser(Canvas canvas, Paint metal, Paint edge) {
    final rubberRect = RRect.fromRectAndRadius(const Rect.fromLTRB(6.8, 9, 23.2, 34), const Radius.circular(4.8));
    final rubber = Paint()..shader = const LinearGradient(
      colors: [Color(0xffc9806f), Color(0xfff8ccbe), Color(0xffe5a091), Color(0xffb97264)],
      stops: [0, 0.42, 0.78, 1],
    ).createShader(const Rect.fromLTRB(6.8, 9, 23.2, 34));
    canvas.drawRRect(rubberRect, rubber);
    canvas.drawRRect(rubberRect, edge);
    final ferrule = Rect.fromLTRB(5, 29, 25, 37.4);
    canvas.drawRect(ferrule, metal);
    canvas.drawRect(ferrule, edge);
    canvas.drawRect(const Rect.fromLTRB(5, 29, 25, 29.9), Paint()..color = Colors.black.withValues(alpha: 0.15));
  }
  @override
  bool shouldRepaint(covariant _NotesPhysicalToolPainter oldDelegate) =>
      oldDelegate.tool != tool || oldDelegate.ink != ink || oldDelegate.scheme != scheme;
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
        side: BorderSide(color: blocked ? scheme.error : scheme.outlineVariant),
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
            Wrap(spacing: 8, runSpacing: 8, children: _actionsForState()),
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
    this.retryLabel,
    this.onRetry,
  });
  final String title;
  final String transcript;
  final String copyLabel;
  final String doneLabel;
  final VoidCallback onCopy;
  final VoidCallback onDone;
  final Widget? playbackContext;
  final String? emptyLabel;
  final String? retryLabel;
  final VoidCallback? onRetry;
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
                  if (retryLabel != null && onRetry != null)
                    AppButton.outlined(
                      label: retryLabel!,
                      icon: Icons.refresh_rounded,
                      size: AppButtonSize.s,
                      onPressed: onRetry,
                    ),
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
