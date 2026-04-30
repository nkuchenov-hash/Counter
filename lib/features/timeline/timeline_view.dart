import 'dart:async';

import 'package:counter/core/widgets/mouse_drag_scroll_behavior.dart';
import 'package:counter/features/timeline/timeline_widgets.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/shared/chip_component.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/features/stats/stats_view.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:counter/core/widgets/app_loading.dart';
// ---------------------------------------------------------------------------
// TIMELINE FEATURE — UI_ISOLATION (§7). PLANETARY TIME PROTOCOL (§5). ACTIVE_STATUS_LAW (§2).
// All strings via t() from dictionary. Timeline **day** keys use profile wall-calendar via DatabaseService ([DATA_MAP] §8).
// ---------------------------------------------------------------------------

// --- Time helpers: device-local calendar for day strip; profile offset for clock labels only ---
DateTime _localToday() => DatabaseService.instance.getTimelineDeviceLocalToday();

bool _isToday(DateTime date) {
  final today = DatabaseService.instance.getTimelineDeviceLocalToday();
  return date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;
}

/// Calendar strip / timeline keys (naive date components from picker / swipe).
DateTime _dateOnlyCalendar(DateTime d) =>
    DateTime(d.year, d.month, d.day);

/// For record `startTime` (UTC): **profile wall-calendar** Y-M-D (must match [recordsStream] buckets; [DATA_MAP] §8).
String _wallCalendarDayKeyFromUtcInstant(DateTime startUtcOrAny) {
  final wall = DatabaseService.instance.applyUserOffset(startUtcOrAny.toUtc());
  return '${wall.year}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';
}

String _formatTimeOfDay(DateTime dt) =>
    DateFormat.Hm(currentLocale.value).format(dt);

DateTime _utcToDisplay(DateTime utc) =>
    DatabaseService.instance.applyUserOffset(utc);

String _formatDuration(Duration d) {
  final totalSeconds = d.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  if (m > 0) return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '${s}s';
}

/// PocketBase `records.id` (or legacy numeric row key). **Not** `record_id` UUID.
String _timelineRowSystemId(Map<String, dynamic> data) {
  final rest = (data['backendRestPathId'] ?? '').toString().trim();
  if (rest.isNotEmpty) return rest;
  final id = (data['id'] ?? '').toString().trim();
  if (id.isNotEmpty) return id;
  return '';
}

/// Client `record_id` (business UUID) — stable before/after PocketBase row id is assigned.
String _timelineBusinessRecordId(Map<String, dynamic> data) {
  final biz = (data['record_id'] ?? '').toString().trim();
  if (biz.isNotEmpty) return biz;
  return '';
}

bool _timelineSameRecordRow(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final bizA = _timelineBusinessRecordId(a);
  final bizB = _timelineBusinessRecordId(b);
  if (bizA.isNotEmpty && bizB.isNotEmpty && bizA == bizB) return true;
  final sysA = _timelineRowSystemId(a);
  final sysB = _timelineRowSystemId(b);
  return sysA.isNotEmpty && sysA == sysB;
}

/// Wraps Timeline in a PageView for swipe-to-change date. Exported for LifeOSDashboard.
class TimelineSwipeWrapper extends StatefulWidget {
  const TimelineSwipeWrapper({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    required this.onJumpToConflict,
    required this.tasks,
    required this.tasksLoading,
    required this.titleController,
    required this.titleFocus,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onStart,
    required this.onPlan,
    required this.onNewTaskForPastDate,
    required this.onStopRecord,
    required this.onDeleteRecord,
  required this.rules,
  required this.onShowEditRecordSheet,
  });

  final DateTime selectedDate;
  final void Function(DateTime date) onDateChanged;
  final void Function(DateTime date)? onJumpToConflict;
  final List<Task> tasks;
  final bool tasksLoading;
  final TextEditingController titleController;
  final FocusNode titleFocus;
  final int? selectedCategoryId;
  final void Function(int? categoryId) onCategoryChanged;
  final Future<void> Function() onStart;
  final Future<void> Function() onPlan;
  final VoidCallback onNewTaskForPastDate;
  /// PocketBase `records.id` (not legacy `record_id` UUID).
  final Future<void> Function(String systemRowId) onStopRecord;
  final Future<void> Function(String systemRowId) onDeleteRecord;
  final List<CategoryRule> rules;
  final void Function(BuildContext context, Map<String, dynamic> data)
      onShowEditRecordSheet;

  @override
  State<TimelineSwipeWrapper> createState() => _TimelineSwipeWrapperState();
}

class _TimelineSwipeWrapperState extends State<TimelineSwipeWrapper> {
  static const int _centerIndex = 5000;
  late PageController _controller;
  /// Shared across all [TimelinePage] indices so calendar/date changes keep List vs Stats.
  bool _showStatsView = false;

  DateTime get _anchorToday =>
      _dateOnlyCalendar(DatabaseService.instance.getTimelineDeviceLocalToday());

  @override
  void initState() {
    super.initState();
    final daysOffset = _dateOnlyCalendar(widget.selectedDate)
        .difference(_anchorToday)
        .inDays;
    _controller = PageController(initialPage: _centerIndex + daysOffset);
  }

  @override
  void didUpdateWidget(covariant TimelineSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldD = _dateOnlyCalendar(oldWidget.selectedDate);
    final newD = _dateOnlyCalendar(widget.selectedDate);
    if (oldD.year == newD.year &&
        oldD.month == newD.month &&
        oldD.day == newD.day) {
      return;
    }
    final daysOffset = newD.difference(_anchorToday).inDays;
    final page = _centerIndex + daysOffset;
    if (_controller.hasClients) {
      final cur = _controller.page;
      if (cur != null && cur.round() == page) return;
      _controller.animateToPage(page,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final anchor = _anchorToday;
    return ScrollConfiguration(
      behavior: const MouseDragScrollBehavior(),
      child: PageView.builder(
      controller: _controller,
      itemCount: 10000,
      onPageChanged: (int index) {
        final raw = anchor.add(Duration(days: index - _centerIndex));
        final next = _dateOnlyCalendar(raw);
        final sel = _dateOnlyCalendar(widget.selectedDate);
        if (next.year == sel.year &&
            next.month == sel.month &&
            next.day == sel.day) {
          return;
        }
        widget.onDateChanged(next);
      },
      itemBuilder: (context, index) {
        final raw = anchor.add(Duration(days: index - _centerIndex));
        final date = _dateOnlyCalendar(raw);
        final dateKey = _dateKey(date);
        final isFuture = date.isAfter(_anchorToday);
        final isSelectedDate = date.year == widget.selectedDate.year &&
            date.month == widget.selectedDate.month &&
            date.day == widget.selectedDate.day;
        return TimelinePage(
          selectedDate: date,
          selectedDateString: dateKey,
          isFutureDate: isFuture,
          tasks: isSelectedDate ? widget.tasks : [],
          tasksLoading: isSelectedDate ? widget.tasksLoading : false,
          titleController: widget.titleController,
          titleFocus: widget.titleFocus,
          selectedCategoryId: widget.selectedCategoryId,
          onCategoryChanged: widget.onCategoryChanged,
          onStart: widget.onStart,
          onPlan: widget.onPlan,
          onNewTaskForPastDate: widget.onNewTaskForPastDate,
          onStopRecord: widget.onStopRecord,
          onDeleteRecord: widget.onDeleteRecord,
          onJumpToConflictDate: widget.onJumpToConflict,
          rules: widget.rules,
          onShowEditRecordSheet: widget.onShowEditRecordSheet,
          onNavigateToDate: widget.onDateChanged,
          showStatsView: _showStatsView,
          onShowStatsViewChanged: (v) => setState(() => _showStatsView = v),
        );
      },
      ),
    );
  }
}

/// Single timeline tab page: list/stats toggle (above input), task input row, record list or StatsView.
class TimelinePage extends StatefulWidget {
  const TimelinePage({
    super.key,
    required this.selectedDate,
    required this.selectedDateString,
    required this.isFutureDate,
    required this.tasks,
    required this.tasksLoading,
    required this.titleController,
    required this.titleFocus,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onStart,
    required this.onPlan,
    required this.onNewTaskForPastDate,
    required this.onStopRecord,
    required this.onDeleteRecord,
  required this.rules,
  this.onJumpToConflictDate,
  required this.onShowEditRecordSheet,
  this.onNavigateToDate,
  required this.showStatsView,
  required this.onShowStatsViewChanged,
  });

  /// Picks a calendar day (AppBar / Stats PageView); drives parent [TimelineSwipeWrapper] PageController.
  final void Function(DateTime date)? onNavigateToDate;

  /// List vs Stats segment; owned by [TimelineSwipeWrapper] so date jumps preserve mode.
  final bool showStatsView;
  final ValueChanged<bool> onShowStatsViewChanged;

  final DateTime selectedDate;
  final String selectedDateString;
  final bool isFutureDate;
  final List<Task> tasks;
  final bool tasksLoading;
  final TextEditingController titleController;
  final FocusNode titleFocus;
  final int? selectedCategoryId;
  final void Function(int? categoryId) onCategoryChanged;
  final Future<void> Function() onStart;
  final Future<void> Function() onPlan;
  final VoidCallback onNewTaskForPastDate;
  /// PocketBase `records.id` (not legacy `record_id` UUID).
  final Future<void> Function(String systemRowId) onStopRecord;
  final Future<void> Function(String systemRowId) onDeleteRecord;
  final List<CategoryRule> rules;
  final void Function(DateTime date)? onJumpToConflictDate;
  /// Called when user taps a record to edit. Host (e.g. main) shows ActivityDetailSheet.
  final void Function(BuildContext context, Map<String, dynamic> data)
      onShowEditRecordSheet;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  late Stream<List<Map<String, dynamic>>> _recordsStream;

  /// Last non-transient list for this calendar day; keeps ListView stable when stream
  /// briefly emits `waiting` + empty during background refresh.
  List<Map<String, dynamic>> _lastCoalescedRecords = [];

  void _initStream() {
    _recordsStream =
        DatabaseService.instance.recordsStream(widget.selectedDate);
  }

  void _rememberCoalescedIfAuthoritative(
    List<Map<String, dynamic>> records,
    AsyncSnapshot<List<Map<String, dynamic>>> snap,
  ) {
    if (records.isNotEmpty) {
      _lastCoalescedRecords = List<Map<String, dynamic>>.from(records);
    } else if (snap.connectionState == ConnectionState.active ||
        snap.connectionState == ConnectionState.done) {
      _lastCoalescedRecords = [];
    }
  }

  /// List / stats / active stream subtree after [records] is resolved (no waiting shield here).
  Widget _buildTimelineRecordsArea(
    BuildContext context,
    List<Map<String, dynamic>> records,
    AsyncSnapshot<List<Map<String, dynamic>>> recordSnap,
  ) {
    if (widget.showStatsView) {
      if (records.isEmpty) {
        return EmptyStatePlaceholder(
          icon: Icons.schedule_rounded,
          titleL10nKey: 'empty_timeline_title',
          subtitleL10nKey: 'empty_timeline_subtitle',
          actionLabelL10nKey: 'empty_action_focus_search',
          onAction: () => widget.titleFocus.requestFocus(),
        );
      }
      return StatsView(
        records: records,
        rules: widget.rules,
        isFutureDate: widget.isFutureDate,
        selectedDate: widget.selectedDate,
        onDayChanged: widget.onNavigateToDate,
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: DatabaseService.instance.activeRecordStream,
      builder: (context, activeSnap) {
        List<Map<String, dynamic>> displayList = List.from(records);
        final active = activeSnap.data;
        final selectedDateKey = widget.selectedDateString;
        String? activeDayStr = active?['calendarDayStr'] as String?;
        if ((activeDayStr == null || activeDayStr.isEmpty) &&
            active != null) {
          final st = active['startTime'] as DateTime?;
          if (st != null) {
            activeDayStr = _wallCalendarDayKeyFromUtcInstant(st);
          }
        }
        // Only inject the running row into the list for the **local calendar day** of its start.
        final shouldShowActive = active != null &&
            activeDayStr != null &&
            activeDayStr.isNotEmpty &&
            activeDayStr == selectedDateKey;
        if (shouldShowActive) {
          final alreadyInList = displayList.any(
            (r) => _timelineSameRecordRow(r, active),
          );
          if (!alreadyInList) {
            displayList.insert(0, active);
          } else {
            displayList.removeWhere(
              (r) => _timelineSameRecordRow(r, active),
            );
            displayList.insert(0, active);
          }
        }
        if (displayList.isEmpty) {
          return EmptyStatePlaceholder(
            icon: Icons.schedule_rounded,
            titleL10nKey: 'empty_timeline_title',
            subtitleL10nKey: 'empty_timeline_subtitle',
            actionLabelL10nKey: 'empty_action_focus_search',
            onAction: () => widget.titleFocus.requestFocus(),
          );
        }
        final indexByBizId = <String, int>{};
        for (var i = 0; i < displayList.length; i++) {
          final b = _timelineBusinessRecordId(displayList[i]);
          if (b.isNotEmpty) {
            indexByBizId[b] = i;
          }
        }
        final activeRecord = activeSnap.data;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          physics: const AlwaysScrollableScrollPhysics(),
          cacheExtent: 1000,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          findItemIndexCallback: (Key key) {
            if (key is! ValueKey<String>) return null;
            final v = key.value;
            if (v.startsWith('record-fallback-')) {
              final idxStr = v.substring('record-fallback-'.length);
              final i = int.tryParse(idxStr);
              if (i != null && i >= 0 && i < displayList.length) {
                return i;
              }
              return null;
            }
            final i = indexByBizId[v];
            return i;
          },
          itemCount: displayList.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = displayList[index];
            final systemRowId = _timelineRowSystemId(data);
            final bizId = _timelineBusinessRecordId(data);
            final tileKey = ValueKey<String>(
              bizId.isNotEmpty ? bizId : 'record-fallback-$index',
            );
            String? otherDayStr =
                activeRecord?['calendarDayStr'] as String?;
            if ((otherDayStr == null || otherDayStr.isEmpty) &&
                activeRecord != null) {
              final st = activeRecord['startTime'] as DateTime?;
              if (st != null) {
                otherDayStr =
                    _wallCalendarDayKeyFromUtcInstant(st);
              }
            }
            final isActiveFromOtherDay = activeRecord != null &&
                _timelineSameRecordRow(data, activeRecord) &&
                otherDayStr != null &&
                otherDayStr.isNotEmpty &&
                otherDayStr != widget.selectedDateString;
            return KeyedSubtree(
              key: tileKey,
              child: _TimelineRecordCard(
                systemRowId: systemRowId,
                data: data,
                dateKey: widget.selectedDateString,
                currentActivityFromDate:
                    isActiveFromOtherDay ? otherDayStr : null,
                onStop: widget.onStopRecord,
                onDelete: widget.onDeleteRecord,
                onEdit: () => _showEditRecordSheet(context, data),
                rules: widget.rules,
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant TimelinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month ||
        oldWidget.selectedDate.day != widget.selectedDate.day) {
      _lastCoalescedRecords = [];
      _initStream();
      setState(() {});
    }
  }

  void _showEditRecordSheet(
      BuildContext context, Map<String, dynamic> data) {
    widget.onShowEditRecordSheet(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            TimelineTopDateStrip(
              selectedDate: widget.selectedDate,
              onDateSelected: (d) => widget.onNavigateToDate?.call(d),
              onNavigateToDate: widget.onNavigateToDate,
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.list_rounded),
                      label: Text(t(currentLocale.value, 'list'))),
                  ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: Text(t(currentLocale.value, 'stats'))),
                ],
                selected: {widget.showStatsView},
                onSelectionChanged: (Set<bool> sel) {
                  if (sel.isEmpty) return;
                  widget.onShowStatsViewChanged(sel.first);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.titleController,
                      focusNode: widget.titleFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (widget.isFutureDate) {
                          widget.onPlan();
                        } else if (_isToday(widget.selectedDate)) {
                          widget.onStart();
                        } else {
                          widget.onNewTaskForPastDate();
                        }
                      },
                      decoration: InputDecoration(
                        hintText:
                            t(currentLocale.value, 'input_placeholder_record'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      final projectedToday = _localToday();
                      final isToday = widget.selectedDate.year ==
                              projectedToday.year &&
                          widget.selectedDate.month ==
                              projectedToday.month &&
                          widget.selectedDate.day == projectedToday.day;
                      final isFuture = widget.isFutureDate;
                      return FilledButton.icon(
                        onPressed: () {
                          if (isFuture) {
                            widget.onPlan();
                          } else if (isToday) {
                            widget.onStart();
                          } else {
                            widget.onNewTaskForPastDate();
                          }
                        },
                        icon: Icon(
                          isFuture
                              ? Icons.event_rounded
                              : isToday
                                  ? Icons.play_arrow_rounded
                                  : Icons.add_task_rounded,
                        ),
                        label: Text(
                          isFuture
                              ? t(currentLocale.value, 'plan')
                              : isToday
                                  ? t(currentLocale.value, 'start_timer')
                                  : t(currentLocale.value, 'new_record_btn'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _recordsStream,
                          builder: (context, recordSnap) {
                            try {
                            if (recordSnap.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    t(currentLocale.value, 'no_data_found'),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }
                            if (recordSnap.hasData) {
                              final records =
                                  List<Map<String, dynamic>>.from(
                                      recordSnap.data!);
                              _rememberCoalescedIfAuthoritative(
                                  records, recordSnap);
                              return _buildTimelineRecordsArea(
                                  context, records, recordSnap);
                            }
                            if (recordSnap.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const AppLoading(),
                                    const SizedBox(height: 8),
                                    Text(t(
                                        currentLocale.value,
                                        'waiting_planetary_data')),
                                  ],
                                ),
                              );
                            }
                            return _buildTimelineRecordsArea(
                              context,
                              List<Map<String, dynamic>>.from(
                                  _lastCoalescedRecords),
                              recordSnap,
                            );
                          } catch (e, st) {
                            if (kDebugMode) {
                              debugPrint(
                                'Timeline records StreamBuilder: $e\n$st',
                              );
                            }
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  t(currentLocale.value, 'no_data_found'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _timelineRecordMetaIcons(BuildContext context, Record r) {
  final base = Theme.of(context).iconTheme.color;
  final color = base?.withValues(alpha: 0.48);
  if (color == null) return const [];
  if (!r.hasNotes &&
      !r.hasChecklist &&
      !r.hasParentRecord &&
      !r.hasLinkedSubRecords) {
    return const [];
  }
  final out = <Widget>[];
  void add(IconData icon) {
    if (out.isNotEmpty) out.add(const SizedBox(width: 4));
    out.add(Icon(icon, size: 15, color: color));
  }

  if (r.hasNotes) add(Icons.sticky_note_2_outlined);
  if (r.hasChecklist) add(Icons.checklist_rounded);
  if (r.hasParentRecord) add(Icons.account_tree_outlined);
  if (r.hasLinkedSubRecords) add(Icons.layers_outlined);
  return out;
}

/// Single timeline card: running shows live timer + Stop, completed shows duration, planned shows label.
class _TimelineRecordCard extends StatefulWidget {
  const _TimelineRecordCard({
    required this.systemRowId,
    required this.data,
    this.dateKey,
    this.currentActivityFromDate,
    required this.onStop,
    required this.onDelete,
    this.onEdit,
    required this.rules,
  });

  final String systemRowId;
  final Map<String, dynamic> data;
  final String? dateKey;
  final String? currentActivityFromDate;
  final Future<void> Function(String systemRowId) onStop;
  final Future<void> Function(String systemRowId) onDelete;
  final VoidCallback? onEdit;
  final List<CategoryRule> rules;

  @override
  State<_TimelineRecordCard> createState() => _TimelineRecordCardState();
}

class _TimelineRecordCardState extends State<_TimelineRecordCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfRunning();
  }

  @override
  void didUpdateWidget(_TimelineRecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data['status'] != widget.data['status'] ||
        oldWidget.data['endTime'] != widget.data['endTime']) {
      _startTimerIfRunning();
    }
  }

  void _startTimerIfRunning() {
    _timer?.cancel();
    _timer = null;
    if (CategoryServiceExtension.isRecordMapActuallyRunning(widget.data)) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(currentLocale.value, 'delete_record_confirm')),
        content: Text(t(currentLocale.value, 'cannot_undo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(currentLocale.value, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t(currentLocale.value, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.onDelete(widget.systemRowId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.data['title'] as String? ??
        (widget.systemRowId.isNotEmpty ? widget.systemRowId : '?');
    final type = widget.data['type'] as String? ?? 'record';
    final isPlanned = type == 'planned';
    final isRunning = type == 'record' &&
        CategoryServiceExtension.isRecordMapActuallyRunning(widget.data);

    final categoryPath = DatabaseService.instance
        .categoryDisplayPathForRecordData(widget.data);
    final categoryColor = DatabaseService.instance
        .categoryDisplayColorForRecordData(widget.data);

    Duration? duration;
    late String subtitle;
    if (isPlanned) {
      subtitle = t(currentLocale.value, 'planned_label');
    } else if (isRunning) {
      final startTimeUtc = CategoryServiceExtension.startTimeFromRecord(widget.data);
      if (startTimeUtc != null) {
        duration =
            DatabaseService.getPlanetaryNow().difference(startTimeUtc);
        final start = _formatTimeOfDay(_utcToDisplay(startTimeUtc));
        final end = '...';
        subtitle = '$start — $end (${_formatDuration(duration)})';
      } else {
        subtitle = t(currentLocale.value, 'running_label');
      }
    } else {
      final startTimeUtc = CategoryServiceExtension.startTimeFromRecord(widget.data);
      final endTimeUtc = CategoryServiceExtension.endTimeFromRecord(widget.data);
      if (startTimeUtc != null) {
        final endOrNow =
            endTimeUtc ?? DatabaseService.getPlanetaryNow();
        duration = endOrNow.difference(startTimeUtc);
      }
      if (startTimeUtc != null) {
        final start = _formatTimeOfDay(_utcToDisplay(startTimeUtc));
        final end = endTimeUtc != null
            ? _formatTimeOfDay(_utcToDisplay(endTimeUtc))
            : '...';
        final durationStr =
            duration != null ? _formatDuration(duration) : '–';
        subtitle = '$start — $end ($durationStr)';
      } else if (duration != null) {
        subtitle = _formatDuration(duration);
      } else {
        subtitle = '–';
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final runningFill = isRunning
        ? (isDark
            ? scheme.primary.withValues(alpha: 0.2)
            : scheme.primaryContainer.withValues(alpha: 0.45))
        : null;
    final runningBorder = isRunning ? scheme.primary : Colors.transparent;
    final runningTextColor =
        isRunning ? (isDark ? scheme.primary : scheme.onPrimaryContainer) : null;

    final cardTheme = Theme.of(context).cardTheme;
    final suppressInnerInk = Theme.of(context).copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );

    final recordIndicators = Record.forTimelineCard(widget.data);
    final metaIcons = _timelineRecordMetaIcons(context, recordIndicators);

    final paddedRow = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.currentActivityFromDate != null) ...[
                  Text(
                    t(currentLocale.value, 'current_activity_from')
                        .replaceFirst('%s', widget.currentActivityFromDate!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (metaIcons.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.only(start: 4, top: 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: metaIcons,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Theme(
                  data: suppressInnerInk,
                  child: CategoryBreadcrumb(
                    breadcrumbPath: categoryPath,
                    accentColor: categoryColor,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isRunning
                              ? runningTextColor
                              : scheme.onSurfaceVariant,
                          fontWeight:
                              isRunning ? FontWeight.w600 : null,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isRunning)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: FilledButton.icon(
                onPressed: () {
                  widget.onStop(widget.systemRowId);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: Text(t(currentLocale.value, 'stop')),
              ),
            ),
          IconButton(
            style: IconButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
              hoverColor: Colors.transparent,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: t(currentLocale.value, 'delete'),
            onPressed: _confirmDelete,
          ),
        ],
      ),
    );

    const cardRadius = 12.0;
    final layoutDirection = Directionality.of(context);
    final stripeCornerRadius = BorderRadiusDirectional.only(
      topStart: const Radius.circular(cardRadius),
      bottomStart: const Radius.circular(cardRadius),
    ).resolve(layoutDirection);
    final contentInkRadius = BorderRadiusDirectional.only(
      topEnd: const Radius.circular(cardRadius),
      bottomEnd: const Radius.circular(cardRadius),
    ).resolve(layoutDirection);
    // Non-positioned child sizes the Stack; stripe is Positioned top/bottom to match (no Row stretch).
    final cardBody = IntrinsicHeight(
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: stripeCornerRadius,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: widget.onEdit != null
                ? InkWell(
                    onTap: widget.onEdit,
                    borderRadius: contentInkRadius,
                    child: Theme(
                      data: suppressInnerInk,
                      child: paddedRow,
                    ),
                  )
                : Theme(
                    data: suppressInnerInk,
                    child: paddedRow,
                  ),
          ),
        ],
      ),
    );

    return Material(
      elevation: cardTheme.elevation ?? 1,
      shadowColor: cardTheme.shadowColor,
      surfaceTintColor: cardTheme.surfaceTintColor,
      color: runningFill ?? cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(
          color: runningBorder,
          width: isRunning ? 2.0 : 0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: cardBody,
    );
  }
}
