import 'package:counter/core/time/plan_time_labels.dart';
import 'package:counter/core/widgets/plan_card.dart';
import 'package:counter/data/cache/render_snapshot.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/widgets/planning_empty_states.dart';
import 'package:flutter/material.dart';

/// Read-only offscreen / frozen day plan card list (PageView neighbor pages).
class PlanningFrozenDayList extends StatelessWidget {
  const PlanningFrozenDayList({
    super.key,
    required this.tasks,
    required this.scheme,
    required this.wallDay,
    required this.activeRecordingTitleNorm,
  });

  final List<PlanningTask> tasks;
  final ColorScheme scheme;
  final DateTime wallDay;
  final String? activeRecordingTitleNorm;

  @override
  Widget build(BuildContext context) {
    DatabaseService.instance.buildPlansDayRenderSnapshot(
      wallDay,
      activeRecordingTitleNorm: activeRecordingTitleNorm,
    );
    final renderSnap =
        DatabaseService.instance.plansRenderSnapshotForDate(wallDay);
    final planActual = DatabaseService.instance
        .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);

    if (tasks.isEmpty) {
      return PlanningFrozenListEmptyState(scheme: scheme);
    }

    final cards = renderSnap?.ready == true
        ? renderSnap!.cards
        : tasks.map((task) {
            final pbId = DatabaseService.pocketRelationIdOrNull(
              task.pocketRecordId,
            );
            return PlanCardRenderDto(
              task: task,
              planTrackedSeconds: pbId != null ? (planActual[pbId] ?? 0) : 0,
              planEstimatedSeconds: planningWallEstimateSeconds(task),
              displayIsDone: task.isDone,
              showPlay: !task.isDone,
              highlightAsRunning: false,
              timeLabel: timelineTimeRangeLabel(task),
              tagsReady: true,
              categoryReady: true,
            );
          }).toList();

    return ColoredBox(
      color: scheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        physics: const ClampingScrollPhysics(),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final dto = cards[index];
          return PlanCard(
            key: ValueKey<String>(
              'plan-day-${dto.task.planRowIdForBackend}',
            ),
            task: dto.task,
            planTrackedSeconds: dto.planTrackedSeconds,
            planEstimatedSeconds: dto.planEstimatedSeconds,
            displayIsDone: dto.displayIsDone,
            selectMode: false,
            isSelected: false,
            highlightAsRunning: dto.highlightAsRunning,
            toggleDoneEnabled: false,
            onToggleDone: () {},
            onBodyTap: () {},
            onPlay: dto.showPlay ? () {} : null,
            onOpenMenu: (_) {},
          );
        },
      ),
    );
  }
}
