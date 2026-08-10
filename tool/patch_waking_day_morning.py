from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing {label}')
    return text.replace(old, new, 1)

# ---------------------------------------------------------------------------
# StatsView: use one waking-day record set for every Stats sub-view.
# ---------------------------------------------------------------------------
p = Path('lib/features/stats/stats_view.dart')
s = p.read_text()
s = replace_once(
    s,
    "import 'package:counter/data/models.dart';\n",
    "import 'package:counter/data/models.dart';\nimport 'package:counter/features/shared/sleep_record_policy.dart';\n",
    'stats sleep policy import',
)
old = """  Widget _buildDayPager(BuildContext context) {
    final aggregatedKey = _aggregatedCacheKey(
      widget.records,
      widget.selectedDate,
    );
"""
new = """  Widget _buildDayPager(BuildContext context) {
    final wakingWindow = SleepRecordPolicy.wakingDayWindow(
      selectedDay: widget.selectedDate,
      currentRecords: widget.records,
    );
    final statsRecords = wakingWindow.records;
    final aggregatedKey = Object.hash(
      _aggregatedCacheKey(statsRecords, widget.selectedDate),
      wakingWindow.wakeWall,
      wakingWindow.bedWall,
    );
"""
s = replace_once(s, old, new, 'stats waking window')
s = replace_once(
    s,
    """      aggregated = DatabaseService.instance.getAggregatedStats(
        widget.records,
        widget.selectedDate,
      );
""",
    """      aggregated = DatabaseService.instance.getAggregatedStats(
        statsRecords,
        widget.selectedDate,
      );
""",
    'stats aggregate records',
)
s = replace_once(
    s,
    """      dashboard = DayStatsDashboardData.build(
        records: _recordsWithResolvedCategoryIds(widget.records),
        rules: widget.rules,
        aggregated: aggregated,
        selectedDate: widget.selectedDate,
      );
""",
    """      dashboard = DayStatsDashboardData.build(
        records: _recordsWithResolvedCategoryIds(statsRecords),
        rules: widget.rules,
        aggregated: aggregated,
        selectedDate: widget.selectedDate,
        rangeStartWall: wakingWindow.wakeWall,
        rangeEndWall: wakingWindow.bedWall,
      );
""",
    'stats dashboard range',
)
s = replace_once(
    s,
    "    final content = _buildStatsContent(aggregated, dashboard);\n",
    "    final content = _buildStatsContent(aggregated, dashboard, statsRecords);\n",
    'stats content call',
)
s = replace_once(
    s,
    """  Widget _buildStatsContent(
    List<StatsNode> aggregated,
    DayStatsDashboardData dashboard,
  ) {
""",
    """  Widget _buildStatsContent(
    List<StatsNode> aggregated,
    DayStatsDashboardData dashboard,
    List<Map<String, dynamic>> statsRecords,
  ) {
""",
    'stats content signature',
)
s = replace_once(
    s,
    "        records: widget.records,\n",
    "        records: statsRecords,\n",
    'plan fact waking records',
)
p.write_text(s)

# ---------------------------------------------------------------------------
# Dashboard: all visual timelines run from wake to bed, not 00:00 to 24:00.
# ---------------------------------------------------------------------------
p = Path('lib/features/stats/day_stats_dashboard.dart')
s = p.read_text()
s = replace_once(
    s,
    """  const DayStatsDashboardData({
    required this.selectedDate,
    required this.totalSeconds,
    required this.categories,
    required this.sessions,
  });

  final DateTime selectedDate;
  final int totalSeconds;
""",
    """  const DayStatsDashboardData({
    required this.selectedDate,
    required this.rangeStartWall,
    required this.rangeEndWall,
    required this.totalSeconds,
    required this.categories,
    required this.sessions,
  });

  final DateTime selectedDate;
  final DateTime rangeStartWall;
  final DateTime rangeEndWall;
  final int totalSeconds;
""",
    'dashboard range fields',
)
s = replace_once(
    s,
    """  static DayStatsDashboardData build({
    required List<Map<String, dynamic>> records,
    required List<CategoryRule> rules,
    required List<StatsNode> aggregated,
    required DateTime selectedDate,
  }) {
""",
    """  static DayStatsDashboardData build({
    required List<Map<String, dynamic>> records,
    required List<CategoryRule> rules,
    required List<StatsNode> aggregated,
    required DateTime selectedDate,
    DateTime? rangeStartWall,
    DateTime? rangeEndWall,
  }) {
""",
    'dashboard build signature',
)
s = replace_once(
    s,
    """    final dayEnd = dayStart.add(const Duration(days: 1));
    final sessions = <DayStatsSession>[];
""",
    """    final dayEnd = dayStart.add(const Duration(days: 1));
    final rangeStart = rangeStartWall ?? dayStart;
    var rangeEnd = rangeEndWall ?? dayEnd;
    if (!rangeEnd.isAfter(rangeStart)) {
      rangeEnd = rangeStart.add(const Duration(minutes: 1));
    }
    final sessions = <DayStatsSession>[];
""",
    'dashboard range defaults',
)
old = """      final seconds =
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
"""
new = """      var startWall = db.applyUserOffset(startUtc);
      var endWall = db.applyUserOffset(endUtc);
      if (startWall.isBefore(rangeStart)) startWall = rangeStart;
      if (endWall.isAfter(rangeEnd)) endWall = rangeEnd;
      if (!endWall.isAfter(startWall)) continue;
      final seconds = endWall.difference(startWall).inSeconds;
      if (seconds <= 0) continue;
"""
s = replace_once(s, old, new, 'dashboard range duration')
s = replace_once(
    s,
    """    final totalSeconds = aggregated.fold<int>(
      0,
      (sum, node) => sum + node.totalSeconds,
    );

    return DayStatsDashboardData(
      selectedDate: dayStart,
      totalSeconds: totalSeconds,
""",
    """    final totalSeconds = sessions.fold<int>(
      0,
      (sum, session) => sum + session.seconds,
    );

    return DayStatsDashboardData(
      selectedDate: dayStart,
      rangeStartWall: rangeStart,
      rangeEndWall: rangeEnd,
      totalSeconds: totalSeconds,
""",
    'dashboard total and return range',
)

# Replace full desktop horizontal ribbon.
start = s.index('class _HorizontalDay extends StatelessWidget {')
end = s.index('\nclass _CompactDayPreview', start)
horizontal = r'''class _HorizontalDay extends StatelessWidget {
  const _HorizontalDay({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat.Hm(currentLocale.value);
    final rangeSeconds = math.max(
      1.0,
      data.rangeEndWall.difference(data.rangeStartWall).inSeconds.toDouble(),
    );
    final middle = data.rangeStartWall.add(
      Duration(seconds: (rangeSeconds / 2).round()),
    );
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(fmt.format(data.rangeStartWall)),
            Text(fmt.format(middle)),
            Text(fmt.format(data.rangeEndWall)),
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
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: c.maxWidth / 2,
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
                          .difference(data.rangeStartWall)
                          .inSeconds
                          .clamp(0, rangeSeconds.round())
                          .toDouble();
                      final end = session.endWall
                          .difference(data.rangeStartWall)
                          .inSeconds
                          .clamp(0, rangeSeconds.round())
                          .toDouble();
                      final left = c.maxWidth * start / rangeSeconds;
                      final width = c.maxWidth * (end - start) / rangeSeconds;
                      return Positioned(
                        left: left,
                        top: 5,
                        bottom: 5,
                        width: math.min(
                          math.max(0.0, width),
                          math.max(0.0, c.maxWidth - left),
                        ),
                        child: Tooltip(
                          message: '${session.title} · ${_durationShort(session.seconds)}',
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
'''
s = s[:start] + horizontal + s[end:]

# Replace mobile overview preview with waking interval, preserving exact scale.
start = s.index('class _MiniVerticalDay extends StatelessWidget {')
end = s.index('\nclass _DayView', start)
mini = r'''class _MiniVerticalDay extends StatelessWidget {
  const _MiniVerticalDay({required this.data});
  final DayStatsDashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat.Hm(currentLocale.value);
    const height = 250.0;
    const labelWidth = 40.0;
    final rangeMinutes = math.max(
      1,
      data.rangeEndWall.difference(data.rangeStartWall).inMinutes,
    );
    final middle = data.rangeStartWall.add(
      Duration(minutes: (rangeMinutes / 2).round()),
    );
    final marks = [data.rangeStartWall, middle, data.rangeEndWall];
    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyWidth = math.max(0.0, constraints.maxWidth - labelWidth - 6);
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (var i = 0; i < marks.length; i++) ...[
                Positioned(
                  left: 0,
                  top: i / (marks.length - 1) * (height - 16),
                  width: labelWidth - 4,
                  child: Text(
                    fmt.format(marks[i]),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Positioned(
                  left: labelWidth,
                  right: 0,
                  top: i / (marks.length - 1) * (height - 16) + 6,
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
                        .difference(data.rangeStartWall)
                        .inMinutes
                        .clamp(0, rangeMinutes);
                    final end = session.endWall
                        .difference(data.rangeStartWall)
                        .inMinutes
                        .clamp(0, rangeMinutes);
                    final top = start / rangeMinutes * (height - 16) + 5;
                    final h = (end - start) / rangeMinutes * (height - 16);
                    return Positioned(
                      left: labelWidth + 6,
                      width: bodyWidth,
                      top: top,
                      height: math.min(math.max(0.0, h), height - top),
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
'''
s = s[:start] + mini + s[end:]

# Replace full Day grid with wake-to-bed clock-aligned grid.
start = s.index('class _TimeGrid extends StatefulWidget {')
end = s.index('\nclass _CategoryPanel', start)
time_grid = r'''class _TimeGrid extends StatefulWidget {
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

  DateTime _ceilHour(DateTime value) {
    final floor = DateTime(value.year, value.month, value.day, value.hour);
    return value == floor ? floor : floor.add(const Duration(hours: 1));
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
    final rangeMinutes = math.max(
      1,
      data.rangeEndWall.difference(data.rangeStartWall).inMinutes,
    );
    final gridHeight = rangeMinutes / 60 * hourHeight;
    final labelWidth = mobile ? 46.0 : 58.0;
    final showHalfHours = _zoom >= 1.5;
    final hourMarks = <DateTime>[];
    for (var mark = _ceilHour(data.rangeStartWall);
        !mark.isAfter(data.rangeEndWall);
        mark = mark.add(const Duration(hours: 1))) {
      hourMarks.add(mark);
    }

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
                      '${fmt.format(data.rangeStartWall)} — ${fmt.format(data.rangeEndWall)} · ${DateFormat('EEEE, MMM d', currentLocale.value).format(data.selectedDate)}',
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
                label: Text(_copy('Fit waking day', 'Весь день')),
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
              'Sleep is excluded. The tape runs from wake-up to the next main sleep.',
              'Сон не показывается. Лента идёт от подъёма до следующего основного сна.',
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
                final bodyWidth = math.max(0.0, constraints.maxWidth - bodyLeft);
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
                              color: scheme.outlineVariant.withValues(alpha: 0.20),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        width: labelWidth,
                        child: Text(
                          fmt.format(data.rangeStartWall),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      for (final mark in hourMarks) ...[
                        Builder(
                          builder: (_) {
                            final top = mark
                                    .difference(data.rangeStartWall)
                                    .inMinutes /
                                60 *
                                hourHeight;
                            return Positioned(
                              left: bodyLeft,
                              right: 0,
                              top: math.min(gridHeight - 1, top),
                              child: Container(
                                height: 1,
                                color: scheme.outlineVariant.withValues(alpha: 0.20),
                              ),
                            );
                          },
                        ),
                        Builder(
                          builder: (_) {
                            final top = mark
                                    .difference(data.rangeStartWall)
                                    .inMinutes /
                                60 *
                                hourHeight;
                            return Positioned(
                              left: 0,
                              top: math.min(
                                math.max(0.0, gridHeight - 15),
                                math.max(0.0, top - 7),
                              ),
                              width: labelWidth,
                              child: Text(
                                fmt.format(mark),
                                textAlign: TextAlign.right,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            );
                          },
                        ),
                        if (showHalfHours &&
                            mark.subtract(const Duration(minutes: 30)).isAfter(data.rangeStartWall))
                          Builder(
                            builder: (_) {
                              final half = mark.subtract(const Duration(minutes: 30));
                              final top = half
                                      .difference(data.rangeStartWall)
                                      .inMinutes /
                                  60 *
                                  hourHeight;
                              return Positioned(
                                left: bodyLeft,
                                right: 0,
                                top: top,
                                child: Container(
                                  height: 1,
                                  color: scheme.outlineVariant.withValues(alpha: 0.08),
                                ),
                              );
                            },
                          ),
                      ],
                      Positioned(
                        left: 0,
                        bottom: 0,
                        width: labelWidth,
                        child: Text(
                          fmt.format(data.rangeEndWall),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      for (final session in data.sessions)
                        Builder(
                          builder: (_) {
                            final startMinutes = session.startWall
                                .difference(data.rangeStartWall)
                                .inMinutes
                                .clamp(0, rangeMinutes);
                            final endMinutes = session.endWall
                                .difference(data.rangeStartWall)
                                .inMinutes
                                .clamp(0, rangeMinutes);
                            final top = startMinutes / 60 * hourHeight;
                            final rawHeight =
                                (endMinutes - startMinutes) / 60 * hourHeight;
                            final blockHeight = math.min(
                              math.max(0.0, rawHeight),
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
                                        session.color.withValues(alpha: dark ? 0.38 : 0.28),
                                        session.color.withValues(alpha: dark ? 0.20 : 0.12),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: session.color.withValues(alpha: dark ? 0.64 : 0.50),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: session.color.withValues(alpha: dark ? 0.17 : 0.12),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(width: 4, color: session.color),
                                      if (showTitle) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(vertical: showMeta ? 5 : 2),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  session.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                if (showMeta)
                                                  Text(
                                                    '${fmt.format(session.startWall)} — ${fmt.format(session.endWall)} · ${session.categoryLabel}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: theme.textTheme.labelSmall?.copyWith(
                                                      color: scheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (blockHeight >= 34)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Center(
                                              child: Text(
                                                _durationShort(session.seconds),
                                                style: theme.textTheme.labelMedium?.copyWith(
                                                  color: session.color,
                                                  fontWeight: FontWeight.w900,
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
'''
s = s[:start] + time_grid + s[end:]
p.write_text(s)

# ---------------------------------------------------------------------------
# Plan / Fact: exclude Sleep from both task and time dimensions.
# ---------------------------------------------------------------------------
p = Path('lib/features/stats/plan_vs_fact_tab.dart')
s = p.read_text()
s = replace_once(
    s,
    "import 'package:counter/data/models.dart';\n",
    "import 'package:counter/data/models.dart';\nimport 'package:counter/features/shared/sleep_record_policy.dart';\n",
    'plan fact sleep policy import',
)
s = replace_once(
    s,
    "  List<PlanningTask> get plans => stats.plansScheduledThisDay;\n",
    """  List<PlanningTask> get plans => stats.plansScheduledThisDay
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
""",
    'plan fact non-sleep getters',
)
s = s.replace('facts.stats.planTimeSeconds', 'facts.plannedTimeSeconds')
s = s.replace('facts.stats.factTimeSeconds', 'facts.factTimeSeconds')
s = replace_once(
    s,
    """        db.rules.where((rule) {
          final plannedSeconds = _sumSecondsInSubtree(
""",
    """        db.rules.where((rule) {
          if (SleepRecordPolicy.isSleepCategoryId(rule.id)) return false;
          final plannedSeconds = _sumSecondsInSubtree(
""",
    'plan fact root filter',
)
p.write_text(s)

# ---------------------------------------------------------------------------
# Timeline: run the morning gate only on the active current-day page.
# ---------------------------------------------------------------------------
p = Path('lib/features/timeline/timeline_view.dart')
s = p.read_text()
s = replace_once(
    s,
    "import 'package:counter/features/timeline/timeline_header_controls.dart';\n",
    "import 'package:counter/features/timeline/timeline_header_controls.dart';\nimport 'package:counter/features/timeline/timeline_morning_start.dart';\n",
    'timeline morning import',
)
old = """            Expanded(
              child: kUseMountedDayStrip &&
                      widget.mountedWindow != null &&
"""
new = """            Expanded(
              child: MorningStartGate(
                selectedDate: _visibleDate,
                active: widget.isActivePage && widget.shellTabActive,
                titleController: widget.titleController,
                titleFocus: widget.titleFocus,
                onStart: widget.onStart,
                child: kUseMountedDayStrip &&
                      widget.mountedWindow != null &&
"""
s = replace_once(s, old, new, 'timeline morning gate open')
old = """                  : const ColoredBox(
                      color: Colors.transparent,
                      child: SizedBox.expand(),
                    ),
            ),
"""
new = """                  : const ColoredBox(
                      color: Colors.transparent,
                      child: SizedBox.expand(),
                    ),
              ),
            ),
"""
s = replace_once(s, old, new, 'timeline morning gate close')
p.write_text(s)

# ---------------------------------------------------------------------------
# Architecture manifest for the two new production files.
# ---------------------------------------------------------------------------
p = Path('docs/APP_STRUCTURE.md')
s = p.read_text()
s = replace_once(
    s,
    "| `timeline/timeline_header_controls.dart` | List/stats segmented control + record input row |\n",
    "| `timeline/timeline_header_controls.dart` | List/stats segmented control + record input row |\n| `timeline/timeline_morning_start.dart` | Morning Start Day check-in: sleep confirmation + first Timeline record |\n| `shared/sleep_record_policy.dart` | Shared Timeline/Stats policy for sleep detection and wake-to-bed day boundaries |\n",
    'architecture new files',
)
p.write_text(s)
