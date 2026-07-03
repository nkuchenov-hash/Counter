import 'package:counter/core/widgets/plan_time_task_card/plan_card_controls.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_metrics.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_sections.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';

class PlanCardProgressSlot extends StatelessWidget {
  const PlanCardProgressSlot({
    required this.planTrackedSeconds,
    required this.categoryColor,
    this.planEstimatedSeconds,
    this.spacing = PlanCardVerticalSpacing.shared,
  });

  final int planTrackedSeconds;
  final int? planEstimatedSeconds;
  final Color categoryColor;
  final PlanCardVerticalSpacing spacing;

  @override
  Widget build(BuildContext context) {
    final estimated = planEstimatedSeconds ?? 0;
    final hasActual = planTrackedSeconds > 0;
    final slotHeight = spacing.progressSlotHeight(
      hasTrackedProgress: hasActual,
    );
    return SizedBox(
      height: slotHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: spacing.actualTimeSlotHeight,
            child: hasActual
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      PlanCardProgressRow.formatCompact(planTrackedSeconds),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: PlanCardTokens.timeColor,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: spacing.progressAfterActualGap),
          PlanCardProgressRow(
            trackedSeconds: planTrackedSeconds,
            estimatedSeconds: estimated,
            categoryColor: categoryColor,
            compact: true,
            alwaysShowTrack: true,
            trackHeight: spacing.progressBarHeight,
          ),
        ],
      ),
    );
  }
}

class PlanCardInvariantBody extends StatelessWidget {
  const PlanCardInvariantBody({
    required this.task,
    required this.titleMaxLines,
    required this.visibleTags,
    required this.displayIsDone,
    required this.hasRepeat,
    required this.metaIcons,
    required this.progressSlot,
    required this.categoryTrail,
    required this.timeLabel,
    required this.scheduleConflict,
    required this.categoryColor,
    required this.spacing,
    this.anchorFooterBottom = false,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanningTask task;
  final int titleMaxLines;
  final List<Tag> visibleTags;
  final bool displayIsDone;
  final bool hasRepeat;
  final List<Widget> metaIcons;
  final PlanCardProgressSlot progressSlot;
  final String categoryTrail;
  final String timeLabel;
  final bool scheduleConflict;
  final Color categoryColor;
  final PlanCardVerticalSpacing spacing;
  final bool anchorFooterBottom;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    if (anchorFooterBottom) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final compact = h.isFinite && h < 88;
          final showTags = !compact && visibleTags.isNotEmpty;
          final showProgress = !compact;
          return PlanCardBodyTapShell(
            onTap: onBodyTap,
            onLongPress: onBodyLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: PlanCardGeom.titleRowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PlanCardTitleRow(
                          title: task.title,
                          displayIsDone: displayIsDone,
                          hasRepeat: hasRepeat,
                          maxLines: titleMaxLines,
                          metaIcons: metaIcons,
                        ),
                      ),
                      if (onOpenMenu != null)
                        PlanCardMenuButton(onOpenMenu: onOpenMenu!),
                    ],
                  ),
                ),
                if (showTags)
                  SizedBox(
                    height: spacing.tagsSlotHeight(hasTags: true),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: spacing.titleToTagsGap),
                        child: PlanCardTagsRow(tags: visibleTags),
                      ),
                    ),
                  ),
                const Spacer(),
                if (showProgress) ...[
                  progressSlot,
                  SizedBox(height: spacing.footerBlockGap),
                ],
                PlanCardFooterRow(
                  categoryTrail: compact ? '' : categoryTrail,
                  timeLabel: timeLabel,
                  scheduleConflict: scheduleConflict,
                  categoryColor: categoryColor,
                ),
              ],
            ),
          );
        },
      );
    }
    return PlanCardBodyTapShell(
      onTap: onBodyTap,
      onLongPress: onBodyLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: PlanCardGeom.titleRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PlanCardTitleRow(
                    title: task.title,
                    displayIsDone: displayIsDone,
                    hasRepeat: hasRepeat,
                    maxLines: titleMaxLines,
                    metaIcons: metaIcons,
                  ),
                ),
                if (onOpenMenu != null)
                  PlanCardMenuButton(onOpenMenu: onOpenMenu!),
              ],
            ),
          ),
          SizedBox(
            height: spacing.tagsSlotHeight(hasTags: visibleTags.isNotEmpty),
            child: Align(
              alignment: Alignment.centerLeft,
              child: visibleTags.isNotEmpty
                  ? Padding(
                      padding: EdgeInsets.only(top: spacing.titleToTagsGap),
                      child: PlanCardTagsRow(tags: visibleTags),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          SizedBox(height: PlanCardGeom.tagsToProgressGap),
          progressSlot,
          SizedBox(height: spacing.footerBlockGap),
          PlanCardFooterRow(
            categoryTrail: categoryTrail,
            timeLabel: timeLabel,
            scheduleConflict: scheduleConflict,
            categoryColor: categoryColor,
          ),
        ],
      ),
    );
  }
}

class PlanCardRailShell extends StatelessWidget {
  const PlanCardRailShell({
    required this.showPlay,
    required this.selectMode,
    required this.isSelected,
    required this.displayIsDone,
    required this.toggleDoneEnabled,
    required this.spacing,
    required this.body,
    this.fillHeight = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
  });

  final bool showPlay;
  final bool selectMode;
  final bool isSelected;
  final bool displayIsDone;
  final bool toggleDoneEnabled;
  final PlanCardVerticalSpacing spacing;
  final Widget body;
  final bool fillHeight;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        PlanCardGeom.padLeft,
        spacing.padTop,
        PlanCardGeom.padRight,
        spacing.padBottom,
      ),
      child: Row(
        crossAxisAlignment: fillHeight
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          PlanCardControlRail(
            showPlay: showPlay,
            selectMode: selectMode,
            isSelected: isSelected,
            displayIsDone: displayIsDone,
            toggleDoneEnabled: toggleDoneEnabled,
            onToggleDone: onToggleDone,
            onSelectToggle: onSelectToggle,
            onPlay: onPlay,
          ),
          const SizedBox(width: PlanCardGeom.railToContentGap),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class PlanCardProgressRow extends StatelessWidget {
  const PlanCardProgressRow({
    required this.trackedSeconds,
    required this.estimatedSeconds,
    required this.categoryColor,
    this.compact = false,
    this.alwaysShowTrack = false,
    this.trackHeight = 2,
  });

  final int trackedSeconds;
  final int estimatedSeconds;
  final Color categoryColor;
  final bool compact;
  final bool alwaysShowTrack;
  final double trackHeight;

  static String formatTracked(int sec) {
    final s = sec.clamp(0, 8640000);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String formatCompact(int sec) {
    final s = sec.clamp(0, 8640000);
    if (s < 60) return '${s}s';
    if (s < 3600) return '${(s / 60).round()}m';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final pct = estimatedSeconds > 0
        ? ((trackedSeconds * 100) / estimatedSeconds).round()
        : 0;
    final over = estimatedSeconds > 0 && trackedSeconds > estimatedSeconds;
    final accent = categoryColor.a > 0
        ? categoryColor
        : PlanCardTokens.breadcrumbFallbackColor;
    final showFill = estimatedSeconds > 0;
    final fraction = showFill
        ? (trackedSeconds <= estimatedSeconds
              ? trackedSeconds / estimatedSeconds
              : 1.0)
        : 0.0;
    final trackRadius = BorderRadius.circular(trackHeight / 2);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: trackHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x61D9D9D9),
                    borderRadius: trackRadius,
                  ),
                ),
                if (showFill || alwaysShowTrack)
                  FractionallySizedBox(
                    widthFactor: showFill ? fraction.clamp(0.0, 1.0) : 0.0,
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: over
                            ? Theme.of(context).colorScheme.error
                            : accent,
                        borderRadius: trackRadius,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          Text(
            '${formatCompact(trackedSeconds)} / ${formatCompact(estimatedSeconds)} ($pct%)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              color: over
                  ? Theme.of(context).colorScheme.error
                  : PlanCardTokens.timeColor,
            ),
          ),
        ],
      ],
    );
  }
}

