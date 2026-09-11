import 'dart:math' as math;

import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';
import 'package:counter/shared/categories/presentation/plan_category_lookup.dart';
import 'package:counter/data/models.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/core/tag_contrast.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

import 'plan_card_controls.dart';
import 'plan_card_geometry.dart';
import 'plan_card_metrics.dart';
import 'plan_card_sections.dart';
import 'plan_card_progress.dart';
import 'plan_card_layouts.dart';
import 'plan_card_density.dart';

export 'plan_card_metrics.dart';
export 'plan_card_density.dart';

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
        : planCardWallTimeLabel(widget.task);
    final isTimeViewCard =
        widget.surface == PlanCardSurface.timeline &&
        widget.timelineVisualDensity != null;
    final timeViewTrailingPlay = isTimeViewCard && _showPlay;
    final timeViewTrailingMenu = isTimeViewCard && widget.onOpenMenu != null;

    final hovered = _hovered && !widget.interacting;
    final selected = widget.selectMode && widget.isSelected;
    final borderColor = selected
        ? scheme.primary.withValues(alpha: 0.52)
        : widget.highlightAsRunning
        ? scheme.primary
        : widget.interacting
        ? scheme.primary.withValues(alpha: 0.45)
        : hovered
        ? scheme.outlineVariant.withValues(alpha: isTimeViewCard ? 0.80 : 0.62)
        : scheme.outlineVariant.withValues(alpha: isTimeViewCard ? 0.58 : 0.38);
    final borderWidth = selected
        ? 1.25
        : widget.highlightAsRunning
        ? 1.75
        : widget.interacting
        ? 1.5
        : hovered
        ? 1.25
        : 1.0;

    final baseSurface = isTimeViewCard
        ? (scheme.brightness == Brightness.light
              ? const Color(0xFFFFFFFF)
              : scheme.surfaceContainerHigh)
        : PlanCardTokens.surface;
    var surface = selected
        ? Color.alphaBlend(
            scheme.primaryContainer.withValues(alpha: 0.16),
            baseSurface,
          )
        : baseSurface;
    if (hovered) {
      surface = Color.alphaBlend(
        scheme.surfaceContainerHighest.withValues(
          alpha: isTimeViewCard ? 0.10 : 0.28,
        ),
        surface,
      );
    }

    final effectiveDensity = widget.density;
    final useInvariantSlots =
        widget.showProgressBar &&
        (isTimeViewCard ||
            effectiveDensity == PlanTimeTaskCardDensity.medium ||
            effectiveDensity == PlanTimeTaskCardDensity.large);
    const cardSpacing = PlanCardVerticalSpacing.shared;
    final progressSlot = useInvariantSlots
        ? PlanCardProgressSlot(
            planTrackedSeconds: widget.planTrackedSeconds,
            planEstimatedSeconds: widget.planEstimatedSeconds,
            categoryColor: categoryTone,
            isRunning: widget.highlightAsRunning,
            spacing: cardSpacing,
          )
        : null;

    Widget body;
    if (isTimeViewCard) {
      body = TimeViewDensityBody(
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
        showPlay: false,
        visibleTags: _visibleTags,
        scheduleConflict: widget.scheduleConflict,
        toggleDoneEnabled: widget.toggleDoneEnabled,
        metaIcons: widget.metaIcons,
        showProgressBar: widget.showProgressBar,
        metricsBlock: progressSlot,
        spacing: cardSpacing,
        onToggleDone: widget.onToggleDone,
        onSelectToggle: widget.onSelectToggle,
        onPlay: null,
        onOpenMenu: null,
        onBodyTap: widget.onTap,
        onBodyLongPress: widget.onLongPress,
      );
    } else {
      switch (effectiveDensity) {
        case PlanTimeTaskCardDensity.micro:
          body = TimelinePlanCardSmall(
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
          body = TimelinePlanCardSmall(
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
          body = TimelinePlanCardMedium(
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
          body = TimelinePlanCardLarge(
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
        boxShadow: isTimeViewCard
            ? [
                BoxShadow(
                  color: Color(hovered ? 0x20000000 : 0x16000000),
                  blurRadius: hovered ? 12 : 9,
                  spreadRadius: -2,
                  offset: const Offset(0, 3),
                ),
              ]
            : PlanCardTokens.cardShadow(widget.interacting, hovered: hovered),
      ),
      child: ClipRRect(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(PlanCardGeom.radius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final timelineBlockH = widget.timelineBlockHeightPx;
            final measuredH = isTimeViewCard && timelineBlockH != null
                ? timelineBlockH
                : planTimeCardMeasureHeight(
                    hasTags: _visibleTags.isNotEmpty,
                    hasTrackedProgress: widget.planTrackedSeconds > 0,
                    density: effectiveDensity,
                  );
            final h = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : measuredH;
            final resolvedHeight = h.isFinite ? h : measuredH;
            final showWatermark = isTimeViewCard
                ? categoryIcon != null
                : !widget.timelineFillHeight &&
                    effectiveDensity != PlanTimeTaskCardDensity.micro &&
                    resolvedHeight >= PlanCardGeom.watermarkMinCardHeight;
            final trailingControlCount =
                (timeViewTrailingPlay ? 1 : 0) + (timeViewTrailingMenu ? 1 : 0);
            final trailingControlsWidth = trailingControlCount == 0
                ? 0.0
                : trailingControlCount * PlanCardGeom.controlSize +
                      (trailingControlCount - 1) * 8.0;
            final bodyContent = trailingControlCount > 0
                ? Padding(
                    padding: EdgeInsets.only(
                      right: trailingControlsWidth + PlanCardGeom.padRight,
                    ),
                    child: body,
                  )
                : body;
            return SizedBox(
              height: resolvedHeight,
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
                      cardHeight: resolvedHeight,
                    ),
                  bodyContent,
                  if (trailingControlCount > 0)
                    Positioned(
                      top: math.max(
                        0.0,
                        (resolvedHeight - PlanCardGeom.controlSize) / 2,
                      ),
                      right: PlanCardGeom.padRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (timeViewTrailingPlay)
                            PlanCardPlayButton(onPlay: widget.onPlay),
                          if (timeViewTrailingPlay && timeViewTrailingMenu)
                            const SizedBox(width: 8),
                          if (timeViewTrailingMenu)
                            PlanCardMenuButton(onOpenMenu: widget.onOpenMenu!),
                        ],
                      ),
                    ),
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
