import 'package:counter/core/app_colors.dart';
import 'package:flutter/material.dart';

enum LifeCardState { normal, selected, completed, disabled, active }

enum LifeCardDensity { regular, compact }

enum AppTaskCardType { task, backlog, timeline }

class LifeCard extends StatelessWidget {
  const LifeCard({
    super.key,
    required this.child,
    this.state = LifeCardState.normal,
    this.density = LifeCardDensity.regular,
    this.onTap,
    this.leadingAccentColor,
    this.semanticLabel,
  });

  final Widget child;
  final LifeCardState state;
  final LifeCardDensity density;
  final VoidCallback? onTap;
  final Color? leadingAccentColor;
  final String? semanticLabel;

  bool get _isDisabled => state == LifeCardState.disabled;
  bool get _isSelected => state == LifeCardState.selected;
  bool get _isCompleted => state == LifeCardState.completed;
  bool get _isActive => state == LifeCardState.active;

  EdgeInsetsGeometry get _padding => switch (density) {
    LifeCardDensity.compact => const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    LifeCardDensity.regular => const EdgeInsets.all(14),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = leadingAccentColor ?? scheme.primary;
    final borderColor = _isSelected || _isActive
        ? scheme.primary
        : scheme.outlineVariant;
    final background = _isSelected
        ? scheme.primaryContainer.withValues(alpha: 0.45)
        : AppColors.cardSurface;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: _isSelected || _isActive ? 1.5 : 1,
        ),
        boxShadow: [
          if (!_isDisabled)
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
              blurRadius: _isSelected || _isActive ? 14 : 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      foregroundDecoration: _isCompleted
          ? BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(18),
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: _padding,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: _isDisabled
                          ? scheme.onSurface.withValues(alpha: 0.45)
                          : scheme.onSurface,
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: _isDisabled
                            ? scheme.onSurface.withValues(alpha: 0.42)
                            : scheme.onSurfaceVariant,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null && !_isDisabled,
      selected: _isSelected,
      enabled: !_isDisabled,
      child: Opacity(
        opacity: _isDisabled ? 0.62 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _isDisabled ? null : onTap,
            child: card,
          ),
        ),
      ),
    );
  }
}

class AppTaskCard extends StatelessWidget {
  const AppTaskCard({
    super.key,
    required this.title,
    this.subtitle,
    this.state = LifeCardState.normal,
    this.density = LifeCardDensity.regular,
    this.type = AppTaskCardType.task,
    this.categoryColor,
    this.leadingIcon,
    this.trailing,
    this.tags = const [],
    this.checklistCount,
    this.notes,
    this.repeats = false,
    this.timeLabel,
    this.activeLabel,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final LifeCardState state;
  final LifeCardDensity density;
  final AppTaskCardType type;
  final Color? categoryColor;
  final IconData? leadingIcon;
  final Widget? trailing;
  final List<String> tags;
  final int? checklistCount;
  final String? notes;
  final bool repeats;
  final String? timeLabel;
  final String? activeLabel;
  final VoidCallback? onTap;

  bool get _isCompleted => state == LifeCardState.completed;
  bool get _isActive => state == LifeCardState.active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent =
        categoryColor ??
        switch (type) {
          AppTaskCardType.task => scheme.primary,
          AppTaskCardType.backlog => scheme.secondary,
          AppTaskCardType.timeline => scheme.tertiary,
        };
    final icon =
        leadingIcon ??
        switch (type) {
          AppTaskCardType.task => Icons.check_circle_outline_rounded,
          AppTaskCardType.backlog => Icons.inbox_outlined,
          AppTaskCardType.timeline => Icons.timer_outlined,
        };
    final titleStyle =
        (density == LifeCardDensity.compact
                ? theme.textTheme.titleSmall
                : theme.textTheme.titleMedium)
            ?.copyWith(
              fontWeight: FontWeight.w700,
              decoration: _isCompleted ? TextDecoration.lineThrough : null,
              color: state == LifeCardState.disabled
                  ? scheme.onSurface.withValues(alpha: 0.48)
                  : scheme.onSurface,
            );
    return LifeCard(
      state: state,
      density: density,
      onTap: onTap,
      leadingAccentColor: accent,
      semanticLabel: title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: density == LifeCardDensity.compact ? 30 : 36,
            height: density == LifeCardDensity.compact ? 30 : 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isCompleted ? Icons.check_rounded : icon,
              color: accent,
              size: density == LifeCardDensity.compact ? 17 : 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(title, style: titleStyle)),
                    if (_isActive && (activeLabel ?? '').isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _TaskMetaPill(
                        icon: Icons.radio_button_checked_rounded,
                        label: activeLabel!,
                        color: scheme.tertiary,
                      ),
                    ],
                  ],
                ),
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_hasMetadata) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if ((timeLabel ?? '').isNotEmpty)
                        _TaskMetaPill(
                          icon: Icons.schedule_rounded,
                          label: timeLabel!,
                        ),
                      if (checklistCount != null)
                        _TaskMetaPill(
                          icon: Icons.checklist_rounded,
                          label: '$checklistCount',
                        ),
                      if ((notes ?? '').isNotEmpty)
                        _TaskMetaPill(icon: Icons.notes_rounded, label: notes!),
                      if (repeats)
                        const _TaskMetaPill(
                          icon: Icons.repeat_rounded,
                          label: 'Repeat',
                        ),
                      for (final tag in tags) _TaskTagPill(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }

  bool get _hasMetadata =>
      (timeLabel ?? '').isNotEmpty ||
      checklistCount != null ||
      (notes ?? '').isNotEmpty ||
      repeats ||
      tags.isNotEmpty;
}

class _TaskMetaPill extends StatelessWidget {
  const _TaskMetaPill({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c),
          ),
        ],
      ),
    );
  }
}

class _TaskTagPill extends StatelessWidget {
  const _TaskTagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
