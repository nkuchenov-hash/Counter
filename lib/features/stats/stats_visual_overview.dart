import 'dart:math' as math;

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Focused visual Stats screen.
///
/// It deliberately answers only two questions:
/// 1. How was tracked time split between top-level categories?
/// 2. When did those top-level categories occupy the waking day?
///
/// Task names, subcategories, plan/fact and secondary KPIs stay out of this
/// screen. Detailed records remain available in [StatsDetailTree].
class StatsVisualOverview extends StatelessWidget {
  const StatsVisualOverview({
    super.key,
    required this.records,
    required this.rules,
    required this.rangeStartWall,
    required this.rangeEndWall,
  });

  final List<Map<String, dynamic>> records;
  final List<CategoryRule> rules;
  final DateTime rangeStartWall;
  final DateTime rangeEndWall;

  String _copy(String en, String ru) =>
      currentLocale.value.toLowerCase().startsWith('ru') ? ru : en;

  @override
  Widget build(BuildContext context) {
    final data = _StatsVisualData.build(
      records: records,
      rules: rules,
      rangeStartWall: rangeStartWall,
      rangeEndWall: rangeEndWall,
    );

    if (data.sessions.isEmpty) {
      return Center(
        child: Text(
          t(currentLocale.value, 'no_records_yet'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
      children: [
        Text(
          _copy('Time distribution', 'Распределение времени'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        _DistributionCard(data: data),
        const SizedBox(height: 22),
        Text(
          _copy('Day by top-level categories', 'День по верхним категориям'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _copy(
            'Only top-level folders are shown on the hourly scale.',
            'На часовой шкале показаны только верхнеуровневые папки.',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _DayCategoryChart(data: data),
      ],
    );
  }
}

class _StatsVisualData {
  const _StatsVisualData({
    required this.rangeStartWall,
    required this.rangeEndWall,
    required this.slices,
    required this.sessions,
    required this.totalSeconds,
  });

  final DateTime rangeStartWall;
  final DateTime rangeEndWall;
  final List<_StatsVisualSlice> slices;
  final List<_StatsVisualSession> sessions;
  final int totalSeconds;

  static _StatsVisualData build({
    required List<Map<String, dynamic>> records,
    required List<CategoryRule> rules,
    required DateTime rangeStartWall,
    required DateTime rangeEndWall,
  }) {
    final db = DatabaseService.instance;
    final safeEnd = rangeEndWall.isAfter(rangeStartWall)
        ? rangeEndWall
        : rangeStartWall.add(const Duration(hours: 1));

    final rootByCategoryId = <int, CategoryRule>{};
    void register(CategoryRule node, CategoryRule root) {
      rootByCategoryId[node.id] = root;
      for (final child in node.children ?? const <CategoryRule>[]) {
        register(child, root);
      }
    }

    for (final root in rules) {
      register(root, root);
    }

    CategoryRule? rootForRecord(Map<String, dynamic> record) {
      final rawCategory =
          record['categoryId'] ?? record['category_id'] ?? record['category'];
      if (rawCategory == null) return null;
      final probe = record['categoryId'] == rawCategory
          ? record
          : <String, dynamic>{...record, 'categoryId': rawCategory};
      final localId = db.resolvedCategoryIdForRecord(probe);
      if (localId == null) return null;
      return rootByCategoryId[localId];
    }

    final rawSessions = <_StatsVisualSession>[];
    final secondsByRoot = <int, int>{};
    var uncategorizedSeconds = 0;

    for (final record in records) {
      final startUtc = CategoryServiceExtension.startTimeFromRecord(record);
      if (startUtc == null) continue;

      final status = (record['status'] as String? ?? '').toLowerCase();
      final endUtc =
          CategoryServiceExtension.endTimeFromRecord(record) ??
          (status == 'running' ? DatabaseService.getPlanetaryNow() : null);
      if (endUtc == null) continue;

      var startWall = db.applyUserOffset(startUtc);
      var endWall = db.applyUserOffset(endUtc);
      if (startWall.isBefore(rangeStartWall)) startWall = rangeStartWall;
      if (endWall.isAfter(safeEnd)) endWall = safeEnd;
      if (!endWall.isAfter(startWall)) continue;

      final seconds = endWall.difference(startWall).inSeconds;
      if (seconds <= 0) continue;

      final root = rootForRecord(record);
      if (root == null) {
        uncategorizedSeconds += seconds;
      } else {
        secondsByRoot[root.id] = (secondsByRoot[root.id] ?? 0) + seconds;
      }

      rawSessions.add(
        _StatsVisualSession(
          rootId: root?.id,
          label: root == null
              ? t(currentLocale.value, 'uncategorized')
              : localizeCategoryDbSegment(root.name, currentLocale.value),
          color: root?.colorOrDefault ?? Colors.grey,
          icon: root?.iconOrDefault ?? Icons.folder_off_rounded,
          startWall: startWall,
          endWall: endWall,
          seconds: seconds,
        ),
      );
    }

    rawSessions.sort((a, b) => a.startWall.compareTo(b.startWall));
    final sessions = _mergeAdjacentSessions(rawSessions);

    final slices = <_StatsVisualSlice>[
      for (final root in rules)
        if ((secondsByRoot[root.id] ?? 0) > 0)
          _StatsVisualSlice(
            rootId: root.id,
            label: localizeCategoryDbSegment(root.name, currentLocale.value),
            seconds: secondsByRoot[root.id]!,
            color: root.colorOrDefault,
            icon: root.iconOrDefault,
          ),
      if (uncategorizedSeconds > 0)
        _StatsVisualSlice(
          rootId: null,
          label: t(currentLocale.value, 'uncategorized'),
          seconds: uncategorizedSeconds,
          color: Colors.grey,
          icon: Icons.folder_off_rounded,
        ),
    ]..sort((a, b) => b.seconds.compareTo(a.seconds));

    final totalSeconds = slices.fold<int>(
      0,
      (sum, slice) => sum + slice.seconds,
    );

    return _StatsVisualData(
      rangeStartWall: rangeStartWall,
      rangeEndWall: safeEnd,
      slices: slices,
      sessions: sessions,
      totalSeconds: totalSeconds,
    );
  }

  static List<_StatsVisualSession> _mergeAdjacentSessions(
    List<_StatsVisualSession> source,
  ) {
    if (source.isEmpty) return const [];
    final result = <_StatsVisualSession>[];
    for (final session in source) {
      if (result.isEmpty) {
        result.add(session);
        continue;
      }
      final previous = result.last;
      final sameRoot = previous.rootId == session.rootId;
      final gapSeconds = session.startWall.difference(previous.endWall).inSeconds;
      if (sameRoot && gapSeconds <= 60) {
        final mergedEnd = session.endWall.isAfter(previous.endWall)
            ? session.endWall
            : previous.endWall;
        result[result.length - 1] = _StatsVisualSession(
          rootId: previous.rootId,
          label: previous.label,
          color: previous.color,
          icon: previous.icon,
          startWall: previous.startWall,
          endWall: mergedEnd,
          seconds: mergedEnd.difference(previous.startWall).inSeconds,
        );
      } else {
        result.add(session);
      }
    }
    return result;
  }
}

class _StatsVisualSlice {
  const _StatsVisualSlice({
    required this.rootId,
    required this.label,
    required this.seconds,
    required this.color,
    required this.icon,
  });

  final int? rootId;
  final String label;
  final int seconds;
  final Color color;
  final IconData icon;
}

class _StatsVisualSession {
  const _StatsVisualSession({
    required this.rootId,
    required this.label,
    required this.color,
    required this.icon,
    required this.startWall,
    required this.endWall,
    required this.seconds,
  });

  final int? rootId;
  final String label;
  final Color color;
  final IconData icon;
  final DateTime startWall;
  final DateTime endWall;
  final int seconds;
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.data});

  final _StatsVisualData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 650;
          final donut = SizedBox(
            width: wide ? 250 : double.infinity,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(210),
                  painter: _DonutPainter(
                    slices: data.slices,
                    trackColor: scheme.surfaceContainerHighest,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(data.totalSeconds),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      t(currentLocale.value, 'total'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
          final legend = _DistributionLegend(data: data);

          if (!wide) {
            return Column(
              children: [donut, const SizedBox(height: 4), legend],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              donut,
              const SizedBox(width: 24),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }
}

class _DistributionLegend extends StatelessWidget {
  const _DistributionLegend({required this.data});

  final _StatsVisualData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final slice in data.slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: slice.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(slice.icon, size: 17, color: slice.color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    slice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(slice.seconds),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: Text(
                    data.totalSeconds <= 0
                        ? '0%'
                        : '${(slice.seconds * 100 / data.totalSeconds).round()}%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices, required this.trackColor});

  final List<_StatsVisualSlice> slices;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 18;
    const strokeWidth = 26.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    final total = slices.fold<int>(0, (sum, slice) => sum + slice.seconds);
    if (total <= 0) return;

    var start = -math.pi / 2;
    const gap = 0.018;
    for (final slice in slices) {
      final exactSweep = slice.seconds / total * math.pi * 2;
      final sweep = math.max(0.004, exactSweep - gap);
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += exactSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.trackColor != trackColor;
}

class _DayCategoryChart extends StatelessWidget {
  const _DayCategoryChart({required this.data});

  final _StatsVisualData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rangeSeconds = math.max(
      1,
      data.rangeEndWall.difference(data.rangeStartWall).inSeconds,
    );
    const hourHeight = 42.0;
    final chartHeight = math.max(300.0, rangeSeconds / 3600 * hourHeight);
    final hourMarks = <DateTime>[];
    var mark = DateTime(
      data.rangeStartWall.year,
      data.rangeStartWall.month,
      data.rangeStartWall.day,
      data.rangeStartWall.hour,
    );
    if (mark.isBefore(data.rangeStartWall)) {
      mark = mark.add(const Duration(hours: 1));
    }
    while (!mark.isAfter(data.rangeEndWall)) {
      hourMarks.add(mark);
      mark = mark.add(const Duration(hours: 1));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const labelWidth = 48.0;
          const chartGap = 10.0;
          final bodyLeft = labelWidth + chartGap;
          final bodyWidth = math.max(0.0, constraints.maxWidth - bodyLeft);
          final fmt = DateFormat.Hm(currentLocale.value);

          double yFor(DateTime value) {
            final seconds = value.difference(data.rangeStartWall).inSeconds;
            return seconds / rangeSeconds * chartHeight;
          }

          return SizedBox(
            height: chartHeight,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: bodyLeft,
                  top: 0,
                  width: bodyWidth,
                  height: chartHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  width: labelWidth,
                  child: _AxisLabel(text: fmt.format(data.rangeStartWall)),
                ),
                for (final hour in hourMarks) ...[
                  Positioned(
                    left: bodyLeft,
                    right: 0,
                    top: yFor(hour),
                    child: Container(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.30),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: math.max(0.0, yFor(hour) - 7),
                    width: labelWidth,
                    child: _AxisLabel(text: fmt.format(hour)),
                  ),
                ],
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: labelWidth,
                  child: _AxisLabel(text: fmt.format(data.rangeEndWall)),
                ),
                for (final session in data.sessions)
                  Builder(
                    builder: (_) {
                      final top = yFor(session.startWall);
                      final rawHeight = yFor(session.endWall) - top;
                      final height = math.max(3.0, rawHeight);
                      final showLabel = height >= 24;
                      final showTime = height >= 44;
                      return Positioned(
                        left: bodyLeft + 5,
                        width: math.max(0.0, bodyWidth - 10),
                        top: top,
                        height: math.min(height, math.max(0.0, chartHeight - top)),
                        child: Container(
                          padding: showLabel
                              ? const EdgeInsets.symmetric(horizontal: 9, vertical: 4)
                              : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            color: session.color.withValues(alpha: 0.68),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: session.color.withValues(alpha: 0.92),
                            ),
                          ),
                          child: showLabel
                              ? Row(
                                  children: [
                                    Icon(
                                      session.icon,
                                      size: 15,
                                      color: _foregroundFor(session.color),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: _foregroundFor(session.color),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          if (showTime)
                                            Text(
                                              '${fmt.format(session.startWall)}–${fmt.format(session.endWall)}',
                                              maxLines: 1,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: _foregroundFor(
                                                      session.color,
                                                    ).withValues(alpha: 0.82),
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

String _formatDuration(int secondsTotal) {
  if (secondsTotal <= 0) return '0m';
  final hours = secondsTotal ~/ 3600;
  final minutes = (secondsTotal % 3600) ~/ 60;
  if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
  if (hours > 0) return '${hours}h';
  if (minutes > 0) return '${minutes}m';
  return '<1m';
}

Color _foregroundFor(Color color) =>
    color.computeLuminance() > 0.48 ? Colors.black87 : Colors.white;
