import 'dart:math' as math;

import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class PlanCardCheckbox extends StatefulWidget {
  const PlanCardCheckbox({
    required this.selectMode,
    required this.isSelected,
    required this.displayIsDone,
    required this.toggleDoneEnabled,
    this.onToggleDone,
    this.onSelectToggle,
    this.size = PlanCardGeom.controlSize,
  });

  final bool selectMode;
  final bool isSelected;
  final bool displayIsDone;
  final bool toggleDoneEnabled;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final double size;

  @override
  State<PlanCardCheckbox> createState() => PlanCardCheckboxState();
}

class PlanCardCheckboxState extends State<PlanCardCheckbox>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _checkPulseCtrl;

  @override
  void initState() {
    super.initState();
    _checkPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    if (!widget.selectMode && widget.displayIsDone) {
      _checkPulseCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant PlanCardCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selectMode &&
        !oldWidget.displayIsDone &&
        widget.displayIsDone) {
      _checkPulseCtrl.forward(from: 0);
    } else if (widget.selectMode || !widget.displayIsDone) {
      _checkPulseCtrl.value = widget.displayIsDone ? 1.0 : 0.0;
    }
  }

  @override
  void dispose() {
    _checkPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.selectMode
        ? widget.isSelected
        : widget.displayIsDone;
    final enabled = widget.selectMode
        ? widget.onSelectToggle != null
        : widget.toggleDoneEnabled && widget.onToggleDone != null;
    final scheme = Theme.of(context).colorScheme;
    final pulse = Curves.easeOut.transform(_checkPulseCtrl.value);
    final borderColor = Color.lerp(
      _hovered && enabled
          ? PlanCardTokens.playFill.withValues(alpha: 0.55)
          : PlanCardTokens.checkboxStroke,
      scheme.primary,
      checked && !widget.selectMode ? 0.35 * pulse : 0.0,
    )!;
    return Semantics(
      checked: checked,
      button: true,
      enabled: enabled,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled
              ? (widget.selectMode
                    ? widget.onSelectToggle
                    : widget.onToggleDone)
              : null,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(widget.size * 0.28),
                border: Border.all(color: borderColor),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x38000000),
                    blurRadius: 4,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: checked
                  ? Center(
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.72, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _checkPulseCtrl,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: widget.size * 0.56,
                          color: PlanCardTokens.playFill,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class PlanCardPlayButton extends StatefulWidget {
  const PlanCardPlayButton({
    this.onPlay,
    this.size = PlanCardGeom.controlSize,
  });

  final VoidCallback? onPlay;
  final double size;

  @override
  State<PlanCardPlayButton> createState() => PlanCardPlayButtonState();
}

class PlanCardPlayButtonState extends State<PlanCardPlayButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: t(currentLocale.value, 'start'),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPlay,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: CustomPaint(
                size: const Size(
                  PlanCardGeom.playIconWidth,
                  PlanCardGeom.playIconHeight,
                ),
                painter: PlanCardPlayIconPainter(
                  fill: _hovered
                      ? const Color(0xFF4A4A4A)
                      : PlanCardTokens.playFill,
                  cornerRadius: PlanCardGeom.playIconCornerRadius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlanCardPlayIconPainter extends CustomPainter {
  const PlanCardPlayIconPainter({
    this.fill = PlanCardTokens.playFill,
    this.cornerRadius = PlanCardGeom.playIconCornerRadius,
  });

  final Color fill;
  final double cornerRadius;

  static Path _roundedPlayTrianglePath(
    Size size, {
    required double cornerRadius,
  }) {
    final w = size.width;
    final h = size.height;
    final vertices = <Offset>[
      Offset(w * 0.08, h * 0.06),
      Offset(w * 0.08, h * 0.94),
      Offset(w * 0.96, h * 0.50),
    ];
    return _roundedPolygonPath(vertices, cornerRadius);
  }

  static Path _roundedPolygonPath(List<Offset> vertices, double radius) {
    final path = Path();
    final n = vertices.length;
    for (var i = 0; i < n; i++) {
      final prev = vertices[(i - 1 + n) % n];
      final curr = vertices[i];
      final next = vertices[(i + 1) % n];
      final v1 = curr - prev;
      final v2 = next - curr;
      final len1 = v1.distance;
      final len2 = v2.distance;
      if (len1 < 0.001 || len2 < 0.001) continue;
      final r = math.min(radius, math.min(len1, len2) * 0.45);
      final d1 = Offset(v1.dx / len1 * r, v1.dy / len1 * r);
      final d2 = Offset(v2.dx / len2 * r, v2.dy / len2 * r);
      final before = curr - d1;
      final after = curr + d2;
      if (i == 0) {
        path.moveTo(before.dx, before.dy);
      } else {
        path.lineTo(before.dx, before.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, after.dx, after.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _roundedPlayTrianglePath(size, cornerRadius: cornerRadius);
    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant PlanCardPlayIconPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.cornerRadius != cornerRadius;
}

/// Inline recurring marker ? circular autorenew arrows after title.
class PlanCardRecurringGlyph extends StatelessWidget {
  const PlanCardRecurringGlyph({this.displayIsDone = false});

  final bool displayIsDone;

  @override
  Widget build(BuildContext context) {
    final color = displayIsDone
        ? PlanCardTokens.breadcrumbFallbackColor.withValues(alpha: 0.45)
        : PlanCardTokens.breadcrumbFallbackColor.withValues(alpha: 0.88);
    return Icon(
      Icons.autorenew_rounded,
      size: PlanCardGeom.recurringIconSize,
      color: color,
    );
  }
}

class PlanCardMenuButton extends StatefulWidget {
  const PlanCardMenuButton({
    required this.onOpenMenu,
    this.size = PlanCardGeom.menuSize,
  });

  final void Function(BuildContext) onOpenMenu;
  final double size;

  @override
  State<PlanCardMenuButton> createState() => PlanCardMenuButtonState();
}

class PlanCardMenuButtonState extends State<PlanCardMenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (menuCtx) => Semantics(
        button: true,
        label: t(currentLocale.value, 'plan_radial_menu_tip'),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.onOpenMenu(menuCtx),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _hovered
                      ? const Color(0xFFDEDEDE)
                      : PlanCardTokens.menuBg,
                  shape: BoxShape.circle,
                ),
                child: const CustomPaint(painter: PlanCardMenuIconPainter()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlanCardMenuIconPainter extends CustomPainter {
  const PlanCardMenuIconPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PlanCardTokens.menuStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const pad = 11.0;
    final w = size.width;
    final midY1 = size.height * 0.36;
    final midY2 = size.height * 0.52;
    final midY3 = size.height * 0.68;
    canvas.drawLine(Offset(pad, midY1), Offset(w - pad - 6, midY1), paint);
    canvas.drawLine(Offset(pad, midY2), Offset(w - pad - 10, midY2), paint);
    canvas.drawLine(Offset(pad, midY3), Offset(w - pad - 6, midY3), paint);
    final bracket = Path()
      ..moveTo(w - pad - 2, midY2 + 6)
      ..lineTo(w - pad - 6, midY2)
      ..lineTo(w - pad - 2, midY2 - 6);
    canvas.drawPath(bracket, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PlanCardTitleRow extends StatelessWidget {
  const PlanCardTitleRow({
    required this.title,
    required this.displayIsDone,
    required this.hasRepeat,
    required this.maxLines,
    this.metaIcons = const [],
  });

  final String title;
  final bool displayIsDone;
  final bool hasRepeat;
  final int maxLines;
  final List<Widget> metaIcons;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: 16,
      height: 1.0,
      fontWeight: FontWeight.w400,
      leadingDistribution: TextLeadingDistribution.even,
      decoration: displayIsDone
          ? TextDecoration.lineThrough
          : TextDecoration.none,
      color: displayIsDone
          ? PlanCardTokens.titleColor.withValues(alpha: 0.55)
          : PlanCardTokens.titleColor,
    );
    return Row(
      children: [
        Flexible(
          child: Row(
            children: [
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: titleStyle,
                  child: Text(
                    title,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                  ),
                ),
              ),
              if (hasRepeat) ...[
                const SizedBox(width: PlanCardGeom.titleToRecurringGap),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: PlanCardRecurringGlyph(displayIsDone: displayIsDone),
                ),
              ],
            ],
          ),
        ),
        if (metaIcons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: metaIcons),
          ),
      ],
    );
  }
}

class PlanCardBodyTapShell extends StatelessWidget {
  const PlanCardBodyTapShell({
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (onTap == null && onLongPress == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: child,
      ),
    );
  }
}

class PlanCardControlRail extends StatelessWidget {
  const PlanCardControlRail({
    required this.showPlay,
    required this.selectMode,
    required this.isSelected,
    required this.displayIsDone,
    required this.toggleDoneEnabled,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.expandSpacer = false,
    this.controlSize = PlanCardGeom.controlSize,
  });

  final bool showPlay;
  final bool selectMode;
  final bool isSelected;
  final bool displayIsDone;
  final bool toggleDoneEnabled;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final bool expandSpacer;
  final double controlSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: controlSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlanCardCheckbox(
            selectMode: selectMode,
            isSelected: isSelected,
            displayIsDone: displayIsDone,
            toggleDoneEnabled: toggleDoneEnabled,
            onToggleDone: onToggleDone,
            onSelectToggle: onSelectToggle,
            size: controlSize,
          ),
          const SizedBox(height: PlanCardGeom.checkboxPlayGap),
          if (showPlay)
            PlanCardPlayButton(onPlay: onPlay, size: controlSize)
          else
            SizedBox(width: controlSize, height: controlSize),
          if (expandSpacer) const Spacer(),
        ],
      ),
    );
  }
}
