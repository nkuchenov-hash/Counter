import 'dart:async';

import 'package:counter/data/models.dart';
import 'package:counter/features/calendar/calendar_drag_and_reschedule.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/features/calendar/calendar_week_grouping.dart';
import 'package:counter/features/calendar/calendar_day_events.dart';
import 'package:counter/features/calendar/calendar_helpers.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Week browsing grid — real time grid with hourly rows and positioned events.
class CalendarWeekPlannerGrid extends StatelessWidget {
  const CalendarWeekPlannerGrid({
    super.key,
    required this.weekStart,
    required this.today,
    required this.tasksByDay,
    required this.loading,
    required this.showEventPills,
    required this.onDayTap,
    required this.onTaskTap,
    required this.onSlotTap,
    required this.onGroupTap,
    required this.onPlanDrop,
  });

  final DateTime weekStart;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final bool loading;
  final bool showEventPills;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<PlanningTask> onTaskTap;
  final ValueChanged<DateTime> onSlotTap;
  final void Function(DateTime day, String categoryName, List<PlanningTask> tasks) onGroupTap;
  final Future<void> Function(List<PlanningTask>, DateTime) onPlanDrop;

  static const double _hourHeight = 64;
  static const double _timeGutter = 44;
  static const double _headerHeight = 52;

  double _topFor(DateTime time) =>
      (time.hour * 60 + time.minute) / 60 * _hourHeight;

  /// Group siblings under their closest shared category branch; retain an
  /// intermediate branch when the hierarchy has a broad top-level category.
  int _groupCategory(int categoryId) {
    final db = DatabaseService.instance;
    var current = categoryId;
    var parent = db.getParentId(current);
    if (parent == null) return current;
    final visited = <int>{categoryId};
    while (parent != null && visited.add(parent)) {
      final grandparent = db.getParentId(parent);
      if (grandparent == null) {
        return current == categoryId ? parent : current;
      }
      current = parent;
      parent = grandparent;
    }
    return current;
  }

  static String _hhmm(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  static double _blockHeight(CalendarWeekBlock block) {
    final minutes = block.end.difference(block.start).inMinutes.clamp(20, 24 * 60);
    return (minutes / 60 * _hourHeight).clamp(28.0, 24 * _hourHeight).toDouble();
  }

  /// A small localized hover summary; click opens full interactive task cards.
  String _tooltip(CalendarWeekBlock block, String categoryName) {
    return [
      categoryName,
      for (final task in block.tasks) '${_hhmm(task.startTime!)}  ${task.title}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final scrollController = ScrollController(
      initialScrollOffset: 7 * _hourHeight,
    );

    return Stack(
      children: [
        Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  const SizedBox(width: _timeGutter),
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final day = weekStart.add(Duration(days: i));
                          final isToday =
                              day.year == today.year &&
                              day.month == today.month &&
                              day.day == today.day;
                          return InkWell(
                            onTap: () => onDayTap(day),
                            borderRadius: BorderRadius.circular(14),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat.E(loc).format(day),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: isToday
                                      ? BoxDecoration(
                                          color: scheme.onSurface,
                                          shape: BoxShape.circle,
                                        )
                                      : null,
                                  child: Text(
                                    '${day.day}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isToday
                                              ? scheme.surface
                                              : scheme.onSurface,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: SizedBox(
                  height: 24 * _hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: _timeGutter,
                        child: Stack(
                          children: [
                            for (var hour = 0; hour < 24; hour++)
                              Positioned(
                                top: hour * _hourHeight - 7,
                                right: 6,
                                child: Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.72),
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            for (var hour = 0; hour <= 24; hour++)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: hour * _hourHeight,
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.42,
                                  ),
                                ),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < 7; i++)
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final day = weekStart.add(
                                          Duration(days: i),
                                        );
                                        final tasks = (tasksByDay[calendarDayKey(day)] ??
                                                const <PlanningTask>[])
                                            .where((task) => task.startTime != null)
                                            .toList();
                                        final blocks = buildCalendarWeekBlocks(tasks, _groupCategory);
                                        return DragTarget<CalendarDragPayload>(
                                          onWillAcceptWithDetails: (details) => details.data.canMove,
                                          onAcceptWithDetails: (details) {
                                            final box = context.findRenderObject() as RenderBox?;
                                            if (box == null) return;
                                            final local = box.globalToLocal(details.offset);
                                            final minutes = ((local.dy / _hourHeight * 60) / 10).round() * 10;
                                            final snapped = minutes.clamp(0, 23 * 60 + 50);
                                            unawaited(onPlanDrop(
                                              details.data.tasks,
                                              DateTime(day.year, day.month, day.day,
                                                  snapped ~/ 60, snapped % 60),
                                            ));
                                          },
                                          builder: (context, candidates, rejected) => DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: candidates.isNotEmpty
                                                ? scheme.primary.withValues(alpha: 0.10)
                                                : Colors.transparent,
                                            border: Border(
                                              left: BorderSide(
                                                color: scheme.outlineVariant.withValues(alpha: 0.34),
                                              ),
                                            ),
                                          ),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              final placements = layoutCalendarWeekBlocks(blocks);
                                              return Stack(
                                                clipBehavior: Clip.hardEdge,
                                                children: [
                                                  Positioned.fill(
                                                    child: GestureDetector(
                                                      behavior: HitTestBehavior.opaque,
                                                      onTapUp: (details) {
                                                        final minutes = ((details.localPosition.dy /
                                                                _hourHeight * 60) ~/ 10 * 10)
                                                            .clamp(0, 23 * 60 + 50).toInt();
                                                        onSlotTap(DateTime(day.year, day.month, day.day,
                                                            minutes ~/ 60, minutes % 60));
                                                      },
                                                    ),
                                                  ),
                                                  for (final placement in placements)
                                                    Positioned(
                                                      top: _topFor(placement.block.start),
                                                      left: constraints.maxWidth * placement.lane / placement.laneCount + 2,
                                                      width: (constraints.maxWidth / placement.laneCount - 4).clamp(1.0, double.infinity).toDouble(),
                                                      height: _blockHeight(placement.block),
                                                      child: Builder(
                                                        builder: (context) {
                                                          final block = placement.block;
                                                          final grouped = block.tasks.length > 1;
                                                          final name = grouped
                                                              ? (DatabaseService.instance.getCategoryRuleById(block.groupCategoryId)?.name ??
                                                                  t(loc, 'plan'))
                                                              : block.tasks.first.title;
                                                          final color = DatabaseService.instance
                                                              .getCategoryColor(block.groupCategoryId);
                                                          final timeLabel = grouped
                                                              ? '${_hhmm(block.start)}–${_hhmm(block.end)}'
                                                              : _hhmm(block.start);
                                                          final card = Tooltip(
                                                            waitDuration: const Duration(milliseconds: 400),
                                                            message: _tooltip(block, name),
                                                            child: Material(
                                                              color: color.withValues(alpha: 0.17),
                                                              borderRadius: BorderRadius.circular(7),
                                                              clipBehavior: Clip.antiAlias,
                                                              child: InkWell(
                                                                onTap: grouped
                                                                    ? () => onGroupTap(day, name, List.unmodifiable(block.tasks))
                                                                    : () => onTaskTap(block.tasks.single),
                                                                child: Container(
                                                                  decoration: BoxDecoration(
                                                                    border: Border(left: BorderSide(color: color, width: 3)),
                                                                  ),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                                                  child: LayoutBuilder(
                                                                    builder: (context, cardConstraints) {
                                                                      final compact = cardConstraints.maxWidth < 90;
                                                                      return Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          Text(
                                                                            timeLabel,
                                                                            maxLines: 1,
                                                                            overflow: TextOverflow.ellipsis,
                                                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                                              fontSize: 11,
                                                                              fontWeight: FontWeight.w800,
                                                                              color: scheme.onSurface,
                                                                              height: 1.05,
                                                                            ),
                                                                          ),
                                                                          if (!compact && cardConstraints.maxHeight >= 25)
                                                                            Text(
                                                                              name,
                                                                              maxLines: 2,
                                                                              overflow: TextOverflow.ellipsis,
                                                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                                                fontSize: 11,
                                                                                fontWeight: FontWeight.w600,
                                                                                color: scheme.onSurface,
                                                                                height: 1.05,
                                                                              ),
                                                                            ),
                                                                          if (grouped && cardConstraints.maxHeight >= 44)
                                                                            Text(
                                                                              '${block.tasks.length} × ${t(loc, 'plan')}',
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.ellipsis,
                                                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                                                fontSize: 10,
                                                                                color: scheme.onSurfaceVariant,
                                                                              ),
                                                                            ),
                                                                        ],
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                          return CalendarPlanDraggable(
                                                            tasks: block.tasks,
                                                            child: card,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (loading)
          Positioned(
            top: 4,
            right: 4,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact week strip shown when a day is focused.
class CalendarWeekCompactStrip extends StatelessWidget {
  const CalendarWeekCompactStrip({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.today,
    required this.tasksByDay,
    required this.onDayTap,
    this.minimal = false,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final DateTime today;
  final Map<String, List<PlanningTask>> tasksByDay;
  final ValueChanged<DateTime> onDayTap;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final day = weekStart.add(Duration(days: i));
                final key = calendarDayKey(day);
                final tasks = tasksByDay[key] ?? const <PlanningTask>[];
                final selected =
                    day.year == selectedDay.year &&
                    day.month == selectedDay.month &&
                    day.day == selectedDay.day;
                final isToday =
                    day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;

                if (minimal) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: selected
                          ? scheme.primaryContainer.withValues(alpha: 0.65)
                          : isToday
                          ? scheme.surfaceContainerLow.withValues(alpha: 0.5)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: selected
                            ? BorderSide(color: scheme.primary, width: 1.5)
                            : isToday
                            ? BorderSide(
                                color: scheme.primary.withValues(alpha: 0.45),
                              )
                            : BorderSide.none,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onDayTap(day),
                        borderRadius: BorderRadius.circular(10),
                        child: Center(
                          child: Text(
                            '${DateFormat.E(loc).format(day)} ${day.day}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: isToday && !selected
                        ? scheme.surfaceContainerLow.withValues(alpha: 0.5)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: isToday && !selected
                          ? BorderSide(
                              color: scheme.primary.withValues(alpha: 0.45),
                            )
                          : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onDayTap(day),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat.E(loc).format(day),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: selected
                                  ? BoxDecoration(
                                      color: scheme.primaryContainer.withValues(
                                        alpha: 0.65,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: scheme.primary,
                                        width: 1.5,
                                      ),
                                    )
                                  : null,
                              child: Text(
                                '${day.day}',
                                maxLines: 1,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 4),
                            CalendarDayEventList(
                              tasks: tasks
                                  .where((t) => t.startTime != null)
                                  .toList(),
                              loc: loc,
                              showPills: false,
                              maxVisible: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
