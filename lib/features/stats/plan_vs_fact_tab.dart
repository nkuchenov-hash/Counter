import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

int _rollupSubtreeSeconds(int categoryId, Map<int, int> byCategorySec) {
  var sum = 0;
  for (final id in DatabaseService.instance.getRecordIdsInSubtree(categoryId)) {
    sum += byCategorySec[id] ?? 0;
  }
  return sum;
}

Set<int> _allRuleTreeIds(Iterable<CategoryRule> roots) {
  final out = <int>{};
  void walk(CategoryRule r) {
    out.add(r.id);
    for (final c in r.children ?? const <CategoryRule>[]) {
      walk(c);
    }
  }

  for (final r in roots) {
    walk(r);
  }
  return out;
}

String _duration(int seconds) {
  if (seconds <= 0) return '0 h 00 m';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '$h h ${m.toString().padLeft(2, '0')} m';
}

String _durationCompact(int seconds) {
  final value = seconds.abs();
  final h = value ~/ 3600;
  final m = (value % 3600) ~/ 60;
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  if (m > 0) return '${m}m';
  return '${value}s';
}

String _delta(int plan, int fact) {
  final diff = fact - plan;
  if (diff == 0) return '0m';
  return '${diff > 0 ? '+' : '−'}${_durationCompact(diff)}';
}

class PlanVsFactTab extends StatefulWidget {
  const PlanVsFactTab({
    super.key,
    required this.selectedDate,
    required this.records,
    required this.isFutureDate,
  });

  final DateTime selectedDate;
  final List<Map<String, dynamic>> records;
  final bool isFutureDate;

  @override
  State<PlanVsFactTab> createState() => _PlanVsFactTabState();
}

class _PlanVsFactTabState extends State<PlanVsFactTab> {
  StreamSubscription<void>? _planRefreshSub;
  late Future<BasicDayStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _reloadStats();
    _planRefreshSub =
        DatabaseService.instance.planningRefreshNotifications.listen((_) {
      if (mounted) setState(() => _statsFuture = _reloadStats());
    });
  }

  @override
  void dispose() {
    _planRefreshSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlanVsFactTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.records != widget.records) {
      setState(() => _statsFuture = _reloadStats());
    }
  }

  Future<BasicDayStats> _reloadStats() {
    return DatabaseService.instance.getBasicDayStats(
      widget.selectedDate,
      recordsForDay: widget.records,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);

    return FutureBuilder<BasicDayStats>(
      future: _statsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLoading(),
                const SizedBox(height: 12),
                Text(
                  t(loc, 'waiting_planetary_data'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        final stats = snap.data;
        if (stats == null) {
          return AppErrorState(message: t(loc, 'no_data_found'));
        }

        final planned = Map<int, int>.from(stats.plannedSecByCategory);
        final actual = Map<int, int>.from(stats.actualSecByCategory);
        final allCatIds = <int>{...planned.keys, ...actual.keys};

        if (stats.planTaskCount == 0 && allCatIds.isEmpty) {
          return AppEmptyState(
            message: t(
              loc,
              widget.isFutureDate ? 'no_planned_tasks' : 'stats_pvf_no_plans',
            ),
            icon: Icons.compare_arrows_rounded,
          );
        }

        final byPlan = DatabaseService.instance
            .aggregateSourcePlanActualSecondsForWallCalendarDay(
              widget.selectedDate,
            );
        final ghostPlans = stats.plansScheduledThisDay.where((task) {
          final raw = task.pocketRecordId?.trim();
          if (raw == null || raw.isEmpty) return true;
          final key = DatabaseService.pocketRelationIdOrNull(raw) ?? raw;
          return (byPlan[key] ?? 0) <= 0;
        }).toList(growable: false);

        final roots = DatabaseService.instance.rules;
        final knownIds = _allRuleTreeIds(roots);
        final orphanIds = allCatIds
            .where((id) => !knownIds.contains(id))
            .toList()
          ..sort();

        final activeRoots = roots.where((r) {
          final p = _rollupSubtreeSeconds(r.id, planned);
          final a = _rollupSubtreeSeconds(r.id, actual);
          return p > 0 || a > 0;
        }).toList()
          ..sort((a, b) {
            final av = math.max(
              _rollupSubtreeSeconds(a.id, planned),
              _rollupSubtreeSeconds(a.id, actual),
            );
            final bv = math.max(
              _rollupSubtreeSeconds(b.id, planned),
              _rollupSubtreeSeconds(b.id, actual),
            );
            return bv.compareTo(av);
          });

        return LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 700;
            final pad = mobile ? 12.0 : 18.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, 30),
              children: [
                _PlanFactHero(stats: stats, mobile: mobile),
                const SizedBox(height: 14),
                _Legend(),
                const SizedBox(height: 14),
                Text(
                  t(loc, 'stats_pvf_by_category'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                for (final rule in activeRoots)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _CategoryCompareCard(
                      rule: rule,
                      planned: planned,
                      actual: actual,
                    ),
                  ),
                for (final id in orphanIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _OrphanCompareCard(
                      categoryId: id,
                      plan: planned[id] ?? 0,
                      fact: actual[id] ?? 0,
                    ),
                  ),
                if (ghostPlans.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _UntrackedPlans(plans: ghostPlans),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _PlanFactHero extends StatelessWidget {
  const _PlanFactHero({required this.stats, required this.mobile});
  final BasicDayStats stats;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plan = stats.planTimeSeconds;
    final fact = stats.factTimeSeconds;
    final ratio = plan > 0 ? fact / plan : (fact > 0 ? 1.0 : 0.0);
    final percent = (ratio * 100).round();
    final diff = fact - plan;
    final accent = diff > 0
        ? scheme.tertiary
        : diff < 0
            ? scheme.primary
            : scheme.secondary;

    return _Glass(
      accent: accent,
      padding: EdgeInsets.all(mobile ? 17 : 22),
      child: Stack(
        children: [
          Positioned(
            right: -65,
            top: -80,
            child: _Glow(color: accent, size: mobile ? 180 : 235),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t(currentLocale.value, 'stats_tab_plan_fact'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '$percent%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (mobile) ...[
                _HeroMetric(
                  label: t(currentLocale.value, 'stats_pvf_row_time'),
                  plan: _duration(plan),
                  fact: _duration(fact),
                  delta: _delta(plan, fact),
                  accent: accent,
                ),
                const SizedBox(height: 12),
                _HeroMetric(
                  label: t(currentLocale.value, 'stats_pvf_row_tasks'),
                  plan: '${stats.planTaskCount}',
                  fact: '${stats.factDistinctPlansFromRecords}',
                  delta:
                      '${stats.factDistinctPlansFromRecords - stats.planTaskCount >= 0 ? '+' : '−'}${(stats.factDistinctPlansFromRecords - stats.planTaskCount).abs()}',
                  accent: accent,
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(
                        label: t(currentLocale.value, 'stats_pvf_row_time'),
                        plan: _duration(plan),
                        fact: _duration(fact),
                        delta: _delta(plan, fact),
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HeroMetric(
                        label: t(currentLocale.value, 'stats_pvf_row_tasks'),
                        plan: '${stats.planTaskCount}',
                        fact: '${stats.factDistinctPlansFromRecords}',
                        delta:
                            '${stats.factDistinctPlansFromRecords - stats.planTaskCount >= 0 ? '+' : '−'}${(stats.factDistinctPlansFromRecords - stats.planTaskCount).abs()}',
                        accent: accent,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              _OverallRail(plan: plan, fact: fact, accent: accent),
              const SizedBox(height: 8),
              Text(
                diff == 0
                    ? '${t(currentLocale.value, 'stats_pvf_row_time')}: ${_duration(plan)}'
                    : '${_delta(plan, fact)} ${diff > 0 ? 'vs plan' : 'vs plan'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.plan,
    required this.fact,
    required this.delta,
    required this.accent,
  });
  final String label;
  final String plan;
  final String fact;
  final String delta;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _PlanFactValue(label: 'PLAN', value: plan, plan: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlanFactValue(label: 'FACT', value: fact, plan: false),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            delta,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanFactValue extends StatelessWidget {
  const _PlanFactValue({
    required this.label,
    required this.value,
    required this.plan,
  });
  final String label;
  final String value;
  final bool plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: plan ? scheme.onSurface : scheme.primary,
          ),
        ),
      ],
    );
  }
}

class _OverallRail extends StatelessWidget {
  const _OverallRail({
    required this.plan,
    required this.fact,
    required this.accent,
  });
  final int plan;
  final int fact;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = math.max(1, math.max(plan, fact));
    return LayoutBuilder(
      builder: (context, constraints) {
        final planW = constraints.maxWidth * plan / maxValue;
        final factW = constraints.maxWidth * fact / maxValue;
        return SizedBox(
          height: 22,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (plan > 0)
                Container(
                  width: planW,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.32),
                      width: 1.5,
                    ),
                  ),
                ),
              if (fact > 0)
                Container(
                  width: factW,
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.58)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _LegendItem(
          label: 'Plan',
          child: Container(
            width: 30,
            height: 13,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
          ),
        ),
        _LegendItem(
          label: 'Fact',
          child: Container(
            width: 30,
            height: 9,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCompareCard extends StatelessWidget {
  const _CategoryCompareCard({
    required this.rule,
    required this.planned,
    required this.actual,
  });

  final CategoryRule rule;
  final Map<int, int> planned;
  final Map<int, int> actual;

  @override
  Widget build(BuildContext context) {
    final p = _rollupSubtreeSeconds(rule.id, planned);
    final a = _rollupSubtreeSeconds(rule.id, actual);
    final children = (rule.children ?? const <CategoryRule>[]).where((child) {
      return _rollupSubtreeSeconds(child.id, planned) > 0 ||
          _rollupSubtreeSeconds(child.id, actual) > 0;
    }).toList()
      ..sort((x, y) {
        final xv = math.max(
          _rollupSubtreeSeconds(x.id, planned),
          _rollupSubtreeSeconds(x.id, actual),
        );
        final yv = math.max(
          _rollupSubtreeSeconds(y.id, planned),
          _rollupSubtreeSeconds(y.id, actual),
        );
        return yv.compareTo(xv);
      });

    return _Glass(
      accent: rule.colorOrDefault,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompareHeader(
            icon: rule.iconOrDefault,
            label: localizeCategoryDbSegment(rule.name, currentLocale.value),
            color: rule.colorOrDefault,
            plan: p,
            fact: a,
          ),
          const SizedBox(height: 12),
          _CompareRail(
            plan: p,
            fact: a,
            color: rule.colorOrDefault,
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 2),
                dense: true,
                title: Text(
                  t(currentLocale.value, 'list'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                children: [
                  for (final child in children)
                    _ChildCompare(
                      rule: child,
                      planned: planned,
                      actual: actual,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChildCompare extends StatelessWidget {
  const _ChildCompare({
    required this.rule,
    required this.planned,
    required this.actual,
  });
  final CategoryRule rule;
  final Map<int, int> planned;
  final Map<int, int> actual;

  @override
  Widget build(BuildContext context) {
    final p = _rollupSubtreeSeconds(rule.id, planned);
    final a = _rollupSubtreeSeconds(rule.id, actual);
    final children = (rule.children ?? const <CategoryRule>[]).where((child) {
      return _rollupSubtreeSeconds(child.id, planned) > 0 ||
          _rollupSubtreeSeconds(child.id, actual) > 0;
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 9, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompareHeader(
            icon: rule.iconOrDefault,
            label: localizeCategoryDbSegment(rule.name, currentLocale.value),
            color: rule.colorOrDefault,
            plan: p,
            fact: a,
            compact: true,
          ),
          const SizedBox(height: 7),
          _CompareRail(
            plan: p,
            fact: a,
            color: rule.colorOrDefault,
            compact: true,
          ),
          if (children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                children: [
                  for (final child in children)
                    _ChildCompare(
                      rule: child,
                      planned: planned,
                      actual: actual,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompareHeader extends StatelessWidget {
  const _CompareHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.plan,
    required this.fact,
    this.compact = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final int plan;
  final int fact;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final diff = fact - plan;
    final diffColor = diff > 0
        ? scheme.tertiary
        : diff < 0
            ? scheme.primary
            : scheme.onSurfaceVariant;

    return Row(
      children: [
        Container(
          width: compact ? 28 : 34,
          height: compact ? 28 : 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(compact ? 9 : 11),
          ),
          child: Icon(icon, size: compact ? 15 : 18, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? theme.textTheme.bodyMedium : theme.textTheme.titleMedium)
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_durationCompact(plan)}  →  ${_durationCompact(fact)}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              _delta(plan, fact),
              style: theme.textTheme.labelSmall?.copyWith(
                color: diffColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompareRail extends StatelessWidget {
  const _CompareRail({
    required this.plan,
    required this.fact,
    required this.color,
    this.compact = false,
  });
  final int plan;
  final int fact;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = math.max(1, math.max(plan, fact));
    return LayoutBuilder(
      builder: (context, constraints) {
        final planW = constraints.maxWidth * plan / maxValue;
        final factW = constraints.maxWidth * fact / maxValue;
        return SizedBox(
          height: compact ? 16 : 20,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (plan > 0)
                Container(
                  width: planW,
                  height: compact ? 16 : 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: color.withValues(alpha: 0.40),
                      width: 1.5,
                    ),
                  ),
                ),
              if (fact > 0)
                Container(
                  width: factW,
                  height: compact ? 8 : 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.56)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.17),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OrphanCompareCard extends StatelessWidget {
  const _OrphanCompareCard({
    required this.categoryId,
    required this.plan,
    required this.fact,
  });
  final int categoryId;
  final int plan;
  final int fact;

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final rule = db.getCategoryRuleById(categoryId);
    final color = rule?.colorOrDefault ?? db.getCategoryColor(categoryId);
    final rawLabel = categoryId == CategoryRule.uncategorizedSyntheticId
        ? t(currentLocale.value, 'uncategorized')
        : rule != null
            ? db.getCategoryPath(categoryId)
            : 'Category ($categoryId)';
    return _Glass(
      accent: color,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          _CompareHeader(
            icon: rule?.iconOrDefault ?? Icons.folder_rounded,
            label: localizeCategoryBreadcrumbPath(
              rawLabel,
              currentLocale.value,
            ),
            color: color,
            plan: plan,
            fact: fact,
          ),
          const SizedBox(height: 12),
          _CompareRail(plan: plan, fact: fact, color: color),
        ],
      ),
    );
  }
}

class _UntrackedPlans extends StatelessWidget {
  const _UntrackedPlans({required this.plans});
  final List<PlanningTask> plans;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Glass(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_note_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t(currentLocale.value, 'stats_pvf_ghosts'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${plans.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final task in plans)
            Container(
              margin: const EdgeInsets.only(top: 7),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          localizeCategoryBreadcrumbPath(
                            DatabaseService.instance
                                .getCategoryPath(task.categoryId),
                            currentLocale.value,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.14
                  : 0.09,
            ),
          ),
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.all(18),
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
    final radius = BorderRadius.circular(22);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.20 : 0.06),
            blurRadius: dark ? 24 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surface.withValues(alpha: dark ? 0.76 : 0.82),
                  Color.alphaBlend(
                    glow.withValues(alpha: dark ? 0.045 : 0.028),
                    scheme.surface.withValues(alpha: dark ? 0.64 : 0.72),
                  ),
                ],
              ),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.72),
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
