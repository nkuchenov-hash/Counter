import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/sleep_record_policy.dart';
import 'package:counter/features/stats/stats_detail_tree.dart';
import 'package:counter/features/stats/stats_visual_overview.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

enum _StatsMode { details, visual }

/// Daily project/category time statistics inside Timeline.
///
/// Stats intentionally stays small: the original expandable time tree plus one
/// focused visual overview. No plan/fact dashboard or secondary KPI surfaces.
class StatsView extends StatefulWidget {
  const StatsView({
    super.key,
    required this.records,
    required this.rules,
    required this.isFutureDate,
    required this.selectedDate,
    this.onDayChanged,
  });

  final List<Map<String, dynamic>> records;
  final List<CategoryRule> rules;
  final bool isFutureDate;
  final DateTime selectedDate;
  final ValueChanged<DateTime>? onDayChanged;

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  static const int _statsPageCenter = 5000;

  final Set<String> _expandedKeys = {};
  _StatsMode _mode = _StatsMode.details;

  int? _lastAggregatedKey;
  List<StatsNode>? _cachedAggregated;
  PageController? _dayPageController;

  String _copy(String en, String ru) =>
      currentLocale.value.toLowerCase().startsWith('ru') ? ru : en;

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  int _pageIndexForDate(DateTime day) {
    final today = _dateOnly(
      DatabaseService.instance.getTimelineDeviceLocalToday(),
    );
    return _statsPageCenter + _dateOnly(day).difference(today).inDays;
  }

  int _aggregatedCacheKey(
    List<Map<String, dynamic>> records,
    DateTime selectedDate,
  ) {
    return CategoryServiceExtension.statsRecordsSignature(
      records,
      selectedDate,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.onDayChanged != null) {
      _dayPageController = PageController(
        initialPage: _pageIndexForDate(widget.selectedDate),
      );
    }
  }

  @override
  void dispose() {
    _dayPageController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onDayChanged == null && widget.onDayChanged != null) {
      _dayPageController?.dispose();
      _dayPageController = PageController(
        initialPage: _pageIndexForDate(widget.selectedDate),
      );
    } else if (oldWidget.onDayChanged != null && widget.onDayChanged == null) {
      _dayPageController?.dispose();
      _dayPageController = null;
    }

    final controller = _dayPageController;
    if (controller == null || widget.onDayChanged == null) return;

    final oldDay = oldWidget.selectedDate;
    final newDay = widget.selectedDate;
    if (oldDay.year == newDay.year &&
        oldDay.month == newDay.month &&
        oldDay.day == newDay.day) {
      return;
    }

    final target = _pageIndexForDate(newDay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentController = _dayPageController;
      if (currentController == null || !currentController.hasClients) return;
      final currentPage = currentController.page?.round() ?? target;
      if (currentPage == target) return;
      currentController.animateToPage(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (DatabaseService.instance.allCategoryIdPathPairs.isEmpty) {
      return Center(
        child: Text(
          t(currentLocale.value, 'add_categories_auditor'),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return _buildDayPager(context);
  }

  Widget _buildDayPager(BuildContext context) {
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

    final List<StatsNode> aggregated;
    if (aggregatedKey == _lastAggregatedKey && _cachedAggregated != null) {
      aggregated = _cachedAggregated!;
    } else {
      aggregated = DatabaseService.instance.getAggregatedStats(
        statsRecords,
        widget.selectedDate,
        rangeStartWall: wakingWindow.wakeWall,
        rangeEndWall: wakingWindow.bedWall,
      );
      _lastAggregatedKey = aggregatedKey;
      _cachedAggregated = aggregated;
    }

    final totalDuration = aggregated.fold<Duration>(
      Duration.zero,
      (sum, node) => sum + node.total,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<_StatsMode>(
              showSelectedIcon: false,
              style: appCompactSegmentedButtonStyle(
                context,
                segmentWidth: 112,
              ),
              segments: [
                ButtonSegment<_StatsMode>(
                  value: _StatsMode.details,
                  icon: const Icon(Icons.account_tree_rounded),
                  label: AppCompactSegmentLabel(
                    text: _copy('List', 'Список'),
                  ),
                ),
                ButtonSegment<_StatsMode>(
                  value: _StatsMode.visual,
                  icon: const Icon(Icons.donut_large_rounded),
                  label: AppCompactSegmentLabel(
                    text: _copy('Charts', 'Диаграммы'),
                  ),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                if (selection.isEmpty || selection.first == _mode) return;
                setState(() => _mode = selection.first);
              },
            ),
          ),
        ),
        Expanded(
          child: _mode == _StatsMode.details
              ? StatsDetailTree(
                  roots: aggregated,
                  totalDuration: totalDuration,
                  selectedDate: widget.selectedDate,
                  expandedKeys: _expandedKeys,
                  onToggle: (key) {
                    setState(() {
                      if (!_expandedKeys.remove(key)) {
                        _expandedKeys.add(key);
                      }
                    });
                  },
                )
              : StatsVisualOverview(
                  records: statsRecords,
                  rules: widget.rules,
                  rangeStartWall: wakingWindow.wakeWall,
                  rangeEndWall: wakingWindow.bedWall,
                ),
        ),
      ],
    );

    final navigate = widget.onDayChanged;
    final controller = _dayPageController;
    if (navigate == null || controller == null) return content;

    return PageView.builder(
      controller: controller,
      itemCount: 10000,
      onPageChanged: (index) {
        final anchor = _dateOnly(
          DatabaseService.instance.getTimelineDeviceLocalToday(),
        );
        final next = _dateOnly(
          anchor.add(Duration(days: index - _statsPageCenter)),
        );
        final selected = _dateOnly(widget.selectedDate);
        if (next == selected) return;
        navigate(next);
      },
      itemBuilder: (context, index) {
        final anchor = _dateOnly(
          DatabaseService.instance.getTimelineDeviceLocalToday(),
        );
        final pageDay = _dateOnly(
          anchor.add(Duration(days: index - _statsPageCenter)),
        );
        if (pageDay != _dateOnly(widget.selectedDate)) {
          return ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const SizedBox.expand(),
          );
        }
        return content;
      },
    );
  }
}
