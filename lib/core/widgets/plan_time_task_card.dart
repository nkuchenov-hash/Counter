// ---------------------------------------------------------------------------
// PlanTimeTaskCard — CardPlan_Small / CardPlan_Medium / CardPlan_Large
// Geometry source: Figma MCP metadata (328px ref). Visual tokens: design/*.svg
// ---------------------------------------------------------------------------

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/profile/tag_manager_page.dart';
import 'package:counter/features/shared/chip_component.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

enum PlanTimeTaskCardDensity { compact, medium, large }

/// CardPlan-style task card for Planning Time + Calendar focused-day rows.
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
            _PlanCardTokens.surface,
          )
        : _PlanCardTokens.surface;

    Widget body;
    switch (density) {
      case PlanTimeTaskCardDensity.compact:
        body = _TimelinePlanCardSmall(
          task: task,
          timeLabel: timeLabel,
          displayIsDone: displayIsDone,
          selectMode: selectMode,
          isSelected: isSelected,
          hasRepeat: _hasRepeat,
          showPlay: _showPlay,
          visibleTags: _visibleTags,
          toggleDoneEnabled: toggleDoneEnabled,
          onToggleDone: onToggleDone,
          onSelectToggle: onSelectToggle,
          onPlay: onPlay,
          onOpenMenu: onOpenMenu,
        );
      case PlanTimeTaskCardDensity.medium:
        body = _TimelinePlanCardMedium(
          task: task,
          timeLabel: timeLabel,
          categoryTrail: categoryTrail,
          displayIsDone: displayIsDone,
          selectMode: selectMode,
          isSelected: isSelected,
          hasRepeat: _hasRepeat,
          showPlay: _showPlay,
          visibleTags: _visibleTags,
          scheduleConflict: scheduleConflict,
          toggleDoneEnabled: toggleDoneEnabled,
          onToggleDone: onToggleDone,
          onSelectToggle: onSelectToggle,
          onPlay: onPlay,
          onOpenMenu: onOpenMenu,
          titleMaxLines: 1,
          heightPx: heightPx,
        );
      case PlanTimeTaskCardDensity.large:
        body = _TimelinePlanCardLarge(
          task: task,
          timeLabel: timeLabel,
          categoryTrail: categoryTrail,
          displayIsDone: displayIsDone,
          selectMode: selectMode,
          isSelected: isSelected,
          hasRepeat: _hasRepeat,
          showPlay: _showPlay,
          visibleTags: _visibleTags,
          scheduleConflict: scheduleConflict,
          toggleDoneEnabled: toggleDoneEnabled,
          onToggleDone: onToggleDone,
          onSelectToggle: onSelectToggle,
          onPlay: onPlay,
          onOpenMenu: onOpenMenu,
          heightPx: heightPx,
        );
    }

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_PlanCardGeom.radius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: _PlanCardTokens.cardShadow(interacting),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_PlanCardGeom.radius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = heightPx ?? constraints.maxHeight;
            return Stack(
              fit: heightPx != null ? StackFit.expand : StackFit.passthrough,
              children: [
                _PlanCardWatermark(
                  icon: categoryIcon,
                  color: categoryTone,
                  density: density,
                  cardWidth: w.isFinite ? w : _PlanCardGeom.refWidth,
                  cardHeight: h.isFinite ? h : _PlanCardGeom.refHeight(density),
                ),
                if (heightPx != null)
                  SizedBox(
                    height: heightPx,
                    width: double.infinity,
                    child: body,
                  )
                else
                  body,
              ],
            );
          },
        ),
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_PlanCardGeom.radius),
        child: card,
      ),
    );
  }
}

// --- Figma geometry (328px reference) ----------------------------------------

abstract final class _PlanCardGeom {
  static const double refWidth = 328;
  static const double padLeft = 12;
  static const double padRight = 12;
  static const double padTopSmall = 10;
  static const double padTopMediumLarge = 12;
  static const double controlSize = 32;
  static const double playInlineX = 48;
  static const double contentXSmall = 84;
  static const double contentXMediumLarge = 56;
  static const double railWidth = 32;
  static const double railToContentGap = 12;
  static const double checkboxPlayGap = 8;
  static const double playAfterCheckboxGap = 4;
  static const double menuSize = 33;
  static const double contentSpanMediumLarge = 260;
  static const double radius = 12;
  static const double refHeightSmall = 54;
  static const double refHeightMedium = 95;
  static const double refHeightLarge = 147;
  static const double titleToTagsGap = 12;
  static const double footerBlockGap = 8;
  static const double dividerHeight = 1;
  static const double footerTextHeight = 8;
  static const double tagRowHeight = 16;
  static const double tagGap = 5;

  static double refHeight(PlanTimeTaskCardDensity d) => switch (d) {
        PlanTimeTaskCardDensity.compact => refHeightSmall,
        PlanTimeTaskCardDensity.medium => refHeightMedium,
        PlanTimeTaskCardDensity.large => refHeightLarge,
      };

  static double contentSpanWidth(double cardWidth) =>
      cardWidth - contentXMediumLarge - padRight;
}

// --- Visual tokens (design/CardPlan *.svg fallback) ---------------------------

abstract final class _PlanCardTokens {
  static const Color surface = Color(0xFFF8F8F8);
  static const Color titleColor = Color(0xFF353535);
  static const Color checkboxStroke = Color(0xFFCCCCCC);
  static const Color playFill = Color(0xFF696969);
  static const Color menuBg = Color(0xFFEBEBEB);
  static const Color menuStroke = Color(0xFF8E8E8E);
  static const Color dividerColor = Color(0x61D9D9D9);
  static const Color breadcrumbColor = Color(0xFF609CE1);
  static const Color timeColor = Color(0xB8878787);
  static const Color tagPinkBg = Color(0xFFFFE8E8);
  static const Color tagPinkText = Color(0xFFF55D88);
  static const Color tagPurpleBg = Color(0xFFEEE5F8);
  static const Color tagPurpleText = Color(0xFF7118E5);

  static List<BoxShadow> cardShadow(bool interacting) => [
        BoxShadow(
          color: const Color(0x0A000000),
          blurRadius: interacting ? 6 : 4,
          offset: const Offset(0, 4),
        ),
      ];
}

// --- CardPlan_Small -----------------------------------------------------------

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
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
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
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final showTagRow = visibleTags.isNotEmpty || timeLabel.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _PlanCardGeom.padLeft,
        _PlanCardGeom.padTopSmall,
        _PlanCardGeom.padRight,
        _PlanCardGeom.padTopSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanCardCheckbox(
            selectMode: selectMode,
            isSelected: isSelected,
            displayIsDone: displayIsDone,
            toggleDoneEnabled: toggleDoneEnabled,
            onToggleDone: onToggleDone,
            onSelectToggle: onSelectToggle,
          ),
          if (showPlay) ...[
            const SizedBox(width: _PlanCardGeom.playAfterCheckboxGap),
            _PlanCardPlayButton(onPlay: onPlay),
            const SizedBox(width: _PlanCardGeom.playAfterCheckboxGap),
          ] else
            SizedBox(
              width: _PlanCardGeom.contentXSmall -
                  _PlanCardGeom.padLeft -
                  _PlanCardGeom.controlSize,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _PlanCardTitleRow(
                  title: task.title,
                  displayIsDone: displayIsDone,
                  hasRepeat: hasRepeat,
                  maxLines: 1,
                ),
                if (showTagRow)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _PlanCardTagsRow(
                      tags: visibleTags,
                      trailing: timeLabel.isNotEmpty
                          ? _PlanCardTimeText(label: timeLabel)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          if (onOpenMenu != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _PlanCardMenuButton(onOpenMenu: onOpenMenu!),
            ),
        ],
      ),
    );
  }
}

// --- CardPlan_Medium ----------------------------------------------------------

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
    this.heightPx,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
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
  final double? heightPx;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final bounded = heightPx != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _PlanCardGeom.padLeft,
        _PlanCardGeom.padTopMediumLarge,
        _PlanCardGeom.padRight,
        _PlanCardGeom.padTopMediumLarge,
      ),
      child: SizedBox(
        height: bounded
            ? null
            : _PlanCardGeom.refHeightMedium -
                _PlanCardGeom.padTopMediumLarge * 2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlanCardControlRail(
              showPlay: showPlay,
              selectMode: selectMode,
              isSelected: isSelected,
              displayIsDone: displayIsDone,
              toggleDoneEnabled: toggleDoneEnabled,
              onToggleDone: onToggleDone,
              onSelectToggle: onSelectToggle,
              onPlay: onPlay,
            ),
            const SizedBox(width: _PlanCardGeom.railToContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _PlanCardTitleRow(
                                title: task.title,
                                displayIsDone: displayIsDone,
                                hasRepeat: hasRepeat,
                                maxLines: titleMaxLines,
                              ),
                            ),
                            if (visibleTags.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: _PlanCardGeom.titleToTagsGap,
                                ),
                                child: _PlanCardTagsRow(tags: visibleTags),
                              ),
                          ],
                        ),
                      ),
                      if (onOpenMenu != null)
                        _PlanCardMenuButton(onOpenMenu: onOpenMenu!),
                    ],
                  ),
                  if (bounded) const Spacer(),
                  const _PlanCardDividerLine(),
                  const SizedBox(height: _PlanCardGeom.footerBlockGap),
                  _PlanCardFooterRow(
                    categoryTrail: categoryTrail,
                    timeLabel: timeLabel,
                    scheduleConflict: scheduleConflict,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CardPlan_Large -----------------------------------------------------------

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
    this.heightPx,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.onOpenMenu,
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
  final double? heightPx;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onPlay;
  final void Function(BuildContext)? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final bounded = heightPx != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _PlanCardGeom.padLeft,
        _PlanCardGeom.padTopMediumLarge,
        _PlanCardGeom.padRight,
        _PlanCardGeom.padTopMediumLarge,
      ),
      child: SizedBox(
        height: bounded
            ? null
            : _PlanCardGeom.refHeightLarge -
                _PlanCardGeom.padTopMediumLarge * 2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlanCardControlRail(
              showPlay: showPlay,
              selectMode: selectMode,
              isSelected: isSelected,
              displayIsDone: displayIsDone,
              toggleDoneEnabled: toggleDoneEnabled,
              onToggleDone: onToggleDone,
              onSelectToggle: onSelectToggle,
              onPlay: onPlay,
              expandSpacer: true,
            ),
            const SizedBox(width: _PlanCardGeom.railToContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _PlanCardTitleRow(
                                title: task.title,
                                displayIsDone: displayIsDone,
                                hasRepeat: hasRepeat,
                                maxLines: 3,
                              ),
                            ),
                            if (visibleTags.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: _PlanCardGeom.titleToTagsGap,
                                ),
                                child: _PlanCardTagsRow(tags: visibleTags),
                              ),
                          ],
                        ),
                      ),
                      if (onOpenMenu != null)
                        _PlanCardMenuButton(onOpenMenu: onOpenMenu!),
                    ],
                  ),
                  if (bounded) const Spacer(),
                  const _PlanCardDividerLine(),
                  const SizedBox(height: _PlanCardGeom.footerBlockGap),
                  _PlanCardFooterRow(
                    categoryTrail: categoryTrail,
                    timeLabel: timeLabel,
                    scheduleConflict: scheduleConflict,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Shared parts -------------------------------------------------------------

class _PlanCardControlRail extends StatelessWidget {
  const _PlanCardControlRail({
    required this.showPlay,
    required this.selectMode,
    required this.isSelected,
    required this.displayIsDone,
    required this.toggleDoneEnabled,
    this.onToggleDone,
    this.onSelectToggle,
    this.onPlay,
    this.expandSpacer = false,
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PlanCardGeom.railWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PlanCardCheckbox(
            selectMode: selectMode,
            isSelected: isSelected,
            displayIsDone: displayIsDone,
            toggleDoneEnabled: toggleDoneEnabled,
            onToggleDone: onToggleDone,
            onSelectToggle: onSelectToggle,
          ),
          if (showPlay) ...[
            const SizedBox(height: _PlanCardGeom.checkboxPlayGap),
            _PlanCardPlayButton(onPlay: onPlay),
          ],
          if (expandSpacer) const Spacer(),
        ],
      ),
    );
  }
}

class _PlanCardCheckbox extends StatelessWidget {
  const _PlanCardCheckbox({
    required this.selectMode,
    required this.isSelected,
    required this.displayIsDone,
    required this.toggleDoneEnabled,
    this.onToggleDone,
    this.onSelectToggle,
  });

  final bool selectMode;
  final bool isSelected;
  final bool displayIsDone;
  final bool toggleDoneEnabled;
  final VoidCallback? onToggleDone;
  final VoidCallback? onSelectToggle;

  @override
  Widget build(BuildContext context) {
    final checked = selectMode ? isSelected : displayIsDone;
    final enabled = selectMode
        ? onSelectToggle != null
        : toggleDoneEnabled && onToggleDone != null;
    return Semantics(
      checked: checked,
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled
            ? (selectMode ? onSelectToggle : onToggleDone)
            : null,
        child: SizedBox(
          width: _PlanCardGeom.controlSize,
          height: _PlanCardGeom.controlSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _PlanCardTokens.checkboxStroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x38000000),
                  blurRadius: 4,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: checked
                ? const Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: _PlanCardTokens.playFill,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _PlanCardPlayButton extends StatelessWidget {
  const _PlanCardPlayButton({this.onPlay});

  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: t(currentLocale.value, 'start'),
      child: GestureDetector(
        onTap: onPlay,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _PlanCardGeom.controlSize,
          height: _PlanCardGeom.controlSize,
          child: Center(
            child: CustomPaint(
              size: const Size(16, 18),
              painter: const _PlanCardPlayIconPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCardPlayIconPainter extends CustomPainter {
  const _PlanCardPlayIconPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _PlanCardTokens.playFill
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.05)
      ..quadraticBezierTo(w * 0.92, h * 0.48, w * 0.92, h * 0.52)
      ..quadraticBezierTo(w * 0.92, h * 0.56, w * 0.08, h * 0.95)
      ..quadraticBezierTo(w * 0.02, h * 0.5, w * 0.08, h * 0.05)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlanCardMenuButton extends StatelessWidget {
  const _PlanCardMenuButton({required this.onOpenMenu});

  final void Function(BuildContext) onOpenMenu;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (menuCtx) => Semantics(
        button: true,
        label: t(currentLocale.value, 'plan_radial_menu_tip'),
        child: GestureDetector(
          onTap: () => onOpenMenu(menuCtx),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: _PlanCardGeom.menuSize,
            height: _PlanCardGeom.menuSize,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: _PlanCardTokens.menuBg,
                shape: BoxShape.circle,
              ),
              child: CustomPaint(
                painter: const _PlanCardMenuIconPainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCardMenuIconPainter extends CustomPainter {
  const _PlanCardMenuIconPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _PlanCardTokens.menuStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const pad = 11.0;
    final w = size.width;
    final midY1 = size.height * 0.36;
    final midY2 = size.height * 0.52;
    final midY3 = size.height * 0.68;
    canvas.drawLine(Offset(pad, midY1), Offset(w - pad - 6, midY1), paint);
    canvas.drawLine(Offset(pad, midY2), Offset(w - pad - 10, midY2), paint);
    canvas.drawLine(Offset(pad, midY3), Offset(w - pad - 6, midY3), paint);
    final bracket = Path()
      ..moveTo(w - pad - 2, midY2 + 6)
      ..lineTo(w - pad - 6, midY2)
      ..lineTo(w - pad - 2, midY2 - 6);
    canvas.drawPath(bracket, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlanCardTitleRow extends StatelessWidget {
  const _PlanCardTitleRow({
    required this.title,
    required this.displayIsDone,
    required this.hasRepeat,
    required this.maxLines,
  });

  final String title;
  final bool displayIsDone;
  final bool hasRepeat;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              height: 1.1,
              fontWeight: FontWeight.w400,
              decoration:
                  displayIsDone ? TextDecoration.lineThrough : null,
              color: displayIsDone
                  ? _PlanCardTokens.titleColor.withValues(alpha: 0.55)
                  : _PlanCardTokens.titleColor,
            ),
          ),
        ),
        if (hasRepeat)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.repeat_rounded,
              size: 15,
              color: _PlanCardTokens.breadcrumbColor.withValues(alpha: 0.85),
            ),
          ),
      ],
    );
  }
}

class _PlanCardTagsRow extends StatelessWidget {
  const _PlanCardTagsRow({
    required this.tags,
    this.trailing,
  });

  final List<Tag> tags;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _PlanCardGeom.tagRowHeight,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: tags.length.clamp(0, 4),
              separatorBuilder: (_, _) =>
                  const SizedBox(width: _PlanCardGeom.tagGap),
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
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _PlanCardTimeText extends StatelessWidget {
  const _PlanCardTimeText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        height: 1.0,
        fontWeight: FontWeight.w400,
        color: _PlanCardTokens.timeColor,
      ),
    );
  }
}

class _PlanCardDividerLine extends StatelessWidget {
  const _PlanCardDividerLine();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: _PlanCardGeom.dividerHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(color: _PlanCardTokens.dividerColor),
      ),
    );
  }
}

class _PlanCardFooterRow extends StatelessWidget {
  const _PlanCardFooterRow({
    required this.categoryTrail,
    required this.timeLabel,
    required this.scheduleConflict,
  });

  final String categoryTrail;
  final String timeLabel;
  final bool scheduleConflict;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _PlanCardGeom.footerTextHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (categoryTrail.isNotEmpty)
            Expanded(
              child: Text(
                categoryTrail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.0,
                  fontWeight: FontWeight.w400,
                  color: _PlanCardTokens.breadcrumbColor,
                ),
              ),
            ),
          if (timeLabel.isNotEmpty) ...[
            if (categoryTrail.isNotEmpty) const SizedBox(width: 8),
            _PlanCardTimeText(label: timeLabel),
            if (scheduleConflict)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 12,
                  color: scheme.error.withValues(alpha: 0.75),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PlanCardWatermark extends StatelessWidget {
  const _PlanCardWatermark({
    required this.icon,
    required this.color,
    required this.density,
    required this.cardWidth,
    required this.cardHeight,
  });

  final IconData? icon;
  final Color color;
  final PlanTimeTaskCardDensity density;
  final double cardWidth;
  final double cardHeight;

  static const double _opacity = 0.04;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox.shrink();

    final ref = switch (density) {
      PlanTimeTaskCardDensity.compact => (left: 213.0, top: 18.86, size: 102.68),
      PlanTimeTaskCardDensity.medium => (left: 183.0, top: 33.40, size: 149.80),
      PlanTimeTaskCardDensity.large => (left: 128.93, top: 60.01, size: 230.48),
    };

    final widthScale = cardWidth / _PlanCardGeom.refWidth;
    final wideBoost = widthScale > 1
        ? 1.0 + (widthScale - 1).clamp(0.0, 0.6) * 0.45
        : 1.0;
    final size = ref.size * wideBoost;
    final left = ref.left * widthScale;
    final top = ref.top * (cardHeight / _PlanCardGeom.refHeight(density));

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -0.457,
          child: Icon(
            icon,
            size: size,
            color: color.withValues(alpha: _opacity),
          ),
        ),
      ),
    );
  }
}

/// Maps timeline block metrics to CardPlan_Small / Medium / Large density.
PlanTimeTaskCardDensity planTimeCardDensityForBlock(
  double heightPx,
  int durationMin,
) {
  if (heightPx < 59 || durationMin <= 35) {
    return PlanTimeTaskCardDensity.compact;
  }
  if (heightPx < 121) {
    return PlanTimeTaskCardDensity.medium;
  }
  return PlanTimeTaskCardDensity.large;
}
