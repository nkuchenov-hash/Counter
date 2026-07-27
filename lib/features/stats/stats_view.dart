import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/stats/day_stats_dashboard.dart';
import 'package:counter/features/stats/plan_vs_fact_tab.dart';
import 'package:counter/features/stats/stats_detail_tree.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Daily statistics: the existing expandable tree remains available as the
/// Details dashboard, while overview/timeline/category views are read-only UI.
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

  /// Swipe between calendar days in Stats; matches Timeline day navigation.
  final ValueChanged<DateTime>? onDayChanged;

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  static const int _statsPageCenter = 5000;

  final Set<String> _expandedKeys = {};
  DayStatsDashboardMode _dashboardMode = DayStatsDashboardMode.overview;

  int? _lastAggregatedKey;
  List<StatsNode>? _cachedAggregated;
  int? _lastDashboardKey;
  DayStatsDashboardData? _cachedDashboard;

  PageController? _dayPageController;

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  int _pageIndexForDate(DateTime day) {
    final today =
        _dateOnly(DatabaseService.instance.getTimelineDeviceLocalToday());
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

  int _rulesVisualSignature(Iterable<CategoryRule> roots) {
    var signature = 17;

    void walk(CategoryRule rule) {
      signature = Object.hash(
        signature,
        rule.id,
        rule.name,
        rule.colorValue,
        rule.iconCodePoint,
      );
      for (final child in rule.children ?? const <CategoryRule>[]) {
        walk(child);
      }
    }

    for (final root in roots) {
      walk(root);
    }
    return signature;
  }

  @override
  void initState() {
    super.initState();
    if (widget.onDayChanged != null) {
      _dayPageController =
          PageController(initialPage: _pageIndexForDate(widget.selectedDate));
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
      _dayPageController =
          PageController(initialPage: _pageIndexForDate(widget.selectedDate));
    } else if (oldWidget.onDayChanged != null &&
        widget.onDayChanged == null) {
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final locale = currentLocale.value;
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            tabs: [
              Tab(text: t(locale, 'stats_tab_time_tracker')),
              Tab(text: t(locale, 'stats_tab_plan_fact')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTrackerTab(context),
                PlanVsFactTab(
                  selectedDate: widget.selectedDate,
                  records: widget.records,
                  isFutureDate: widget.isFutureDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerTab(BuildContext context) {
    final aggregatedKey =
        _aggregatedCacheKey(widget.records, widget.selectedDate);
    final List<StatsNode> aggregated;
    if (aggregatedKey == _lastAggregatedKey && _cachedAggregated != null) {
      aggregated = _cachedAggregated!;
    } else {
      aggregated = DatabaseService.instance.getAggregatedStats(
        widget.records,
        widget.selectedDate,
      );
      _lastAggregatedKey = aggregatedKey;
      _cachedAggregated = aggregated;
    }

    final dashboardKey = Object.hash(
      aggregatedKey,
      _rulesVisualSignature(widget.rules),
    );
    final DayStatsDashboardData dashboard;
    if (dashboardKey == _lastDashboardKey && _cachedDashboard != null) {
      dashboard = _cachedDashboard!;
    } else {
      dashboard = DayStatsDashboardData.build(
        records: widget.records,
        rules: widget.rules,
        aggregated: aggregated,
        selectedDate: widget.selectedDate,
      );
      _lastDashboardKey = dashboardKey;
      _cachedDashboard = dashboard;
    }

    final content = _buildStatsContent(context, aggregated, dashboard);
    final navigate = widget.onDayChanged;
    final controller = _dayPageController;
    if (navigate == null || controller == null) return content;

    return PageView.builder(
      controller: controller,
      itemCount: 10000,
      onPageChanged: (index) {
        final anchor =
            _dateOnly(DatabaseService.instance.getTimelineDeviceLocalToday());
        final next =
            _dateOnly(anchor.add(Duration(days: index - _statsPageCenter)));
        final selected = _dateOnly(widget.selectedDate);
        if (next == selected) return;
        navigate(next);
      },
      itemBuilder: (context, index) {
        final anchor =
            _dateOnly(DatabaseService.instance.getTimelineDeviceLocalToday());
        final pageDay =
            _dateOnly(anchor.add(Duration(days: index - _statsPageCenter)));
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

  Widget _buildStatsContent(
    BuildContext context,
    List<StatsNode> aggregated,
    DayStatsDashboardData dashboard,
  ) {
    if (widget.records.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Text(
          widget.isFutureDate
              ? t(currentLocale.value, 'no_planned_tasks')
              : t(currentLocale.value, 'no_records_yet'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return DayStatsDashboard(
      mode: _dashboardMode,
      onModeChanged: (mode) {
        if (mode == _dashboardMode) return;
        setState(() => _dashboardMode = mode);
      },
      data: dashboard,
      detailsView: StatsDetailTree(
        roots: aggregated,
        totalDuration: Duration(seconds: dashboard.totalSeconds),
        selectedDate: widget.selectedDate,
        expandedKeys: _expandedKeys,
        onToggle: (key) {
          setState(() {
            if (!_expandedKeys.remove(key)) {
              _expandedKeys.add(key);
            }
          });
        },
      ),
    );
  }
}
