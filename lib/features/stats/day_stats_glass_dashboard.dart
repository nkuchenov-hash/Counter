import 'dart:math' as math;

import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/features/stats/day_stats_dashboard.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Production-facing visual layer for daily statistics.
///
/// The existing [DayStatsDashboardData] aggregation and the legacy expandable
/// details tree stay untouched. This widget only changes presentation.
class DayStatsGlassDashboard extends StatelessWidget {
  const DayStatsGlassDashboard({
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
              final segmentWidth = math.max(
                compact ? 64.0 : 78.0,
                math.min(compact ? 88.0 : 116.0, constraints.maxWidth / 4),
              );
              return SizedBox(
                height: kAppCompactControlHeight,
                child: SegmentedButton<DayStatsDashboardMode>(
                  showSelectedIcon: false,
                  style: appCompactSegmentedButtonStyle(
                    context,
                    segmentWidth: segmentWidth,
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
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (mode) {
      case DayStatsDashboardMode.overview:
        return _OverviewGlass(data: data);
      case DayStatsDashboardMode.timeline:
        return _TimelineGlass(data: data);
      case DayStatsDashboardMode.categories:
        return _CategoriesGlass(data: data);
      case DayStatsDashboardMode.details:
        // Important: this is the old summed + expandable daily record tree.
        return detailsView;
    }
  }
}

class _OverviewGlass extends StatelessWidget {
  const _OverviewGlass({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 680;
        if (narrow) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
            children: [
              _SummaryHero(data: data, compact: true),
              const SizedBox(height: 12),
              _VerticalDayPanel(data: data),
              const SizedBox(height: 12),
              _CategoryBreakdownPanel(data: data),
              const SizedBox(height: 12),
              _SignalsPanel(data: data),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          children: [
            _SummaryHero(data: data, compact: false),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _CategoryBreakdownPanel(data: data)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _SignalsPanel(data: data)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.data, required this.compact});

  final DayStatsDashboardData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final longest = data.longestSession;
    final sortedCategories = [...data.categories]
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    final top = sortedCategories.isNotEmpty ? sortedCategories.first : null;

    return _GlassPanel(
      accent: top?.color,
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    icon: Icons.schedule_rounded,
                    value: _formatDuration(data.totalSeconds),
                    label: t(currentLocale.value, 'total'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroMetric(
                    icon: Icons.view_agenda_outlined,
                    value: '${data.sessions.length}',
                    label: t(currentLocale.value, 'stats_pvf_row_tasks'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _HeroMetric(
                    icon: Icons.schedule_rounded,
                    value: _formatDuration(data.totalSeconds),
                    label: t(currentLocale.value, 'total'),
                    large: true,
                  ),
                ),
                const _SoftDivider(),
                Expanded(
                  child: _HeroMetric(
                    icon: Icons.view_agenda_outlined,
                    value: '${data.sessions.length}',
                    label: t(currentLocale.value, 'stats_pvf_row_tasks'),
                  ),
                ),
                const _SoftDivider(),
                Expanded(
                  child: _HeroMetric(
                    icon: longest?.icon ?? Icons.timelapse_rounded,
                    value: longest == null
                        ? '—'
                        : _formatDuration(longest.seconds),
                    label: t(currentLocale.value, 'long_duration'),
                    accent: longest?.color,
                  ),
                ),
              ],
            ),
          if (!compact) ...[
            const SizedBox(height: 24),
            _HorizontalDayRibbon(data: data),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (large
                  ? Theme.of(context).textTheme.headlineMedium
                  : Theme.of(context).textTheme.titleLarge)
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
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

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.35),
    );
  }
}

class _HorizontalDayRibbon extends StatelessWidget {
  const _HorizontalDayRibbon({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalDaySeconds = const Duration(days: 1).inSeconds.toDouble();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('00'),
            Text('06'),
            Text('12'),
            Text('18'),
            Text('24'),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 38,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.55,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.32),
                        ),
                      ),
                    ),
                  ),
                  for (final session in data.sessions)
                    Builder(
                      builder: (context) {
                        final start = session.startWall
                            .difference(data.selectedDate)
                            .inSeconds
                            .clamp(0, totalDaySeconds.toInt())
                            .toDouble();
                        final end = session.endWall
                            .difference(data.selectedDate)
                            .inSeconds
                            .clamp(0, totalDaySeconds.toInt())
                            .toDouble();
                        final left = constraints.maxWidth * start / totalDaySeconds;
                        final rawWidth =
                            constraints.maxWidth * (end - start) / totalDaySeconds;
                        final width = math.max(4.0, rawWidth);
                        return Positioned(
                          left: left,
                          top: 4,
                          bottom: 4,
                          width: math.min(
                            width,
                            math.max(0.0, constraints.maxWidth - left),
                          ),
                          child: Tooltip(
                            message:
                                '${session.title} · ${_formatDuration(session.seconds)}',
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: session.color.withValues(alpha: 0.86),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: session.color.withValues(alpha: 0.24),
                                    blurRadius: 12,
                                    spreadRadius: 1,
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
            );
          },
        ),
      ],
    );
  }
}

class _TimelineGlass extends StatelessWidget {
  const _TimelineGlass({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 680;
        return ListView(
          padding: EdgeInsets.fromLTRB(narrow ? 12 : 16, 8, narrow ? 12 : 16, 28),
          children: [
            if (narrow)
              _VerticalDayPanel(data: data)
            else
              _ChronologicalDayPanel(data: data),
          ],
        );
      },
    );
  }
}

class _VerticalDayPanel extends StatelessWidget {
  const _VerticalDayPanel({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const chartHeight = 690.0;
    const axisX = 40.0;
    const contentLeft = 58.0;
    final formatter = DateFormat.Hm(currentLocale.value);

    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'timeline'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final blockWidth = math.max(0.0, constraints.maxWidth - contentLeft);
              return SizedBox(
                height: chartHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: axisX,
                      top: 8,
                      bottom: 8,
                      child: Container(
                        width: 1.5,
                        color: scheme.outlineVariant.withValues(alpha: 0.50),
                      ),
                    ),
                    for (final hour in const [0, 6, 12, 18, 24]) ...[
                      Positioned(
                        top: (hour / 24) * (chartHeight - 20),
                        left: 0,
                        width: 32,
                        child: Text(
                          hour.toString().padLeft(2, '0'),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Positioned(
                        top: (hour / 24) * (chartHeight - 20) + 6,
                        left: axisX - 3,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.outlineVariant,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                    for (final session in data.sessions)
                      Builder(
                        builder: (context) {
                          final startMinutes = session.startWall
                              .difference(data.selectedDate)
                              .inMinutes
                              .clamp(0, 1440);
                          final endMinutes = session.endWall
                              .difference(data.selectedDate)
                              .inMinutes
                              .clamp(0, 1440);
                          final top =
                              (startMinutes / 1440) * (chartHeight - 20) + 2;
                          final rawHeight =
                              ((endMinutes - startMinutes) / 1440) *
                              (chartHeight - 20);
                          final height = math.max(30.0, rawHeight);
                          final safeHeight = math.min(
                            height,
                            math.max(18.0, chartHeight - top - 2),
                          );
                          return Positioned(
                            top: top,
                            left: contentLeft,
                            width: blockWidth,
                            height: safeHeight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: session.color.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: session.color.withValues(alpha: 0.35),
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if (safeHeight >= 42)
                                          Text(
                                            '${formatter.format(session.startWall)} — ${formatter.format(session.endWall)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDuration(session.seconds),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
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

class _ChronologicalDayPanel extends StatelessWidget {
  const _ChronologicalDayPanel({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat.Hm(currentLocale.value);
    final scheme = Theme.of(context).colorScheme;
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'timeline'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < data.sessions.length; index++)
            _ChronologicalRow(
              session: data.sessions[index],
              formatter: formatter,
              showLine: index < data.sessions.length - 1,
              scheme: scheme,
            ),
        ],
      ),
    );
  }
}

class _ChronologicalRow extends StatelessWidget {
  const _ChronologicalRow({
    required this.session,
    required this.formatter,
    required this.showLine,
    required this.scheme,
  });

  final DayStatsSession session;
  final DateFormat formatter;
  final bool showLine;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatter.format(session.startWall)} — ${formatter.format(session.endWall)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  _formatDuration(session.seconds),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: session.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: session.color.withValues(alpha: 0.30),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: session.color.withValues(alpha: 0.20),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(session.icon, size: 20, color: session.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w750,
                            ),
                          ),
                          const SizedBox(height: 2),
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
                    const SizedBox(width: 12),
                    Text(
                      _formatDuration(session.seconds),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: session.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownPanel extends StatelessWidget {
  const _CategoryBreakdownPanel({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final categories = [...data.categories]
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'stats_pvf_by_category'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _ShareSpectrum(categories: categories),
          const SizedBox(height: 16),
          for (final category in categories.take(7))
            _CategorySummaryRow(
              category: category,
              totalSeconds: data.totalSeconds,
            ),
        ],
      ),
    );
  }
}

class _CategoriesGlass extends StatelessWidget {
  const _CategoriesGlass({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final categories = [...data.categories]
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      children: [
        _GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(currentLocale.value, 'stats_pvf_by_category'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _ShareSpectrum(categories: categories),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CategoryGlassCard(
              category: category,
              totalSeconds: data.totalSeconds,
            ),
          ),
      ],
    );
  }
}

class _CategoryGlassCard extends StatelessWidget {
  const _CategoryGlassCard({required this.category, required this.totalSeconds});

  final DayStatsCategorySlice category;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final share = totalSeconds > 0 ? category.seconds / totalSeconds : 0.0;
    return _GlassPanel(
      accent: category.color,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(category.icon, color: category.color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w750),
                ),
              ),
              Text(
                _formatDuration(category.seconds),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: category.color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(share * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              color: category.color,
              backgroundColor: scheme.surfaceContainerHighest.withValues(
                alpha: 0.60,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSpectrum extends StatelessWidget {
  const _ShareSpectrum({required this.categories});

  final List<DayStatsCategorySlice> categories;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (categories.isEmpty) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (final category in categories)
              Expanded(
                flex: math.max(1, category.seconds),
                child: ColoredBox(
                  color: category.color.withValues(alpha: 0.86),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategorySummaryRow extends StatelessWidget {
  const _CategorySummaryRow({
    required this.category,
    required this.totalSeconds,
  });

  final DayStatsCategorySlice category;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final share = totalSeconds > 0 ? category.seconds / totalSeconds : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(category.icon, color: category.color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0).toDouble(),
                    minHeight: 4,
                    color: category.color,
                    backgroundColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDuration(category.seconds),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
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
      ),
    );
  }
}

class _SignalsPanel extends StatelessWidget {
  const _SignalsPanel({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final sorted = [...data.categories]
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    final top = sorted.isNotEmpty ? sorted.first : null;
    final longest = data.longestSession;

    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'stats'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _SignalTile(
            icon: Icons.timelapse_rounded,
            label: t(currentLocale.value, 'long_duration'),
            value: longest == null ? '—' : _formatDuration(longest.seconds),
            supporting: longest?.title,
            accent: longest?.color,
          ),
          _SignalTile(
            icon: top?.icon ?? Icons.category_outlined,
            label: t(currentLocale.value, 'category_label'),
            value: top?.label ?? '—',
            supporting: top == null ? null : _formatDuration(top.seconds),
            accent: top?.color,
          ),
          _SignalTile(
            icon: Icons.view_agenda_outlined,
            label: t(currentLocale.value, 'stats_pvf_row_tasks'),
            value: '${data.sessions.length}',
          ),
          _SignalTile(
            icon: Icons.schedule_rounded,
            label: t(currentLocale.value, 'total'),
            value: _formatDuration(data.totalSeconds),
          ),
        ],
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
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
          const SizedBox(width: 10),
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.055),
            blurRadius: dark ? 22 : 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface.withValues(alpha: dark ? 0.82 : 0.94),
                Color.alphaBlend(
                  glow.withValues(alpha: dark ? 0.055 : 0.035),
                  scheme.surface.withValues(alpha: dark ? 0.72 : 0.86),
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

String _formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '0:00';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
