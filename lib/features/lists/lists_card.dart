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

  /// Returns a short preview of the note body for the row, stripping the
  /// `LIFEOS_LINK::` prefix and any leading URL line that backlog ideas use.
  /// Returns '' when the note is empty so the preview line is hidden.
  static String _notePreview(PlanningTask task) {
    final raw = task.notesPlain ?? '';
    var s = raw.trim();
    if (s.isEmpty) return '';
    const prefix = 'LIFEOS_LINK::';
    if (s.startsWith(prefix)) {
      s = s.substring(prefix.length).trim();
      // Drop a leading URL line (backlog idea link) — keep only the body.
      final nl = s.indexOf('\n');
      if (nl >= 0) {
        final firstLine = s.substring(0, nl).trim();
        if (firstLine.startsWith('http://') ||
            firstLine.startsWith('https://')) {
          s = s.substring(nl + 1).trim();
        }
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final listTags = _listDomainTags(task).toList();
    final catRule =
        DatabaseService.instance.getCategoryRuleById(task.categoryId);
    final catColor = catRule?.colorOrDefault ?? scheme.outline;
    final previewText = _notePreview(task);
    final titleText = task.title.trim().isEmpty
        ? t(locale, 'notes_library_untitled')
        : task.title;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.30)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onBodyTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leading category color rail — makes notes feel like notes,
              // not checkbox task rows. In selection mode we still show a
              // checkbox so multi-select stays obvious.
              if (selectionMode)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10, top: 2),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onBodyTap(),
                  ),
                )
              else
                Container(
                  width: 3,
                  margin: const EdgeInsets.only(right: 12, top: 4),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Subtle circular done toggle for non-optimistic notes.
                        // Compact, never the dominant visual.
                        if (!selectionMode &&
                            !task.planRowIdForBackend.startsWith('optimistic-'))
                          Padding(
                            padding:
                                const EdgeInsetsDirectional.only(end: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: task.isDone,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                onChanged: (v) {
                                  if (v == null) return;
                                  onToggleDone(v);
                                },
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            titleText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: (theme.textTheme.titleMedium ??
                                    const TextStyle())
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                  decoration: task.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isDone
                                      ? scheme.onSurface.withValues(alpha: 0.55)
                                      : scheme.onSurface,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (previewText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        previewText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ] else if (!task.isDone) ...[
                      const SizedBox(height: 2),
                      Text(
                        t(locale, 'notes_library_no_text'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                    if (showTagsStrip && listTags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
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
              // Subtle `...` trailing affordance — replaced the large round
              // task menu button. Compact, calm, opens the row menu.
              if (!selectionMode)
                Builder(
                  builder: (menuCtx) {
                    return IconButton(
                      tooltip: t(locale, 'notes_editor_more_tooltip'),
                      icon: const Icon(Icons.more_horiz_rounded, size: 20),
                      color: scheme.onSurfaceVariant,
                      splashRadius: 18,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      padding: EdgeInsets.zero,
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
    required this.isPinned,
    required this.isDone,
    required this.onTogglePin,
    required this.onToggleDone,
  });

  final Offset anchorCenter;
  final VoidCallback onDismiss;
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final bool isPinned;
  final bool isDone;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleDone;

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
      return math.pi + i * (math.pi / 4);
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
                  icon: widget.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  label: widget.isPinned
                      ? t(loc, 'notes_v3_editor_unpin')
                      : t(loc, 'notes_v3_editor_pin'),
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                  onTap: widget.onTogglePin,
                ),
                _labeledAction(
                  index: 3,
                  offsetFromHub: _orbitOffsetLeftArc(angleForSatellite(3)),
                  icon: widget.isDone
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  label: widget.isDone
                      ? t(loc, 'mark_incomplete')
                      : t(loc, 'mark_done'),
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurface,
                  onTap: widget.onToggleDone,
                ),
                _labeledAction(
                  index: 4,
                  offsetFromHub: _orbitOffsetLeftArc(angleForSatellite(4)),
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
