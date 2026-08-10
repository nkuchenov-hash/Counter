from pathlib import Path

p = Path('lib/features/stats/day_stats_dashboard.dart')
s = p.read_text()
old_start = 'class _TimeGrid extends StatelessWidget {'
if old_start not in s:
    raise SystemExit(0)
start = s.index(old_start)
end = s.index('\nclass _CategoryPanel', start)
replacement = r'''class _TimeGrid extends StatefulWidget {
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
                              color: scheme.outlineVariant.withValues(alpha: 0.20),
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
                              color: scheme.outlineVariant.withValues(alpha: 0.08),
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
                            final rawHeight = math.max(
                              2.0,
                              (endMinutes - startMinutes) / 60 * hourHeight,
                            );
                            final blockHeight = math.min(
                              math.max(mobile ? 20.0 : 18.0, rawHeight),
                              math.max(2.0, gridHeight - top),
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
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
p.write_text(s[:start] + replacement + s[end:])
