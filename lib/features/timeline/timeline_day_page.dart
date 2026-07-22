import 'dart:async';

import 'package:counter/shared/diagnostics/performance/rebuild_metrics.dart';
import 'package:counter/shared/diagnostics/performance/runtime_flags.dart';
import 'package:counter/core/widgets/app_state_views.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/features/stats/stats_view.dart';
import 'package:counter/features/timeline/timeline_helpers.dart';
import 'package:counter/features/timeline/timeline_record_card.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class TimelineDayCardList extends StatefulWidget {
  const TimelineDayCardList({
    super.key,
    required this.date,
    required this.dateKey,
    required this.isFutureDate,
    required this.isActive,
    required this.showStatsView,
    required this.rules,
    this.liveRecordMaps,
    required this.onStop,
    required this.onDelete,
    required this.onEdit,
    this.onNavigateToDate,
    required this.titleFocus,
  });

  final DateTime date;
  final String dateKey;
  final bool isFutureDate;
  final bool isActive;
  final bool showStatsView;
  final List<CategoryRule> rules;
  final List<Map<String, dynamic>>? liveRecordMaps;
  final Future<void> Function(String systemRowId) onStop;
  final Future<void> Function(String systemRowId) onDelete;
  final void Function(Map<String, dynamic> data) onEdit;
  final void Function(DateTime date)? onNavigateToDate;
  final FocusNode titleFocus;

  @override
  State<TimelineDayCardList> createState() => TimelineDayCardListState();
}

class TimelineDayCardListState extends State<TimelineDayCardList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _recordMaps() {
    final live = widget.liveRecordMaps;
    if (live != null) {
      return live;
    }
    if (widget.isActive) {
      return DatabaseService.instance.peekTimelineRecordsForDate(widget.date);
    }
    return DatabaseService.instance
        .timelineBodyEntryForDate(widget.date)
        .records;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final recordMaps = _recordMaps();
    if (widget.showStatsView) {
      if (recordMaps.isEmpty) {
        return EmptyStatePlaceholder(
          icon: Icons.schedule_rounded,
          titleL10nKey: 'empty_timeline_title',
          subtitleL10nKey: 'empty_timeline_subtitle',
          actionLabelL10nKey: 'empty_action_focus_search',
          onAction: () => widget.titleFocus.requestFocus(),
        );
      }
      return StatsView(
        records: recordMaps,
        rules: widget.rules,
        isFutureDate: widget.isFutureDate,
        selectedDate: widget.date,
        onDayChanged: widget.onNavigateToDate,
      );
    }

    if (recordMaps.isEmpty) {
      return EmptyStatePlaceholder(
        icon: Icons.schedule_rounded,
        titleL10nKey: 'empty_timeline_title',
        subtitleL10nKey: 'empty_timeline_subtitle',
        actionLabelL10nKey: 'empty_action_focus_search',
        onAction: () => widget.titleFocus.requestFocus(),
      );
    }
    return TimelineLazyRecordList(
      recordMaps: recordMaps,
      dateKey: widget.dateKey,
      selectedDate: widget.date,
      selectedDateString: widget.dateKey,
      onStop: widget.onStop,
      onDelete: widget.onDelete,
      onEdit: widget.onEdit,
    );
  }
}

/// Virtualized timeline record list вЂ” no [StreamBuilder] over full list; active overlay optional.
class TimelineLazyRecordList extends StatefulWidget {
  const TimelineLazyRecordList({
    required this.recordMaps,
    required this.dateKey,
    required this.selectedDate,
    required this.selectedDateString,
    required this.onStop,
    required this.onDelete,
    required this.onEdit,
  });

  final List<Map<String, dynamic>> recordMaps;
  final String dateKey;
  final DateTime selectedDate;
  final String selectedDateString;
  final Future<void> Function(String systemRowId) onStop;
  final Future<void> Function(String systemRowId) onDelete;
  final void Function(Map<String, dynamic> data) onEdit;

  @override
  State<TimelineLazyRecordList> createState() => TimelineLazyRecordListState();
}

class TimelineLazyRecordListState extends State<TimelineLazyRecordList> {
  StreamSubscription<Map<String, dynamic>?>? _activeSub;
  Map<String, dynamic>? _active;
  String? _activeOtherDayStr;

  bool _mapLooksRunning(Map<String, dynamic> data) {
    final type = (data['type'] as String? ?? 'record');
    if (type != 'record') return false;
    return CategoryServiceExtension.isRecordMapActuallyRunning(data);
  }

  bool get _needsActiveOverlay =>
      widget.recordMaps.any(_mapLooksRunning) ||
      timelineIsToday(widget.selectedDate);

  @override
  void initState() {
    super.initState();
    if (_needsActiveOverlay) {
      _activeSub = DatabaseService.instance.activeRecordStream.listen((active) {
        if (!mounted) return;
        String? otherDay;
        if (active != null) {
          otherDay = active['calendarDayStr'] as String?;
          if ((otherDay == null || otherDay.isEmpty)) {
            final st = active['startTime'] as DateTime?;
            if (st != null) {
              otherDay = timelineWallCalendarDayKeyFromUtcInstant(st);
            }
          }
        }
        setState(() {
          _active = active;
          _activeOtherDayStr = otherDay;
        });
      });
    }
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = Stopwatch()..start();
    final maps = widget.recordMaps;
    if (kRebuildMetricsEnabled) {
      RebuildMetrics.instance.logTimelineVisibleBuild(
        itemCount: maps.length,
        ms: sw.elapsedMilliseconds,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 320,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemCount: maps.length,
      itemBuilder: (context, index) {
        RebuildMetrics.instance.logTimelineRowBuildTick();
        final data = maps[index];
        final vm = DatabaseService.instance.timelineRowVmForRecordMapOrNull(
          widget.dateKey,
          data,
        );
        final biz = (data['record_id'] ?? '').toString().trim();
        final tileKey = ValueKey<String>(
          biz.isNotEmpty ? biz : 'record-fallback-$index',
        );
        String? otherDayBanner;
        if (_active != null &&
            biz.isNotEmpty &&
            biz == (_active!['record_id'] ?? '').toString().trim() &&
            _activeOtherDayStr != null &&
            _activeOtherDayStr!.isNotEmpty &&
            _activeOtherDayStr != widget.selectedDateString) {
          otherDayBanner = _activeOtherDayStr;
        }
        return Padding(
          padding: EdgeInsets.only(bottom: index < maps.length - 1 ? 10 : 0),
          child: KeyedSubtree(
            key: tileKey,
            child: RepaintBoundary(
              child: TimelineRecordCard(
                vm: vm,
                currentActivityFromDate: otherDayBanner,
                onStop: widget.onStop,
                onDelete: widget.onDelete,
                onEdit: () => widget.onEdit(data),
              ),
            ),
          ),
        );
      },
    );
  }
}
