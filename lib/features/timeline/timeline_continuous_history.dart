import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/timeline/timeline_header_controls.dart';
import 'package:counter/features/timeline/timeline_helpers.dart';
import 'package:counter/features/timeline/timeline_morning_start.dart';
import 'package:counter/features/timeline/timeline_record_card.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Timeline list mode as one continuous reverse-chronological history.
///
/// Days are not pages. Scrolling down keeps extending into the past. Each day
/// owns a pinned date header, so the date is always visible and naturally
/// changes as the next day reaches the top. Sleep is intentionally not filtered
/// here: Timeline is the complete life record, while Stats may use a waking-day
/// projection.
class TimelineContinuousPage extends StatefulWidget {
  const TimelineContinuousPage({
    super.key,
    required this.selectedDate,
    required this.anchorToday,
    required this.shellTabActive,
    required this.titleController,
    required this.titleFocus,
    required this.onStart,
    required this.onPlan,
    required this.onNewTaskForPastDate,
    required this.onStopRecord,
    required this.onDeleteRecord,
    required this.onShowEditRecordSheet,
    required this.onShowStatsViewChanged,
    required this.onVisibleDateChanged,
  });

  final DateTime selectedDate;
  final DateTime anchorToday;
  final bool shellTabActive;
  final TextEditingController titleController;
  final FocusNode titleFocus;
  final Future<void> Function() onStart;
  final Future<void> Function() onPlan;
  final VoidCallback onNewTaskForPastDate;
  final Future<void> Function(String systemRowId) onStopRecord;
  final Future<void> Function(String systemRowId) onDeleteRecord;
  final void Function(BuildContext context, Map<String, dynamic> data)
  onShowEditRecordSheet;
  final ValueChanged<bool> onShowStatsViewChanged;
  final ValueChanged<DateTime> onVisibleDateChanged;

  @override
  State<TimelineContinuousPage> createState() =>
      _TimelineContinuousPageState();
}

class _TimelineContinuousPageState extends State<TimelineContinuousPage> {
  late DateTime _visibleDate;

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _visibleDate = _day(widget.selectedDate);
  }

  @override
  void didUpdateWidget(covariant TimelineContinuousPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _day(widget.selectedDate);
    if (!_sameDay(next, _visibleDate) &&
        !_sameDay(next, _day(oldWidget.selectedDate))) {
      setState(() => _visibleDate = next);
    }
  }

  void _handleVisibleDate(DateTime date) {
    final next = _day(date);
    if (_sameDay(next, _visibleDate)) return;
    setState(() => _visibleDate = next);
    widget.onVisibleDateChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final isFuture = _visibleDate.isAfter(widget.anchorToday);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            TimelineHeaderControls(
              showStatsView: false,
              visibleDate: _visibleDate,
              visibleIsFuture: isFuture,
              titleController: widget.titleController,
              titleFocus: widget.titleFocus,
              onShowStatsViewChanged: widget.onShowStatsViewChanged,
              onStart: widget.onStart,
              onPlan: widget.onPlan,
              onNewTaskForPastDate: widget.onNewTaskForPastDate,
            ),
            Expanded(
              child: MorningStartGate(
                selectedDate: _visibleDate,
                active: widget.shellTabActive,
                titleController: widget.titleController,
                titleFocus: widget.titleFocus,
                onStart: widget.onStart,
                child: ContinuousTimelineHistory(
                  initialDate: widget.selectedDate,
                  anchorToday: widget.anchorToday,
                  onVisibleDateChanged: _handleVisibleDate,
                  onStop: widget.onStopRecord,
                  onDelete: widget.onDeleteRecord,
                  onEdit: (data) =>
                      widget.onShowEditRecordSheet(context, data),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContinuousTimelineHistory extends StatefulWidget {
  const ContinuousTimelineHistory({
    super.key,
    required this.initialDate,
    required this.anchorToday,
    required this.onVisibleDateChanged,
    required this.onStop,
    required this.onDelete,
    required this.onEdit,
  });

  final DateTime initialDate;
  final DateTime anchorToday;
  final ValueChanged<DateTime> onVisibleDateChanged;
  final Future<void> Function(String systemRowId) onStop;
  final Future<void> Function(String systemRowId) onDelete;
  final void Function(Map<String, dynamic> data) onEdit;

  @override
  State<ContinuousTimelineHistory> createState() =>
      _ContinuousTimelineHistoryState();
}

class _ContinuousTimelineHistoryState extends State<ContinuousTimelineHistory> {
  static const int _batchDays = 14;
  static const double _loadThreshold = 900;

  final ScrollController _controller = ScrollController();
  StreamSubscription<void>? _timeSub;
  late DateTime _topDate;
  int _loadedDays = _batchDays;
  bool _extendScheduled = false;
  DateTime? _reportedPinnedDate;

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _topDate = _day(widget.initialDate);
    _reportedPinnedDate = _topDate;
    widget.onVisibleDateChanged(_topDate);
    _controller.addListener(_onScroll);
    _timeSub = DatabaseService.instance.timeUpdates.listen((_) {
      if (mounted) setState(() {});
    });
    DatabaseService.instance.ensureTimelineWarmWindow(_topDate);
  }

  @override
  void didUpdateWidget(covariant ContinuousTimelineHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _day(widget.initialDate);
    if (_sameDay(next, _topDate)) return;
    _topDate = next;
    _loadedDays = _batchDays;
    _reportedPinnedDate = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(0);
      widget.onVisibleDateChanged(next);
    });
    DatabaseService.instance.ensureTimelineWarmWindow(next);
  }

  @override
  void dispose() {
    _timeSub?.cancel();
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    if (_controller.position.extentAfter > _loadThreshold || _extendScheduled) {
      return;
    }
    _extendScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final oldest = _topDate.subtract(Duration(days: _loadedDays - 1));
      DatabaseService.instance.extendTimelineRenderedBodiesIfNeeded(oldest);
      setState(() => _loadedDays += _batchDays);
      _extendScheduled = false;
    });
  }

  void _reportPinned(DateTime date) {
    final normalized = _day(date);
    if (_reportedPinnedDate != null &&
        _sameDay(_reportedPinnedDate!, normalized)) {
      return;
    }
    _reportedPinnedDate = normalized;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisibleDateChanged(normalized);
    });
  }

  List<Map<String, dynamic>> _recordsFor(DateTime date) {
    return DatabaseService.instance.peekTimelineRecordsForDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[];
    for (var dayIndex = 0; dayIndex < _loadedDays; dayIndex++) {
      final date = _topDate.subtract(Duration(days: dayIndex));
      final records = _recordsFor(date);
      final dateKey = _dateKey(date);

      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _TimelineDateHeaderDelegate(
            date: date,
            anchorToday: widget.anchorToday,
            onPinned: _reportPinned,
          ),
        ),
      );

      if (records.isEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Text(
                currentLocale.value.toLowerCase().startsWith('ru')
                    ? 'Нет записей'
                    : 'No entries',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          sliver: SliverList.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final data = records[index];
              final vm = DatabaseService.instance
                  .timelineRowVmForRecordMapOrNull(dateKey, data);
              final biz = (data['record_id'] ?? '').toString().trim();
              final system = (data['id'] ?? '').toString().trim();
              final key = ValueKey<String>(
                biz.isNotEmpty
                    ? 'history-$biz'
                    : system.isNotEmpty
                    ? 'history-$system'
                    : 'history-$dateKey-$index',
              );
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == records.length - 1 ? 0 : 10,
                ),
                child: KeyedSubtree(
                  key: key,
                  child: RepaintBoundary(
                    child: TimelineRecordCard(
                      vm: vm,
                      onStop: widget.onStop,
                      onDelete: widget.onDelete,
                      onEdit: () => widget.onEdit(data),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    slivers.add(
      const SliverToBoxAdapter(
        child: SizedBox(height: 80),
      ),
    );

    return CustomScrollView(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 900,
      slivers: slivers,
    );
  }
}

class _TimelineDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TimelineDateHeaderDelegate({
    required this.date,
    required this.anchorToday,
    required this.onPinned,
  });

  final DateTime date;
  final DateTime anchorToday;
  final ValueChanged<DateTime> onPinned;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _label() {
    final locale = currentLocale.value;
    final yesterday = anchorToday.subtract(const Duration(days: 1));
    final formatted = DateFormat('EEEE, d MMMM yyyy', locale).format(date);
    if (_sameDay(date, anchorToday)) {
      return locale.toLowerCase().startsWith('ru')
          ? 'Сегодня · $formatted'
          : 'Today · $formatted';
    }
    if (_sameDay(date, yesterday)) {
      return locale.toLowerCase().startsWith('ru')
          ? 'Вчера · $formatted'
          : 'Yesterday · $formatted';
    }
    return formatted;
  }

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    if (overlapsContent || shrinkOffset > 0) {
      onPinned(date);
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.96),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.38),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: scheme.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _label(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TimelineDateHeaderDelegate oldDelegate) {
    return oldDelegate.date != date || oldDelegate.anchorToday != anchorToday;
  }
}
