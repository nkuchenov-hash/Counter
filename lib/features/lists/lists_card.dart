import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/tag_contrast.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/core/widgets/radial_menu_viewport.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fast filter chip: rounded rect (~8px), horizontal scroll row.
/// Fill and border use the category’s [categoryColor] (from [CategoryRule.colorValue]).
class ListsQuadraticChip extends StatelessWidget {
  const ListsQuadraticChip({
    required this.label,
    required this.categoryColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color categoryColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = categoryColor;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.42)
                : base.withValues(alpha: 0.22),
            border: Border.all(
              color: selected ? scheme.primary : base,
              width: selected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip bar: strict raw [CategoryRule.name] only (no breadcrumb path).
String categoryRawName(int categoryId) {
  final r = DatabaseService.instance.getCategoryRuleById(categoryId);
  if (r == null) return '—';
  final n = r.name.trim();
  return n.isEmpty ? '—' : n;
}

Color listsCategoryAccentColor(int categoryId) {
  final r = DatabaseService.instance.getCategoryRuleById(categoryId);
  return r?.colorOrDefault ?? Colors.grey;
}

class BacklogPlanCard extends StatelessWidget {
  const BacklogPlanCard({
    required this.task,
    required this.locale,
    required this.showTagsStrip,
    required this.selectionMode,
    required this.isSelected,
    required this.onBodyTap,
    required this.onToggleDone,
    required this.onDelete,
    required this.onOpenMenu,
    this.onLongPress,
  });

  final PlanningTask task;
  final String locale;
  final bool showTagsStrip;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onBodyTap;
  final void Function(bool toDone) onToggleDone;
  final VoidCallback onDelete;
  final void Function(BuildContext anchorContext) onOpenMenu;

  /// Optional long-press handler (e.g. open the row's radial `...` menu).
  /// When null, long-press is a no-op.
  final VoidCallback? onLongPress;

  static Iterable<Tag> _listDomainTags(PlanningTask task) sync* {
    for (final tag in task.tags) {
      if (!tag.rendersAsChip) continue;
      if (TagCatalogScope.list.matchesTag(tag)) yield tag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final listTags = _listDomainTags(task).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: InkWell(
        onTap: onBodyTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              selectionMode
                  ? Checkbox(value: isSelected, onChanged: (_) => onBodyTap())
                  : Checkbox(
                      value: task.isDone,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged:
                          task.planRowIdForBackend.startsWith('optimistic-')
                          ? null
                          : (v) {
                              if (v == null) return;
                              onToggleDone(v);
                            },
                    ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: task.isDone
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      if (showTagsStrip && listTags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: StreamBuilder<UserSettings>(
                            stream: DatabaseService.instance.userSettingsStream,
                            initialData: DatabaseService.instance.settings,
                            builder: (context, snap) {
                              final mode =
                                  snap.data?.tagDisplayMode ??
                                  CategoryDisplayMode.letterChip;
                              final sch = Theme.of(context).colorScheme;
                              return Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final tag in listTags)
                                    CategoryChip(
                                      mode: mode,
                                      label: tag.name.trim().isNotEmpty
                                          ? tag.name.trim()
                                          : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}',
                                      color:
                                          parseTagHexColor(tag.color) ??
                                          sch.primary,
                                      icon: iconForTagKey(tag.icon),
                                      compactGlyphLayout: true,
                                      syntheticNoTagsMonochrome:
                                          tag.tagId == -1,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!selectionMode)
                Builder(
                  builder: (menuCtx) {
                    return IconButton(
                      tooltip: t(locale, 'plan_radial_menu_tip'),
                      style: IconButton.styleFrom(
                        splashFactory: NoSplash.splashFactory,
                        hoverColor: Colors.transparent,
                        backgroundColor: scheme.secondaryContainer.withValues(
                          alpha: 0.92,
                        ),
                        foregroundColor: scheme.onSecondaryContainer,
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.menu_open_rounded, size: 24),
                      onPressed: () => onOpenMenu(menuCtx),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Semi-circle satellite menu for list/backlog cards (no Start — lists are not time-bound).
class ListsSemicircleMenuOverlay extends StatefulWidget {
  const ListsSemicircleMenuOverlay({
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
  State<ListsSemicircleMenuOverlay> createState() =>
      ListsSemicircleMenuOverlayState();
}

class ListsSemicircleMenuOverlayState
    extends State<ListsSemicircleMenuOverlay>
    with SingleTickerProviderStateMixin {
  static const double _canvas = 300;
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
        index * 0.09,
        0.62 + index * 0.1,
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

    double angleForSatellite(int i) {
      return math.pi + i * (math.pi / 3);
    }

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
                _labeledAction(
                  index: 0,
                  offsetFromHub: _orbitOffsetLeftArc(angleForSatellite(0)),
                  icon: Icons.edit_rounded,
                  label: t(loc, 'lists_menu_change'),
                  background: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                  onTap: widget.onEdit,
                ),
                _labeledAction(
                  index: 1,
                  offsetFromHub: _orbitOffsetLeftArc(angleForSatellite(1)),
                  icon: Icons.checklist_rounded,
                  label: t(loc, 'lists_menu_choose'),
                  background: scheme.secondaryContainer,
                  foreground: scheme.onSecondaryContainer,
                  onTap: widget.onSelect,
                ),
                _labeledAction(
                  index: 2,
                  offsetFromHub: _orbitOffsetLeftArc(angleForSatellite(2)),
                  icon: Icons.delete_outline_rounded,
                  label: t(loc, 'delete'),
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
