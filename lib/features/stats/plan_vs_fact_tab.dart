import 'dart:math' as math;

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// PLAN VS FACT — comparative planned hours vs tracked time per category (DNA).
// UI_ISOLATION (§7). Reads via DatabaseService streams only; no new Brain APIs.
// ---------------------------------------------------------------------------

String _fmtHoursOneDecimal(double hours) {
  if (hours <= 0) return '0 h';
  return '${hours.toStringAsFixed(1)} h';
}

bool _planHasLinkedSeconds(
  PlanningTask t,
  Map<String, int> byPlanPocketId,
) {
  final raw = t.pocketRecordId?.trim();
  if (raw == null || raw.isEmpty) {
    return false;
  }
  final key = DatabaseService.pocketRelationIdOrNull(raw) ?? raw;
  return (byPlanPocketId[key] ?? 0) > 0;
}

/// Tab 2 under Stats: planned duration per category vs record time same day.
class PlanVsFactTab extends StatelessWidget {
  const PlanVsFactTab({
    super.key,
    required this.selectedDate,
    required this.records,
    required this.isFutureDate,
  });

  final DateTime selectedDate;
  final List<Map<String, dynamic>> records;
  final bool isFutureDate;

  void _rollupActualByCategory(Map<int, int> out) {
    final offset = DatabaseService.instance.settings.timezoneOffsetHours;
    final tz = DatabaseService.instance.settings.preferredTimeZone;
    for (final rec in records) {
      final sec = DatabaseService.recordDurationSecondsWithinDayFromTimestamps(
        rec,
        selectedDate,
        offset,
        tz,
      );
      if (sec <= 0) continue;
      final cid = DatabaseService.instance.resolvedCategoryIdForRecord(rec) ??
          CategoryRule.uncategorizedSyntheticId;
      out[cid] = (out[cid] ?? 0) + sec;
    }
  }

  void _rollupPlannedByCategory(
    List<PlanningTask> plans,
    Map<int, int> plannedSec,
  ) {
    for (final t in plans) {
      final sec = DatabaseService.planningWallEstimateSeconds(t);
      if (sec == null || sec <= 0) continue;
      plannedSec[t.categoryId] = (plannedSec[t.categoryId] ?? 0) + sec;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<PlanningTask>>(
      stream: DatabaseService.instance.planningStream(selectedDate),
      builder: (context, planSnap) {
        if (planSnap.connectionState == ConnectionState.waiting &&
            !planSnap.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  t(loc, 'waiting_planetary_data'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        final plans = planSnap.data ?? const <PlanningTask>[];
        final byPlan = DatabaseService.instance
            .aggregateSourcePlanActualSecondsForWallCalendarDay(selectedDate);

        final plannedSecByCat = <int, int>{};
        _rollupPlannedByCategory(plans, plannedSecByCat);

        final actualSecByCat = <int, int>{};
        _rollupActualByCategory(actualSecByCat);

        final allCatIds = <int>{...plannedSecByCat.keys, ...actualSecByCat.keys};

        if (plans.isEmpty && allCatIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                t(
                  loc,
                  isFutureDate ? 'no_planned_tasks' : 'stats_pvf_no_plans',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }

        var totalPlannedSec = 0;
        for (final v in plannedSecByCat.values) {
          totalPlannedSec += v;
        }
        var totalActualSec = 0;
        for (final v in actualSecByCat.values) {
          totalActualSec += v;
        }

        final completionPct = totalPlannedSec > 0
            ? (100.0 * totalActualSec / totalPlannedSec)
            : null;

        final ghostPlans = plans
            .where((t) => !_planHasLinkedSeconds(t, byPlan))
            .toList(growable: false);

        final sortedKeys = allCatIds.toList()
          ..sort((a, b) {
            final pa = DatabaseService.instance.getCategoryPath(a);
            final pb = DatabaseService.instance.getCategoryPath(b);
            return pa.compareTo(pb);
          });

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _metricBlock(
                            context,
                            t(loc, 'stats_pvf_planned_h'),
                            _fmtHoursOneDecimal(totalPlannedSec / 3600.0),
                            scheme.primary,
                          ),
                        ),
                        Expanded(
                          child: _metricBlock(
                            context,
                            t(loc, 'stats_pvf_actual_h'),
                            _fmtHoursOneDecimal(totalActualSec / 3600.0),
                            scheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    if (completionPct != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${t(loc, 'stats_pvf_completion')}: ${completionPct.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t(loc, 'stats_pvf_by_category'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            ...sortedKeys.map(
              (cid) => _categoryCompareBar(
                context,
                categoryId: cid,
                plannedSec: plannedSecByCat[cid] ?? 0,
                actualSec: actualSecByCat[cid] ?? 0,
              ),
            ),
            if (ghostPlans.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                t(loc, 'stats_pvf_ghosts'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                    DatabaseService.instance.getCategoryPath(task.categoryId),
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

  Widget _metricBlock(
    BuildContext context,
    String label,
    String value,
    Color accent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
        ),
      ],
    );
  }

  Widget _categoryCompareBar(
    BuildContext context, {
    required int categoryId,
    required int plannedSec,
    required int actualSec,
  }) {
    final loc = currentLocale.value;
    final label = DatabaseService.instance.getCategoryPath(categoryId);
    final base = DatabaseService.instance.getCategoryColor(categoryId);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (actualSec > plannedSec && plannedSec > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    t(loc, 'stats_pvf_overflow'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              if (w <= 0) return const SizedBox.shrink();
              final p = plannedSec / 3600.0;
              final a = actualSec / 3600.0;
              if (p <= 0 && a <= 0) {
                return const SizedBox.shrink();
              }
              final denom = math.max(p, a);
              if (denom <= 0) return const SizedBox.shrink();
              final pw = w * (p / denom);
              final aw = w * (a / denom);
              const h = 22.0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    children: [
                      Container(
                        width: pw.clamp(0.0, w),
                        height: h,
                        decoration: BoxDecoration(
                          color: base.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: aw,
                      height: h,
                      decoration: BoxDecoration(
                        color: a > p ? base.withValues(alpha: 1.0) : base,
                        borderRadius: BorderRadius.circular(6),
                        border: a > p
                            ? Border.all(color: scheme.error, width: 1.5)
                            : null,
                      ),
                    ),
                  ),
                ],
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
      ),
    );
  }
}
