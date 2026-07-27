import 'dart:math' as math;

import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum DayStatsDashboardMode { overview, timeline, categories, details }

class DayStatsCategorySlice {
  const DayStatsCategorySlice({
    required this.label,
    required this.seconds,
    required this.color,
    required this.icon,
  });

  final String label;
  final int seconds;
  final Color color;
  final IconData icon;
}

class DayStatsSession {
  const DayStatsSession({
    required this.title,
    required this.categoryLabel,
    required this.startWall,
    required this.endWall,
    required this.seconds,
    required this.color,
    required this.icon,
    required this.isRunning,
  });

  final String title;
  final String categoryLabel;
  final DateTime startWall;
  final DateTime endWall;
  final int seconds;
  final Color color;
  final IconData icon;
  final bool isRunning;
}

class DayStatsDashboardData {
  const DayStatsDashboardData({
    required this.selectedDate,
    required this.totalSeconds,
    required this.categories,
    required this.sessions,
  });

  final DateTime selectedDate;
  final int totalSeconds;
  final List<DayStatsCategorySlice> categories;
  final List<DayStatsSession> sessions;

  DayStatsSession? get longestSession {
    DayStatsSession? longest;
    for (final session in sessions) {
      if (longest == null || session.seconds > longest.seconds) {
        longest = session;
      }
    }
    return longest;
  }

  static DayStatsDashboardData build({
    required List<Map<String, dynamic>> records,
    required List<CategoryRule> rules,
    required List<StatsNode> aggregated,
    required DateTime selectedDate,
  }) {
    final rootByCategoryId = <int, CategoryRule>{};
    final rootByName = <String, CategoryRule>{};

    void register(CategoryRule rule, CategoryRule root) {
      rootByCategoryId[rule.id] = root;
      for (final child in rule.children ?? const <CategoryRule>[]) {
        register(child, root);
      }
    }

    for (final root in rules) {
      rootByName[root.name.trim().toLowerCase()] = root;
      for (final localized in root.localizedNames?.values ?? const <String>[]) {
        final normalized = localized.trim().toLowerCase();
        if (normalized.isNotEmpty) rootByName[normalized] = root;
      }
      register(root, root);
    }

    const fallbackColor = Color(0xFF8A8A8A);
    const fallbackIcon = Icons.folder_rounded;

    final categories = aggregated
        .where((node) => node.totalSeconds > 0)
        .map((node) {
          final rule = rootByName[node.label.trim().toLowerCase()];
          return DayStatsCategorySlice(
            label: node.label,
            seconds: node.totalSeconds,
            color: rule?.colorOrDefault ?? fallbackColor,
            icon: rule?.iconOrDefault ?? fallbackIcon,
          );
        })
        .toList(growable: false);

    final dayStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final sessions = <DayStatsSession>[];

    for (final record in records) {
      final startUtc = CategoryServiceExtension.startTimeFromRecord(record);
      if (startUtc == null) continue;

      final status = (record['status'] as String? ?? '').toLowerCase();
      final isRunning = status == 'running';
      final endUtc =
          CategoryServiceExtension.endTimeFromRecord(record) ??
          (isRunning ? DatabaseService.getPlanetaryNow() : null);
      if (endUtc == null) continue;

      final seconds =
          CategoryServiceExtension.recordDurationSecondsWithinDayFromTimestamps(
            record,
            selectedDate,
            DatabaseService.instance.settings.timezoneOffsetHours,
            DatabaseService.instance.settings.preferredTimeZone,
          );
      if (seconds <= 0) continue;

      var startWall = DatabaseService.instance.applyUserOffset(startUtc);
      var endWall = DatabaseService.instance.applyUserOffset(endUtc);
      if (startWall.isBefore(dayStart)) startWall = dayStart;
      if (endWall.isAfter(dayEnd)) endWall = dayEnd;
      if (!endWall.isAfter(startWall)) continue;

      final rawCategoryId =
          record['categoryId'] ?? record['category_id'] ?? record['category'];
      final categoryId = rawCategoryId is int
          ? rawCategoryId
          : int.tryParse(rawCategoryId?.toString() ?? '');
      final root = categoryId != null ? rootByCategoryId[categoryId] : null;
      final rawTitle = (record['title'] as String?)?.trim();
      final title = rawTitle != null && rawTitle.isNotEmpty
          ? rawTitle
          : t(currentLocale.value, 'untitled');

      sessions.add(
        DayStatsSession(
          title: title,
          categoryLabel: root != null
              ? localizeCategoryBreadcrumbPath(root.name, currentLocale.value)
              : t(currentLocale.value, 'uncategorized'),
          startWall: startWall,
          endWall: endWall,
          seconds: seconds,
          color: root?.colorOrDefault ?? fallbackColor,
          icon: root?.iconOrDefault ?? fallbackIcon,
          isRunning: isRunning,
        ),
      );
    }

    sessions.sort((a, b) => a.startWall.compareTo(b.startWall));
    final totalSeconds = aggregated.fold<int>(
      0,
      (sum, node) => sum + node.totalSeconds,
    );

    return DayStatsDashboardData(
      selectedDate: dayStart,
      totalSeconds: totalSeconds,
      categories: categories,
      sessions: sessions,
    );
  }
}

class DayStatsDashboard extends StatelessWidget {
  const DayStatsDashboard({
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = math.max(
                72.0,
                math.min(108.0, constraints.maxWidth / 4),
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
                      icon: const Icon(Icons.view_timeline_rounded),
                      label: AppCompactSegmentLabel(
                        text: t(currentLocale.value, 'timeline'),
                      ),
                    ),
                    ButtonSegment(
                      value: DayStatsDashboardMode.categories,
                      icon: const Icon(Icons.donut_large_rounded),
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
        const Divider(height: 1),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (mode) {
      case DayStatsDashboardMode.overview:
        return _OverviewView(data: data);
      case DayStatsDashboardMode.timeline:
        return _TimelineView(data: data);
      case DayStatsDashboardMode.categories:
        return _CategoriesView(data: data);
      case DayStatsDashboardMode.details:
        return detailsView;
    }
  }
}

class _OverviewView extends StatelessWidget {
  const _OverviewView({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final topCategory = data.categories.isNotEmpty
        ? data.categories.first
        : null;
    final longest = data.longestSession;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.schedule_rounded,
                    label: t(currentLocale.value, 'total'),
                    value: _formatDuration(data.totalSeconds),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.view_agenda_outlined,
                    label: t(currentLocale.value, 'stats_pvf_row_tasks'),
                    value: '${data.sessions.length}',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: topCategory?.icon ?? Icons.category_outlined,
                    label: t(currentLocale.value, 'category_label'),
                    value: topCategory?.label ?? '—',
                    accent: topCategory?.color,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    icon: Icons.timelapse_rounded,
                    label: t(currentLocale.value, 'long_duration'),
                    value: longest != null
                        ? _formatDuration(longest.seconds)
                        : '—',
                    supporting: longest?.title,
                    accent: longest?.color,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _DayMapCard(data: data),
        const SizedBox(height: 16),
        _CategoryShareCard(data: data),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
    final effectiveAccent = accent ?? scheme.primary;

    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: effectiveAccent),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
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
          if (supporting != null && supporting!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              supporting!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayMapCard extends StatelessWidget {
  const _DayMapCard({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dayStart = data.selectedDate;
    final totalDaySeconds = const Duration(days: 1).inSeconds.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'timeline'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: 34,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    for (final session in data.sessions)
                      Builder(
                        builder: (context) {
                          final start = session.startWall
                              .difference(dayStart)
                              .inSeconds
                              .clamp(0, totalDaySeconds.toInt())
                              .toDouble();
                          final end = session.endWall
                              .difference(dayStart)
                              .inSeconds
                              .clamp(0, totalDaySeconds.toInt())
                              .toDouble();
                          final left =
                              constraints.maxWidth * start / totalDaySeconds;
                          final rawWidth =
                              constraints.maxWidth *
                              (end - start) /
                              totalDaySeconds;
                          final width = math.max(3.0, rawWidth);
                          return Positioned(
                            left: left,
                            top: 0,
                            bottom: 0,
                            width: math.min(
                              width,
                              math.max(0.0, constraints.maxWidth - left),
                            ),
                            child: Tooltip(
                              message:
                                  '${session.title} · ${_formatDuration(session.seconds)}',
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: session.color,
                                  borderRadius: BorderRadius.circular(5),
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
          const SizedBox(height: 12),
          _CategoryLegend(categories: data.categories.take(5).toList()),
        ],
      ),
    );
  }
}

class _CategoryShareCard extends StatelessWidget {
  const _CategoryShareCard({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = data.categories.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'stats_pvf_by_category'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _ShareBar(categories: data.categories),
          const SizedBox(height: 14),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategorySummaryRow(
                category: category,
                totalSeconds: data.totalSeconds,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final formatter = DateFormat.Hm(loc);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: data.sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = data.sessions[index];
        final scheme = Theme.of(context).colorScheme;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(width: 6, height: 86, color: session.color),
              const SizedBox(width: 12),
              Icon(session.icon, color: session.color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.categoryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatter.format(session.startWall)} — '
                        '${formatter.format(session.endWall)}'
                        '${session.isRunning ? ' · ${t(loc, 'running_label')}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(
                  _formatDuration(session.seconds),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: session.color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoriesView extends StatelessWidget {
  const _CategoriesView({required this.data});

  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _ShareBar(categories: data.categories),
        const SizedBox(height: 16),
        for (final category in data.categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CategoryCard(
              category: category,
              totalSeconds: data.totalSeconds,
            ),
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.totalSeconds});

  final DayStatsCategorySlice category;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final share = totalSeconds > 0 ? category.seconds / totalSeconds : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(category.icon, color: category.color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _formatDuration(category.seconds),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: category.color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(share * 100).round()}%',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: share.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: category.color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.categories});

  final List<DayStatsCategorySlice> categories;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (categories.isEmpty) {
      return Container(
        height: 14,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            for (final category in categories)
              Expanded(
                flex: math.max(1, category.seconds),
                child: ColoredBox(color: category.color),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({required this.categories});

  final List<DayStatsCategorySlice> categories;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final category in categories)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
      ],
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
    final share = totalSeconds > 0 ? category.seconds / totalSeconds : 0.0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: category.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            category.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          _formatDuration(category.seconds),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(
            '${(share * 100).round()}%',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
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
