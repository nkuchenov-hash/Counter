import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/widgets/radial_menu_viewport.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Expanding semi-circle FAB menu: primary at [anchorCenter], three satellites with labels.
class SemicirclePlanningMenuOverlay extends StatefulWidget {
  const SemicirclePlanningMenuOverlay({
    required this.anchorCenter,
    required this.onDismiss,
    required this.onEdit,
    required this.onSelect,
    required this.onDelete,
  });

  final Offset anchorCenter;
  final VoidCallback onDismiss;
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  State<SemicirclePlanningMenuOverlay> createState() =>
      SemicirclePlanningMenuOverlayState();
}

class SemicirclePlanningMenuOverlayState
    extends State<SemicirclePlanningMenuOverlay>
    with SingleTickerProviderStateMixin {
  static const double _canvas = 300;

  /// Match planning card menu control (44) so the close hub covers the tap target.
  static const double _hub = 44;
  static const double _orbit = 100;
  static const double _satellite = 60;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    unawaited(_controller.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Polar offsets from hub center: standard math angle from +X (east), CCW.
  /// Flutter Y grows downward, so Y uses `-sin` for a visual CCW arc.
  /// Arc to the **left** of the hub uses angles π, 2π/3, 4π/3 (straight left, up-left, down-left).
  Offset _orbitOffsetLeftArc(double radians) {
    return Offset(math.cos(radians) * _orbit, -math.sin(radians) * _orbit);
  }

  Widget _labeledAction({
    required int index,
    required Offset offsetFromHub,
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final delayed = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        index * 0.11,
        0.65 + index * 0.12,
        curve: Curves.easeOutBack,
      ),
    );
    return Positioned(
      left: _canvas / 2 + offsetFromHub.dx - _satellite / 2,
      top: _canvas / 2 + offsetFromHub.dy - _satellite / 2 - 22,
      child: FadeTransition(
        opacity: delayed,
        child: ScaleTransition(
          scale: delayed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                elevation: 4,
                color: background,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox(
                    width: _satellite,
                    height: _satellite,
                    child: Icon(icon, color: foreground, size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;

    final canvasTopLeft = RadialMenuViewport.clampCanvasTopLeft(
      context: context,
      anchorCenter: widget.anchorCenter,
      canvasSize: _canvas,
      orbitRadius: _orbit,
      satelliteDiameter: _satellite,
    );

    final hubAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: ColoredBox(color: scheme.scrim.withValues(alpha: 0.36)),
            ),
          ),
          Positioned(
            left: canvasTopLeft.dx,
            top: canvasTopLeft.dy,
            width: _canvas,
            height: _canvas,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Left semicircle: up-left → Edit, mid-left → Select, down-left → Delete (thumb-friendly).
                _labeledAction(
                  index: 0,
                  offsetFromHub: _orbitOffsetLeftArc(2 * math.pi / 3),
                  icon: Icons.edit_rounded,
                  label: t(loc, 'plan_sheet_edit'),
                  background: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                  onTap: widget.onEdit,
                ),
                _labeledAction(
                  index: 1,
                  offsetFromHub: _orbitOffsetLeftArc(math.pi),
                  icon: Icons.checklist_rounded,
                  label: t(loc, 'plan_sheet_select'),
                  background: scheme.secondaryContainer,
                  foreground: scheme.onSecondaryContainer,
                  onTap: widget.onSelect,
                ),
                _labeledAction(
                  index: 2,
                  offsetFromHub: _orbitOffsetLeftArc(4 * math.pi / 3),
                  icon: Icons.delete_outline_rounded,
                  label: t(loc, 'plan_sheet_delete'),
                  background: scheme.errorContainer,
                  foreground: scheme.onErrorContainer,
                  onTap: widget.onDelete,
                ),
                Positioned(
                  left: _canvas / 2 - _hub / 2,
                  top: _canvas / 2 - _hub / 2,
                  child: FadeTransition(
                    opacity: hubAnim,
                    child: ScaleTransition(
                      scale: hubAnim,
                      child: Tooltip(
                        message: t(loc, 'plan_radial_close'),
                        child: Material(
                          elevation: 6,
                          color: scheme.primary,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: widget.onDismiss,
                            child: SizedBox(
                              width: _hub,
                              height: _hub,
                              child: Icon(
                                Icons.close_rounded,
                                color: scheme.onPrimary,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
