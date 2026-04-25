import 'dart:async';
import 'dart:math' as math;

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:counter/core/widgets/app_loading.dart';

// ---------------------------------------------------------------------------
// PLAN VS FACT — simple scheduled plan vs tracked time per category (DNA).
// UI_ISOLATION (§7). Reads via [DatabaseService.getBasicDayStats]; no writes.
// ---------------------------------------------------------------------------

/// Accent for “fact” (logged time) — premium contrast vs plan.
const Color _kPlanFactOrange = Color(0xFFF57C00);

String _fmtHoursOneDecimal(double hours) {
  if (hours <= 0) return '0 h';
  return '${hours.toStringAsFixed(1)} h';
}

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

/// Tab 2 under Stats: basic plan vs fact for the selected wall day.
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
    if (oldWidget.selectedDate != widget.selectedDate) {
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
    final scheme = Theme.of(context).colorScheme;
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                t(loc, 'no_data_found'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final plannedSecByCat =
            Map<int, int>.from(stats.plannedSecByCategory);
        final actualSecByCat =
            Map<int, int>.from(stats.actualSecByCategory);

        final allCatIds = <int>{...plannedSecByCat.keys, ...actualSecByCat.keys};

        if (stats.planTaskCount == 0 && allCatIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                t(
                  loc,
                  widget.isFutureDate
                      ? 'no_planned_tasks'
                      : 'stats_pvf_no_plans',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final byPlan = DatabaseService.instance
            .aggregateSourcePlanActualSecondsForWallCalendarDay(
                widget.selectedDate);

        final ghostPlans = stats.plansScheduledThisDay.where((t) {
          final raw = t.pocketRecordId?.trim();
          if (raw == null || raw.isEmpty) return true;
          final key = DatabaseService.pocketRelationIdOrNull(raw) ?? raw;
          return (byPlan[key] ?? 0) <= 0;
        }).toList(growable: false);

        final rulesRoots = DatabaseService.instance.rules;
        final knownTreeIds = _allRuleTreeIds(rulesRoots);
        final orphanIds = allCatIds
            .where((id) => !knownTreeIds.contains(id))
            .toList()
          ..sort((a, b) => a.compareTo(b));

        final rootRulesWithActivity = rulesRoots
            .where((r) {
              final p = _rollupSubtreeSeconds(r.id, plannedSecByCat);
              final a = _rollupSubtreeSeconds(r.id, actualSecByCat);
              return p > 0 || a > 0;
            })
            .toList()
          ..sort((a, b) {
            final pa = _rollupSubtreeSeconds(a.id, plannedSecByCat);
            final aa = _rollupSubtreeSeconds(a.id, actualSecByCat);
            final pb = _rollupSubtreeSeconds(b.id, plannedSecByCat);
            final ab = _rollupSubtreeSeconds(b.id, actualSecByCat);
            final ma = math.max(pa, aa);
            final mb = math.max(pb, ab);
            return mb.compareTo(ma);
          });

        final planH = stats.planTimeSeconds / 3600.0;
        final factH = stats.factTimeSeconds / 3600.0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _PlanFactSummaryRow(
              label: t(loc, 'stats_pvf_row_tasks'),
              planText: '${stats.planTaskCount}',
              factText: '${stats.factDistinctPlansFromRecords}',
              planColor: scheme.primary,
              factColor: _kPlanFactOrange,
            ),
            const SizedBox(height: 10),
            _PlanFactSummaryRow(
              label: t(loc, 'stats_pvf_row_time'),
              planText: _fmtHoursOneDecimal(planH),
              factText: _fmtHoursOneDecimal(factH),
              planColor: scheme.primary,
              factColor: _kPlanFactOrange,
            ),
            const SizedBox(height: 20),
            Text(
              t(loc, 'stats_pvf_by_category'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...rootRulesWithActivity.map(
              (rule) => _PlanFactCategoryBranch(
                rule: rule,
                plannedSecByCat: plannedSecByCat,
                actualSecByCat: actualSecByCat,
                depth: 0,
              ),
            ),
            ...orphanIds.map(
              (cid) => _PlanFactOrphanCategoryRow(
                categoryId: cid,
                plannedSecByCat: plannedSecByCat,
                actualSecByCat: actualSecByCat,
              ),
            ),
            if (ghostPlans.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                t(loc, 'stats_pvf_ghosts'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...ghostPlans.map(
                (task) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.event_note_outlined, size: 20),
                  title: Text(task.title),
                  subtitle: Text(
                    localizeCategoryBreadcrumbPath(
                      DatabaseService.instance
                          .getCategoryPath(task.categoryId),
                      currentLocale.value,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PlanFactSummaryRow extends StatelessWidget {
  const _PlanFactSummaryRow({
    required this.label,
    required this.planText,
    required this.factText,
    required this.planColor,
    required this.factColor,
  });

  final String label;
  final String planText;
  final String factText;
  final Color planColor;
  final Color factColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Baseline(
            baseline: 28,
            baselineType: TextBaseline.alphabetic,
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: planText,
                    style: TextStyle(color: planColor),
                  ),
                  TextSpan(
                    text: ' / ',
                    style: TextStyle(
                      color: scheme.outline.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: factText,
                    style: TextStyle(color: factColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanFactOrphanCategoryRow extends StatelessWidget {
  const _PlanFactOrphanCategoryRow({
    required this.categoryId,
    required this.plannedSecByCat,
    required this.actualSecByCat,
  });

  final int categoryId;
  final Map<int, int> plannedSecByCat;
  final Map<int, int> actualSecByCat;

  @override
  Widget build(BuildContext context) {
    final p = plannedSecByCat[categoryId] ?? 0;
    final a = actualSecByCat[categoryId] ?? 0;
    if (p <= 0 && a <= 0) return const SizedBox.shrink();

    final String rawLabel;
    if (categoryId == CategoryRule.uncategorizedSyntheticId) {
      rawLabel = t(currentLocale.value, 'uncategorized');
    } else {
      final r = DatabaseService.instance.getCategoryRuleById(categoryId);
      rawLabel = r != null
          ? DatabaseService.instance.getCategoryPath(categoryId)
          : 'Category ($categoryId)';
    }
    final label =
        localizeCategoryBreadcrumbPath(rawLabel, currentLocale.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _PlanFactBarBlock(
        label: label,
        categoryId: categoryId,
        plannedSec: p,
        actualSec: a,
        titleStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PlanFactCategoryBranch extends StatelessWidget {
  const _PlanFactCategoryBranch({
    required this.rule,
    required this.plannedSecByCat,
    required this.actualSecByCat,
    required this.depth,
  });

  final CategoryRule rule;
  final Map<int, int> plannedSecByCat;
  final Map<int, int> actualSecByCat;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final p = _rollupSubtreeSeconds(rule.id, plannedSecByCat);
    final a = _rollupSubtreeSeconds(rule.id, actualSecByCat);
    if (p <= 0 && a <= 0) return const SizedBox.shrink();

    final rawChildren = rule.children ?? const <CategoryRule>[];
    final activeChildren = rawChildren
        .where((c) {
          final cp = _rollupSubtreeSeconds(c.id, plannedSecByCat);
          final ca = _rollupSubtreeSeconds(c.id, actualSecByCat);
          return cp > 0 || ca > 0;
        })
        .toList()
      ..sort((a, b) {
        final pa = _rollupSubtreeSeconds(a.id, plannedSecByCat);
        final aa = _rollupSubtreeSeconds(a.id, actualSecByCat);
        final pb = _rollupSubtreeSeconds(b.id, plannedSecByCat);
        final ab = _rollupSubtreeSeconds(b.id, actualSecByCat);
        return math.max(pb, ab).compareTo(math.max(pa, aa));
      });

    final titleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: depth == 0 ? FontWeight.w700 : FontWeight.w600,
          fontSize: depth == 0 ? 16 : 14,
        );

    if (activeChildren.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _PlanFactBarBlock(
          label: localizeCategoryDbSegment(rule.name, loc),
          categoryId: rule.id,
          plannedSec: p,
          actualSec: a,
          titleStyle: titleStyle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey<String>('pvf_${rule.id}_$depth'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: EdgeInsets.only(
              left: depth == 0 ? 12 : 8,
              bottom: 4,
            ),
            collapsedShape: const RoundedRectangleBorder(
              side: BorderSide.none,
            ),
            shape: const RoundedRectangleBorder(
              side: BorderSide.none,
            ),
            controlAffinity: ListTileControlAffinity.trailing,
            dense: true,
            title: Text(
              localizeCategoryDbSegment(rule.name, loc),
              style: titleStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: _PlanFactBarBlock(
                label: null,
                categoryId: rule.id,
                plannedSec: p,
                actualSec: a,
                titleStyle: titleStyle,
                compact: true,
              ),
            ),
            children: activeChildren
                .map(
                  (c) => _PlanFactCategoryBranch(
                    rule: c,
                    plannedSecByCat: plannedSecByCat,
                    actualSecByCat: actualSecByCat,
                    depth: depth + 1,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _PlanFactBarBlock extends StatelessWidget {
  const _PlanFactBarBlock({
    required this.categoryId,
    required this.plannedSec,
    required this.actualSec,
    this.label,
    this.titleStyle,
    this.compact = false,
  });

  final int categoryId;
  final int plannedSec;
  final int actualSec;
  final String? label;
  final TextStyle? titleStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final base = DatabaseService.instance.getCategoryColor(categoryId);

    final overPlan = actualSec > plannedSec && plannedSec > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label!,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle ??
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                ),
              ),
              if (overPlan)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.trending_up_rounded,
                    size: 18,
                    color: scheme.error.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
          if (!compact) const SizedBox(height: 6),
        ] else if (overPlan)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t(loc, 'stats_pvf_overflow'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.error.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: scheme.error.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, c) {
            return _ModernPlanFactBar(
              maxWidth: c.maxWidth,
              categoryColor: base,
              plannedHours: plannedSec / 3600.0,
              actualHours: actualSec / 3600.0,
              scheme: scheme,
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          '${_fmtHoursOneDecimal(plannedSec / 3600.0)} → ${_fmtHoursOneDecimal(actualSec / 3600.0)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ModernPlanFactBar extends StatelessWidget {
  const _ModernPlanFactBar({
    required this.maxWidth,
    required this.categoryColor,
    required this.plannedHours,
    required this.actualHours,
    required this.scheme,
  });

  final double maxWidth;
  final Color categoryColor;
  final double plannedHours;
  final double actualHours;
  final ColorScheme scheme;

  static const double _barHeight = 14;
  static const double _radius = 8;

  @override
  Widget build(BuildContext context) {
    final w = maxWidth;
    if (w <= 0) return const SizedBox.shrink();

    final p = plannedHours;
    final a = actualHours;
    if (p <= 0 && a <= 0) return const SizedBox.shrink();

    final denom = math.max(math.max(p, a), 1e-9);
    final pw = w * (p / denom);
    final aw = w * (a / denom);

    final over = a > p && p > 0;
    final actualFill =
        over ? Color.lerp(_kPlanFactOrange, scheme.error, 0.45)! : _kPlanFactOrange;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: SizedBox(
        height: _barHeight,
        width: w,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          alignment: Alignment.centerLeft,
          children: [
            if (p > 0)
              Container(
                width: pw.clamp(0.0, w),
                height: _barHeight,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
            if (a > 0)
              Container(
                width: aw.clamp(0.0, w),
                height: _barHeight,
                decoration: BoxDecoration(
                  color: actualFill,
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: over
                      ? [
                          BoxShadow(
                            color: scheme.error.withValues(alpha: 0.22),
                            blurRadius: 6,
                            spreadRadius: 0,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: _kPlanFactOrange.withValues(alpha: 0.28),
                            blurRadius: 5,
                            spreadRadius: 0,
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
