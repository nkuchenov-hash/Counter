import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/stats/stats_view.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';

// ---------------------------------------------------------------------------
// TIMELINE FEATURE — UI_ISOLATION (§7). PLANETARY TIME PROTOCOL (§5). ACTIVE_STATUS_LAW (§2).
// All strings via t() from dictionary. No DateTime.now().toLocal(). Uses DatabaseService for POINTER_HANDOVER.
// ---------------------------------------------------------------------------

// --- Time helpers (Planetary: UTC + profile offset only) ---
DateTime _localToday() => DatabaseService.instance.getProjectedToday();

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

bool _isToday(DateTime date) {
  final projectedToday = DatabaseService.instance.getProjectedToday();
  return date.year == projectedToday.year &&
      date.month == projectedToday.month &&
      date.day == projectedToday.day;
}

String _formatTimeOfDay(DateTime dt) => DateFormat.Hm().format(dt);

DateTime _utcToDisplay(DateTime utc) =>
    DatabaseService.instance.applyUserOffset(utc);

DateTime _displayToUtc(DateTime displayNaive) =>
    DatabaseService.instance.displayTimeToUtc(displayNaive);

String _formatTimeRange(DateTime start, DateTime? end) {
  if (end == null) return '${_formatTimeOfDay(start)} – now';
  return '${_formatTimeOfDay(start)} – ${_formatTimeOfDay(end)}';
}

String _formatDuration(Duration d) {
  final totalSeconds = d.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  if (m > 0) return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '${s}s';
}

DateTime _displayNow() =>
    DatabaseService.instance.applyUserOffset(DatabaseService.getPlanetaryNow());

Future<DateTime?> showAppDateTimePicker(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final theme = Theme.of(context);
  final defaultInitial =
      DatabaseService.instance.applyUserOffset(DatabaseService.getPlanetaryNow());
  return showOmniDateTimePicker(
    context: context,
    initialDate: initial ?? defaultInitial,
    firstDate: firstDate ?? DateTime.utc(2020),
    lastDate: lastDate ?? DateTime.utc(2030),
    is24HourMode: true,
    theme: theme,
  );
}

/// App bar live clock. Updates on timeUpdates stream (profile timezone). No .toLocal().
class _AppBarLiveClock extends StatefulWidget {
  const _AppBarLiveClock({this.textStyle});
  final TextStyle? textStyle;

  @override
  State<_AppBarLiveClock> createState() => _AppBarLiveClockState();
}

class _AppBarLiveClockState extends State<_AppBarLiveClock> {
  StreamSubscription<void>? _timeUpdateSub;

  @override
  void initState() {
    super.initState();
    _timeUpdateSub = DatabaseService.instance.timeUpdates.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timeUpdateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: DatabaseService.instance.timeUpdates,
      builder: (context, _) {
        return Text(
          DateFormat.Hm().format(_displayNow()),
          style: widget.textStyle ??
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        );
      },
    );
  }
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
  required this.onManualAdd,
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
  final Future<void> Function(String recordId) onStopRecord;
  final Future<void> Function(String recordId) onDeleteRecord;
  final VoidCallback onManualAdd;
  final List<CategoryRule> rules;
  final void Function(BuildContext context, Map<String, dynamic> data)
      onShowEditRecordSheet;

  @override
  State<TimelineSwipeWrapper> createState() => _TimelineSwipeWrapperState();
}

class _TimelineSwipeWrapperState extends State<TimelineSwipeWrapper> {
  static const int _centerIndex = 5000;
  late PageController _controller;
  DateTime get _today => DatabaseService.instance.getProjectedToday();

  // Prevent off-by-one issues caused by DateTime "timezone kind" differences.
  // We compute day offsets using UTC date-only anchors.
  DateTime _utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final daysOffset = _utcDay(widget.selectedDate).difference(_utcDay(_today)).inDays;
    _controller = PageController(initialPage: _centerIndex + daysOffset);
  }

  @override
  void didUpdateWidget(covariant TimelineSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      final daysOffset = _utcDay(widget.selectedDate).difference(_utcDay(_today)).inDays;
      final page = _centerIndex + daysOffset;
      if (_controller.hasClients) {
        _controller.animateToPage(page,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
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
    return PageView.builder(
      controller: _controller,
      itemCount: 10000,
      onPageChanged: (int index) {
        final day = _utcDay(_today).add(Duration(days: index - _centerIndex));
        widget.onDateChanged(DateTime(day.year, day.month, day.day));
      },
      itemBuilder: (context, index) {
        final day = _utcDay(_today).add(Duration(days: index - _centerIndex));
        final date = DateTime(day.year, day.month, day.day);
        final dateKey = _dateKey(date);
        final isFuture = date.isAfter(_today);
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
          onManualAdd: widget.onManualAdd,
          onJumpToConflictDate: widget.onJumpToConflict,
          rules: widget.rules,
          onShowEditRecordSheet: widget.onShowEditRecordSheet,
        );
      },
    );
  }
}

/// Single timeline tab page: date, input row, list/stats toggle, record list or StatsView.
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
  required this.onManualAdd,
  required this.rules,
  this.onJumpToConflictDate,
  required this.onShowEditRecordSheet,
  });

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
  final Future<void> Function(String recordId) onStopRecord;
  final Future<void> Function(String recordId) onDeleteRecord;
  final VoidCallback onManualAdd;
  final List<CategoryRule> rules;
  final void Function(DateTime date)? onJumpToConflictDate;
  /// Called when user taps a record to edit. Host (e.g. main) shows ActivityDetailSheet.
  final void Function(BuildContext context, Map<String, dynamic> data)
      onShowEditRecordSheet;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  bool _showStatsView = false;
  late Stream<List<Map<String, dynamic>>> _recordsStream;

  void _initStream() {
    _recordsStream =
        DatabaseService.instance.recordsStream(widget.selectedDate);
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
    final isToday = _isToday(widget.selectedDate);
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.w500);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${t(currentLocale.value, 'tab_timeline')} • ${_formatDate(widget.selectedDate)}',
              style: titleStyle,
            ),
            if (isToday) ...[
              Text(' • ', style: titleStyle),
              _AppBarLiveClock(
                  textStyle: titleStyle.copyWith(
                      fontSize: 14, fontWeight: FontWeight.w400)),
            ],
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.onManualAdd,
            tooltip: t(currentLocale.value, 'add_task'),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                        labelText: t(currentLocale.value, 'task_title'),
                        hintText: t(currentLocale.value, 'hint_task_example'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      final projectedToday = _localToday();
                      final isToday = widget.selectedDate.year == projectedToday.year &&
                          widget.selectedDate.month == projectedToday.month &&
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
            SegmentedButton<bool>(
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
              selected: {_showStatsView},
              onSelectionChanged: (Set<bool> sel) =>
                  setState(() => _showStatsView = sel.first),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: widget.tasksLoading
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<UserSettings>(
                      stream: DatabaseService.instance.userSettingsStream,
                      builder: (context, settingsSnapshot) {
                        return StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _recordsStream,
                          builder: (context, recordSnap) {
                            if (recordSnap.connectionState ==
                                    ConnectionState.waiting &&
                                !recordSnap.hasData) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 8),
                                    Text(t(
                                        currentLocale.value,
                                        'waiting_planetary_data')),
                                  ],
                                ),
                              );
                            }
                            if (recordSnap.hasError) {
                              return ErrorWidget(
                                  recordSnap.error.toString());
                            }
                            final records = recordSnap.data ?? [];

                            if (_showStatsView) {
                              if (records.isEmpty) {
                                return Center(
                                  child: Text(
                                    t(currentLocale.value, 'no_records'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                );
                              }
                              return StatsView(
                                records: records,
                                rules: widget.rules,
                                isFutureDate: widget.isFutureDate,
                                selectedDate: widget.selectedDate,
                              );
                            }

                            return StreamBuilder<Map<String, dynamic>?>(
                              stream: DatabaseService.instance.activeRecordStream,
                              builder: (context, activeSnap) {
                                List<Map<String, dynamic>> displayList =
                                    List.from(records);
                                final active = activeSnap.data;
                                final isSelectedDateToday =
                                    _isToday(widget.selectedDate);
                                final selectedDateKey =
                                    widget.selectedDateString;
                                String? activeDayStr =
                                    active?['calendarDayStr'] as String?;
                                if ((activeDayStr == null ||
                                        activeDayStr.isEmpty) &&
                                    active != null) {
                                  final st =
                                      active['startTime'] as DateTime?;
                                  if (st != null) {
                                    final u = st.toUtc();
                                    activeDayStr =
                                        '${u.year}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
                                  }
                                }
                                final shouldShowActive = active != null &&
                                    (isSelectedDateToday ||
                                        (activeDayStr != null &&
                                            activeDayStr.isNotEmpty &&
                                            activeDayStr == selectedDateKey));
                                if (shouldShowActive) {
                                  final activeRid = (active['record_id'] ??
                                          active['id'] ??
                                          '')
                                      .toString();
                                  final alreadyInList = displayList.any((r) =>
                                      (r['record_id'] ?? r['id'] ?? '')
                                          .toString() ==
                                      activeRid);
                                  if (!alreadyInList) {
                                    displayList.insert(0, active);
                                  } else {
                                    displayList.removeWhere((r) =>
                                        (r['record_id'] ?? r['id'] ?? '')
                                            .toString() ==
                                        activeRid);
                                    displayList.insert(0, active);
                                  }
                                }
                                if (recordSnap.connectionState ==
                                        ConnectionState.waiting &&
                                    displayList.isEmpty) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                if (recordSnap.hasError) {
                                  return ErrorWidget(
                                      recordSnap.error.toString());
                                }
                                if (displayList.isEmpty) {
                                  return Center(
                                    child: Text(
                                      t(currentLocale.value, 'no_records'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  );
                                }
                                final activeRecord = activeSnap.data;
                                return ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                  itemCount: displayList.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final data = displayList[index];
                                    final recordId = (data['record_id'] ??
                                            data['id'] ??
                                            '')
                                        .toString();
                                    final tileKey = recordId.isNotEmpty
                                        ? ValueKey<String>('record-$recordId')
                                        : ValueKey<String>(
                                            'record-fallback-$index');
                                    String? otherDayStr = activeRecord?[
                                            'calendarDayStr']
                                        as String?;
                                    if ((otherDayStr == null ||
                                            otherDayStr.isEmpty) &&
                                        activeRecord != null) {
                                      final st = activeRecord['startTime']
                                          as DateTime?;
                                      if (st != null) {
                                        final u = st.toUtc();
                                        otherDayStr =
                                            '${u.year}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
                                      }
                                    }
                                    final activeRid2 = (activeRecord?[
                                                'record_id'] ??
                                            activeRecord?['id'] ??
                                            '')
                                        .toString();
                                    final isActiveFromOtherDay =
                                        activeRecord != null &&
                                            (data['record_id'] ?? data['id'] ?? '')
                                                    .toString() ==
                                                activeRid2 &&
                                            otherDayStr != null &&
                                            otherDayStr.isNotEmpty &&
                                            otherDayStr !=
                                                widget.selectedDateString;
                                    return _TimelineRecordCard(
                                      key: tileKey,
                                      recordId: recordId,
                                      data: data,
                                      dateKey: widget.selectedDateString,
                                      currentActivityFromDate:
                                          isActiveFromOtherDay
                                              ? otherDayStr
                                              : null,
                                      onStop: widget.onStopRecord,
                                      onDelete: widget.onDeleteRecord,
                                      onEdit: () =>
                                          _showEditRecordSheet(context, data),
                                      rules: widget.rules,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single timeline card: running shows live timer + Stop, completed shows duration, planned shows label.
class _TimelineRecordCard extends StatefulWidget {
  const _TimelineRecordCard({
    super.key,
    required this.recordId,
    required this.data,
    this.dateKey,
    this.currentActivityFromDate,
    required this.onStop,
    required this.onDelete,
    this.onEdit,
    required this.rules,
  });

  final String recordId;
  final Map<String, dynamic> data;
  final String? dateKey;
  final String? currentActivityFromDate;
  final Future<void> Function(String recordId) onStop;
  final Future<void> Function(String recordId) onDelete;
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
    if (DatabaseService.isRecordMapActuallyRunning(widget.data)) {
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
      await widget.onDelete(widget.recordId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.data['title'] as String? ??
        (widget.recordId.isNotEmpty ? widget.recordId : '?');
    final type = widget.data['type'] as String? ?? 'record';
    final isPlanned = type == 'planned';
    final isRunning = type == 'record' &&
        DatabaseService.isRecordMapActuallyRunning(widget.data);

    final resolvedCategoryId =
        DatabaseService.instance.resolvedCategoryIdForRecord(widget.data);
    final categoryPath = DatabaseService.instance
        .categoryDisplayPathForTimeline(resolvedCategoryId);
    final categoryColor = DatabaseService.instance
        .categoryDisplayColorForTimeline(resolvedCategoryId);

    Duration? duration;
    late String subtitle;
    if (isPlanned) {
      subtitle = t(currentLocale.value, 'planned_label');
    } else if (isRunning) {
      final startTimeUtc = DatabaseService.startTimeFromRecord(widget.data);
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
      final startTimeUtc = DatabaseService.startTimeFromRecord(widget.data);
      final endTimeUtc = DatabaseService.endTimeFromRecord(widget.data);
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

    return Card(
      margin: EdgeInsets.zero,
      color: runningFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: runningBorder,
          width: isRunning ? 2.0 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onEdit,
                borderRadius: BorderRadius.circular(12),
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
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(
                        categoryPath,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      backgroundColor: categoryColor.withOpacity(0.25),
                      side: BorderSide(color: categoryColor, width: 1),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            ),
            const SizedBox(width: 8),
            if (isRunning)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilledButton.icon(
                  onPressed: () => widget.onStop(widget.recordId),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  label: Text(t(currentLocale.value, 'stop')),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: t(currentLocale.value, 'delete'),
              onPressed: _confirmDelete,
            ),
          ],
        ),
      ),
    );
  }
}
