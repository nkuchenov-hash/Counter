// Drawesome-inspired freehand geometry for the Life OS Notes canvas.
//
// Drawesome itself is a React/TypeScript package, so Notes does not depend on
// its runtime. This is a small Dart-native brush implementation based on the
// same interaction ideas: streamlined input, synthetic pressure/thinning,
// smooth outlines, and rounded caps.
//
// Drawesome: https://github.com/benjitaylor/drawesome (MIT)

import 'dart:math' as math;
import 'dart:ui';

/// Builds smooth freehand geometry without introducing a JS/web-only runtime.
final class NotesDrawesomeBrush {
  const NotesDrawesomeBrush._();

  /// Builds a filled variable-width pen outline.
  ///
  /// [size] is the nominal stroke diameter. Faster point movement narrows the
  /// synthetic-pressure stroke while slower movement widens it. The result is
  /// deterministic from the stored points, so the Notes drawing model does not
  /// need pressure/timestamp persistence.
  static Path buildPenPath(
    List<Offset> rawPoints, {
    required double size,
    double streamline = 0.48,
    double thinning = 0.62,
    double smoothing = 0.62,
  }) {
    final safeSize = math.max(0.5, size);
    final points = _streamline(rawPoints, streamline.clamp(0.0, 1.0));
    if (points.isEmpty) return Path();
    if (points.length == 1) {
      final radius = safeSize / 2;
      return Path()..addOval(Rect.fromCircle(center: points.first, radius: radius));
    }

    final radii = _pressureRadii(
      points,
      size: safeSize,
      thinning: thinning.clamp(0.0, 1.0),
      smoothing: smoothing.clamp(0.0, 1.0),
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

    final reversedRight = right.reversed.toList(growable: false);
    _appendSmoothSide(path, reversedRight, moveToFirst: false);

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

  /// Builds a smoothed centerline for fixed-width tools such as highlighter.
  static Path buildCenterlinePath(
    List<Offset> rawPoints, {
    double streamline = 0.56,
  }) {
    final points = _streamline(rawPoints, streamline.clamp(0.0, 1.0));
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

    // Higher streamline means the rendered point follows the pointer more
    // gradually. Keep a useful lower bound so short strokes still feel direct.
    final follow = 0.18 + (1 - strength) * 0.62;
    final result = <Offset>[unique.first];
    for (final point in unique.skip(1)) {
      final previous = result.last;
      result.add(previous + (point - previous) * follow);
    }

    // Pull the final sample closer to the pointer so completed strokes end
    // where the user released, without introducing a hard unsmoothed segment.
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
        final normalizedSpeed = (distance / (size * 2.4)).clamp(0.0, 1.0);
        final targetPressure = (1 - normalizedSpeed).clamp(0.12, 1.0);
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
