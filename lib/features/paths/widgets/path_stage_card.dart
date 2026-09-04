import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/features/paths/widgets/path_edit_sheet.dart';
import 'package:counter/data/paths/path_repository.dart';
import 'package:flutter/material.dart';

typedef PathActionToggle = void Function(int actionIndex, bool done);
typedef PathActionEdit = void Function(int actionIndex);
typedef PathActionReorder = void Function(int oldIndex, int newIndex);

/// Literal Flutter port of the approved Paths Variant-2 HTML card.
///
/// Light-theme geometry, spacing, radii, shadows, typography, state tints,
/// control order, and row anatomy intentionally mirror the approved HTML.
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
    required this.onEditAction,
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
  final PathActionEdit onEditAction;
  final PathActionReorder onReorderAction;

  @override
  State<PathStageCard> createState() => _PathStageCardState();
}

class _PathStageCardState extends State<PathStageCard> {
  static const _htmlText = Color(0xFF1F2328);
  static const _htmlMuted = Color(0xFF6F7782);
  static const _htmlOutline = Color(0xFFDDE1E6);
  static const _htmlOutlineSoft = Color(0xFFE9ECEF);
  static const _htmlGreen = Color(0xFF2E9F58);
  static const _htmlAmber = Color(0xFFD89614);
  static const _htmlNeutral = Color(0xFF8C949E);

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

  bool _light(ThemeData theme) => theme.brightness == Brightness.light;

  Color _stateColor() {
    if (widget.stage.isDone) return _htmlGreen;
    if (widget.current) return _htmlAmber;
    return _htmlNeutral;
  }

  Color _headerColor(ThemeData theme) {
    final state = _stateColor();
    if (_light(theme)) {
      final alpha = widget.stage.isDone || widget.current ? .075 : .08;
      return Color.alphaBlend(state.withValues(alpha: alpha), Colors.white);
    }
    final base = theme.colorScheme.surfaceContainerLow;
    final alpha = widget.stage.isDone || widget.current ? .09 : .08;
    return Color.alphaBlend(state.withValues(alpha: alpha), base);
  }

  Color _outline(ThemeData theme) =>
      _light(theme) ? _htmlOutline : theme.colorScheme.outlineVariant;

  Color _outlineSoft(ThemeData theme) => _light(theme)
      ? _htmlOutlineSoft
      : theme.colorScheme.outlineVariant.withValues(alpha: .55);

  Color _text(ThemeData theme) =>
      _light(theme) ? _htmlText : theme.colorScheme.onSurface;

  Color _muted(ThemeData theme) =>
      _light(theme) ? _htmlMuted : theme.colorScheme.onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateColor = _stateColor();
    final doneCount = widget.stage.actions
        .where((action) => action.isDone)
        .length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: _outline(theme)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: _light(theme)
            ? const [
                BoxShadow(
                  color: Color.fromRGBO(20, 24, 28, .07),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppHoldToReorderListener(
                  index: widget.index,
                  child: _header(theme, stateColor, doneCount),
                ),
                if (_expanded) _body(theme),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(width: 4, child: ColoredBox(color: stateColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, Color stateColor, int doneCount) {
    final criteria =
        '${widget.ru ? 'Критерий завершения' : 'Completion criteria'}: '
        '${widget.stage.completionCriteria}';

    return Material(
      color: _headerColor(theme),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _outlineSoft(theme))),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth <= 760;
              final main = _StageHeaderMain(
                index: widget.index,
                title: widget.stage.title,
                criteria: criteria,
                done: widget.stage.isDone,
                current: widget.current,
                compact: compact,
                textColor: _text(theme),
                mutedColor: _muted(theme),
              );
              final side = _StageHeaderSide(
                expanded: _expanded,
                done: widget.stage.isDone,
                current: widget.current,
                doneCount: doneCount,
                totalCount: widget.stage.actions.length,
                dragHandle: widget.stageDragHandle,
                mutedColor: _muted(theme),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    main,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: side),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: main),
                  const SizedBox(width: 14),
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
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: AppReorderableList(
        itemCount: widget.stage.actions.length,
        itemKeyBuilder: (actionIndex) => ValueKey(
          'path-action-${widget.pathId}-${widget.stage.id}-'
          '${widget.stage.actions[actionIndex].id}',
        ),
        dragLabelBuilder: (actionIndex) => widget.ru
            ? 'Перетащить пункт ${actionIndex + 1}'
            : 'Reorder item ${actionIndex + 1}',
        dragHandleBuilder: (context, actionIndex) => PathOptionsButton(
          ru: widget.ru,
          tooltip: widget.ru ? 'Опции пункта' : 'Item options',
          onEdit: () => widget.onEditAction(actionIndex),
        ),
        onReorder: widget.onReorderAction,
        spacing: 0,
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
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
            AppHoldToReorderListener(
              index: actionIndex,
              child: _PathActionRow(
                action: widget.stage.actions[actionIndex],
                ru: widget.ru,
                dragHandle: actionDragHandle,
                textColor: _text(theme),
                mutedColor: _muted(theme),
                dividerColor: _outlineSoft(theme),
                onToggle: (done) => widget.onToggleAction(actionIndex, done),
                onEdit: () => widget.onEditAction(actionIndex),
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
    required this.done,
    required this.current,
    required this.compact,
    required this.textColor,
    required this.mutedColor,
  });

  final int index;
  final String title;
  final String criteria;
  final bool done;
  final bool current;
  final bool compact;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final badgeBackground = done
        ? _PathStageCardState._htmlGreen.withValues(alpha: .13)
        : current
        ? _PathStageCardState._htmlAmber.withValues(alpha: .14)
        : _PathStageCardState._htmlNeutral.withValues(alpha: .13);
    final badgeText = done ? _PathStageCardState._htmlGreen : textColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeBackground,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: badgeText,
              fontSize: 15,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: compact ? null : 1,
                overflow: compact
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: done ? _PathStageCardState._htmlGreen : textColor,
                  fontSize: 16,
                  height: 1.25,
                  letterSpacing: -.24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                criteria,
                maxLines: compact ? null : 1,
                overflow: compact
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
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
    required this.current,
    required this.doneCount,
    required this.totalCount,
    required this.dragHandle,
    required this.mutedColor,
  });

  final bool expanded;
  final bool done;
  final bool current;
  final int doneCount;
  final int totalCount;
  final Widget dragHandle;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final stateColor = done
        ? _PathStageCardState._htmlGreen
        : current
        ? _PathStageCardState._htmlAmber
        : _PathStageCardState._htmlNeutral;
    final backgroundAlpha = done
        ? .13
        : current
        ? .14
        : .12;

    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 30,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: backgroundAlpha),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${done ? '✓ ' : ''}$doneCount/$totalCount',
              style: TextStyle(
                color: stateColor,
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          dragHandle,
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 24,
              color: mutedColor,
            ),
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
    required this.textColor,
    required this.mutedColor,
    required this.dividerColor,
    required this.onToggle,
    required this.onEdit,
  });

  final PathActionSnapshot action;
  final bool ru;
  final Widget dragHandle;
  final Color textColor;
  final Color mutedColor;
  final Color dividerColor;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final checklistDone = action.checklist.where((item) => item.isDone).length;
    final hasDetails =
        action.description.isNotEmpty || action.checklist.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlanCardCheckbox(
            selectMode: false,
            isSelected: false,
            displayIsDone: action.isDone,
            toggleDoneEnabled: true,
            onToggleDone: () => onToggle(!action.isDone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.text,
                    style: TextStyle(
                      color: action.isDone ? mutedColor : textColor,
                      decoration: action.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (action.expectedResult.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${ru ? 'Результат' : 'Output'}: ${action.expectedResult}',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                  if (hasDetails) ...[
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (action.description.isNotEmpty)
                          ru ? 'есть описание' : 'description',
                        if (action.checklist.isNotEmpty)
                          '${ru ? 'чек-лист' : 'checklist'} '
                              '$checklistDone/${action.checklist.length}',
                      ].join(' · '),
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${action.minutes} ${ru ? 'мин' : 'min'}',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 4),
                dragHandle,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
