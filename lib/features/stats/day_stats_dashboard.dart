import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum DayStatsDashboardMode { overview, timeline, planFact, details }

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

    void register(CategoryRule rule, CategoryRule root) {
      rootByCategoryId[rule.id] = root;
      for (final child in rule.children ?? const <CategoryRule>[]) {
        register(child, root);
      }
    }

    for (final root in rules) {
      register(root, root);
    }

    const fallbackColor = Color(0xFF8A8A8A);
    const fallbackIcon = Icons.folder_rounded;
    final db = DatabaseService.instance;

    CategoryRule? rootForRecord(Map<String, dynamic> record) {
      final rawCategory =
          record['categoryId'] ?? record['category_id'] ?? record['category'];
      if (rawCategory == null) return null;
      final probe = record['categoryId'] == rawCategory
          ? record
          : <String, dynamic>{...record, 'categoryId': rawCategory};
      final localId = db.resolvedCategoryIdForRecord(probe);
      return localId == null ? null : rootByCategoryId[localId];
    }

    final dayStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final sessions = <DayStatsSession>[];
    final secondsByRoot = <int, int>{};
    var unresolvedSeconds = 0;

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
            db.settings.timezoneOffsetHours,
            db.settings.preferredTimeZone,
          );
      if (seconds <= 0) continue;

      var startWall = db.applyUserOffset(startUtc);
      var endWall = db.applyUserOffset(endUtc);
      if (startWall.isBefore(dayStart)) startWall = dayStart;
      if (endWall.isAfter(dayEnd)) endWall = dayEnd;
      if (!endWall.isAfter(startWall)) continue;

      final root = rootForRecord(record);
      if (root == null) {
        unresolvedSeconds += seconds;
      } else {
        secondsByRoot[root.id] = (secondsByRoot[root.id] ?? 0) + seconds;
      }

      final rawTitle = (record['title'] as String?)?.trim();
      final title = rawTitle != null && rawTitle.isNotEmpty
          ? rawTitle
          : t(currentLocale.value, 'untitled');
      sessions.add(
        DayStatsSession(
          title: title,
          categoryLabel: root != null
              ? localizeCategoryDbSegment(root.name, currentLocale.value)
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
    final categories = <DayStatsCategorySlice>[
      for (final root in rules)
        if ((secondsByRoot[root.id] ?? 0) > 0)
          DayStatsCategorySlice(
            label: localizeCategoryDbSegment(root.name, currentLocale.value),
            seconds: secondsByRoot[root.id]!,
            color: root.colorOrDefault,
            icon: root.iconOrDefault,
          ),
      if (unresolvedSeconds > 0)
        DayStatsCategorySlice(
          label: t(currentLocale.value, 'uncategorized'),
          seconds: unresolvedSeconds,
          color: fallbackColor,
          icon: fallbackIcon,
        ),
    ];

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

/// Final Timeline > Stats presentation.
///
/// One navigation level only: Overview / Day / Plan-Fact / Details. Stats stays
/// inside Timeline; the old detailed daily tree is injected as [detailsView].
class DayStatsDashboard extends StatelessWidget {
  const DayStatsDashboard({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.data,
    required this.planFactView,
    required this.detailsView,
  });

  final DayStatsDashboardMode mode;
  final ValueChanged<DayStatsDashboardMode> onModeChanged;
  final DayStatsDashboardData data;
  final Widget planFactView;
  final Widget detailsView;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: _ModeRail(mode: mode, onChanged: onModeChanged),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    switch (mode) {
      case DayStatsDashboardMode.overview:
        return _Overview(data: data);
      case DayStatsDashboardMode.timeline:
        return _DayView(data: data);
      case DayStatsDashboardMode.planFact:
        return planFactView;
      case DayStatsDashboardMode.details:
        return detailsView;
    }
  }
}

class _ModeRail extends StatelessWidget {
  const _ModeRail({required this.mode, required this.onChanged});
  final DayStatsDashboardMode mode;
  final ValueChanged<DayStatsDashboardMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;
        final width = math.max(
          compact ? 66.0 : 84.0,
          math.min(compact ? 91.0 : 124.0, constraints.maxWidth / 4),
        );
        return SizedBox(
          height: kAppCompactControlHeight,
          child: SegmentedButton<DayStatsDashboardMode>(
            showSelectedIcon: false,
            style: appCompactSegmentedButtonStyle(context, segmentWidth: width),
            segments: [
              ButtonSegment(
                value: DayStatsDashboardMode.overview,
                icon: const Icon(Icons.blur_on_rounded),
                label: AppCompactSegmentLabel(
                  text: t(currentLocale.value, 'stats'),
                ),
              ),
              ButtonSegment(
                value: DayStatsDashboardMode.timeline,
                icon: const Icon(Icons.calendar_view_day_rounded),
                label: AppCompactSegmentLabel(
                  text: t(currentLocale.value, 'timeline'),
                ),
              ),
              ButtonSegment(
                value: DayStatsDashboardMode.planFact,
                icon: const Icon(Icons.compare_arrows_rounded),
                label: AppCompactSegmentLabel(
                  text: t(currentLocale.value, 'stats_tab_plan_fact'),
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
              if (selection.isNotEmpty) onChanged(selection.first);
            },
          ),
        );
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        final pad = mobile ? 12.0 : 18.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 30),
          children: [
            _Hero(data: data, compact: mobile),
            const SizedBox(height: 14),
            if (mobile) ...[
              _CompactDayPreview(data: data),
              const SizedBox(height: 14),
              _CategoryPanel(data: data),
              const SizedBox(height: 14),
              _Signals(data: data),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _CategoryPanel(data: data)),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: _Signals(data: data)),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sorted = [...data.categories]
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    final dominant = sorted.isEmpty ? null : sorted.first;
    final longest = data.longestSession;
    final fmt = DateFormat('EEEE · MMMM d', currentLocale.value);

    return _Glass(
      accent: dominant?.color,
      padding: EdgeInsets.all(compact ? 17 : 22),
      child: Stack(
        children: [
          if (dominant != null)
            Positioned(
              right: -70,
              top: -90,
              child: _GlowOrb(color: dominant.color, size: compact ? 190 : 250),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fmt.format(data.selectedDate),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      _durationLong(data.totalSeconds),
                      style:
                          (compact
                                  ? theme.textTheme.displaySmall
                                  : theme.textTheme.displayMedium)
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.6,
                                height: 0.95,
                              ),
                    ),
                  ),
                  if (!compact)
                    _SoftPill(
                      icon: Icons.view_agenda_outlined,
                      text:
                          '${data.sessions.length} ${t(currentLocale.value, 'stats_pvf_row_tasks').toLowerCase()}',
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                t(currentLocale.value, 'total'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (compact) ...[
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SoftPill(
                      icon: Icons.view_agenda_outlined,
                      text: '${data.sessions.length}',
                    ),
                    if (longest != null)
                      _SoftPill(
                        icon: Icons.timelapse_rounded,
                        text: _durationShort(longest.seconds),
                        color: longest.color,
                      ),
                    if (dominant != null)
                      _SoftPill(
                        icon: dominant.icon,
                        text: dominant.label,
                        color: dominant.color,
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 24),
                _HorizontalDay(data: data),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (dominant != null)
                      Expanded(
                        child: _HeroSignal(
                          icon: dominant.icon,
                          label: dominant.label,
                          value: _durationShort(dominant.seconds),
                          color: dominant.color,
                        ),
                      ),
                    if (dominant != null && longest != null)
                      const SizedBox(width: 10),
                    if (longest != null)
                      Expanded(
                        child: _HeroSignal(
                          icon: Icons.timelapse_rounded,
                          label: longest.title,
                          value: _durationShort(longest.seconds),
                          color: longest.color,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSignal extends StatelessWidget {
  const _HeroSignal({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
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

class _SoftPill extends StatelessWidget {
  const _SoftPill({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
          builder: (context, c) => SizedBox(
            height: 42,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.28,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
                for (final hour in const [6, 12, 18])
                  Positioned(
                    left: c.maxWidth * hour / 24,
                    top: 6,
                    bottom: 6,
                    child: Container(
                      width: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.24),
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
                      final width = math.max(
                        3.0,
                        c.maxWidth * (end - start) / daySeconds,
                      );
                      return Positioned(
                        left: left,
                        top: 5,
                        bottom: 5,
                        width: math.min(
                          width,
                          math.max(0.0, c.maxWidth - left),
                        ),
                        child: Tooltip(
                          message:
                              '${session.title} · ${_durationShort(session.seconds)}',
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  session.color.withValues(alpha: 0.94),
                                  session.color.withValues(alpha: 0.70),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: session.color.withValues(alpha: 0.24),
                                  blurRadius: 11,
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

class _CompactDayPreview extends StatelessWidget {
  const _CompactDayPreview({required this.data});
  final DayStatsDashboardData data;

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
              Expanded(
                child: Text(
                  t(currentLocale.value, 'timeline'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_view_day_rounded,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MiniVerticalDay(data: data),
        ],
      ),
    );
  }
}

class _MiniVerticalDay extends StatelessWidget {
  const _MiniVerticalDay({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const height = 250.0;
    const labelWidth = 32.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyWidth = math.max(0.0, constraints.maxWidth - labelWidth - 6);
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (final hour in const [0, 6, 12, 18, 24]) ...[
                Positioned(
                  left: 0,
                  top: (hour / 24) * (height - 16),
                  width: 26,
                  child: Text(
                    hour.toString().padLeft(2, '0'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Positioned(
                  left: labelWidth,
                  right: 0,
                  top: (hour / 24) * (height - 16) + 6,
                  child: Container(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
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
                    final top = start / 1440 * (height - 16) + 5;
                    final h = math.max(
                      5.0,
                      (end - start) / 1440 * (height - 16),
                    );
                    return Positioned(
                      left: labelWidth + 6,
                      width: bodyWidth,
                      top: top,
                      height: math.min(h, height - top),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: session.color.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: session.color.withValues(alpha: 0.14),
                              blurRadius: 7,
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
        final mobile = constraints.maxWidth < 700;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            mobile ? 12 : 18,
            8,
            mobile ? 12 : 18,
            30,
          ),
          children: [_TimeGrid(data: data, mobile: mobile)],
        );
      },
    );
  }
}

/// A calendar-like 24-hour grid. Activity is represented by spatial, colored
/// blocks rather than dots/list rows, so the shape of the day is readable at a
/// glance. Mobile deliberately keeps the day vertical.
class _TimeGrid extends StatefulWidget {
  const _TimeGrid({required this.data, required this.mobile});
  final DayStatsDashboardData data;
  final bool mobile;

  @override
  State<_TimeGrid> createState() => _TimeGridState();
}

class _TimeGridState extends State<_TimeGrid> {
  static const double _minZoom = 0.75;
  static const double _maxZoom = 3.0;
  static const double _zoomStep = 0.25;
  double _zoom = 1.5;

  String _copy(String en, String ru) =>
      currentLocale.value.toLowerCase().startsWith('ru') ? ru : en;

  void _setZoom(double value) {
    final next = value.clamp(_minZoom, _maxZoom).toDouble();
    if ((next - _zoom).abs() < 0.001) return;
    setState(() => _zoom = next);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final mobile = widget.mobile;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fmt = DateFormat.Hm(currentLocale.value);
    final baseHourHeight = mobile ? 50.0 : 44.0;
    final hourHeight = baseHourHeight * _zoom;
    final gridHeight = hourHeight * 24;
    final labelWidth = mobile ? 40.0 : 54.0;
    final labelEvery = _zoom >= 1.25 ? 1 : 2;
    final showHalfHours = _zoom >= 1.5;

    return _Glass(
      padding: EdgeInsets.fromLTRB(mobile ? 10 : 16, 16, mobile ? 10 : 16, 18),
      child: Column(
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
                      t(currentLocale.value, 'timeline'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat(
                        'EEEE, MMM d',
                        currentLocale.value,
                      ).format(data.selectedDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SoftPill(
                icon: Icons.schedule_rounded,
                text: _durationLong(data.totalSeconds),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_rounded, size: 19),
                      tooltip: _copy('Zoom out', 'Уменьшить масштаб'),
                      onPressed: _zoom <= _minZoom
                          ? null
                          : () => _setZoom(_zoom - _zoomStep),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${(_zoom * 100).round()}%',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_rounded, size: 19),
                      tooltip: _copy('Zoom in', 'Увеличить масштаб'),
                      onPressed: _zoom >= _maxZoom
                          ? null
                          : () => _setZoom(_zoom + _zoomStep),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _setZoom(0.75),
                icon: const Icon(Icons.fit_screen_rounded, size: 17),
                label: Text(_copy('Fit day', 'Весь день')),
              ),
              TextButton.icon(
                onPressed: () => _setZoom(1.5),
                icon: const Icon(Icons.view_day_rounded, size: 17),
                label: Text(_copy('Comfort', 'Подробно')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _copy(
              'Increase scale to turn the day into a long, scrollable tape.',
              'Увеличивайте масштаб — день станет длинной прокручиваемой лентой.',
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (data.sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 44),
              child: Center(
                child: Text(
                  t(currentLocale.value, 'no_records_yet'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final bodyLeft = labelWidth + 8;
                final bodyWidth = math.max(
                  0.0,
                  constraints.maxWidth - bodyLeft,
                );
                return SizedBox(
                  height: gridHeight,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: bodyLeft,
                        top: 0,
                        width: bodyWidth,
                        height: gridHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: dark ? 0.13 : 0.20,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (showHalfHours)
                        for (var half = 1; half < 48; half += 2)
                          Positioned(
                            left: bodyLeft,
                            right: 0,
                            top: half * hourHeight / 2,
                            child: Container(
                              height: 1,
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                      for (var hour = 0; hour <= 24; hour++) ...[
                        Positioned(
                          left: bodyLeft,
                          right: 0,
                          top: math.min(gridHeight - 1, hour * hourHeight),
                          child: Container(
                            height: 1,
                            color: scheme.outlineVariant.withValues(
                              alpha: hour % 6 == 0 ? 0.36 : 0.18,
                            ),
                          ),
                        ),
                        if (hour % labelEvery == 0)
                          Positioned(
                            left: 0,
                            top: math.min(
                              gridHeight - 15,
                              math.max(0.0, hour * hourHeight - 7),
                            ),
                            width: labelWidth,
                            child: Text(
                              hour.toString().padLeft(2, '0'),
                              textAlign: TextAlign.right,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                      ],
                      for (final session in data.sessions)
                        Builder(
                          builder: (_) {
                            final startMinutes = session.startWall
                                .difference(data.selectedDate)
                                .inMinutes
                                .clamp(0, 1440);
                            final endMinutes = session.endWall
                                .difference(data.selectedDate)
                                .inMinutes
                                .clamp(0, 1440);
                            final top = startMinutes / 60 * hourHeight;
                            final rawHeight =
                                (endMinutes - startMinutes) / 60 * hourHeight;
                            final blockHeight = math.min(
                              rawHeight,
                              math.max(0.0, gridHeight - top),
                            );
                            final showTitle = blockHeight >= 27;
                            final showMeta = blockHeight >= (mobile ? 50 : 46);
                            return Positioned(
                              left: bodyLeft + 5,
                              width: math.max(0.0, bodyWidth - 10),
                              top: top,
                              height: blockHeight,
                              child: Tooltip(
                                message:
                                    '${fmt.format(session.startWall)} — ${fmt.format(session.endWall)} · ${session.title}',
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        session.color.withValues(
                                          alpha: dark ? 0.38 : 0.28,
                                        ),
                                        session.color.withValues(
                                          alpha: dark ? 0.20 : 0.12,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: session.color.withValues(
                                        alpha: dark ? 0.64 : 0.50,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: session.color.withValues(
                                          alpha: dark ? 0.17 : 0.12,
                                        ),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(width: 4, color: session.color),
                                      if (showTitle) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: showMeta ? 5 : 2,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  session.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                                if (showMeta)
                                                  Text(
                                                    '${fmt.format(session.startWall)} — ${fmt.format(session.endWall)} · ${session.categoryLabel}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: scheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (blockHeight >= 34)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Center(
                                              child: Text(
                                                _durationShort(session.seconds),
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: session.color,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                              ),
                                            ),
                                          ),
                                      ],
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
      ),
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final categories = [...data.categories]
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'stats_pvf_by_category'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _Spectrum(categories: categories),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            Text('—', style: Theme.of(context).textTheme.bodyMedium)
          else
            for (final category in categories.take(8))
              _CategoryRow(category: category, totalSeconds: data.totalSeconds),
        ],
      ),
    );
  }
}

class _Spectrum extends StatelessWidget {
  const _Spectrum({required this.categories});
  final List<DayStatsCategorySlice> categories;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (categories.isEmpty) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 13,
        child: Row(
          children: [
            for (final category in categories)
              Expanded(
                flex: math.max(1, category.seconds),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        category.color.withValues(alpha: 0.95),
                        category.color.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.totalSeconds});
  final DayStatsCategorySlice category;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final share = totalSeconds > 0 ? category.seconds / totalSeconds : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                  border: Border.all(
                    color: category.color.withValues(alpha: 0.16),
                  ),
                ),
                child: Icon(category.icon, size: 18, color: category.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _durationLong(category.seconds),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
                child: Text(
                  '${(share * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 5,
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
                    widthFactor: share.clamp(0.0, 1.0).toDouble(),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            category.color,
                            category.color.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
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

class _Signals extends StatelessWidget {
  const _Signals({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final categories = [...data.categories]
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    final top = categories.isEmpty ? null : categories.first;
    final longest = data.longestSession;
    final average = data.sessions.isEmpty
        ? 0
        : data.totalSeconds ~/ data.sessions.length;
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLocale.value, 'stats'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 11),
          _Signal(
            icon: Icons.timelapse_rounded,
            label: t(currentLocale.value, 'long_duration'),
            value: longest == null ? '—' : _durationShort(longest.seconds),
            supporting: longest?.title,
            accent: longest?.color,
          ),
          _Signal(
            icon: top?.icon ?? Icons.category_outlined,
            label: t(currentLocale.value, 'category_label'),
            value: top?.label ?? '—',
            supporting: top == null ? null : _durationLong(top.seconds),
            accent: top?.color,
          ),
          _Signal(
            icon: Icons.av_timer_rounded,
            label: t(currentLocale.value, 'stats_pvf_row_time'),
            value: average == 0 ? '—' : _durationShort(average),
            supporting:
                '${data.sessions.length} ${t(currentLocale.value, 'stats_pvf_row_tasks').toLowerCase()}',
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 9),
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

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.15
                  : 0.10,
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
          BoxShadow(
            color: glow.withValues(alpha: dark ? 0.045 : 0.025),
            blurRadius: 30,
            spreadRadius: -8,
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

String _durationShort(int secondsTotal) {
  if (secondsTotal <= 0) return '0m';
  final hours = secondsTotal ~/ 3600;
  final minutes = (secondsTotal % 3600) ~/ 60;
  if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
  if (hours > 0) return '${hours}h';
  if (minutes > 0) return '${minutes}m';
  return '${secondsTotal}s';
}

String _durationLong(int secondsTotal) {
  if (secondsTotal <= 0) return '0 h 00 m';
  final hours = secondsTotal ~/ 3600;
  final minutes = (secondsTotal % 3600) ~/ 60;
  return '$hours h ${minutes.toString().padLeft(2, '0')} m';
}
