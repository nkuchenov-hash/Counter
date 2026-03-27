// ---------------------------------------------------------------------------
// SHARED UI — Sheets and tiles used by Timeline, Planning, Categories. UI_ISOLATION (§7).
// All strings via t(). Use Theme.of(context). No hardcoded colors.
// ---------------------------------------------------------------------------

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';

// --- Time helpers (Planetary: UTC + profile offset). Used by sheets. ---
String _two(int n) => n.toString().padLeft(2, '0');
String formatDate(DateTime date) => '${date.year}-${_two(date.month)}-${_two(date.day)}';
String formatTimeOfDay(DateTime dt) => DateFormat.Hm().format(dt);
DateTime utcToDisplay(DateTime utc) => DatabaseService.instance.applyUserOffset(utc);
DateTime displayToUtc(DateTime displayNaive) => DatabaseService.instance.displayTimeToUtc(displayNaive);
DateTime displayNow() => DatabaseService.instance.applyUserOffset(DatabaseService.getPlanetaryNow());

Future<DateTime?> showAppDateTimePicker(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final theme = Theme.of(context);
  final defaultInitial = DatabaseService.instance.applyUserOffset(DatabaseService.getPlanetaryNow());
  return showOmniDateTimePicker(
    context: context,
    initialDate: initial ?? defaultInitial,
    firstDate: firstDate ?? DateTime.utc(2020),
    lastDate: lastDate ?? DateTime.utc(2030),
    is24HourMode: true,
    theme: theme,
  );
}

DateTime? planningDateFromKey(String key) {
  if (key.length < 10) return null;
  final y = int.tryParse(key.substring(0, 4));
  final m = int.tryParse(key.substring(5, 7));
  final d = int.tryParse(key.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d);
}

const List<String> _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// ---------------------------------------------------------------------------
// ActivityDetailSheet & related
// ---------------------------------------------------------------------------

enum ActivityDetailKind { timelineRecord, planningTask }

class ActivityDetailSheet extends StatelessWidget {
  const ActivityDetailSheet({
    super.key,
    required this.kind,
    this.timelineRecord,
    this.planningTask,
    required this.scrollController,
    required this.onSaved,
    this.onDelete,
    this.onStop,
  });

  final ActivityDetailKind kind;
  final TimelineRecord? timelineRecord;
  final PlanningTask? planningTask;
  final ScrollController scrollController;
  final void Function(dynamic updated) onSaved;
  final VoidCallback? onDelete;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    if (kind == ActivityDetailKind.planningTask && planningTask != null) {
      return _PlanningTaskEditSheet(
        task: planningTask!,
        dateKey: planningTask!.dateKey,
        scrollController: scrollController,
        onDelete: onDelete != null ? (_) => onDelete!() : null,
        onSaved: onSaved,
      );
    }
    if (kind == ActivityDetailKind.timelineRecord && timelineRecord != null) {
      return _TimelineRecordSheetContent(
        record: timelineRecord!,
        scrollController: scrollController,
        onSaved: onSaved,
        onDelete: onDelete ?? () {},
        onStop: onStop ?? () {},
      );
    }
    return const SizedBox.shrink();
  }
}

class _PlanningTaskEditSheet extends StatefulWidget {
  const _PlanningTaskEditSheet({
    required this.task,
    required this.dateKey,
    required this.scrollController,
    this.onDelete,
    this.onSaved,
  });

  final PlanningTask task;
  final String dateKey;
  final ScrollController scrollController;
  final void Function(PlanningTask task)? onDelete;
  final void Function(dynamic updated)? onSaved;

  @override
  State<_PlanningTaskEditSheet> createState() => _PlanningTaskEditSheetState();
}

class _PlanningTaskEditSheetState extends State<_PlanningTaskEditSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late int _categoryId;
  DateTime? _scheduledTime;
  DateTime? _endTime;
  late DateTime _date;
  final List<TextEditingController> _checklistControllers = [];
  final List<bool> _checklistDone = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _categoryId = widget.task.categoryId;
    _scheduledTime = widget.task.startTime != null ? utcToDisplay(widget.task.startTime!) : null;
    _endTime = widget.task.endDateTime != null ? utcToDisplay(widget.task.endDateTime!) : null;
    _date = planningDateFromKey(widget.task.dateKey) ?? widget.task.date ?? DateTime.now();
    _date = DateTime(_date.year, _date.month, _date.day);
    for (final item in widget.task.checklist) {
      final text = (item['text'] ?? '').toString();
      final done = item['isDone'] == true;
      _checklistControllers.add(TextEditingController(text: text));
      _checklistDone.add(done);
    }
    if (_checklistControllers.isEmpty) {
      _checklistControllers.add(TextEditingController());
      _checklistDone.add(false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _dateKeyFromDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _shortMonth(int month) => month >= 1 && month <= 12 ? _shortMonths[month - 1] : '';

  void _commitSave() {
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final catId = pairs.any((p) => p.id == _categoryId)
        ? _categoryId
        : (pairs.isNotEmpty ? pairs.first.id : _categoryId);
    final newDateKey = _dateKeyFromDate(_date);
    final List<Map<String, dynamic>> checklist = [];
    for (var i = 0; i < _checklistControllers.length; i++) {
      final text = _checklistControllers[i].text.trim();
      if (text.isEmpty) continue;
      checklist.add({'text': text, 'isDone': _checklistDone[i]});
    }
    final updated = widget.task.copyWith(
      title: title,
      categoryId: catId,
      startTime: _scheduledTime,
      date: _date,
      dateKey: newDateKey,
      endDateTime: _endTime != null
          ? DateTime(_date.year, _date.month, _date.day, _endTime!.hour, _endTime!.minute)
          : null,
      endDateKey: _endTime != null ? newDateKey : null,
      checklist: checklist,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    if (widget.onSaved != null) {
      widget.onSaved!(updated);
    } else {
      Navigator.of(context).pop<PlanningTask?>(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final dropdownValue = pairs.any((p) => p.id == _categoryId)
        ? _categoryId
        : (pairs.isNotEmpty ? pairs.first.id : _categoryId);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                    child: Text(t(currentLocale.value, 'edit_record'),
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop<PlanningTask?>(null)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: t(currentLocale.value, 'tab_details')),
                    Tab(text: t(currentLocale.value, 'notes_tab')),
                    Tab(text: t(currentLocale.value, 'checklist_tab')),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ListView(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          TextField(
                            autofocus: true,
                            decoration:
                                InputDecoration(labelText: t(currentLocale.value, 'title_label')),
                            controller: _titleController,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: pairs.any((p) => p.id == dropdownValue)
                                ? dropdownValue
                                : (pairs.isNotEmpty ? pairs.first.id : null),
                            decoration: InputDecoration(
                                labelText: t(currentLocale.value, 'category_label')),
                            items: pairs
                                .map((p) => DropdownMenuItem<int>(
                                    value: p.id,
                                    child: Text(p.path, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (id) => setState(() => _categoryId = id ?? _categoryId),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_scheduledTime == null
                                ? t(currentLocale.value, 'scheduled')
                                : '${_date.day} ${_shortMonth(_date.month)} ${_date.year}, ${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'),
                            trailing: const Icon(Icons.schedule_rounded),
                            onTap: () async {
                              final initial = DateTime(_date.year, _date.month, _date.day,
                                  _scheduledTime?.hour ?? 9, _scheduledTime?.minute ?? 0);
                              final picked = await showAppDateTimePicker(context, initial: initial);
                              if (picked != null && mounted) {
                                setState(() {
                                  _date = DateTime(picked.year, picked.month, picked.day);
                                  _scheduledTime = picked;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_endTime == null
                                ? t(currentLocale.value, 'no_end_time')
                                : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'),
                            trailing: const Icon(Icons.schedule_rounded),
                            onTap: () async {
                              final initial = DateTime(_date.year, _date.month, _date.day,
                                  _endTime?.hour ?? 10, _endTime?.minute ?? 0);
                              final picked = await showAppDateTimePicker(context, initial: initial);
                              if (picked != null && mounted) {
                                setState(() => _endTime = DateTime(
                                    _date.year, _date.month, _date.day, picked.hour, picked.minute));
                              }
                            },
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          TextField(
                            controller: _notesController,
                            maxLines: 12,
                            decoration: InputDecoration(
                              labelText: t(currentLocale.value, 'notes_label'),
                              hintText: t(currentLocale.value, 'add_details'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          ...List.generate(_checklistControllers.length, (i) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(children: [
                                  Checkbox(
                                      value: _checklistDone[i],
                                      onChanged: (v) =>
                                          setState(() => _checklistDone[i] = v ?? false)),
                                  Expanded(
                                      child: TextField(
                                    controller: _checklistControllers[i],
                                    decoration: InputDecoration(
                                      hintText: t(currentLocale.value, 'checklist_item'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  )),
                                ]),
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      if (widget.onDelete != null)
                        TextButton(
                            onPressed: () {
                              widget.onDelete!(widget.task);
                              Navigator.of(context).pop<PlanningTask?>(null);
                            },
                            child: Text(t(currentLocale.value, 'delete'),
                                style: TextStyle(color: Theme.of(context).colorScheme.error))),
                      const Spacer(),
                      TextButton(
                          onPressed: () => Navigator.of(context).pop<PlanningTask?>(null),
                          child: Text(t(currentLocale.value, 'cancel'))),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _commitSave,
                        child: Text(t(currentLocale.value, 'save')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRecordSheetContent extends StatefulWidget {
  const _TimelineRecordSheetContent({
    required this.record,
    required this.scrollController,
    required this.onSaved,
    required this.onDelete,
    required this.onStop,
  });

  final TimelineRecord record;
  final ScrollController scrollController;
  final void Function(dynamic updated) onSaved;
  final VoidCallback onDelete;
  final VoidCallback onStop;

  @override
  State<_TimelineRecordSheetContent> createState() => _TimelineRecordSheetContentState();
}

class _TimelineRecordSheetContentState extends State<_TimelineRecordSheetContent>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  int? _categoryId;
  DateTime? _startDisplay;
  DateTime? _endDisplay;
  final List<TextEditingController> _checklistControllers = [];
  final List<bool> _checklistDone = [];
  late TabController _tabController;

  List<Map<String, dynamic>> _checklistForApi() {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < _checklistControllers.length; i++) {
      final text = _checklistControllers[i].text.trim();
      if (text.isEmpty) continue;
      out.add(<String, dynamic>{
        'text': text,
        'isDone': i < _checklistDone.length ? _checklistDone[i] : false,
      });
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _titleController = TextEditingController(text: widget.record.title);
    _noteController = TextEditingController(text: widget.record.note ?? '');
    _categoryId = widget.record.categoryId;
    _startDisplay = widget.record.startTime != null ? utcToDisplay(widget.record.startTime!) : null;
    _endDisplay = widget.record.endTime != null ? utcToDisplay(widget.record.endTime!) : null;
    for (final item in widget.record.checklist ?? []) {
      _checklistControllers.add(
        TextEditingController(text: (item['text'] ?? '').toString()),
      );
      _checklistDone.add(item['isDone'] == true);
    }
    if (_checklistControllers.isEmpty) {
      _checklistControllers.add(TextEditingController());
      _checklistDone.add(false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStart() async {
    final initial = _startDisplay ?? displayNow();
    final picked = await showAppDateTimePicker(context, initial: initial);
    if (picked != null && mounted) setState(() => _startDisplay = picked);
  }

  Future<void> _pickEnd() async {
    final initial = _endDisplay ?? displayNow();
    final picked = await showAppDateTimePicker(context, initial: initial);
    if (picked != null && mounted) setState(() => _endDisplay = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final noteText = _noteController.text.trim();
    final checklistPayload = _checklistForApi();
    final isRunning = widget.record.endTime == null;

    if (isRunning) {
      final updated = await DatabaseService.instance.updateRecord(
        recordId: widget.record.recordId,
        title: title,
        categoryId: _categoryId,
        note: noteText,
        checklist: checklistPayload,
      );
      if (updated != null && mounted) {
        widget.onSaved(updated);
      }
      return;
    }

    if (_startDisplay == null || _endDisplay == null) return;
    final startUtc = displayToUtc(_startDisplay!);
    final endUtc = displayToUtc(_endDisplay!);
    if (endUtc.isBefore(startUtc) || endUtc.isAtSameMomentAs(startUtc)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'end_time_after_start'))),
        );
      }
      return;
    }
    final overlap = await DatabaseService.instance.checkOverlapWithExistingRecords(
      startUtc,
      endUtc,
      excludeRecordId: widget.record.recordId.isNotEmpty
          ? widget.record.recordId
          : null,
    );
    if (overlap && mounted) {
      final conflict = await DatabaseService.instance.findFirstOverlappingRecord(
        startUtc,
        endUtc,
        excludeRecordId: widget.record.recordId.isNotEmpty
            ? widget.record.recordId
            : null,
      );
      if (!mounted) return;
      final loc = currentLocale.value;
      final rawTitle = (conflict?['title'] ?? '').toString().trim();
      final otherLabel = rawTitle.isNotEmpty ? rawTitle : t(loc, 'untitled');
      final msg =
          t(loc, 'time_conflict_with_title').replaceFirst('%s', otherLabel);
      final sm = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sm?.showSnackBar(SnackBar(content: Text(msg)));
      });
      return;
    }
    final updated = await DatabaseService.instance.updateRecord(
      recordId: widget.record.recordId,
      title: title,
      startTime: startUtc,
      endTime: endUtc,
      categoryId: _categoryId,
      note: noteText,
      checklist: checklistPayload,
    );
    if (updated != null && mounted) {
      widget.onSaved(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final isRunning = widget.record.endTime == null;
    final catVal = _categoryId != null && pairs.any((p) => p.id == _categoryId)
        ? _categoryId
        : (pairs.isNotEmpty ? pairs.first.id : null);

    Widget startEndCaption(bool isEnd) {
      if (isEnd && isRunning) {
        return Text(t(currentLocale.value, 'running_label'),
            maxLines: 2, overflow: TextOverflow.ellipsis);
      }
      final dt = isEnd ? _endDisplay : _startDisplay;
      if (dt == null) return const Text('–');
      return Text(
        '${formatDate(dt)} ${formatTimeOfDay(dt)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(child: Text(t(currentLocale.value, 'edit_record'), style: Theme.of(context).textTheme.titleLarge)),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                            labelText: t(currentLocale.value, 'title_label'),
                            hintText: t(currentLocale.value, 'hint_task_example')),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: catVal,
                        decoration: InputDecoration(
                            labelText: t(currentLocale.value, 'category_label')),
                        items: pairs
                            .map((p) => DropdownMenuItem<int>(
                                value: p.id, child: Text(p.path, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (id) => setState(() => _categoryId = id ?? catVal),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _pickStart,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_month_rounded, size: 18),
                                        const SizedBox(width: 6),
                                        Text(t(currentLocale.value, 'start_time'),
                                            style: Theme.of(context).textTheme.labelMedium),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    DefaultTextStyle.merge(
                                      style: Theme.of(context).textTheme.bodySmall!,
                                      child: startEndCaption(false),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isRunning ? null : _pickEnd,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.event_available_rounded, size: 18),
                                        const SizedBox(width: 6),
                                        Text(t(currentLocale.value, 'end_time'),
                                            style: Theme.of(context).textTheme.labelMedium),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    DefaultTextStyle.merge(
                                      style: Theme.of(context).textTheme.bodySmall!,
                                      child: startEndCaption(true),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: [
                    Tab(text: t(currentLocale.value, 'notes_tab')),
                    Tab(text: t(currentLocale.value, 'checklist_tab')),
                    Tab(text: t(currentLocale.value, 'parallel_activities_tab')),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ListView(
                        primary: false,
                        controller: widget.scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          TextField(
                            controller: _noteController,
                            decoration: InputDecoration(
                              labelText: t(currentLocale.value, 'notes_label'),
                              hintText: t(currentLocale.value, 'add_details'),
                              border: const OutlineInputBorder(),
                            ),
                            maxLines: 12,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                      ListView(
                        primary: false,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          ...List.generate(_checklistControllers.length, (i) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Checkbox(
                                      value: i < _checklistDone.length ? _checklistDone[i] : false,
                                      onChanged: (v) => setState(() {
                                        while (_checklistDone.length <= i) {
                                          _checklistDone.add(false);
                                        }
                                        _checklistDone[i] = v ?? false;
                                      }),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _checklistControllers[i],
                                      decoration: InputDecoration(
                                        hintText: t(currentLocale.value, 'checklist_item'),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _checklistControllers.add(TextEditingController());
                              _checklistDone.add(false);
                            }),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(t(currentLocale.value, 'add_checklist_item')),
                          ),
                        ],
                      ),
                      _ParallelActivitiesTab(
                        parentRecord: widget.record,
                        scrollController: widget.scrollController,
                        categoryId: catVal,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      if (isRunning)
                        TextButton.icon(
                            onPressed: widget.onStop,
                            icon: const Icon(Icons.stop_rounded),
                            label: Text(t(currentLocale.value, 'stop'))),
                      TextButton(
                          onPressed: widget.onDelete,
                          child: Text(t(currentLocale.value, 'delete'),
                              style: TextStyle(color: Theme.of(context).colorScheme.error))),
                      const Spacer(),
                      FilledButton(onPressed: _save, child: Text(t(currentLocale.value, 'save'))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Parallel sub-records for an open record sheet: add / list / stop / edit (@DATA_MAP.md parent_id).
class _ParallelActivitiesTab extends StatefulWidget {
  const _ParallelActivitiesTab({
    required this.parentRecord,
    required this.scrollController,
    required this.categoryId,
  });

  final TimelineRecord parentRecord;
  final ScrollController scrollController;
  final int? categoryId;

  @override
  State<_ParallelActivitiesTab> createState() => _ParallelActivitiesTabState();
}

class _ParallelActivitiesTabState extends State<_ParallelActivitiesTab>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _newTitleController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _newTitleController = TextEditingController();
  }

  @override
  void dispose() {
    _newTitleController.dispose();
    super.dispose();
  }

  String _parentWallDateKey() {
    final st = widget.parentRecord.startTime;
    if (st != null) {
      final wall = utcToDisplay(st);
      return formatDate(wall);
    }
    return formatDate(displayNow());
  }

  Future<void> _addParallel() async {
    final title = _newTitleController.text.trim();
    if (title.isEmpty) return;
    final link = DatabaseService.instance
        .resolveParentLinkForChildren(widget.parentRecord.recordId);
    if (link.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(t(currentLocale.value, 'parallel_activities_info'))),
        );
      }
      return;
    }
    try {
      final id = await DatabaseService.instance.writeRecord(
        _parentWallDateKey(),
        title,
        categoryId: widget.categoryId ?? widget.parentRecord.categoryId,
        explicitStartTime: DatabaseService.getPlanetaryNow(),
        parentRecordId: link,
      );
      if (!mounted) return;
      if (id != null) {
        _newTitleController.clear();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  Future<void> _stopChild(TimelineRecord child) async {
    try {
      final ok =
          await DatabaseService.instance.stopRecordByDocId(child.recordId);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  void _openChildEditor(TimelineRecord child) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return _ChildParallelEditBar(
          child: child,
          onSaved: () {
            Navigator.pop(ctx);
            setState(() {});
          },
        );
      },
    );
  }

  Widget _childTile(BuildContext context, TimelineRecord c,
      {required bool running}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      title: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        running
            ? (c.startTime != null
                ? '${formatDate(utcToDisplay(c.startTime!))} ${formatTimeOfDay(utcToDisplay(c.startTime!))}'
                : '—')
            : (c.startTime != null && c.endTime != null
                ? '${formatDate(utcToDisplay(c.startTime!))} ${formatTimeOfDay(utcToDisplay(c.startTime!))} — ${formatTimeOfDay(utcToDisplay(c.endTime!))}'
                : '—'),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (running)
            IconButton(
              icon: const Icon(Icons.stop_rounded),
              onPressed: () => _stopChild(c),
              tooltip: t(currentLocale.value, 'stop'),
            ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _openChildEditor(c),
            tooltip: t(currentLocale.value, 'edit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.parentRecord.recordId.isEmpty) {
      return ListView(
        primary: false,
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            t(currentLocale.value, 'parallel_activities_info'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }
    final link = DatabaseService.instance
        .resolveParentLinkForChildren(widget.parentRecord.recordId);
    return ListView(
      primary: false,
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        TextField(
          controller: _newTitleController,
          decoration: InputDecoration(
            labelText: t(currentLocale.value, 'title_label'),
            hintText: t(currentLocale.value, 'hint_task_example'),
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _addParallel,
          icon: const Icon(Icons.add_rounded),
          label: Text(t(currentLocale.value, 'parallel_add_activity')),
        ),
        const SizedBox(height: 16),
        Text(t(currentLocale.value, 'child_records_running'),
            style: Theme.of(context).textTheme.titleMedium),
        StreamBuilder<List<TimelineRecord>>(
          stream: DatabaseService.instance.runningChildrenStream(link),
          builder: (context, snap) {
            final list = snap.data ?? const <TimelineRecord>[];
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  t(currentLocale.value, 'no_parallel_activities'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: list
                  .map((c) => _childTile(context, c, running: true))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(t(currentLocale.value, 'child_records_completed'),
            style: Theme.of(context).textTheme.titleMedium),
        StreamBuilder<List<TimelineRecord>>(
          stream: DatabaseService.instance.completedChildrenStream(link),
          builder: (context, snap) {
            final list = snap.data ?? const <TimelineRecord>[];
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('—', style: Theme.of(context).textTheme.bodySmall),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: list
                  .map((c) => _childTile(context, c, running: false))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ChildParallelEditBar extends StatefulWidget {
  const _ChildParallelEditBar({required this.child, required this.onSaved});

  final TimelineRecord child;
  final VoidCallback onSaved;

  @override
  State<_ChildParallelEditBar> createState() => _ChildParallelEditBarState();
}

class _ChildParallelEditBarState extends State<_ChildParallelEditBar> {
  late final TextEditingController _title;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.child.title);
    _note = TextEditingController(text: widget.child.note ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    try {
      final u = await DatabaseService.instance.updateRecord(
        recordId: widget.child.recordId,
        title: title,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      if (u != null) {
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  Future<void> _stop() async {
    try {
      final ok = await DatabaseService.instance
          .stopRecordByDocId(widget.child.recordId);
      if (!mounted) return;
      if (ok) {
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.child.endTime == null;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: t(currentLocale.value, 'title_label'),
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: t(currentLocale.value, 'notes_label'),
              border: const OutlineInputBorder(),
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (running)
                TextButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(t(currentLocale.value, 'stop')),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _save,
                child: Text(t(currentLocale.value, 'save')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Create (or edit) a single record with start/end date+time. Used for "New Record" on past date.
class EditRecordSheet extends StatefulWidget {
  const EditRecordSheet({
    super.key,
    required this.serverRecordId,
    required this.data,
    required this.dateKey,
    required this.selectedDate,
    required this.onSaved,
    required this.onJumpToConflict,
  });

  /// NocoDB row id (empty when creating a new row).
  final String serverRecordId;
  final Map<String, dynamic> data;
  final String dateKey;
  final DateTime selectedDate;
  final VoidCallback onSaved;
  final void Function(DateTime date, String conflictRecordId) onJumpToConflict;

  @override
  State<EditRecordSheet> createState() => _EditRecordSheetState();
}

class _EditRecordSheetState extends State<EditRecordSheet> {
  late TextEditingController _titleController;
  int? _categoryId;
  late DateTime _recordDate;
  late DateTime _endDate;
  late DateTime _startTime;
  late DateTime _endTime;
  String? _timeConflictError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: (widget.data['title'] as String?) ?? '');
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final cr = widget.data['categoryId'];
    _categoryId = cr is int ? cr : int.tryParse(cr?.toString() ?? '');
    if (_categoryId == null && pairs.isNotEmpty) _categoryId = pairs.first.id;
    final startUtc = widget.data['startTime'] as DateTime?;
    final endUtc = widget.data['endTime'] as DateTime?;
    final displayStart = startUtc != null ? utcToDisplay(startUtc) : DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 9, 0);
    final displayEnd = endUtc != null ? utcToDisplay(endUtc) : displayStart;
    _recordDate = DateTime(displayStart.year, displayStart.month, displayStart.day);
    _endDate = DateTime(displayEnd.year, displayEnd.month, displayEnd.day);
    _startTime = displayStart;
    _endTime = displayEnd;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  DateTime get _effectiveStart => DateTime(_recordDate.year, _recordDate.month, _recordDate.day, _startTime.hour, _startTime.minute);
  DateTime get _effectiveEnd => DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute);

  Future<void> _pickStartTime() async {
    final picked = await showAppDateTimePicker(context, initial: _startTime, firstDate: _recordDate, lastDate: DateTime(_recordDate.year, _recordDate.month, _recordDate.day, 23, 59));
    if (picked != null && mounted) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showAppDateTimePicker(context, initial: _endTime, firstDate: _endDate, lastDate: DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59));
    if (picked != null && mounted) setState(() => _endTime = picked);
  }

  Future<void> _pickRecordDate() async {
    final d = await showDatePicker(context: context, initialDate: _recordDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (d != null && mounted) {
      setState(() {
        _recordDate = d;
        if (_endDate.isBefore(_recordDate)) _endDate = _recordDate;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final d = await showDatePicker(context: context, initialDate: _endDate, firstDate: _recordDate, lastDate: DateTime(2030));
    if (d != null && mounted) setState(() => _endDate = d);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final start = _effectiveStart;
    final end = _effectiveEnd;
    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      setState(() => _timeConflictError = t(currentLocale.value, 'end_time_after_start'));
      return;
    }
    final startUtc = displayToUtc(start);
    final endUtc = displayToUtc(end);
    final overlap = await DatabaseService.instance.checkOverlapWithExistingRecords(
        startUtc,
        endUtc,
        excludeRecordId: widget.serverRecordId.isNotEmpty
            ? widget.serverRecordId
            : null);
    if (overlap) {
      final conflict = await DatabaseService.instance.findFirstOverlappingRecord(
        startUtc,
        endUtc,
        excludeRecordId: widget.serverRecordId.isNotEmpty
            ? widget.serverRecordId
            : null,
      );
      if (!mounted) return;
      final loc = currentLocale.value;
      final rawTitle = (conflict?['title'] ?? '').toString().trim();
      final otherLabel = rawTitle.isNotEmpty ? rawTitle : t(loc, 'untitled');
      final msg =
          t(loc, 'time_conflict_with_title').replaceFirst('%s', otherLabel);
      final sm = ScaffoldMessenger.maybeOf(context);
      if (conflict != null) {
        final conflictRid =
            (conflict['record_id'] ?? conflict['id'] ?? '').toString();
        final conflictStart = DatabaseService.startTimeFromRecord(conflict);
        final conflictDate = conflictStart != null
            ? DateTime(
                conflictStart.year,
                conflictStart.month,
                conflictStart.day,
              )
            : widget.selectedDate;
        widget.onJumpToConflict(conflictDate, conflictRid);
      }
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sm?.showSnackBar(SnackBar(content: Text(msg)));
      });
      return;
    }
    setState(() => _timeConflictError = null);
    var ok = false;
    if (widget.serverRecordId.isEmpty) {
      ok = await DatabaseService.instance.writeCompletedRecord(
        title,
        startUtc,
        endUtc,
        categoryId: _categoryId,
      );
    } else {
      final updated = await DatabaseService.instance.updateRecord(
        recordId: widget.serverRecordId,
        title: title,
        startTime: startUtc,
        endTime: endUtc,
        categoryId: _categoryId,
      );
      ok = updated != null;
    }
    if (ok && mounted) {
      final msgKey = widget.serverRecordId.isEmpty
          ? 'record_synced'
          : 'changes_saved';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, msgKey))),
      );
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final catVal = _categoryId != null && pairs.any((p) => p.id == _categoryId)
        ? _categoryId
        : (pairs.isNotEmpty ? pairs.first.id : null);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(child: Text(t(currentLocale.value, 'new_record_btn'), style: Theme.of(context).textTheme.titleLarge)),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(labelText: t(currentLocale.value, 'title_label'), hintText: t(currentLocale.value, 'hint_task_example')),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: catVal,
                    decoration: InputDecoration(labelText: t(currentLocale.value, 'category_label')),
                    items: pairs.map((p) => DropdownMenuItem<int>(value: p.id, child: Text(p.path))).toList(),
                    onChanged: (id) => setState(() => _categoryId = id ?? catVal),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(t(currentLocale.value, 'start_time')),
                    subtitle: Text('${formatDate(_recordDate)} ${formatTimeOfDay(_startTime)}'),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      await _pickRecordDate();
                      await _pickStartTime();
                    },
                  ),
                  ListTile(
                    title: Text(t(currentLocale.value, 'end_time')),
                    subtitle: Text('${formatDate(_endDate)} ${formatTimeOfDay(_endTime)}'),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      await _pickEndDate();
                      await _pickEndTime();
                    },
                  ),
                  if (_timeConflictError != null) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_timeConflictError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _save, child: Text(t(currentLocale.value, 'save'))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CategoryFolderTile — Recursive category tree tile. Uses Theme.of(context).
// ---------------------------------------------------------------------------

class CategoryFolderTile extends StatefulWidget {
  const CategoryFolderTile({
    super.key,
    required this.rule,
    required this.rootRules,
    required this.level,
    required this.onChanged,
    required this.onRemove,
  });

  final CategoryRule rule;
  final List<CategoryRule> rootRules;
  final int level;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<CategoryFolderTile> createState() => _CategoryFolderTileState();
}

class _CategoryFolderTileState extends State<CategoryFolderTile> {
  void _addChild() {
    if (DatabaseService.instance.siblingHasTag(widget.rule.id, 'Sub')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'category_exists'))),
      );
      return;
    }
    setState(() {
      widget.rule.children ??= [];
      widget.rule.children!.add(CategoryRule(
        id: DatabaseService.instance.newId(),
        name: 'Sub',
        colorValue: widget.rule.colorValue,
        iconCodePoint: widget.rule.iconCodePoint,
        order: 0,
      ));
    });
    widget.onChanged();
  }

  Future<void> _openCategoryEditorSurgical(BuildContext context) async {
    final controller = TextEditingController(text: widget.rule.name);
    int? selectedColorValue = widget.rule.colorValue;
    MaterialColor? selectedPrimary;
    int? selectedShadeValue;
    String? dialogError;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            List<int> shadeValuesFor(MaterialColor c) => <int>[
              c[50]!.value,
              c[100]!.value,
              c[200]!.value,
              c[300]!.value,
              c[400]!.value,
              c[500]!.value,
              c[600]!.value,
              c[700]!.value,
              c[800]!.value,
              c[900]!.value,
            ];

            MaterialColor? primaryForValue(int? v) {
              if (v == null) return null;
              for (final p in Colors.primaries) {
                if (shadeValuesFor(p).contains(v)) return p;
              }
              return null;
            }

            selectedPrimary ??= primaryForValue(selectedColorValue) ?? Colors.blue;
            selectedShadeValue ??= (selectedColorValue != null && shadeValuesFor(selectedPrimary!).contains(selectedColorValue))
                ? selectedColorValue
                : selectedPrimary![500]!.value;

            return AlertDialog(
              title: Text(t(currentLocale.value, 'edit_category_title')),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: Colors.primaries.map((p) {
                          final isSelected = selectedPrimary == p;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedPrimary = p;
                                selectedShadeValue = p.shade500.value;
                                selectedColorValue = selectedShadeValue;
                              });
                              HapticFeedback.lightImpact();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: p,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Theme.of(ctx).colorScheme.primary : Colors.transparent,
                                  width: isSelected ? 3 : 0,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: <int>[50, 100, 200, 300, 400, 500, 600, 700, 800, 900].map((tone) {
                          final c = selectedPrimary![tone]!;
                          final v = c.value;
                          final isSelected = selectedShadeValue == v;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedShadeValue = v;
                                selectedColorValue = v;
                              });
                              HapticFeedback.lightImpact();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? Theme.of(ctx).colorScheme.primary : Colors.transparent,
                                  width: isSelected ? 3 : 0,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: t(currentLocale.value, 'name_label'),
                          hintText: t(currentLocale.value, 'hint_work_health'),
                          errorText: dialogError,
                        ),
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) {
                          if (dialogError != null) setDialogState(() => dialogError = null);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            widget.rule.iconOrDefault,
                            color: selectedShadeValue != null ? Color(selectedShadeValue!) : Theme.of(ctx).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Selected color updates before save', style: Theme.of(ctx).textTheme.bodySmall)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t(currentLocale.value, 'cancel'))),
                FilledButton(
                  onPressed: () async {
                    final newTag = controller.text.trim().isEmpty ? widget.rule.name : controller.text.trim();
                    final updated = DatabaseService.instance.updateNestedCategory(widget.rule.id, name: newTag, colorValue: selectedColorValue);
                    if (updated) {
                      try {
                        final sync =
                            await DatabaseService.instance.saveCategoryRowToServer(
                          widget.rule.id,
                        );
                        if (!sync.ok && ctx.mounted) {
                          setDialogState(() => dialogError = sync.errorDetail ?? 'Sync failed');
                          return;
                        }
                      } catch (_) {}
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    } else if (newTag != widget.rule.name) {
                      setDialogState(() => dialogError = 'Category already exists');
                    }
                  },
                  child: Text(t(currentLocale.value, 'save')),
                ),
              ],
            );
          },
        ),
      );
      if (saved == true && mounted) {
        widget.onChanged();
        setState(() {});
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasChildren = widget.rule.children != null && widget.rule.children!.isNotEmpty;
    final canAddChild = widget.level < 4;
    final color = widget.rule.colorOrDefault;

    final displayName = widget.rule.localizedNames?[currentLocale.value] ?? widget.rule.name;

    final leading = Icon(widget.rule.iconOrDefault, color: color, size: 24);
    final title = Text(
      displayName,
      style: TextStyle(fontWeight: FontWeight.w600, color: color),
      overflow: TextOverflow.ellipsis,
    );
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canAddChild)
          IconButton(
            iconSize: 22,
            tooltip: t(currentLocale.value, 'add_subcategory'),
            onPressed: _addChild,
            icon: const Icon(Icons.add_rounded),
          ),
        IconButton(
          iconSize: 22,
          tooltip: t(currentLocale.value, 'edit_category_tooltip'),
          onPressed: () => _openCategoryEditorSurgical(context),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          iconSize: 22,
          tooltip: t(currentLocale.value, 'delete_category'),
          onPressed: widget.onRemove,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );

    final List<Widget> childTiles = hasChildren
        ? [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.rule.children!.length,
              itemBuilder: (context, index) {
                final c = widget.rule.children![index];
                return CategoryFolderTile(
                  key: ValueKey(c.id),
                  rule: c,
                  rootRules: widget.rootRules,
                  level: widget.level + 1,
                  onChanged: widget.onChanged,
                  onRemove: () {
                    setState(() {
                      widget.rule.children!.removeWhere((x) => x.id == c.id);
                    });
                    widget.onChanged();
                  },
                );
              },
            ),
          ]
        : [];

    const double kMaxTileHeight = 4000;
    final expansionContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: childTiles,
    );

    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: kMaxTileHeight),
      child: Padding(
        padding: EdgeInsets.only(left: 16.0 * (widget.level - 1)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.level > 1)
              Container(
                width: 2,
                margin: const EdgeInsets.only(right: 8),
                color: scheme.outline,
              ),
            Expanded(
              child: ExpansionTile(
                leading: leading,
                title: title,
                trailing: trailing,
                children: [expansionContent],
              ),
            ),
          ],
        ),
      ),
    );

    return content;
  }
}
