// Full-screen drawing canvas — faithful Flutter port of DrawingCanvas.tsx.
//
// Pointer-based drawing (mouse + touch + stylus), 8 colors, 4 brush sizes,
// undo, clear, save-as-PNG composited on white. Used by the Notes block
// editor to insert new drawing blocks or edit existing ones.
//
// Pure UI: receives an optional initial PNG data URL and returns the saved
// PNG data URL via [onSave]. No Brain/PocketBase imports.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// The eight drawing colors from the GLM source.
const List<Color> kDrawingColors = <Color>[
  Color(0xFF0F172A), // near-black
  Color(0xFFEF4444), // red
  Color(0xFFF59E0B), // amber
  Color(0xFF10B981), // green
  Color(0xFF06B6D4), // cyan
  Color(0xFF6366F1), // indigo
  Color(0xFFEC4899), // pink
  Color(0xFFFFFFFF), // white
];

/// Brush sizes (stroke width in logical px).
const List<double> kDrawingSizes = <double>[2, 4, 8, 14];

/// A single stroke in the drawing model.
@immutable
class _Stroke {
  const _Stroke({
    required this.color,
    required this.size,
    required this.points,
  });

  final Color color;
  final double size;
  final List<Offset> points;
}

/// Opens the drawing canvas as a full-screen route.
///
/// [initialData] is an optional base64 PNG data URL to edit. Returns the
/// saved PNG data URL via [onSave].
Future<void> showDrawingCanvas({
  required BuildContext context,
  String? initialData,
  required void Function(String pngDataUrl) onSave,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => DrawingCanvasPage(
        initialData: initialData,
        onSave: onSave,
      ),
    ),
  );
}

class DrawingCanvasPage extends StatefulWidget {
  const DrawingCanvasPage({
    super.key,
    this.initialData,
    required this.onSave,
  });

  final String? initialData;
  final void Function(String pngDataUrl) onSave;

  @override
  State<DrawingCanvasPage> createState() => _DrawingCanvasPageState();
}

class _DrawingCanvasPageState extends State<DrawingCanvasPage> {
  final List<_Stroke> _strokes = <_Stroke>[];
  _Stroke? _current;
  Color _color = kDrawingColors.first;
  double _size = kDrawingSizes[1];
  ui.Image? _initialImage;
  bool _loadingInitial = true;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final raw = widget.initialData;
    if (raw == null || raw.trim().isEmpty) {
      if (mounted) setState(() => _loadingInitial = false);
      return;
    }
    try {
      final bytes = _bytesFromDataUrl(raw);
      if (bytes == null) {
        if (mounted) setState(() => _loadingInitial = false);
        return;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _initialImage = frame.image;
    } catch (_) {
      _initialImage = null;
    }
    if (mounted) setState(() => _loadingInitial = false);
  }

  static Uint8List? _bytesFromDataUrl(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    final b64 = dataUrl.substring(comma + 1);
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  void _onPointerDown(Offset localPos) {
    setState(() {
      _current = _Stroke(
        color: _color,
        size: _size,
        points: <Offset>[localPos],
      );
    });
  }

  void _onPointerMove(Offset localPos) {
    final c = _current;
    if (c == null) return;
    setState(() {
      c.points.add(localPos);
    });
  }

  void _onPointerUp() {
    final c = _current;
    if (c != null && c.points.isNotEmpty) {
      _strokes.add(c);
    }
    setState(() {
      _current = null;
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes.removeLast();
    });
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _current = null;
    });
  }

  Future<void> _save() async {
    final boundary = _canvasKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    try {
      // Composite on white background to match GLM source behavior.
      final image = await boundary.toImage(pixelRatio: 2.0);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      canvas.drawImage(image, Offset.zero, Paint());
      final picture = recorder.endRecording();
      final composited = await picture.toImage(
        image.width,
        image.height,
      );
      final byteData = await composited.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final b64 = base64Encode(byteData.buffer.asUint8List());
      widget.onSave('data:image/png;base64,$b64');
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: t(loc, 'notes_drawing_close'),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t(loc, 'notes_drawing_title')),
        actions: [
          TextButton(
            onPressed: _strokes.isEmpty ? null : _undo,
            child: Text(t(loc, 'notes_drawing_undo')),
          ),
          IconButton(
            tooltip: t(loc, 'notes_drawing_clear'),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(t(loc, 'notes_drawing_save')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                key: _canvasKey,
                child: Container(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: _loadingInitial
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (d) =>
                                  _onPointerDown(d.localPosition),
                              onPanUpdate: (d) =>
                                  _onPointerMove(d.localPosition),
                              onPanEnd: (_) => _onPointerUp(),
                              onPanCancel: _onPointerUp,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: CustomPaint(
                                  painter: _DrawingPainter(
                                    strokes: _strokes,
                                    current: _current,
                                    initialImage: _initialImage,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            _DrawingToolbar(
              color: _color,
              size: _size,
              onColorChanged: (c) => setState(() => _color = c),
              onSizeChanged: (s) => setState(() => _size = s),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter({
    required this.strokes,
    required this.current,
    required this.initialImage,
  });

  final List<_Stroke> strokes;
  final _Stroke? current;
  final ui.Image? initialImage;

  @override
  void paint(Canvas canvas, Size size) {
    // White composite background so saved PNG is opaque.
    canvas.drawColor(Colors.white, BlendMode.src);
    if (initialImage != null) {
      canvas.drawImageRect(
        initialImage!,
        Rect.fromLTWH(
          0,
          0,
          initialImage!.width.toDouble(),
          initialImage!.height.toDouble(),
        ),
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint(),
      );
    }
    for (final s in strokes) {
      _drawStroke(canvas, s);
    }
    if (current != null) {
      _drawStroke(canvas, current!);
    }
  }

  void _drawStroke(Canvas canvas, _Stroke s) {
    if (s.points.isEmpty) return;
    final paint = Paint()
      ..color = s.color
      ..strokeWidth = s.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (s.points.length == 1) {
      canvas.drawPoints(ui.PointMode.points, s.points, paint);
      return;
    }
    final path = Path()..moveTo(s.points[0].dx, s.points[0].dy);
    for (var i = 1; i < s.points.length; i++) {
      path.lineTo(s.points[i].dx, s.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter old) =>
      !identical(old.strokes, strokes) || !identical(old.current, current);
}

class _DrawingToolbar extends StatelessWidget {
  const _DrawingToolbar({
    required this.color,
    required this.size,
    required this.onColorChanged,
    required this.onSizeChanged,
  });

  final Color color;
  final double size;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                for (final c in kDrawingColors)
                  _ColorDot(
                    color: c,
                    selected: c.value == color.value,
                    onTap: () => onColorChanged(c),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final s in kDrawingSizes)
                _SizeButton(
                  size: s,
                  selected: s == size,
                  onTap: () => onSizeChanged(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: color.value == 0xFFFFFFFF
              ? Border.all(color: scheme.outlineVariant, width: 1)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.8),
                    blurRadius: 0,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: scheme.surface,
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: size * 1.2,
          height: size * 1.2,
          decoration: BoxDecoration(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
