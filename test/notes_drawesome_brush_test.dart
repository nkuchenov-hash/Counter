import 'dart:ui';

import 'package:counter/features/notes/drawing/notes_drawesome_brush.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotesDrawesomeBrush', () {
    test('single point becomes a round dot at the requested nominal size', () {
      final path = NotesDrawesomeBrush.buildPenPath(
        const <Offset>[Offset(20, 30)],
        size: 8,
      );

      final bounds = path.getBounds();
      expect(bounds.center.dx, closeTo(20, 0.001));
      expect(bounds.center.dy, closeTo(30, 0.001));
      expect(bounds.width, closeTo(8, 0.001));
      expect(bounds.height, closeTo(8, 0.001));
    });

    test('freehand outline is finite and produces drawable geometry', () {
      final path = NotesDrawesomeBrush.buildPenPath(
        const <Offset>[
          Offset(0, 20),
          Offset(8, 17),
          Offset(16, 24),
          Offset(24, 15),
          Offset(32, 20),
        ],
        size: 10,
      );

      final bounds = path.getBounds();
      expect(bounds.left.isFinite, isTrue);
      expect(bounds.top.isFinite, isTrue);
      expect(bounds.right.isFinite, isTrue);
      expect(bounds.bottom.isFinite, isTrue);
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('synthetic pressure makes slower movement broader than fast movement', () {
      final slow = NotesDrawesomeBrush.buildPenPath(
        <Offset>[for (var i = 0; i < 20; i++) Offset(i.toDouble(), 20)],
        size: 12,
      );
      final fast = NotesDrawesomeBrush.buildPenPath(
        <Offset>[for (var i = 0; i < 20; i++) Offset(i * 24.0, 20)],
        size: 12,
      );

      expect(slow.getBounds().height, greaterThan(fast.getBounds().height));
    });

    test('highlighter centerline keeps short strokes usable', () {
      final path = NotesDrawesomeBrush.buildCenterlinePath(
        const <Offset>[Offset(4, 5), Offset(14, 15)],
      );

      final bounds = path.getBounds();
      expect(bounds.left, closeTo(4, 0.001));
      expect(bounds.top, closeTo(5, 0.001));
      expect(bounds.right, greaterThan(bounds.left));
      expect(bounds.bottom, greaterThan(bounds.top));
    });
  });
}
