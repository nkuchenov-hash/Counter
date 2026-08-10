import 'dart:math' as math;

import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/features/stats/day_stats_dashboard.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Responsive presentation for Timeline > Stats.
///
/// Data aggregation stays in [DayStatsDashboardData]. The existing expandable
/// daily stats tree is injected through [detailsView] and remains fully usable.
class DayStatsGlassView extends StatelessWidget {
  const DayStatsGlassView({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.data,
    required this.detailsView,
  });

  final DayStatsDashboardMode mode;
  final ValueChanged<DayStatsDashboardMode> onModeChanged;
  final DayStatsDashboardData data;
  final Widget detailsView;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final width = math.max(
                compact ? 64.0 : 78.0,
                math.min(compact ? 88.0 : 116.0, constraints.maxWidth / 4),
              );
              return SizedBox(
                height: kAppCompactControlHeight,
                child: SegmentedButton<DayStatsDashboardMode>(
                  showSelectedIcon: false,
                  style: appCompactSegmentedButtonStyle(
                    context,
                    segmentWidth: width,
                  ),
                  segments: [
                    ButtonSegment(
                      value: DayStatsDashboardMode.overview,
                      icon: const Icon(Icons.dashboard_rounded),
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'stats'),
                      ),
                    ),
                    ButtonSegment(
                      value: DayStatsDashboardMode.timeline,
                      icon: const Icon(Icons.view_day_rounded),
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'timeline'),
                      ),
                    ),
                    ButtonSegment(
                      value: DayStatsDashboardMode.categories,
                      icon: const Icon(Icons.category_rounded),
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'categories'),
                      ),
                    ),
                    ButtonSegment(
                      value: DayStatsDashboardMode.details,
                      icon: const Icon(Icons.account_tree_rounded),
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'list'),
                      ),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) onModeChanged(selection.first);
                  },
                ),
              );
            },
          ),
        ),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    switch (mode) {
      case DayStatsDashboardMode.overview:
        return _Overview(data: data);
      case DayStatsDashboardMode.timeline:
        return _DayView(data: data);
      case DayStatsDashboardMode.categories:
        return _Categories(data: data);
      case DayStatsDashboardMode.details:
        // Preserves the original summed/expandable per-day statistics.
        return detailsView;
    }
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 680;
        return ListView(
          padding: EdgeInsets.fromLTRB(mobile ? 12 : 16, 8, mobile ? 12 : 16, 28),
          children: [
            _Hero(data: data, compact: mobile),
            const SizedBox(height: 12),
            if (mobile) ...[
              _VerticalDay(data: data),
              const SizedBox(height: 12),
              _CategoryPanel(data: data),
              const SizedBox(height: 12),
              _Signals(data: data),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _CategoryPanel(data: data)),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: _Signals(data: data)),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data, required this.compact});
  final DayStatsDashboardData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final longest = data.longestSession;
    final sorted = [...data.categories]..sort((a, b) => b.seconds.compareTo(a.seconds));
    final accent = sorted.isEmpty ? null : sorted.first.color;
    return _Glass(
      accent: accent,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: compact ? 1 : 2,
                child: _Metric(
                  icon: Icons.schedule_rounded,
                  value: _duration(data.totalSeconds),
                  label: t(currentLocale.value, 'total'),
                  large: !compact,
                ),
              ),
              _divider(context, compact),
              Expanded(
                child: _Metric(
                  icon: Icons.view_agenda_outlined,
                  value: '${data.sessions.length}',
                  label: t(currentLocale.value, 'stats_pvf_row_tasks'),
                ),
              ),
              if (!compact) ...[
                _divider(context, false),
                Expanded(
                  child: _Metric(
                    icon: longest?.icon ?? Icons.timelapse_rounded,
                    value: longest == null ? '—' : _duration(longest.seconds),
                    label: t(currentLocale.value, 'long_duration'),
                    accent: longest?.color,
                  ),
                ),
              ],
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 22),
            _HorizontalDay(data: data),
          ],
        ],
      ),
    );
  }

  Widget _divider(BuildContext context, bool short) => Container(
        width: 1,
        height: short ? 58 : 70,
        margin: EdgeInsets.symmetric(horizontal: short ? 12 : 18),
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
    this.large = false,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color? accent;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 9),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (large
                  ? Theme.of(context).textTheme.headlineMedium
                  : Theme.of(context).textTheme.titleLarge)
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _HorizontalDay extends StatelessWidget {
  const _HorizontalDay({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const daySeconds = 86400.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [Text('00'), Text('06'), Text('12'), Text('18'), Text('24')],
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, c) => SizedBox(
            height: 36,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.50),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
                for (final session in data.sessions)
                  Builder(
                    builder: (_) {
                      final start = session.startWall
                          .difference(data.selectedDate)
                          .inSeconds
                          .clamp(0, 86400)
                          .toDouble();
                      final end = session.endWall
                          .difference(data.selectedDate)
                          .inSeconds
                          .clamp(0, 86400)
                          .toDouble();
                      final left = c.maxWidth * start / daySeconds;
                      final width = math.max(4.0, c.maxWidth * (end - start) / daySeconds);
                      return Positioned(
                        left: left,
                        top: 4,
                        bottom: 4,
                        width: math.min(width, math.max(0.0, c.maxWidth - left)),
                        child: Tooltip(
                          message: '${session.title} · ${_duration(session.seconds)}',
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: session.color.withValues(alpha: 0.86),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: session.color.withValues(alpha: 0.22),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 680;
        return ListView(
          padding: EdgeInsets.fromLTRB(mobile ? 12 : 16, 8, mobile ? 12 : 16, 28),
          children: [
            mobile ? _VerticalDay(data: data) : _ChronologicalDay(data: data),
          ],
        );
      },
    );
  }
}

/// Mobile-first spatial representation of the full 24-hour day.
class _VerticalDay extends StatelessWidget {
  const _VerticalDay({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat.Hm(currentLocale.value);
    const height = 690.0;
    const axisX = 38.0;
    const left = 56.0;
    return _Glass(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'timeline'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final itemWidth = math.max(0.0, c.maxWidth - left);
              return SizedBox(
                height: height,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: axisX,
                      top: 8,
                      bottom: 8,
                      child: Container(
                        width: 1.5,
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    for (final hour in const [0, 6, 12, 18, 24]) ...[
                      Positioned(
                        top: (hour / 24) * (height - 22),
                        left: 0,
                        width: 30,
                        child: Text(
                          hour.toString().padLeft(2, '0'),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      Positioned(
                        top: (hour / 24) * (height - 22) + 5,
                        left: axisX - 3,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.surface,
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                        ),
                      ),
                    ],
                    for (final session in data.sessions)
                      Builder(
                        builder: (_) {
                          final start = session.startWall
                              .difference(data.selectedDate)
                              .inMinutes
                              .clamp(0, 1440);
                          final end = session.endWall
                              .difference(data.selectedDate)
                              .inMinutes
                              .clamp(0, 1440);
                          final top = (start / 1440) * (height - 22) + 2;
                          final rawHeight = ((end - start) / 1440) * (height - 22);
                          final blockHeight = math.min(
                            math.max(30.0, rawHeight),
                            math.max(18.0, height - top - 2),
                          );
                          return Positioned(
                            top: top,
                            left: left,
                            width: itemWidth,
                            height: blockHeight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: session.color.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: session.color.withValues(alpha: 0.34),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    decoration: BoxDecoration(
                                      color: session.color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if (blockHeight >= 42)
                                          Text(
                                            '${fmt.format(session.startWall)} — ${fmt.format(session.endWall)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _duration(session.seconds),
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: session.color,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChronologicalDay extends StatelessWidget {
  const _ChronologicalDay({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.Hm(currentLocale.value);
    final scheme = Theme.of(context).colorScheme;
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'timeline'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          for (final session in data.sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      '${fmt.format(session.startWall)} — ${fmt.format(session.endWall)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: session.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          Icon(session.icon, size: 19, color: session.color),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                Text(
                                  session.categoryLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _duration(session.seconds),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: session.color,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final categories = [...data.categories]..sort((a, b) => b.seconds.compareTo(a.seconds));
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'stats_pvf_by_category'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          _Spectrum(categories: categories),
          const SizedBox(height: 14),
          for (final category in categories.take(7))
            _CategoryRow(category: category, totalSeconds: data.totalSeconds),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final categories = [...data.categories]..sort((a, b) => b.seconds.compareTo(a.seconds));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      children: [
        _Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(currentLocale.value, 'stats_pvf_by_category'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              _Spectrum(categories: categories),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Glass(
              accent: category.color,
              padding: const EdgeInsets.all(14),
              child: _CategoryRow(
                category: category,
                totalSeconds: data.totalSeconds,
                showProgress: true,
              ),
            ),
          ),
      ],
    );
  }
}

class _Spectrum extends StatelessWidget {
  const _Spectrum({required this.categories});
  final List<DayStatsCategorySlice> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox(height: 12);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (final category in categories)
              Expanded(
                flex: math.max(1, category.seconds),
                child: ColoredBox(color: category.color.withValues(alpha: 0.86)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.totalSeconds,
    this.showProgress = false,
  });
  final DayStatsCategorySlice category;
  final int totalSeconds;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final share = totalSeconds > 0 ? category.seconds / totalSeconds : 0.0;
    final row = Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(category.icon, size: 17, color: category.color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            category.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Text(
          _duration(category.seconds),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            '${(share * 100).round()}%',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
    if (!showProgress) {
      return Padding(padding: const EdgeInsets.only(bottom: 10), child: row);
    }
    return Column(
      children: [
        row,
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            color: category.color,
            backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _Signals extends StatelessWidget {
  const _Signals({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final categories = [...data.categories]..sort((a, b) => b.seconds.compareTo(a.seconds));
    final top = categories.isEmpty ? null : categories.first;
    final longest = data.longestSession;
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'stats'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          _Signal(
            icon: Icons.timelapse_rounded,
            label: t(currentLocale.value, 'long_duration'),
            value: longest == null ? '—' : _duration(longest.seconds),
            supporting: longest?.title,
            accent: longest?.color,
          ),
          _Signal(
            icon: top?.icon ?? Icons.category_outlined,
            label: t(currentLocale.value, 'category_label'),
            value: top?.label ?? '—',
            supporting: top == null ? null : _duration(top.seconds),
            accent: top?.color,
          ),
          _Signal(
            icon: Icons.view_agenda_outlined,
            label: t(currentLocale.value, 'stats_pvf_row_tasks'),
            value: '${data.sessions.length}',
          ),
          _Signal(
            icon: Icons.schedule_rounded,
            label: t(currentLocale.value, 'total'),
            value: _duration(data.totalSeconds),
          ),
        ],
      ),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({
    required this.icon,
    required this.label,
    required this.value,
    this.supporting,
    this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? supporting;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (supporting != null && supporting!.isNotEmpty)
                  Text(
                    supporting!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.all(17),
    this.accent,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final glow = accent ?? scheme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.17 : 0.055),
            blurRadius: dark ? 20 : 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface.withValues(alpha: dark ? 0.84 : 0.95),
                Color.alphaBlend(
                  glow.withValues(alpha: dark ? 0.055 : 0.035),
                  scheme.surface.withValues(alpha: dark ? 0.74 : 0.88),
                ),
              ],
            ),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.82),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

String _duration(int secondsTotal) {
  if (secondsTotal <= 0) return '0:00';
  final hours = secondsTotal ~/ 3600;
  final minutes = (secondsTotal % 3600) ~/ 60;
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}';
  final seconds = secondsTotal % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
