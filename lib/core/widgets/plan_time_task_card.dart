// ---------------------------------------------------------------------------
// PlanTimeTaskCard — CardPlan Small/Medium/Large visual for Planning Time + Calendar.
// Reference: design/CardPlan Small.png, Medium.png, Large.png
// ---------------------------------------------------------------------------

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/features/shared/chip_component.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

enum PlanTimeTaskCardDensity { compact, medium, large }

/// CardPlan-style task card: white surface, watermark, control rail, text column.
class PlanTimeTaskCard extends StatelessWidget {
  const PlanTimeTaskCard({
    super.key,
    required this.task,
    required this.density,
    required this.timeLabel,
    this.heightPx,
    this.displayIsDone = false,
    this.selectMode = false,
    this.isSelected = false,
    this.highlightAsRunning = false,
    this.interacting = false,
    this.toggleDoneEnabled = true,
    this.planTrackedSeconds = 0,
    this.planEstimatedSeconds,
    this.scheduleConflict = false,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
    this.onTap,
  });

  final PlanningTask task;
  final PlanTimeTaskCardDensity density;
  final String timeLabel;
  final double? heightPx;
  final bool displayIsDone;
  final bool selectMode;
  final bool isSelected;
  final bool highlightAsRunning;
  final bool interacting;
  final bool toggleDoneEnabled;
  final int planTrackedSeconds;
  final int? planEstimatedSeconds;
  final bool scheduleConflict;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext menuContext)? onOpenMenu;
  final VoidCallback? onTap;

  static const double kControlRailWidth = 44;

  bool get _hasRepeat =>
      (task.rrule?.trim().isNotEmpty ?? false) ||
      (task.recurrenceInstanceDateKey?.trim().isNotEmpty ?? false);

  bool get _showPlay => !selectMode && !displayIsDone && onPlay != null;

  List<Tag> get _visibleTags =>
      task.tags.where((t) => t.rendersAsChip).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final categoryTone =
        DatabaseService.instance.getCategoryColor(task.categoryId);
    final categoryTrail = localizeCategoryBreadcrumbPath(
      DatabaseService.instance.getCategoryPath(task.categoryId).trim(),
      loc,
    );
    final categoryIcon =
        DatabaseService.instance.getCategoryRuleById(task.categoryId)?.iconOrDefault;

    final borderColor = highlightAsRunning
        ? scheme.primary
        : interacting
            ? scheme.primary.withValues(alpha: 0.45)
            : scheme.outlineVariant.withValues(alpha: 0.38);
    final borderWidth = highlightAsRunning
        ? 2.0
        : interacting
            ? 1.5
            : 1.0;

    final surface = selectMode && isSelected
        ? Color.alphaBlend(
            scheme.primaryContainer.withValues(alpha: 0.35),
            scheme.surface,
          )
        : scheme.surface;

    Widget content;
    switch (density) {
      case PlanTimeTaskCardDensity.compact:
        content = _compactBody(context, scheme, categoryTone);
      case PlanTimeTaskCardDensity.medium:
        content = _mediumLargeBody(
          context,
          scheme,
          categoryTone,
          categoryTrail,
          large: false,
        );
      case PlanTimeTaskCardDensity.large:
        content = _mediumLargeBody(
          context,
          scheme,
          categoryTone,
          categoryTrail,
          large: true,
        );
    }

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: interacting ? 0.14 : 0.08),
            blurRadius: interacting ? 6 : 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: heightPx != null ? StackFit.expand : StackFit.passthrough,
          children: [
            _CategoryWatermark(
              icon: categoryIcon,
              color: categoryTone,
              density: density,
            ),
            if (heightPx != null)
              SizedBox(height: heightPx, width: double.infinity, child: content)
            else
              content,
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      ),
    );
  }

  Widget _compactBody(
    BuildContext context,
    ColorScheme scheme,
    Color categoryTone,
  ) {
    final h = heightPx ?? 56;
    final showSecondRow =
        h >= 46 && (_visibleTags.isNotEmpty || timeLabel.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _checkbox(scheme, scale: 0.92),
              if (_showPlay) _playButton(scheme, size: 28),
              Expanded(
                child: _titleInlineRepeat(
                  context,
                  scheme,
                  maxLines: 1,
                  fontSize: 13,
                ),
              ),
              _menuButton(context, scheme),
            ],
          ),
          if (showSecondRow)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 2),
              child: Row(
                children: [
                  Expanded(child: _tagStrip(context, scheme, compact: true)),
                  if (timeLabel.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _timeText(context, scheme, compact: true),
                  ],
                ],
              ),
            )
          else if (timeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 1),
              child: Align(
                alignment: Alignment.centerRight,
                child: _timeText(context, scheme, compact: true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mediumLargeBody(
    BuildContext context,
    ColorScheme scheme,
    Color categoryTone,
    String categoryTrail, {
    required bool large,
  }) {
    final showTags = _visibleTags.isNotEmpty;
    final showProgress =
        (planEstimatedSeconds ?? 0) > 0 || planTrackedSeconds > 0;
    final showBreadcrumb = categoryTrail.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, large ? 8 : 6, 8, large ? 8 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: kControlRailWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _checkbox(scheme),
                if (_showPlay) _playButton(scheme, size: 30),
                if (large) const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titleInlineRepeat(
                  context,
                  scheme,
                  maxLines: large ? 3 : 2,
                  fontSize: large ? 15 : 14,
                ),
                if (showTags)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _tagStrip(context, scheme, compact: false),
                  ),
                if (large) const Spacer(),
                if (showBreadcrumb || timeLabel.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: large ? 0 : 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (showBreadcrumb)
                          Expanded(
                            child: Text(
                              categoryTrail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 11,
                                    height: 1.15,
                                    fontWeight: FontWeight.w500,
                                    color: categoryTone.withValues(alpha: 0.92),
                                  ),
                            ),
                          ),
                        if (timeLabel.isNotEmpty) ...[
                          if (showBreadcrumb) const SizedBox(width: 8),
                          _timeText(context, scheme),
                          if (scheduleConflict)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 13,
                                color: scheme.error.withValues(alpha: 0.75),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                if (showProgress)
                  Padding(
                    padding: EdgeInsets.only(top: large ? 6 : 4),
                    child: _progressFooter(context, scheme),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: _menuButton(context, scheme),
          ),
        ],
      ),
    );
  }

  Widget _titleInlineRepeat(
    BuildContext context,
    ColorScheme scheme, {
    int maxLines = 1,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            task.title,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.2,
              fontWeight: FontWeight.w500,
              decoration: displayIsDone ? TextDecoration.lineThrough : null,
              color: displayIsDone
                  ? scheme.onSurface.withValues(alpha: 0.55)
                  : scheme.onSurface,
            ),
          ),
        ),
        if (_hasRepeat)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.repeat_rounded,
              size: fontSize + 1,
              color: scheme.primary.withValues(alpha: 0.78),
            ),
          ),
      ],
    );
  }

  Widget _tagStrip(
    BuildContext context,
    ColorScheme scheme, {
    required bool compact,
  }) {
    if (_visibleTags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final tag in _visibleTags.take(compact ? 2 : 4))
          CategoryChip(
            mode: CategoryDisplayMode.letterChip,
            label: tag.name.trim().isNotEmpty
                ? tag.name.trim()
                : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}',
            color: parseTagHexColor(tag.color) ?? scheme.primary,
            icon: iconForTagKey(tag.icon),
            compactGlyphLayout: true,
            syntheticNoTagsMonochrome: tag.tagId == -1,
          ),
      ],
    );
  }

  Widget _timeText(BuildContext context, ColorScheme scheme, {bool compact = false}) {
    if (timeLabel.isEmpty) return const SizedBox.shrink();
    return Text(
      timeLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
          ),
    );
  }

  Widget _checkbox(ColorScheme scheme, {double scale = 1}) {
    final box = selectMode
        ? Checkbox(
            value: isSelected,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (_) => onSelectToggle?.call(),
          )
        : Checkbox(
            value: displayIsDone,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: toggleDoneEnabled ? (_) => onToggleDone?.call() : null,
          );
    if (scale == 1) return box;
    return Transform.scale(scale: scale, child: box);
  }

  Widget _playButton(ColorScheme scheme, {double size = 32}) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        iconSize: size * 0.58,
        style: IconButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          hoverColor: Colors.transparent,
          foregroundColor: scheme.onSurface.withValues(alpha: 0.72),
        ),
        icon: const Icon(Icons.play_arrow_rounded),
        onPressed: onPlay,
        tooltip: t(currentLocale.value, 'start'),
      ),
    );
  }

  Widget _menuButton(BuildContext context, ColorScheme scheme) {
    if (onOpenMenu == null) return const SizedBox.shrink();
    return Builder(
      builder: (menuCtx) => Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: t(currentLocale.value, 'plan_radial_menu_tip'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          iconSize: 18,
          style: IconButton.styleFrom(
            splashFactory: NoSplash.splashFactory,
            hoverColor: Colors.transparent,
            foregroundColor: scheme.onSurfaceVariant,
          ),
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => onOpenMenu!(menuCtx),
        ),
      ),
    );
  }

  Widget _progressFooter(BuildContext context, ColorScheme scheme) {
    final est = planEstimatedSeconds ?? 0;
    if (est <= 0 && planTrackedSeconds <= 0) {
      return const SizedBox.shrink();
    }
    if (est <= 0) {
      return Text(
        t(currentLocale.value, 'plan_card_fact_time')
            .replaceFirst('%s', _trackedDurationAsHhMm(planTrackedSeconds)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: scheme.onSurfaceVariant,
            ),
      );
    }
    final pct = est > 0 ? ((planTrackedSeconds * 100) / est).round() : 0;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 3,
              value: planTrackedSeconds <= est
                  ? planTrackedSeconds / est
                  : 1.0,
              backgroundColor:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              color: planTrackedSeconds > est ? scheme.error : scheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${_shortDur(planTrackedSeconds)} / ${_shortDur(est)} ($pct%)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  static String _trackedDurationAsHhMm(int seconds) {
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

  static String _shortDur(int seconds) {
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    if (r == 0) return '${h}h';
    return '${h}h${r}m';
  }
}

class _CategoryWatermark extends StatelessWidget {
  const _CategoryWatermark({
    required this.icon,
    required this.color,
    required this.density,
  });

  final IconData? icon;
  final Color color;
  final PlanTimeTaskCardDensity density;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox.shrink();
    final size = switch (density) {
      PlanTimeTaskCardDensity.compact => 0.0,
      PlanTimeTaskCardDensity.medium => 84.0,
      PlanTimeTaskCardDensity.large => 148.0,
    };
    if (size <= 0) return const SizedBox.shrink();
    return Positioned(
      right: density == PlanTimeTaskCardDensity.large ? 12 : 8,
      bottom: density == PlanTimeTaskCardDensity.large ? 16 : 10,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -0.28,
          child: Icon(
            icon,
            size: size,
            color: color.withValues(alpha: 0.06),
          ),
        ),
      ),
    );
  }
}

/// Maps timeline block metrics to CardPlan density.
PlanTimeTaskCardDensity planTimeCardDensityForBlock(
  double heightPx,
  int durationMin,
) {
  if (heightPx < 72 || durationMin <= 40) {
    return PlanTimeTaskCardDensity.compact;
  }
  if (heightPx < 132 || durationMin < 100) {
    return PlanTimeTaskCardDensity.medium;
  }
  return PlanTimeTaskCardDensity.large;
}
