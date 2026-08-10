import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/sleep_record_policy.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

String _copy(String en, String ru) =>
    currentLocale.value.toLowerCase().startsWith('ru') ? ru : en;

String _durationCompact(int seconds) {
  final value = seconds.abs();
  final h = value ~/ 3600;
  final m = (value % 3600) ~/ 60;
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  if (m > 0) return '${m}m';
  return '${value}s';
}

String _deltaTime(int plan, int fact) {
  final diff = fact - plan;
  if (diff == 0) return '0m';
  return '${diff > 0 ? '+' : '−'}${_durationCompact(diff)}';
}

int _sumSecondsInSubtree(int categoryId, Map<int, int> values) {
  var result = 0;
  for (final id in DatabaseService.instance.getRecordIdsInSubtree(categoryId)) {
    result += values[id] ?? 0;
  }
  return result;
}

class _PlanFacts {
  const _PlanFacts({
    required this.stats,
    required this.actualByPlan,
    required this.unplannedRecordCount,
  });

  final BasicDayStats stats;
  final Map<String, int> actualByPlan;
  final int unplannedRecordCount;

  List<PlanningTask> get plans => stats.plansScheduledThisDay
      .where((task) => !SleepRecordPolicy.isSleepCategoryId(task.categoryId))
      .toList(growable: false);

  int _sleepSeconds(Map<int, int> values) {
    var seconds = 0;
    for (final root in DatabaseService.instance.rules) {
      if (!SleepRecordPolicy.isSleepCategoryId(root.id)) continue;
      seconds += _sumSecondsInSubtree(root.id, values);
    }
    return seconds;
  }

  int get plannedTimeSeconds => math.max(
    0,
    stats.planTimeSeconds - _sleepSeconds(stats.plannedSecByCategory),
  );
  int get factTimeSeconds => math.max(
    0,
    stats.factTimeSeconds - _sleepSeconds(stats.actualSecByCategory),
  );
  int get plannedCount => plans.length;
  int get completedCount => plans.where((task) => task.isDone).length;
  int get workedCount => plans.where(hasWork).length;
  int get untouchedCount => plans.where((task) => !hasWork(task)).length;
  int get incompleteCount => plans.where((task) => !task.isDone).length;

  bool hasWork(PlanningTask task) {
    final raw = task.pocketRecordId?.trim() ?? '';
    if (raw.isEmpty) return false;
    final key = DatabaseService.pocketRelationIdOrNull(raw) ?? raw;
    return (actualByPlan[key] ?? 0) > 0;
  }

  int actualForPlan(PlanningTask task) {
    final raw = task.pocketRecordId?.trim() ?? '';
    if (raw.isEmpty) return 0;
    final key = DatabaseService.pocketRelationIdOrNull(raw) ?? raw;
    return actualByPlan[key] ?? 0;
  }

  Set<int> subtreeIds(int categoryId) =>
      DatabaseService.instance.getRecordIdsInSubtree(categoryId);

  List<PlanningTask> plansInSubtree(int categoryId) {
    final ids = subtreeIds(categoryId);
    return plans.where((task) => ids.contains(task.categoryId)).toList();
  }

  int completedInSubtree(int categoryId) =>
      plansInSubtree(categoryId).where((task) => task.isDone).length;

  int workedInSubtree(int categoryId) =>
      plansInSubtree(categoryId).where(hasWork).length;
}

class PlanVsFactV2Tab extends StatefulWidget {
  const PlanVsFactV2Tab({
    super.key,
    required this.selectedDate,
    required this.records,
    required this.isFutureDate,
  });

  final DateTime selectedDate;
  final List<Map<String, dynamic>> records;
  final bool isFutureDate;

  @override
  State<PlanVsFactV2Tab> createState() => _PlanVsFactV2TabState();
}

class _PlanVsFactV2TabState extends State<PlanVsFactV2Tab> {
  StreamSubscription<void>? _planRefreshSub;
  late Future<BasicDayStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _reload();
    _planRefreshSub = DatabaseService.instance.planningRefreshNotifications
        .listen((_) {
          if (mounted) setState(() => _statsFuture = _reload());
        });
  }

  @override
  void dispose() {
    _planRefreshSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlanVsFactV2Tab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.records != widget.records) {
      setState(() => _statsFuture = _reload());
    }
  }

  Future<BasicDayStats> _reload() => DatabaseService.instance.getBasicDayStats(
    widget.selectedDate,
    recordsForDay: widget.records,
  );

  @override
  Widget build(BuildContext context) {
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
                  t(currentLocale.value, 'waiting_planetary_data'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }
        final stats = snap.data;
        if (stats == null) {
          return AppErrorState(
            message: t(currentLocale.value, 'no_data_found'),
          );
        }
        final byPlan = DatabaseService.instance
            .aggregateSourcePlanActualSecondsForWallCalendarDay(
              widget.selectedDate,
            );
        final unplannedRecordCount = widget.records.where((record) {
          final source = (record['source_plan_id'] ?? record['sourcePlanId'])
              ?.toString()
              .trim();
          return source == null || source.isEmpty;
        }).length;
        final facts = _PlanFacts(
          stats: stats,
          actualByPlan: byPlan,
          unplannedRecordCount: unplannedRecordCount,
        );
        if (facts.plannedCount == 0 &&
            facts.plannedTimeSeconds == 0 &&
            facts.factTimeSeconds == 0) {
          return AppEmptyState(
            message: t(
              currentLocale.value,
              widget.isFutureDate ? 'no_planned_tasks' : 'stats_pvf_no_plans',
            ),
            icon: Icons.fact_check_outlined,
          );
        }
        return _PlanFactContent(facts: facts);
      },
    );
  }
}

class _PlanFactContent extends StatelessWidget {
  const _PlanFactContent({required this.facts});
  final _PlanFacts facts;

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final roots =
        db.rules.where((rule) {
          if (SleepRecordPolicy.isSleepCategoryId(rule.id)) return false;
          final plannedSeconds = _sumSecondsInSubtree(
            rule.id,
            facts.stats.plannedSecByCategory,
          );
          final actualSeconds = _sumSecondsInSubtree(
            rule.id,
            facts.stats.actualSecByCategory,
          );
          final taskCount = facts.plansInSubtree(rule.id).length;
          return plannedSeconds > 0 || actualSeconds > 0 || taskCount > 0;
        }).toList()..sort((a, b) {
          final aTasks = facts.plansInSubtree(a.id).length;
          final bTasks = facts.plansInSubtree(b.id).length;
          if (aTasks != bTasks) return bTasks.compareTo(aTasks);
          final av = math.max(
            _sumSecondsInSubtree(a.id, facts.stats.plannedSecByCategory),
            _sumSecondsInSubtree(a.id, facts.stats.actualSecByCategory),
          );
          final bv = math.max(
            _sumSecondsInSubtree(b.id, facts.stats.plannedSecByCategory),
            _sumSecondsInSubtree(b.id, facts.stats.actualSecByCategory),
          );
          return bv.compareTo(av);
        });

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 720;
        final pad = mobile ? 12.0 : 18.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
          children: [
            _OutcomeHero(facts: facts, mobile: mobile),
            const SizedBox(height: 14),
            _ThreeDimensions(facts: facts, mobile: mobile),
            const SizedBox(height: 18),
            Text(
              _copy('By category', 'По категориям'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            for (final rule in roots)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _CategoryOutcomeCard(rule: rule, facts: facts),
              ),
            if (facts.incompleteCount > 0) ...[
              const SizedBox(height: 8),
              _NeedsAttention(facts: facts),
            ],
          ],
        );
      },
    );
  }
}

class _OutcomeHero extends StatelessWidget {
  const _OutcomeHero({required this.facts, required this.mobile});
  final _PlanFacts facts;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final planned = math.max(1, facts.plannedCount);
    final completion = facts.completedCount / planned;
    final worked = facts.workedCount / planned;
    final timeRatio = facts.plannedTimeSeconds > 0
        ? facts.factTimeSeconds / facts.plannedTimeSeconds
        : (facts.factTimeSeconds > 0 ? 1.0 : 0.0);
    final accent = completion >= 0.8
        ? scheme.tertiary
        : completion >= 0.5
        ? scheme.primary
        : scheme.secondary;

    return _Glass(
      accent: accent,
      padding: EdgeInsets.all(mobile ? 17 : 22),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -85,
            child: _Glow(color: accent, size: mobile ? 190 : 260),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _copy('Day outcome', 'Итог дня'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _copy(
                            'Plan is measured by completion, work started and time — not by hours alone.',
                            'План оценивается по выполнению, начатым задачам и времени — не только по часам.',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CompletionRing(
                    value: completion.clamp(0.0, 1.0),
                    label: '${(completion * 100).round()}%',
                    color: accent,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _OutcomeRail(
                label: _copy('Completed', 'Выполнено'),
                value: completion,
                valueText: '${facts.completedCount}/${facts.plannedCount}',
                color: accent,
              ),
              const SizedBox(height: 9),
              _OutcomeRail(
                label: _copy('Worked on', 'Были в работе'),
                value: worked.clamp(0.0, 1.0),
                valueText: '${facts.workedCount}/${facts.plannedCount}',
                color: scheme.primary,
              ),
              const SizedBox(height: 9),
              _OutcomeRail(
                label: _copy('Time vs plan', 'Время к плану'),
                value: timeRatio.clamp(0.0, 1.0),
                valueText:
                    '${_durationCompact(facts.factTimeSeconds)} / ${_durationCompact(facts.plannedTimeSeconds)}',
                color: scheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThreeDimensions extends StatelessWidget {
  const _ThreeDimensions({required this.facts, required this.mobile});
  final _PlanFacts facts;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _DimensionCard(
        icon: Icons.task_alt_rounded,
        title: _copy('Tasks', 'Задачи'),
        main: '${facts.completedCount} / ${facts.plannedCount}',
        mainLabel: _copy('completed / planned', 'выполнено / запланировано'),
        lines: [
          '${facts.workedCount} ${_copy('worked on', 'были в работе')}',
          '${facts.untouchedCount} ${_copy('untouched', 'не начаты')}',
        ],
      ),
      _DimensionCard(
        icon: Icons.schedule_rounded,
        title: _copy('Time', 'Время'),
        main: _durationCompact(facts.factTimeSeconds),
        mainLabel: _copy('actual tracked', 'фактически учтено'),
        lines: [
          '${_durationCompact(facts.plannedTimeSeconds)} ${_copy('planned', 'запланировано')}',
          '${_deltaTime(facts.plannedTimeSeconds, facts.factTimeSeconds)} ${_copy('difference', 'разница')}',
        ],
      ),
      _DimensionCard(
        icon: Icons.route_rounded,
        title: _copy('Execution', 'Исполнение'),
        main: '${facts.workedCount}',
        mainLabel: _copy('planned tasks touched', 'плановых задач начато'),
        lines: [
          '${facts.unplannedRecordCount} ${_copy('unplanned records', 'внеплановых записей')}',
          '${facts.incompleteCount} ${_copy('still incomplete', 'осталось невыполнено')}',
        ],
      ),
    ];
    if (mobile) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i != cards.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _DimensionCard extends StatelessWidget {
  const _DimensionCard({
    required this.icon,
    required this.title,
    required this.main,
    required this.mainLabel,
    required this.lines,
  });
  final IconData icon;
  final String title;
  final String main;
  final String mainLabel;
  final List<String> lines;

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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            main,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            mainLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      line,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
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

class _CategoryOutcomeCard extends StatelessWidget {
  const _CategoryOutcomeCard({required this.rule, required this.facts});
  final CategoryRule rule;
  final _PlanFacts facts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = rule.colorOrDefault;
    final pTime = _sumSecondsInSubtree(
      rule.id,
      facts.stats.plannedSecByCategory,
    );
    final aTime = _sumSecondsInSubtree(
      rule.id,
      facts.stats.actualSecByCategory,
    );
    final plans = facts.plansInSubtree(rule.id);
    final done = plans.where((task) => task.isDone).length;
    final worked = plans.where(facts.hasWork).length;
    final taskRatio = plans.isEmpty ? 0.0 : done / plans.length;
    final workRatio = plans.isEmpty ? 0.0 : worked / plans.length;
    final children = (rule.children ?? const <CategoryRule>[]).where((child) {
      final childPlans = facts.plansInSubtree(child.id).length;
      return childPlans > 0 ||
          _sumSecondsInSubtree(child.id, facts.stats.plannedSecByCategory) >
              0 ||
          _sumSecondsInSubtree(child.id, facts.stats.actualSecByCategory) > 0;
    }).toList();

    return _Glass(
      accent: color,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(rule.iconOrDefault, size: 19, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizeCategoryDbSegment(rule.name, currentLocale.value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$done/${plans.length} ${_copy('done', 'выполнено')} · $worked ${_copy('worked', 'в работе')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _deltaTime(pTime, aTime),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _LabeledRail(
            label: _copy('Tasks completed', 'Задачи выполнены'),
            value: taskRatio,
            valueText: '${(taskRatio * 100).round()}%',
            color: color,
          ),
          const SizedBox(height: 8),
          _LabeledRail(
            label: _copy('Tasks worked on', 'Задачи в работе'),
            value: workRatio,
            valueText: '${(workRatio * 100).round()}%',
            color: scheme.primary,
          ),
          const SizedBox(height: 12),
          _TimeCompareRail(plan: pTime, fact: aTime, color: color),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${_copy('Plan', 'План')}: ${_durationCompact(pTime)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${_copy('Fact', 'Факт')}: ${_durationCompact(aTime)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 5),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                dense: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 2),
                title: Text(
                  _copy('Subcategories', 'Подкатегории'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                  for (final child in children)
                    _SubcategoryRow(rule: child, facts: facts),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubcategoryRow extends StatelessWidget {
  const _SubcategoryRow({required this.rule, required this.facts});
  final CategoryRule rule;
  final _PlanFacts facts;

  @override
  Widget build(BuildContext context) {
    final color = rule.colorOrDefault;
    final plans = facts.plansInSubtree(rule.id);
    final done = plans.where((task) => task.isDone).length;
    final pTime = _sumSecondsInSubtree(
      rule.id,
      facts.stats.plannedSecByCategory,
    );
    final aTime = _sumSecondsInSubtree(
      rule.id,
      facts.stats.actualSecByCategory,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              localizeCategoryDbSegment(rule.name, currentLocale.value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$done/${plans.length}',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: _TimeCompareRail(
              plan: pTime,
              fact: aTime,
              color: color,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.facts});
  final _PlanFacts facts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plans = facts.plans.where((task) => !task.isDone).toList();
    return _Glass(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pending_actions_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _copy('Not completed', 'Не выполнено'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${plans.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          for (final task in plans.take(10))
            Container(
              margin: const EdgeInsets.only(top: 7),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Icon(
                    facts.hasWork(task)
                        ? Icons.timelapse_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: facts.hasWork(task)
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    facts.hasWork(task)
                        ? _durationCompact(facts.actualForPlan(task))
                        : _copy('not started', 'не начато'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
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

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({
    required this.value,
    required this.label,
    required this.color,
  });
  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
            ),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _OutcomeRail extends StatelessWidget {
  const _OutcomeRail({
    required this.label,
    required this.value,
    required this.valueText,
    required this.color,
  });
  final String label;
  final double value;
  final String valueText;
  final Color color;

  @override
  Widget build(BuildContext context) => _LabeledRail(
    label: label,
    value: value,
    valueText: valueText,
    color: color,
  );
}

class _LabeledRail extends StatelessWidget {
  const _LabeledRail({
    required this.label,
    required this.value,
    required this.valueText,
    required this.color,
  });
  final String label;
  final double value;
  final String valueText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              valueText,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 7,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.34,
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.58)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeCompareRail extends StatelessWidget {
  const _TimeCompareRail({
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
        final planWidth = constraints.maxWidth * plan / maxValue;
        final factWidth = constraints.maxWidth * fact / maxValue;
        final height = compact ? 13.0 : 20.0;
        return SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.24,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (plan > 0)
                Container(
                  width: planWidth,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: color.withValues(alpha: 0.48),
                      width: 1.5,
                    ),
                  ),
                ),
              if (fact > 0)
                Container(
                  width: factWidth,
                  height: compact ? 7 : 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.55)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
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

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
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
            color: Colors.black.withValues(alpha: dark ? 0.17 : 0.055),
            blurRadius: dark ? 22 : 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface.withValues(alpha: dark ? 0.86 : 0.96),
                Color.alphaBlend(
                  glow.withValues(alpha: dark ? 0.06 : 0.035),
                  scheme.surface.withValues(alpha: dark ? 0.76 : 0.90),
                ),
              ],
            ),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.84),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
