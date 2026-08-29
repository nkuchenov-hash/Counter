import 'package:flutter/material.dart';

/// Canonical Life OS text-selection controls.
///
/// The visual handle is intentionally much larger than the platform default,
/// with a finger-friendly hit box and a droplet silhouette. The attachment
/// point stays at the top-center so selection endpoints remain precise while
/// the visible bulb sits below the text baseline.
final TextSelectionControls lifeTextSelectionControls =
    _LifeTextSelectionControls();

class LifeSelectableText extends StatelessWidget {
  const LifeSelectableText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.textAlign,
    this.onTap,
    this.enableInteractiveSelection = true,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final VoidCallback? onTap;
  final bool enableInteractiveSelection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextSelectionTheme(
      data: TextSelectionTheme.of(context).copyWith(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: scheme.primary,
      ),
      child: SelectableText(
        data,
        style: style,
        maxLines: maxLines,
        textAlign: textAlign,
        onTap: onTap,
        enableInteractiveSelection: enableInteractiveSelection,
        selectionControls: lifeTextSelectionControls,
        contextMenuBuilder: (context, editableTextState) =>
            AdaptiveTextSelectionToolbar.editableText(
          editableTextState: editableTextState,
        ),
      ),
    );
  }
}

class _LifeTextSelectionControls extends MaterialTextSelectionControls {
  static const Size _handleSize = Size(44, 52);

  @override
  Size getHandleSize(double textLineHeight) => _handleSize;

  @override
  Offset getHandleAnchor(
    TextSelectionHandleType type,
    double textLineHeight,
  ) {
    return const Offset(_handleSize.width / 2, 2);
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: SizedBox.fromSize(
        size: _handleSize,
        child: CustomPaint(
          painter: _LifeSelectionDropPainter(color: color),
        ),
      ),
    );
  }
}

class _LifeSelectionDropPainter extends CustomPainter {
  const _LifeSelectionDropPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;

    // A narrow precision neck at the endpoint flowing into a large rounded
    // droplet. This keeps endpoint placement exact while making drag handles
    // substantially easier to grab than Android's stock controls.
    final path = Path()
      ..moveTo(cx, 2)
      ..cubicTo(cx - 2.5, 7, cx - 9, 12, cx - 10.5, 20)
      ..cubicTo(cx - 13, 32, cx - 7, 42, cx, 46)
      ..cubicTo(cx + 7, 42, cx + 13, 32, cx + 10.5, 20)
      ..cubicTo(cx + 9, 12, cx + 2.5, 7, cx, 2)
      ..close();
    canvas.drawPath(path, paint);

    // Slightly widen the bulb without changing the endpoint anchor.
    canvas.drawCircle(Offset(cx, 29), 11.5, paint);
  }

  @override
  bool shouldRepaint(covariant _LifeSelectionDropPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
