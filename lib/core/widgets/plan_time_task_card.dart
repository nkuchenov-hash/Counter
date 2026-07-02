// ---------------------------------------------------------------------------
// PlanTimeTaskCard ? CardPlan_Small / CardPlan_Medium / CardPlan_Large
// Geometry source: Figma MCP metadata (328px ref). Visual tokens: design/*.svg
// ---------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:counter/core/performance/rebuild_metrics.dart';
import 'package:counter/core/plan_category_lookup.dart';
import 'package:counter/data/models.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

import 'plan_card/plan_card_metrics.dart';
import 'plan_card/plan_time_card_density.dart';

import 'plan_card/plan_card_controls.dart';
import 'plan_card/plan_card_geometry.dart';
import 'plan_card/plan_card_sections.dart';

export 'plan_card/plan_card_metrics.dart';
export 'plan_card/plan_time_card_density.dart';

/// CardPlan-style unified plan task card (list, timeline, calendar).
class PlanTimeTaskCard extends StatefulWidget {
  const PlanTimeTaskCard({
    super.key,
    required this.task,
    required this.density,
    required this.timeLabel,
    this.surface = PlanCardSurface.timeline,
    this.timelineVisualDensity,
    this.timelineBlockHeightPx,
    this.displayIsDone = false,
    this.selectMode = false,
    this.isSelected = false,
    this.highlightAsRunning = false,
    this.interacting = false,
    this.toggleDoneEnabled = true,
    this.planTrackedSeconds = 0,
    this.planEstimatedSeconds,
    this.scheduleConflict = false,
    this.metaIcons = const [],
    this.showFooterBreadcrumb = true,
    this.showProgressBar = true,
    this.timelineFillHeight = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onTap,
    this.onLongPress,
  });

  final PlanningTask task;
  final PlanTimeTaskCardDensity density;
  final PlanCardSurface surface;

  /// Time View CardPlan band from rendered block height (explicit layout path).
  final PlanTimeCardVisualDensity? timelineVisualDensity;
  final double? timelineBlockHeightPx;
  final String timeLabel;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool highlightAsRunning;
  final bool interacting;
  final bool toggleDoneEnabled;
  final int planTrackedSeconds;
  final int? planEstimatedSeconds;
  final bool scheduleConflict;
  final List<Widget> metaIcons;
  final bool showFooterBreadcrumb;
  final bool showProgressBar;

  /// When true (Time mode duration blocks), card fills parent height and pins
  /// progress + footer to the bottom edge.
  final bool timelineFillHeight;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext menuContext)? onOpenMenu;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PlanTimeTaskCard> createState() => _PlanTimeTaskCardState();
}

class _PlanTimeTaskCardState extends State<PlanTimeTaskCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _completionCtrl;

  @override
  void initState() {
    super.initState();
    _completionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    if (widget.displayIsDone) {
      _completionCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant PlanTimeTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.displayIsDone && widget.displayIsDone) {
      _completionCtrl.forward(from: 0);
    } else if (oldWidget.displayIsDone && !widget.displayIsDone) {
      _completionCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _completionCtrl.dispose();
    super.dispose();
  }

  bool get _hasRepeat =>
      (widget.task.rrule?.trim().isNotEmpty ?? false) ||
      (widget.task.recurrenceInstanceDateKey?.trim().isNotEmpty ?? false);

  bool get _showPlay =>
      !widget.selectMode && !widget.displayIsDone && widget.onPlay != null;

  List<Tag> get _visibleTags =>
      widget.task.tags.where((t) => t.rendersAsChip).toList(growable: false);

  bool get _isListLike =>
      widget.surface == PlanCardSurface.list ||
      widget.surface == PlanCardSurface.calendar ||
      (widget.surface == PlanCardSurface.timeline &&
          widget.timelineVisualDensity == null &&
          !widget.timelineFillHeight);

  @override
  Widget build(BuildContext context) {
    rebuildMetricsTick('PlanTimeTaskCard');
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final lookup = PlanCategoryLookup.resolve;
    final categoryPresentation = lookup?.call(widget.task.categoryId);
    final categoryTone =
        categoryPresentation?.color ?? Theme.of(context).colorScheme.primary;
    final categoryTrailRaw = widget.showFooterBreadcrumb
        ? localizeCategoryBreadcrumbPath(
            (categoryPresentation?.breadcrumbPath ?? '').trim(),
            loc,
          ).trim()
        : '';
    final categoryTrail = categoryTrailRaw;
    final categoryIcon = categoryPresentation?.icon;
    final effectiveTimeLabel = widget.timeLabel.trim().isNotEmpty
        ? widget.timeLabel.trim()
        : _planCardWallTimeLabel(widget.task);

    final hovered = _hovered && !widget.interacting;
    final selected = widget.selectMode && widget.isSelected;
    final borderColor = selected
        ? scheme.primary.withValues(alpha: 0.52)
        : widget.highlightAsRunning
        ? scheme.primary
        : widget.interacting
        ? scheme.primary.withValues(alpha: 0.45)
        : hovered
        ? scheme.outlineVariant.withValues(alpha: 0.62)
        : scheme.outlineVariant.withValues(alpha: 0.38);
    final borderWidth = selected
        ? 1.25
        : widget.highlightAsRunning
        ? 1.75
        : widget.interacting
        ? 1.5
        : hovered
        ? 1.25
        : 1.0;

    var surface = selected
        ? Color.alphaBlend(
            scheme.primaryContainer.withValues(alpha: 0.16),
            PlanCardTokens.surface,
          )
        : PlanCardTokens.surface;
    if (hovered) {
      surface = Color.alphaBlend(
        scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        surface,
      );
    }

    final effectiveDensity = widget.density;
    final useInvariantSlots =
        (effectiveDensity == PlanTimeTaskCardDensity.medium ||
            effectiveDensity == PlanTimeTaskCardDensity.large) &&
        widget.showProgressBar;
    const cardSpacing = PlanCardVerticalSpacing.shared;
    final progressSlot = useInvariantSlots
        ? PlanCardProgressSlot(
            planTrackedSeconds: widget.planTrackedSeconds,
            planEstimatedSeconds: widget.planEstimatedSeconds,
            categoryColor: categoryTone,
            spacing: cardSpacing,
          )
        : null;

    Widget body;
    if (widget.surface == PlanCardSurface.timeline &&
        widget.timelineVisualDensity != null) {
      body = _TimeViewDensityBody(
        visual: widget.timelineVisualDensity!,
        heightPx: widget.timelineBlockHeightPx ?? kPlanTimeCardMinHeightPx,
        task: widget.task,
        timeLabel: effectiveTimeLabel,
        categoryTrail: widget.showFooterBreadcrumb ? categoryTrail : '',
        categoryColor: categoryTone,
        displayIsDone: widget.displayIsDone,
        selectMode: widget.selectMode,
        isSelected: widget.isSelected,
        hasRepeat: _hasRepeat,
        showPlay: _showPlay,
        visibleTags: _visibleTags,
        scheduleConflict: widget.scheduleConflict,
        toggleDoneEnabled: widget.toggleDoneEnabled,
        metaIcons: widget.metaIcons,
        showProgressBar: widget.showProgressBar,
        metricsBlock: progressSlot,
        spacing: cardSpacing,
        onToggleDone: widget.onToggleDone,
        onSelectToggle: widget.onSelectToggle,
        onPlay: widget.onPlay,
        onOpenMenu: widget.onOpenMenu,
        onBodyTap: widget.onTap,
        onBodyLongPress: widget.onLongPress,
      );
    } else {
      switch (effectiveDensity) {
        case PlanTimeTaskCardDensity.micro:
          body = _TimelinePlanCardSmall(
            task: widget.task,
            timeLabel: widget.timeLabel,
            displayIsDone: widget.displayIsDone,
            selectMode: widget.selectMode,
            isSelected: widget.isSelected,
            hasRepeat: _hasRepeat,
            showPlay: _showPlay,
            visibleTags: _visibleTags,
            toggleDoneEnabled: widget.toggleDoneEnabled,
            metaIcons: widget.metaIcons,
            metricsBlock: progressSlot,
            onToggleDone: widget.onToggleDone,
            onSelectToggle: widget.onSelectToggle,
            onPlay: widget.onPlay,
            onOpenMenu: widget.onOpenMenu,
            onBodyTap: widget.onTap,
            onBodyLongPress: widget.onLongPress,
          );
        case PlanTimeTaskCardDensity.compact:
          body = _TimelinePlanCardSmall(
            task: widget.task,
            timeLabel: effectiveTimeLabel,
            displayIsDone: widget.displayIsDone,
            selectMode: widget.selectMode,
            isSelected: widget.isSelected,
            hasRepeat: _hasRepeat,
            showPlay: _showPlay,
            visibleTags: _visibleTags,
            toggleDoneEnabled: widget.toggleDoneEnabled,
            metaIcons: widget.metaIcons,
            metricsBlock: progressSlot,
            timelineFillHeight: widget.timelineFillHeight,
            categoryTrail: widget.showFooterBreadcrumb ? categoryTrail : '',
            categoryColor: categoryTone,
            scheduleConflict: widget.scheduleConflict,
            onToggleDone: widget.onToggleDone,
            onSelectToggle: widget.onSelectToggle,
            onPlay: widget.onPlay,
            onOpenMenu: widget.onOpenMenu,
            onBodyTap: widget.onTap,
            onBodyLongPress: widget.onLongPress,
          );
        case PlanTimeTaskCardDensity.medium:
          body = _TimelinePlanCardMedium(
            task: widget.task,
            timeLabel: effectiveTimeLabel,
            categoryTrail: widget.showFooterBreadcrumb ? categoryTrail : '',
            categoryColor: categoryTone,
            displayIsDone: widget.displayIsDone,
            selectMode: widget.selectMode,
            isSelected: widget.isSelected,
            hasRepeat: _hasRepeat,
            showPlay: _showPlay,
            visibleTags: _visibleTags,
            scheduleConflict: widget.scheduleConflict,
            toggleDoneEnabled: widget.toggleDoneEnabled,
            metaIcons: widget.metaIcons,
            metricsBlock: progressSlot,
            spacing: cardSpacing,
            timelineFillHeight: widget.timelineFillHeight,
            onToggleDone: widget.onToggleDone,
            onSelectToggle: widget.onSelectToggle,
            onPlay: widget.onPlay,
            onOpenMenu: widget.onOpenMenu,
            onBodyTap: widget.onTap,
            onBodyLongPress: widget.onLongPress,
            titleMaxLines: 1,
          );
        case PlanTimeTaskCardDensity.large:
          body = _TimelinePlanCardLarge(
            task: widget.task,
            timeLabel: effectiveTimeLabel,
            categoryTrail: widget.showFooterBreadcrumb ? categoryTrail : '',
            categoryColor: categoryTone,
            displayIsDone: widget.displayIsDone,
            selectMode: widget.selectMode,
            isSelected: widget.isSelected,
            hasRepeat: _hasRepeat,
            showPlay: _showPlay,
            visibleTags: _visibleTags,
            scheduleConflict: widget.scheduleConflict,
            toggleDoneEnabled: widget.toggleDoneEnabled,
            metaIcons: widget.metaIcons,
            metricsBlock: progressSlot,
            spacing: cardSpacing,
            timelineFillHeight: widget.timelineFillHeight,
            onToggleDone: widget.onToggleDone,
            onSelectToggle: widget.onSelectToggle,
            onPlay: widget.onPlay,
            onOpenMenu: widget.onOpenMenu,
            onBodyTap: widget.onTap,
            onBodyLongPress: widget.onLongPress,
          );
      }
    }

    final minH = _isListLike ? planTimeCardListMinHeight(widget.density) : null;

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(PlanCardGeom.radius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: PlanCardTokens.cardShadow(
          widget.interacting,
          hovered: hovered,
        ),
      ),
      child: ClipRRect(
        clipBehavior: Clip.none,
        borderRadius: BorderRadius.circular(PlanCardGeom.radius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final timelineBlockH = widget.timelineBlockHeightPx;
            final measuredH =
                widget.surface == PlanCardSurface.timeline &&
                    widget.timelineVisualDensity != null &&
                    timelineBlockH != null
                ? timelineBlockH
                : planTimeCardMeasureHeight(
                    hasTags: _visibleTags.isNotEmpty,
                    hasTrackedProgress: widget.planTrackedSeconds > 0,
                    density: effectiveDensity,
                  );
            final h = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : measuredH;
            final showWatermark =
                widget.surface != PlanCardSurface.timeline &&
                !widget.timelineFillHeight &&
                effectiveDensity != PlanTimeTaskCardDensity.micro &&
                h >= PlanCardGeom.watermarkMinCardHeight;
            return SizedBox(
              height: h.isFinite ? h : measuredH,
              width: w.isFinite ? w : null,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  if (showWatermark)
                    PlanCardWatermark(
                      icon: categoryIcon,
                      color: categoryTone,
                      density: effectiveDensity,
                      cardWidth: w.isFinite ? w : PlanCardGeom.refWidth,
                      cardHeight: h.isFinite ? h : measuredH,
                    ),
                  body,
                ],
              ),
            );
          },
        ),
      ),
    );

    if (minH != null) {
      card = ConstrainedBox(
        constraints: BoxConstraints(minHeight: minH),
        child: card,
      );
    }

    card = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: card,
    );

    if (_completionCtrl.isAnimating) {
      card = AnimatedBuilder(
        animation: _completionCtrl,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_completionCtrl.value);
          return Opacity(
            opacity: (1.0 - 0.12 * t).clamp(0.88, 1.0),
            child: child,
          );
        },
        child: card,
      );
    } else if (widget.displayIsDone) {
      card = Opacity(opacity: 0.88, child: card);
    }

    return card;
  }
}

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

// --- Time View explicit CardPlan density layouts --------------------------------

/// Routes Time View blocks to explicit CardPlan layouts (tags always visible).
class _TimeViewDensityBody extends StatelessWidget {
  const _TimeViewDensityBody({
    required this.visual,
    required this.heightPx,
    required this.task,
    required this.timeLabel,
    required this.categoryTrail,
    required this.categoryColor,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.visibleTags,
    required this.scheduleConflict,
    required this.toggleDoneEnabled,
    required this.metaIcons,
    required this.showProgressBar,
    required this.metricsBlock,
    required this.spacing,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanTimeCardVisualDensity visual;
  final double heightPx;
  final PlanningTask task;
  final String timeLabel;
  final String categoryTrail;
  final Color categoryColor;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool hasRepeat;
  final bool showPlay;
  final List<Tag> visibleTags;
  final bool scheduleConflict;
  final bool toggleDoneEnabled;
  final List<Widget> metaIcons;
  final bool showProgressBar;
  final PlanCardProgressSlot? metricsBlock;
  final PlanCardVerticalSpacing spacing;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final common = _TimeViewCardCommon(
      task: task,
      timeLabel: timeLabel,
      categoryTrail: categoryTrail,
      categoryColor: categoryColor,
      displayIsDone: displayIsDone,
      selectMode: selectMode,
      isSelected: isSelected,
      hasRepeat: hasRepeat,
      showPlay: showPlay,
      visibleTags: visibleTags,
      scheduleConflict: scheduleConflict,
      toggleDoneEnabled: toggleDoneEnabled,
      metaIcons: metaIcons,
      showProgressBar: showProgressBar,
      metricsBlock: metricsBlock,
      spacing: spacing,
      onToggleDone: onToggleDone,
      onSelectToggle: onSelectToggle,
      onPlay: onPlay,
      onOpenMenu: onOpenMenu,
      onBodyTap: onBodyTap,
      onBodyLongPress: onBodyLongPress,
    );
    return switch (visual) {
      PlanTimeCardVisualDensity.verySmall => _TimeViewVerySmallLayout(
        common: common,
        heightPx: heightPx,
      ),
      PlanTimeCardVisualDensity.small => _TimeViewSmallLayout(
        common: common,
        heightPx: heightPx,
      ),
      PlanTimeCardVisualDensity.moreCompact => _TimeViewMoreCompactLayout(
        common: common,
        heightPx: heightPx,
      ),
      PlanTimeCardVisualDensity.compact => _TimeViewCompactLayout(
        common: common,
        heightPx: heightPx,
      ),
      PlanTimeCardVisualDensity.medium => _TimeViewMediumLayout(
        common: common,
        heightPx: heightPx,
      ),
    };
  }
}

class _TimeViewCardCommon {
  const _TimeViewCardCommon({
    required this.task,
    required this.timeLabel,
    required this.categoryTrail,
    required this.categoryColor,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.visibleTags,
    required this.scheduleConflict,
    required this.toggleDoneEnabled,
    required this.metaIcons,
    required this.showProgressBar,
    required this.metricsBlock,
    required this.spacing,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanningTask task;
  final String timeLabel;
  final String categoryTrail;
  final Color categoryColor;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool hasRepeat;
  final bool showPlay;
  final List<Tag> visibleTags;
  final bool scheduleConflict;
  final bool toggleDoneEnabled;
  final List<Widget> metaIcons;
  final bool showProgressBar;
  final PlanCardProgressSlot? metricsBlock;
  final PlanCardVerticalSpacing spacing;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;
}

class _TimeViewLeftControls extends StatelessWidget {
  const _TimeViewLeftControls({required this.common, this.inlinePlay = true});

  final _TimeViewCardCommon common;
  final bool inlinePlay;

  @override
  Widget build(BuildContext context) {
    if (inlinePlay) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlanCardCheckbox(
            selectMode: common.selectMode,
            isSelected: common.isSelected,
            displayIsDone: common.displayIsDone,
            toggleDoneEnabled: common.toggleDoneEnabled,
            onToggleDone: common.onToggleDone,
            onSelectToggle: common.onSelectToggle,
          ),
          if (common.showPlay) ...[
            const SizedBox(width: PlanCardGeom.playAfterCheckboxGap),
            PlanCardPlayButton(onPlay: common.onPlay),
          ],
        ],
      );
    }
    return PlanCardControlRail(
      showPlay: common.showPlay,
      selectMode: common.selectMode,
      isSelected: common.isSelected,
      displayIsDone: common.displayIsDone,
      toggleDoneEnabled: common.toggleDoneEnabled,
      onToggleDone: common.onToggleDone,
      onSelectToggle: common.onSelectToggle,
      onPlay: common.onPlay,
    );
  }
}

/// Responsive CardPlan shell: fixed left rail, expanding center, fixed right menu.
class _TimeViewResponsiveShell extends StatelessWidget {
  const _TimeViewResponsiveShell({
    required this.heightPx,
    required this.leftControls,
    required this.center,
    this.menu,
    this.padVertical = 0,
    this.horizontalPadLeft = PlanCardGeom.padLeft,
    this.horizontalPadRight = 6,
  });

  final double heightPx;
  final Widget leftControls;
  final Widget center;
  final Widget? menu;
  final double padVertical;
  final double horizontalPadLeft;
  final double horizontalPadRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightPx,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadLeft,
          padVertical,
          horizontalPadRight,
          padVertical,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leftControls,
            const SizedBox(width: PlanCardGeom.timeViewRailToContentGap),
            Expanded(child: center),
            ?menu,
          ],
        ),
      ),
    );
  }
}

/// Vertical-rail CardPlan shell for Compact / Medium densities.
class _TimeViewVerticalShell extends StatelessWidget {
  const _TimeViewVerticalShell({
    required this.heightPx,
    required this.common,
    required this.body,
    this.padTop = 6,
    this.padBottom = 4,
  });

  final double heightPx;
  final _TimeViewCardCommon common;
  final Widget body;
  final double padTop;
  final double padBottom;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightPx,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PlanCardGeom.padLeft,
          padTop,
          8,
          padBottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TimeViewLeftControls(common: common, inlinePlay: false),
            const SizedBox(width: PlanCardGeom.timeViewRailToContentGap),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Time View tag row ? every tag visible (horizontal scroll, never +N).
class _TimeViewTagsRow extends StatelessWidget {
  const _TimeViewTagsRow({required this.tags, this.trailing});

  final List<Tag> tags;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty && trailing == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: PlanCardGeom.tagRowHeight,
      child: Row(
        children: [
          if (tags.isNotEmpty)
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: tags.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: PlanCardGeom.tagGap),
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  return CategoryChip(
                    mode: CategoryDisplayMode.letterChip,
                    label: tag.name.trim().isNotEmpty
                        ? tag.name.trim()
                        : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}',
                    color: parseTagHexColor(tag.color) ?? scheme.primary,
                    icon: iconForTagKey(tag.icon),
                    compactGlyphLayout: true,
                    syntheticNoTagsMonochrome: tag.tagId == -1,
                  );
                },
              ),
            )
          else
            const Spacer(),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

/// VerySmall tag column ? compact CardPlan pills stacked vertically (ref).
class _TimeViewTagStack extends StatelessWidget {
  const _TimeViewTagStack({required this.tags});

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 80),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tags.length; i++) ...[
              if (i > 0) const SizedBox(height: 1),
              _TimeViewCompactTagPill(tag: tags[i], scheme: scheme),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact CardPlan tag pill for minimum-density Time View (16px, readable).
class _TimeViewCompactTagPill extends StatelessWidget {
  const _TimeViewCompactTagPill({required this.tag, required this.scheme});

  final Tag tag;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final color = parseTagHexColor(tag.color) ?? scheme.primary;
    final plate = tagLetterChipPlate(color, scheme.surface);
    final fg = tagVibrantForeground(color);
    final label = tag.name.trim().isNotEmpty
        ? tag.name.trim()
        : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}';
    return Container(
      height: PlanCardGeom.tagRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: plate,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: tagLetterChipBorder(color, scheme.surface)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// VerySmall 38px ? single row, reference-sized controls (CardPlan ref).
class _TimeViewVerySmallLayout extends StatelessWidget {
  const _TimeViewVerySmallLayout({
    required this.common,
    required this.heightPx,
  });

  final _TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    return _TimeViewResponsiveShell(
      heightPx: heightPx,
      padVertical: 0,
      horizontalPadRight: 8,
      leftControls: _TimeViewLeftControls(common: common),
      menu: common.onOpenMenu != null
          ? PlanCardMenuButton(onOpenMenu: common.onOpenMenu!)
          : null,
      center: PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: PlanCardTitleRow(
                title: common.task.title,
                displayIsDone: common.displayIsDone,
                hasRepeat: common.hasRepeat,
                maxLines: 1,
                metaIcons: common.metaIcons,
              ),
            ),
            if (common.visibleTags.isNotEmpty) ...[
              const SizedBox(width: 4),
              _TimeViewTagStack(tags: common.visibleTags),
            ],
            if (common.timeLabel.isNotEmpty) ...[
              const SizedBox(width: 6),
              PlanCardTimeText(label: common.timeLabel),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small 39?54px ? title row + tags/time metadata row (CardPlan ref).
class _TimeViewSmallLayout extends StatelessWidget {
  const _TimeViewSmallLayout({required this.common, required this.heightPx});

  final _TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    return _TimeViewTwoRowCenterLayout(
      common: common,
      heightPx: heightPx,
      padVertical: 6,
    );
  }
}

/// MoreCompact 55?77px ? same rhythm as Small with slightly more breathing room.
class _TimeViewMoreCompactLayout extends StatelessWidget {
  const _TimeViewMoreCompactLayout({
    required this.common,
    required this.heightPx,
  });

  final _TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    return _TimeViewTwoRowCenterLayout(
      common: common,
      heightPx: heightPx,
      padVertical: 7,
    );
  }
}

class _TimeViewTwoRowCenterLayout extends StatelessWidget {
  const _TimeViewTwoRowCenterLayout({
    required this.common,
    required this.heightPx,
    required this.padVertical,
  });

  final _TimeViewCardCommon common;
  final double heightPx;
  final double padVertical;

  @override
  Widget build(BuildContext context) {
    return _TimeViewResponsiveShell(
      heightPx: heightPx,
      padVertical: padVertical,
      leftControls: _TimeViewLeftControls(common: common),
      menu: common.onOpenMenu != null
          ? PlanCardMenuButton(onOpenMenu: common.onOpenMenu!)
          : null,
      center: PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            PlanCardTitleRow(
              title: common.task.title,
              displayIsDone: common.displayIsDone,
              hasRepeat: common.hasRepeat,
              maxLines: 1,
              metaIcons: common.metaIcons,
            ),
            const SizedBox(height: 2),
            _TimeViewTagsRow(
              tags: common.visibleTags,
              trailing: common.timeLabel.isNotEmpty
                  ? PlanCardTimeText(label: common.timeLabel)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact 78?94px ? vertical rail, title/tags, optional footer (CardPlan ref).
class _TimeViewCompactLayout extends StatelessWidget {
  const _TimeViewCompactLayout({required this.common, required this.heightPx});

  final _TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    final showProgress = common.showProgressBar && common.metricsBlock != null;
    final showBreadcrumb = common.categoryTrail.trim().isNotEmpty;
    return _TimeViewVerticalShell(
      heightPx: heightPx,
      common: common,
      body: PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PlanCardTitleRow(
                      title: common.task.title,
                      displayIsDone: common.displayIsDone,
                      hasRepeat: common.hasRepeat,
                      maxLines: 1,
                      metaIcons: common.metaIcons,
                    ),
                  ),
                  if (common.onOpenMenu != null)
                    PlanCardMenuButton(onOpenMenu: common.onOpenMenu!),
                ],
              ),
            ),
            if (common.visibleTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _TimeViewTagsRow(tags: common.visibleTags),
              ),
            if (showProgress) ...[
              const SizedBox(height: 4),
              common.metricsBlock!,
            ],
            const Expanded(child: SizedBox.shrink()),
            if (showBreadcrumb || common.timeLabel.isNotEmpty)
              PlanCardFooterRow(
                categoryTrail: showBreadcrumb ? common.categoryTrail : '',
                timeLabel: common.timeLabel,
                scheduleConflict: common.scheduleConflict,
                categoryColor: common.categoryColor,
              ),
          ],
        ),
      ),
    );
  }
}

/// Medium 95px+ ? full CardPlan hierarchy (CardPlan ref).
class _TimeViewMediumLayout extends StatelessWidget {
  const _TimeViewMediumLayout({required this.common, required this.heightPx});

  final _TimeViewCardCommon common;
  final double heightPx;

  @override
  Widget build(BuildContext context) {
    final progressSlot =
        common.metricsBlock ??
        PlanCardProgressSlot(
          planTrackedSeconds: 0,
          categoryColor: common.categoryColor,
          spacing: common.spacing,
        );
    final showBreadcrumb = common.categoryTrail.trim().isNotEmpty;
    return _TimeViewVerticalShell(
      heightPx: heightPx,
      common: common,
      padTop: 8,
      body: PlanCardBodyTapShell(
        onTap: common.onBodyTap,
        onLongPress: common.onBodyLongPress,
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
                      title: common.task.title,
                      displayIsDone: common.displayIsDone,
                      hasRepeat: common.hasRepeat,
                      maxLines: 1,
                      metaIcons: common.metaIcons,
                    ),
                  ),
                  if (common.onOpenMenu != null)
                    PlanCardMenuButton(onOpenMenu: common.onOpenMenu!),
                ],
              ),
            ),
            if (common.visibleTags.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: common.spacing.titleToTagsGap),
                child: _TimeViewTagsRow(tags: common.visibleTags),
              ),
            const Expanded(child: SizedBox.shrink()),
            if (common.showProgressBar) ...[
              progressSlot,
              SizedBox(height: common.spacing.footerBlockGap),
            ] else if (showBreadcrumb || common.timeLabel.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: PlanCardTokens.dividerColor,
                ),
              ),
            PlanCardFooterRow(
              categoryTrail: showBreadcrumb ? common.categoryTrail : '',
              timeLabel: common.timeLabel,
              scheduleConflict: common.scheduleConflict,
              categoryColor: common.categoryColor,
            ),
          ],
        ),
      ),
    );
  }
}

// --- CardPlan_Small (legacy list path) ----------------------------------------

class _TimelinePlanCardSmall extends StatelessWidget {
  const _TimelinePlanCardSmall({
    required this.task,
    required this.timeLabel,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.visibleTags,
    required this.toggleDoneEnabled,
    this.metaIcons = const [],
    this.metricsBlock,
    this.timelineFillHeight = false,
    this.categoryTrail = '',
    this.categoryColor = PlanCardTokens.breadcrumbFallbackColor,
    this.scheduleConflict = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanningTask task;
  final String timeLabel;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool hasRepeat;
  final bool showPlay;
  final List<Tag> visibleTags;
  final bool toggleDoneEnabled;
  final List<Widget> metaIcons;
  final PlanCardProgressSlot? metricsBlock;
  final bool timelineFillHeight;
  final String categoryTrail;
  final Color categoryColor;
  final bool scheduleConflict;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final showTagRow = !timelineFillHeight && visibleTags.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        PlanCardGeom.padLeft,
        timelineFillHeight
            ? PlanCardGeom.padTopSmall
            : PlanCardGeom.padTopSmall,
        PlanCardGeom.padRight,
        timelineFillHeight
            ? PlanCardGeom.footerBottomPad
            : PlanCardGeom.padTopSmall,
      ),
      child: Row(
        crossAxisAlignment: timelineFillHeight
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          PlanCardCheckbox(
            selectMode: selectMode,
            isSelected: isSelected,
            displayIsDone: displayIsDone,
            toggleDoneEnabled: toggleDoneEnabled,
            onToggleDone: onToggleDone,
            onSelectToggle: onSelectToggle,
          ),
          if (showPlay) ...[
            const SizedBox(width: PlanCardGeom.playAfterCheckboxGap),
            PlanCardPlayButton(onPlay: onPlay),
            const SizedBox(width: PlanCardGeom.playAfterCheckboxGap),
          ] else
            SizedBox(
              width:
                  PlanCardGeom.contentXSmall -
                  PlanCardGeom.padLeft -
                  PlanCardGeom.controlSize,
            ),
          Expanded(
            child: PlanCardBodyTapShell(
              onTap: onBodyTap,
              onLongPress: onBodyLongPress,
              child: timelineFillHeight
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PlanCardTitleRow(
                          title: task.title,
                          displayIsDone: displayIsDone,
                          hasRepeat: hasRepeat,
                          maxLines: 1,
                          metaIcons: metaIcons,
                        ),
                        const Spacer(),
                        PlanCardFooterRow(
                          categoryTrail: '',
                          timeLabel: timeLabel,
                          scheduleConflict: scheduleConflict,
                          categoryColor: categoryColor,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlanCardTitleRow(
                          title: task.title,
                          displayIsDone: displayIsDone,
                          hasRepeat: hasRepeat,
                          maxLines: 1,
                          metaIcons: metaIcons,
                        ),
                        if (showTagRow)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: PlanCardTagsRow(tags: visibleTags),
                          ),
                        if (metricsBlock != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: metricsBlock!,
                          ),
                      ],
                    ),
            ),
          ),
          if (onOpenMenu != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: PlanCardMenuButton(onOpenMenu: onOpenMenu!),
            ),
        ],
      ),
    );
  }
}

// --- CardPlan_Medium / CardPlan_Large (invariant skeleton) --------------------

class _TimelinePlanCardMedium extends StatelessWidget {
  const _TimelinePlanCardMedium({
    required this.task,
    required this.timeLabel,
    required this.categoryTrail,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.visibleTags,
    required this.scheduleConflict,
    required this.toggleDoneEnabled,
    required this.titleMaxLines,
    this.metaIcons = const [],
    this.metricsBlock,
    this.categoryColor = PlanCardTokens.breadcrumbFallbackColor,
    this.spacing = PlanCardVerticalSpacing.shared,
    this.timelineFillHeight = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanningTask task;
  final String timeLabel;
  final String categoryTrail;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool hasRepeat;
  final bool showPlay;
  final List<Tag> visibleTags;
  final bool scheduleConflict;
  final bool toggleDoneEnabled;
  final int titleMaxLines;
  final List<Widget> metaIcons;
  final PlanCardProgressSlot? metricsBlock;
  final Color categoryColor;
  final PlanCardVerticalSpacing spacing;
  final bool timelineFillHeight;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final progressSlot =
        metricsBlock ??
        PlanCardProgressSlot(
          planTrackedSeconds: 0,
          categoryColor: categoryColor,
          spacing: spacing,
        );
    return PlanCardRailShell(
      showPlay: showPlay,
      selectMode: selectMode,
      isSelected: isSelected,
      displayIsDone: displayIsDone,
      toggleDoneEnabled: toggleDoneEnabled,
      spacing: spacing,
      fillHeight: timelineFillHeight,
      onToggleDone: onToggleDone,
      onSelectToggle: onSelectToggle,
      onPlay: onPlay,
      body: PlanCardInvariantBody(
        task: task,
        titleMaxLines: titleMaxLines,
        visibleTags: visibleTags,
        displayIsDone: displayIsDone,
        hasRepeat: hasRepeat,
        metaIcons: metaIcons,
        progressSlot: progressSlot,
        categoryTrail: categoryTrail,
        timeLabel: timeLabel,
        scheduleConflict: scheduleConflict,
        categoryColor: categoryColor,
        spacing: spacing,
        anchorFooterBottom: timelineFillHeight,
        onOpenMenu: onOpenMenu,
        onBodyTap: onBodyTap,
        onBodyLongPress: onBodyLongPress,
      ),
    );
  }
}

class _TimelinePlanCardLarge extends StatelessWidget {
  const _TimelinePlanCardLarge({
    required this.task,
    required this.timeLabel,
    required this.categoryTrail,
    required this.displayIsDone,
    required this.selectMode,
    required this.isSelected,
    required this.hasRepeat,
    required this.showPlay,
    required this.visibleTags,
    required this.scheduleConflict,
    required this.toggleDoneEnabled,
    this.metaIcons = const [],
    this.metricsBlock,
    this.categoryColor = PlanCardTokens.breadcrumbFallbackColor,
    this.spacing = PlanCardVerticalSpacing.shared,
    this.timelineFillHeight = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onBodyTap,
    this.onBodyLongPress,
  });

  final PlanningTask task;
  final String timeLabel;
  final String categoryTrail;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool hasRepeat;
  final bool showPlay;
  final List<Tag> visibleTags;
  final bool scheduleConflict;
  final bool toggleDoneEnabled;
  final List<Widget> metaIcons;
  final PlanCardProgressSlot? metricsBlock;
  final Color categoryColor;
  final PlanCardVerticalSpacing spacing;
  final bool timelineFillHeight;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;
  final VoidCallback? onBodyTap;
  final VoidCallback? onBodyLongPress;

  @override
  Widget build(BuildContext context) {
    final progressSlot =
        metricsBlock ??
        PlanCardProgressSlot(
          planTrackedSeconds: 0,
          categoryColor: categoryColor,
          spacing: spacing,
        );
    return PlanCardRailShell(
      showPlay: showPlay,
      selectMode: selectMode,
      isSelected: isSelected,
      displayIsDone: displayIsDone,
      toggleDoneEnabled: toggleDoneEnabled,
      spacing: spacing,
      fillHeight: timelineFillHeight,
      onToggleDone: onToggleDone,
      onSelectToggle: onSelectToggle,
      onPlay: onPlay,
      body: PlanCardInvariantBody(
        task: task,
        titleMaxLines: 3,
        visibleTags: visibleTags,
        displayIsDone: displayIsDone,
        hasRepeat: hasRepeat,
        metaIcons: metaIcons,
        progressSlot: progressSlot,
        categoryTrail: categoryTrail,
        timeLabel: timeLabel,
        scheduleConflict: scheduleConflict,
        categoryColor: categoryColor,
        spacing: spacing,
        anchorFooterBottom: timelineFillHeight,
        onOpenMenu: onOpenMenu,
        onBodyTap: onBodyTap,
        onBodyLongPress: onBodyLongPress,
      ),
    );
  }
}

// --- Shared parts -------------------------------------------------------------

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


/// Time mode block density from rendered height (CardPlan reference bands).
PlanTimeTaskCardDensity planTimeCardDensityForBlock(
  double heightPx,
  int durationMin,
) {
  return planTimeCardTaskDensityForVisual(
    planTimeCardVisualDensityForRenderedHeight(heightPx),
  );
}

String _planCardWallTimeLabel(PlanningTask task) {
  final start = task.startTime;
  if (start == null) return '';
  final startLabel =
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  final end = task.endDateTime;
  if (end != null) {
    return '$startLabel ? ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }
  return startLabel;
}

/// List/calendar rows always use medium so footer (breadcrumb + planned time) is consistent.
PlanTimeTaskCardDensity planTimeCardDensityForList({
  required PlanningTask task,
  int? planEstimatedSeconds,
  int planTrackedSeconds = 0,
}) {
  return PlanTimeTaskCardDensity.medium;
}

/// Minimum visible height for list/calendar surfaces (never collapse to 0).
double planTimeCardListMinHeight(PlanTimeTaskCardDensity density) =>
    switch (density) {
      PlanTimeTaskCardDensity.micro => PlanCardGeom.refHeightMicro,
      PlanTimeTaskCardDensity.compact => PlanCardGeom.refHeightSmall,
      PlanTimeTaskCardDensity.medium => PlanCardGeom.refHeightMedium,
      PlanTimeTaskCardDensity.large => PlanCardGeom.refHeightLarge,
    };

/// Intrinsic CardPlan height ? single source for list minHeight and Time mode blocks.
double planTimeCardMeasureHeight({
  required bool hasTags,
  required bool hasTrackedProgress,
  PlanTimeTaskCardDensity density = PlanTimeTaskCardDensity.medium,
  int titleLines = 1,
}) {
  if (density == PlanTimeTaskCardDensity.micro ||
      density == PlanTimeTaskCardDensity.compact) {
    return planTimeCardListMinHeight(density);
  }
  const spacing = PlanCardVerticalSpacing.shared;
  final titleBlock =
      spacing.titleTopInset +
      PlanCardGeom.titleRowHeight * (titleLines > 1 ? titleLines / 1.0 : 1.0);
  final tagsBlock = spacing.tagsSlotHeight(hasTags: hasTags);
  final progressBlock = spacing.progressSlotHeight(
    hasTrackedProgress: hasTrackedProgress,
  );
  final footerBlock = spacing.footerBlockGap + PlanCardGeom.footerTextHeight;
  final contentColumn =
      titleBlock +
      tagsBlock +
      PlanCardGeom.tagsToProgressGap +
      progressBlock +
      footerBlock;
  final contentWithPad = spacing.padTop + contentColumn + spacing.padBottom;
  const railInner =
      PlanCardGeom.controlSize +
      PlanCardGeom.checkboxPlayGap +
      PlanCardGeom.controlSize;
  final railWithPad = spacing.padTop + railInner + spacing.padBottom;
  return math.max(contentWithPad, railWithPad);
}

/// Time mode [Positioned] height: preferred visual height + border allowance.
double planTimeCardTimelineAllocatedHeight({
  required bool hasTags,
  required bool hasTrackedProgress,
}) {
  return planTimeCardMeasureHeight(
        hasTags: hasTags,
        hasTrackedProgress: hasTrackedProgress,
      ) +
      PlanCardGeom.timelineBlockAllowancePx;
}

/// Left inset for timeline drag/tap body zone ? excludes checkbox + play rail.
double planCardBodyGestureLeftInsetPx(
  PlanTimeTaskCardDensity density, {
  bool timeline = false,
}) => switch (density) {
  PlanTimeTaskCardDensity.micro => PlanCardGeom.contentXSmall,
  PlanTimeTaskCardDensity.compact =>
    timeline ? PlanCardGeom.contentXSmall : PlanCardGeom.contentXSmall,
  PlanTimeTaskCardDensity.medium || PlanTimeTaskCardDensity.large =>
    PlanCardGeom.padLeft +
        PlanCardGeom.railWidth +
        PlanCardGeom.railToContentGap,
};

/// Right inset for timeline drag/tap body zone ? excludes menu button column.
double planCardBodyGestureRightInsetPx({bool hasMenu = true}) =>
    hasMenu ? PlanCardGeom.menuSize + PlanCardGeom.padRight : 0;
