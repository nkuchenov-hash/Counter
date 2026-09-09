// Full-screen Notes drawing editor using the canonical V3 drawing controls.
//
// Pure feature UI: accepts an optional PNG data URL and returns a PNG data URL.
// Brain/PocketBase ownership remains in the composing Notes editor.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_icon_button.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const List<NotesDrawingColorOption> kNotesDrawingColors = [
  NotesDrawingColorOption(color: Color(0xFF0F172A), label: 'Black'),
  NotesDrawingColorOption(color: Color(0xFFEF4444), label: 'Red'),
  NotesDrawingColorOption(color: Color(0xFFF59E0B), label: 'Amber'),
  NotesDrawingColorOption(color: Color(0xFF10B981), label: 'Green'),
  NotesDrawingColorOption(color: Color(0xFF06B6D4), label: 'Cyan'),
  NotesDrawingColorOption(color: Color(0xFF6366F1), label: 'Indigo'),
  NotesDrawingColorOption(color: Color(0xFFEC4899), label: 'Pink'),
  NotesDrawingColorOption(color: Color(0xFFFFFFFF), label: 'White'),
];

Future<void> showDrawingCanvas({
  required BuildContext context,
  String? initialData,
  required ValueChanged<String> onSave,
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
  final ValueChanged<String> onSave;

  @override
  State<DrawingCanvasPage> createState() => _DrawingCanvasPageState();
}

class _DrawingCanvasPageState extends State<DrawingCanvasPage> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<_DrawingStroke> _strokes = [];
  final List<List<_DrawingStroke>> _undo = [];
  final List<List<_DrawingStroke>> _redo = [];

  NotesDrawingTool _tool = NotesDrawingTool.pen;
  Color _color = kNotesDrawingColors.first.color;
  double _strokeWidth = 4;
  _DrawingStroke? _current;
  ui.Image? _initialImage;
  bool _loading = true;
  bool _saving = false;
  int? _selectedStrokeIndex;
  Offset? _lassoOrigin;
  List<Offset>? _lassoOriginalPoints;

  @override
  void initState() {
    super.initState();
    _loadInitialImage();
  }

  @override
  void dispose() {
    _initialImage?.dispose();
    super.dispose();
  }

  Future<void> _loadInitialImage() async {
    final bytes = _decodeDataUrl(widget.initialData);
    if (bytes != null) {
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _initialImage = frame.image;
        codec.dispose();
      } catch (_) {
        _initialImage = null;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _pushUndo() {
    _undo.add(_cloneStrokes(_strokes));
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
  }

  void _undoAction() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add(_cloneStrokes(_strokes));
      final previous = _undo.removeLast();
      _strokes
        ..clear()
        ..addAll(_cloneStrokes(previous));
      _current = null;
      _selectedStrokeIndex = null;
    });
  }

  void _redoAction() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add(_cloneStrokes(_strokes));
      final next = _redo.removeLast();
      _strokes
        ..clear()
        ..addAll(_cloneStrokes(next));
      _current = null;
      _selectedStrokeIndex = null;
    });
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    _pushUndo();
    setState(() {
      _strokes.clear();
      _current = null;
      _selectedStrokeIndex = null;
    });
  }

  void _onPanStart(DragStartDetails details) {
    final point = details.localPosition;
    switch (_tool) {
      case NotesDrawingTool.pen:
      case NotesDrawingTool.highlighter:
        _pushUndo();
        setState(() {
          _selectedStrokeIndex = null;
          _current = _DrawingStroke(
            kind: _tool == NotesDrawingTool.highlighter
                ? _DrawingStrokeKind.highlighter
                : _DrawingStrokeKind.pen,
            color: _color,
            width: _tool == NotesDrawingTool.highlighter
                ? (_strokeWidth * 2.5).clamp(6, 40).toDouble()
                : _strokeWidth,
            opacity: _tool == NotesDrawingTool.highlighter ? 0.32 : 1,
            points: [point],
          );
        });
        break;
      case NotesDrawingTool.eraser:
        final index = _nearestStroke(point);
        if (index == null) return;
        _pushUndo();
        setState(() {
          _strokes.removeAt(index);
          _selectedStrokeIndex = null;
        });
        break;
      case NotesDrawingTool.lasso:
        final index = _nearestStroke(point, extraTolerance: 14);
        setState(() {
          _selectedStrokeIndex = index;
          _lassoOrigin = point;
          _lassoOriginalPoints = index == null
              ? null
              : List<Offset>.from(_strokes[index].points);
        });
        if (index != null) _pushUndo();
        break;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final point = details.localPosition;
    switch (_tool) {
      case NotesDrawingTool.pen:
      case NotesDrawingTool.highlighter:
        final current = _current;
        if (current == null) return;
        setState(() => current.points.add(point));
        break;
      case NotesDrawingTool.eraser:
        final index = _nearestStroke(point);
        if (index == null) return;
        setState(() => _strokes.removeAt(index));
        break;
      case NotesDrawingTool.lasso:
        final index = _selectedStrokeIndex;
        final origin = _lassoOrigin;
        final original = _lassoOriginalPoints;
        if (index == null ||
            origin == null ||
            original == null ||
            index >= _strokes.length) {
          return;
        }
        final delta = point - origin;
        setState(() {
          _strokes[index] = _strokes[index].copyWith(
            points: [for (final source in original) source + delta],
          );
        });
        break;
    }
  }

  void _onPanEnd() {
    final current = _current;
    if (current != null && current.points.isNotEmpty) {
      _strokes.add(current);
    }
    setState(() {
      _current = null;
      _lassoOrigin = null;
      _lassoOriginalPoints = null;
    });
  }

  int? _nearestStroke(Offset point, {double extraTolerance = 0}) {
    var bestDistance = double.infinity;
    int? bestIndex;
    for (var index = _strokes.length - 1; index >= 0; index--) {
      final stroke = _strokes[index];
      final tolerance = stroke.width / 2 + 12 + extraTolerance;
      for (final candidate in stroke.points) {
        final distance = (candidate - point).distance;
        if (distance <= tolerance && distance < bestDistance) {
          bestDistance = distance;
          bestIndex = index;
        }
      }
    }
    return bestIndex;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _selectedStrokeIndex = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _canvasKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('PNG encode returned null');
      final bytes = byteData.buffer.asUint8List();
      if (bytes.lengthInBytes > kLifeOsNotesMaxAssetBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(currentLocale.value, 'notes_v3_editor_image_too_large'),
            ),
          ),
        );
        return;
      }
      widget.onSave('data:image/png;base64,${base64Encode(bytes)}');
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save drawing.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final isRu = loc == 'ru';
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: AppIconButton(
            icon: Icons.close_rounded,
            tooltip: t(loc, 'notes_drawing_close'),
            size: AppIconButtonSize.s,
            variant: AppIconButtonVariant.subtle,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(t(loc, 'notes_drawing_title')),
        actions: [
          AppButton.ghost(
            label: t(loc, 'notes_drawing_clear'),
            size: AppButtonSize.s,
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
          const SizedBox(width: 8),
          AppButton.primary(
            label: t(loc, 'notes_drawing_save'),
            icon: Icons.check_rounded,
            size: AppButtonSize.s,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                key: _canvasKey,
                child: ColoredBox(
                  color: Colors.white,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: (_) => _onPanEnd(),
                              onPanCancel: _onPanEnd,
                              child: CustomPaint(
                                size: Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                                painter: _DrawingPainter(
                                  strokes: _strokes,
                                  current: _current,
                                  initialImage: _initialImage,
                                  selectedStrokeIndex: _selectedStrokeIndex,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            NotesDrawingControls(
              selectedTool: _tool,
              onToolSelected: (tool) => setState(() => _tool = tool),
              selectedColor: _color,
              colors: kNotesDrawingColors,
              onColorSelected: (color) => setState(() => _color = color),
              strokeWidth: _strokeWidth,
              onStrokeWidthChanged: (value) =>
                  setState(() => _strokeWidth = value),
              penTooltip: isRu ? 'Перо' : 'Pen',
              highlighterTooltip: isRu ? 'Маркер' : 'Highlighter',
              eraserTooltip: isRu ? 'Ластик' : 'Eraser',
              lassoTooltip: isRu ? 'Лассо' : 'Lasso',
              undoTooltip: t(loc, 'notes_drawing_undo'),
              redoTooltip: t(loc, 'notes_tools_redo'),
              strokeWidthLabel: isRu ? 'Толщина' : 'Stroke width',
              canUndo: _undo.isNotEmpty,
              canRedo: _redo.isNotEmpty,
              onUndo: _undoAction,
              onRedo: _redoAction,
            ),
          ],
        ),
      ),
    );
  }
}

enum _DrawingStrokeKind { pen, highlighter }

class _DrawingStroke {
  _DrawingStroke({
    required this.kind,
    required this.color,
    required this.width,
    required this.opacity,
    required this.points,
  });

  final _DrawingStrokeKind kind;
  final Color color;
  final double width;
  final double opacity;
  final List<Offset> points;

  Path? _cachedPath;
  int _cachedPointCount = -1;

  Path renderPath() {
    if (_cachedPath != null && _cachedPointCount == points.length) {
      return _cachedPath!;
    }
    final path = switch (kind) {
      _DrawingStrokeKind.pen => _NotesDrawesomeBrush.buildPenPath(
          points,
          size: width,
        ),
      _DrawingStrokeKind.highlighter =>
        _NotesDrawesomeBrush.buildCenterlinePath(points),
    };
    _cachedPath = path;
    _cachedPointCount = points.length;
    return path;
  }

  _DrawingStroke copyWith({List<Offset>? points}) {
    return _DrawingStroke(
      kind: kind,
      color: color,
      width: width,
      opacity: opacity,
      points: points ?? List<Offset>.from(this.points),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  const _DrawingPainter({
    required this.strokes,
    required this.current,
    required this.initialImage,
    required this.selectedStrokeIndex,
  });

  final List<_DrawingStroke> strokes;
  final _DrawingStroke? current;
  final ui.Image? initialImage;
  final int? selectedStrokeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.src);
    final image = initialImage;
    if (image != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }
    for (var index = 0; index < strokes.length; index++) {
      final stroke = strokes[index];
      _drawStroke(canvas, stroke);
      if (selectedStrokeIndex == index) {
        final bounds = _strokeBounds(stroke);
        canvas.drawRect(
          bounds.inflate(stroke.width + 8),
          Paint()
            ..color = const Color(0xFF6366F1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    if (current != null) _drawStroke(canvas, current!);
  }

  void _drawStroke(Canvas canvas, _DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;
    final color = stroke.color.withValues(alpha: stroke.opacity);

    switch (stroke.kind) {
      case _DrawingStrokeKind.pen:
        canvas.drawPath(
          stroke.renderPath(),
          Paint()
            ..color = color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        break;
      case _DrawingStrokeKind.highlighter:
        if (stroke.points.length == 1) {
          canvas.drawCircle(
            stroke.points.first,
            stroke.width / 2,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill
              ..isAntiAlias = true,
          );
          break;
        }
        canvas.drawPath(
          stroke.renderPath(),
          Paint()
            ..color = color
            ..strokeWidth = stroke.width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke
            ..isAntiAlias = true,
        );
        break;
    }
  }

  Rect _strokeBounds(_DrawingStroke stroke) {
    var left = stroke.points.first.dx;
    var top = stroke.points.first.dy;
    var right = left;
    var bottom = top;
    for (final point in stroke.points.skip(1)) {
      left = point.dx < left ? point.dx : left;
      top = point.dy < top ? point.dy : top;
      right = point.dx > right ? point.dx : right;
      bottom = point.dy > bottom ? point.dy : bottom;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

/// Small Dart-native port of Drawesome's freehand ideas. Drawesome itself is a
/// React/TypeScript package, so embedding its runtime in Flutter would add a
/// web-only parallel editor. Notes instead keeps its existing canvas and uses
/// streamlined points, synthetic pressure/thinning, smooth outlines and round
/// caps here. Source inspiration: https://github.com/benjitaylor/drawesome (MIT).
final class _NotesDrawesomeBrush {
  const _NotesDrawesomeBrush._();

  static Path buildPenPath(
    List<Offset> rawPoints, {
    required double size,
    double streamline = 0.48,
    double thinning = 0.62,
    double smoothing = 0.62,
  }) {
    final safeSize = math.max(0.5, size).toDouble();
    final points = _streamline(
      rawPoints,
      streamline.clamp(0.0, 1.0).toDouble(),
    );
    if (points.isEmpty) return Path();
    if (points.length == 1) {
      final radius = safeSize / 2;
      return Path()
        ..addOval(Rect.fromCircle(center: points.first, radius: radius));
    }

    final radii = _pressureRadii(
      points,
      size: safeSize,
      thinning: thinning.clamp(0.0, 1.0).toDouble(),
      smoothing: smoothing.clamp(0.0, 1.0).toDouble(),
    );
    final left = <Offset>[];
    final right = <Offset>[];

    for (var i = 0; i < points.length; i++) {
      final direction = _directionAt(points, i);
      final normal = Offset(-direction.dy, direction.dx);
      final offset = normal * radii[i];
      left.add(points[i] + offset);
      right.add(points[i] - offset);
    }

    final path = Path();
    _appendSmoothSide(path, left, moveToFirst: true);

    final endDirection = _directionAt(points, points.length - 1);
    final endTip = points.last + endDirection * radii.last;
    path.quadraticBezierTo(
      endTip.dx,
      endTip.dy,
      right.last.dx,
      right.last.dy,
    );

    _appendSmoothSide(
      path,
      right.reversed.toList(growable: false),
      moveToFirst: false,
    );

    final startDirection = _directionAt(points, 0);
    final startTip = points.first - startDirection * radii.first;
    path.quadraticBezierTo(
      startTip.dx,
      startTip.dy,
      left.first.dx,
      left.first.dy,
    );
    path.close();
    return path;
  }

  static Path buildCenterlinePath(
    List<Offset> rawPoints, {
    double streamline = 0.56,
  }) {
    final points = _streamline(
      rawPoints,
      streamline.clamp(0.0, 1.0).toDouble(),
    );
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    for (var i = 1; i < points.length - 1; i++) {
      final midpoint = _midpoint(points[i], points[i + 1]);
      path.quadraticBezierTo(
        points[i].dx,
        points[i].dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  static List<Offset> _streamline(List<Offset> rawPoints, double strength) {
    if (rawPoints.isEmpty) return const <Offset>[];

    final unique = <Offset>[rawPoints.first];
    for (final point in rawPoints.skip(1)) {
      if ((point - unique.last).distance >= 0.08) unique.add(point);
    }
    if (unique.length <= 1) return unique;

    final follow = 0.18 + (1 - strength) * 0.62;
    final result = <Offset>[unique.first];
    for (final point in unique.skip(1)) {
      final previous = result.last;
      result.add(previous + (point - previous) * follow);
    }

    final last = result.last;
    result[result.length - 1] = last + (unique.last - last) * 0.45;
    return result;
  }

  static List<double> _pressureRadii(
    List<Offset> points, {
    required double size,
    required double thinning,
    required double smoothing,
  }) {
    final result = <double>[];
    var pressure = 0.68;
    final pressureFollow = 0.16 + (1 - smoothing) * 0.22;

    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        final distance = (points[i] - points[i - 1]).distance;
        final normalizedSpeed = (distance / (size * 2.4))
            .clamp(0.0, 1.0)
            .toDouble();
        final targetPressure = (1 - normalizedSpeed)
            .clamp(0.12, 1.0)
            .toDouble();
        pressure += (targetPressure - pressure) * pressureFollow;
      }

      final widthFactor = (1 + (pressure - 0.5) * 2 * thinning)
          .clamp(0.34, 1.62)
          .toDouble();
      result.add(size * 0.5 * widthFactor);
    }
    return result;
  }

  static Offset _directionAt(List<Offset> points, int index) {
    final Offset delta;
    if (index <= 0) {
      delta = points[1] - points[0];
    } else if (index >= points.length - 1) {
      delta = points.last - points[points.length - 2];
    } else {
      delta = points[index + 1] - points[index - 1];
    }

    final length = delta.distance;
    if (length <= 0.0001) return const Offset(1, 0);
    return delta / length;
  }

  static void _appendSmoothSide(
    Path path,
    List<Offset> points, {
    required bool moveToFirst,
  }) {
    if (points.isEmpty) return;
    if (moveToFirst) path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return;
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return;
    }

    for (var i = 1; i < points.length - 1; i++) {
      final midpoint = _midpoint(points[i], points[i + 1]);
      path.quadraticBezierTo(
        points[i].dx,
        points[i].dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);
  }

  static Offset _midpoint(Offset a, Offset b) =>
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
}

List<_DrawingStroke> _cloneStrokes(List<_DrawingStroke> source) {
  return [
    for (final stroke in source)
      _DrawingStroke(
        kind: stroke.kind,
        color: stroke.color,
        width: stroke.width,
        opacity: stroke.opacity,
        points: List<Offset>.from(stroke.points),
      ),
  ];
}

Uint8List? _decodeDataUrl(String? raw) {
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
