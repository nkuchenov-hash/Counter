import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/data/paths/path_repository.dart';
import 'package:flutter/material.dart';

typedef PathActionToggle = void Function(int actionIndex, bool done);
typedef PathActionReorder = void Function(int oldIndex, int newIndex);

/// Variant-2 Path stage surface.
///
/// Structure is intentionally explicit rather than based on [ExpansionTile]:
/// drag handle at the far left, number/title + completion criteria in the
/// center, progress + chevron at the right, then a quieter action body.
class PathStageCard extends StatefulWidget {
  const PathStageCard({
    super.key,
    required this.pathId,
    required this.stage,
    required this.index,
    required this.current,
    required this.ru,
    required this.stageDragHandle,
    required this.onAddAction,
    required this.onToggleAction,
    required this.onReorderAction,
  });

  final String pathId;
  final PathStageSnapshot stage;
  final int index;
  final bool current;
  final bool ru;
  final Widget stageDragHandle;
  final VoidCallback onAddAction;
  final PathActionToggle onToggleAction;
  final PathActionReorder onReorderAction;

  @override
  State<PathStageCard> createState() => _PathStageCardState();
}

class _PathStageCardState extends State<PathStageCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.stage.isDone;
  }

  @override
  void didUpdateWidget(covariant PathStageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.stage.isDone && widget.stage.isDone) {
      _expanded = false;
    } else if (oldWidget.stage.isDone && !widget.stage.isDone) {
      _expanded = true;
    }
  }

  Color _accent(ColorScheme scheme) {
    if (widget.stage.isDone) return Colors.green.shade600;
    if (widget.current) return Colors.amber.shade700;
    return scheme.primary;
  }

  Color _headerColor(ThemeData theme, Color accent) {
    final scheme = theme.colorScheme;
    final base = theme.brightness == Brightness.dark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLow;
    final tint = widget.stage.isDone || widget.current ? .045 : .018;
    return Color.alphaBlend(accent.withValues(alpha: tint), base);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _accent(scheme);
    final doneCount = widget.stage.actions.where((action) => action.isDone).length;
    final shadow = theme.brightness == Brightness.dark
        ? const <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: .035),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(theme, accent, doneCount),
                if (_expanded) _body(theme),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(width: 4, child: ColoredBox(color: accent)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, Color accent, int doneCount) {
    final scheme = theme.colorScheme;
    final criteria = '${widget.ru ? 'Критерий завершения' : 'Completion criteria'}: '
        '${widget.stage.completionCriteria}';

    return Material(
      color: _headerColor(theme, accent),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 17),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final main = _StageHeaderMain(
                index: widget.index,
                title: widget.stage.title,
                criteria: criteria,
                accent: accent,
                done: widget.stage.isDone,
              );
              final side = _StageHeaderSide(
                expanded: _expanded,
                done: widget.stage.isDone,
                doneCount: doneCount,
                totalCount: widget.stage.actions.length,
                accent: accent,
              );

              if (compact) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.stageDragHandle,
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          main,
                          const SizedBox(height: 10),
                          Align(alignment: Alignment.centerLeft, child: side),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.stageDragHandle,
                  const SizedBox(width: 8),
                  Expanded(child: main),
                  const SizedBox(width: 16),
                  side,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 14, 10),
        child: AppReorderableList(
          itemCount: widget.stage.actions.length,
          itemKeyBuilder: (actionIndex) => ValueKey(
            'path-action-${widget.pathId}-${widget.stage.id}-'
            '${widget.stage.actions[actionIndex].id}',
          ),
          dragLabelBuilder: (actionIndex) => widget.ru
              ? 'Перетащить пункт ${actionIndex + 1}'
              : 'Reorder item ${actionIndex + 1}',
          onReorder: widget.onReorderAction,
          spacing: 0,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          footer: Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppButton.ghost(
                label: widget.ru ? 'Добавить пункт' : 'Add item',
                icon: Icons.add_rounded,
                size: AppButtonSize.s,
                onPressed: widget.onAddAction,
              ),
            ),
          ),
          itemBuilder: (context, actionIndex, actionDragHandle) =>
              _PathActionRow(
                action: widget.stage.actions[actionIndex],
                ru: widget.ru,
                dragHandle: actionDragHandle,
                onToggle: (done) => widget.onToggleAction(actionIndex, done),
              ),
        ),
      ),
    );
  }
}

class _StageHeaderMain extends StatelessWidget {
  const _StageHeaderMain({
    required this.index,
    required this.title,
    required this.criteria,
    required this.accent,
    required this.done,
  });

  final int index;
  final String title;
  final String criteria;
  final Color accent;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .13),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: done ? Colors.green.shade700 : scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsets.only(left: 46),
          child: Text(
            criteria,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _StageHeaderSide extends StatelessWidget {
  const _StageHeaderSide({
    required this.expanded,
    required this.done,
    required this.doneCount,
    required this.totalCount,
    required this.accent,
  });

  final bool expanded;
  final bool done;
  final int doneCount;
  final int totalCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${done ? '✓ ' : ''}$doneCount/$totalCount',
              style: theme.textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            size: 24,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _PathActionRow extends StatelessWidget {
  const _PathActionRow({
    required this.action,
    required this.ru,
    required this.dragHandle,
    required this.onToggle,
  });

  final PathActionSnapshot action;
  final bool ru;
  final Widget dragHandle;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 14, 0, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: PlanCardCheckbox(
              selectMode: false,
              isSelected: false,
              displayIsDone: action.isDone,
              toggleDoneEnabled: true,
              onToggleDone: () => onToggle(!action.isDone),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: action.isDone
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    decoration:
                        action.isDone ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w400,
                    height: 1.42,
                  ),
                ),
                if (action.expectedResult.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${ru ? 'Результат' : 'Output'}: ${action.expectedResult}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.42,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${action.minutes} ${ru ? 'мин' : 'min'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 2),
                dragHandle,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
