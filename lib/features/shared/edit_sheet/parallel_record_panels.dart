import 'dart:async';
import 'dart:convert';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/omni_date_time_picker_dialog.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:counter/data/smart_input_parser.dart';
import 'package:counter/features/planning/recurrence_scope_dialog.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:counter/features/shared/edit_sheet/sheet_time_helpers.dart';/// Child backlog plans linked via [PlanningTask.parentPlanPocketId] (lists sub-items).
class BacklogSubItemsPanel extends StatefulWidget {
  const BacklogSubItemsPanel({
    required this.parentTask,
    required this.categoryId,
  });

  final PlanningTask parentTask;
  final int categoryId;

  @override
  State<BacklogSubItemsPanel> createState() => BacklogSubItemsPanelState();
}

class BacklogSubItemsPanelState extends State<BacklogSubItemsPanel> {
  final TextEditingController _newTitleController = TextEditingController();
  StreamSubscription<void>? _planRefreshSub;

  @override
  void initState() {
    super.initState();
    _planRefreshSub = DatabaseService.instance.planningRefreshNotifications
        .listen((_) {
          if (mounted) setState(() {});
        });
  }

  @override
  void dispose() {
    _planRefreshSub?.cancel();
    _newTitleController.dispose();
    super.dispose();
  }

  bool get _parentPersisted {
    final id = widget.parentTask.planRowIdForBackend.trim();
    return id.isNotEmpty && !id.startsWith('optimistic-');
  }

  List<PlanningTask> get _children {
    if (!_parentPersisted) return const [];
    return DatabaseService.instance.backlogChildPlansForParent(
      widget.parentTask.planRowIdForBackend.trim(),
    );
  }

  Future<void> _addSubItem() async {
    final title = _newTitleController.text.trim();
    if (title.isEmpty) return;
    if (!_parentPersisted) {
      AppSnack.show(
        t(currentLocale.value, 'lists_subitems_save_parent_first'),
        error: true,
      );
      return;
    }
    final ok = await DatabaseService.instance.addBacklogChildPlan(
      parentPocketPlanId: widget.parentTask.planRowIdForBackend.trim(),
      title: title,
      categoryId: widget.categoryId,
    );
    if (!mounted) return;
    if (ok) {
      _newTitleController.clear();
      setState(() {});
    } else {
      AppSnack.failed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final children = _children;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (!_parentPersisted)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              t(loc, 'lists_subitems_save_parent_first'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _newTitleController,
                enabled: _parentPersisted,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: t(loc, 'lists_subitems_add_hint'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => unawaited(_addSubItem()),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _parentPersisted
                  ? () => unawaited(_addSubItem())
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: Text(t(loc, 'add')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (children.isEmpty)
          Text(
            '—',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          for (final child in children)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                value: child.isDone,
                onChanged: child.planRowIdForBackend.startsWith('optimistic-')
                    ? null
                    : (v) {
                        if (v == null) return;
                        final db = DatabaseService.instance;
                        db.applyOptimisticPlanningTask(
                          child.copyWith(isDone: v),
                        );
                        db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
                        setState(() {});
                        unawaited(
                          db.updatePlanningTask(
                            child.planRowIdForBackend,
                            planBusinessId: child.planRowId,
                            isDone: v,
                            suppressAppSnack: true,
                          ),
                        );
                      },
              ),
              title: Text(
                child.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: child.isDone
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
            ),
      ],
    );
  }
}

/// Parallel sub-records for an open record sheet: add / list / stop / edit (@DATA_MAP.md parent_id).
class ParallelActivitiesTab extends StatefulWidget {
  const ParallelActivitiesTab({
    required this.parentRecord,
    required this.scrollController,
    required this.categoryId,
  });

  final TimelineRecord parentRecord;
  final ScrollController scrollController;
  final int? categoryId;

  @override
  State<ParallelActivitiesTab> createState() => ParallelActivitiesTabState();
}

class ParallelActivitiesTabState extends State<ParallelActivitiesTab>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _newTitleController;

  /// Parent link key for which [_runningChildrenStream] / [_completedChildrenStream] were built.
  /// [runningChildrenStream] / [completedChildrenStream] return new streams per call — must not
  /// pass a freshly created stream from [build] each rebuild.
  String? _childStreamsLink;
  late Stream<List<TimelineRecord>> _runningChildrenStream;
  late Stream<List<TimelineRecord>> _completedChildrenStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _newTitleController = TextEditingController();
  }

  void _ensureChildStreams(String link) {
    if (_childStreamsLink == link) return;
    _childStreamsLink = link;
    _runningChildrenStream = DatabaseService.instance.runningChildrenStream(
      link,
    );
    _completedChildrenStream = DatabaseService.instance.completedChildrenStream(
      link,
    );
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
    final link = DatabaseService.instance.resolveParentLinkForChildren(
      widget.parentRecord.id,
    );
    if (link.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(currentLocale.value, 'parallel_activities_info')),
          ),
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
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  Future<void> _stopChild(TimelineRecord child) async {
    try {
      final ok = await DatabaseService.instance.stopRecordByDocId(child.id);
      if (!mounted) return;
      if (!ok) {
        debugPrint(
          'UI ERROR: stopRecordByDocId returned false (systemRowId=${child.id})',
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
    }
  }

  void _openChildEditor(TimelineRecord child) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return ChildParallelEditBar(
          child: child,
          onSaved: () {
            Navigator.pop(ctx);
            setState(() {});
          },
        );
      },
    );
  }

  Widget _childTile(
    BuildContext context,
    TimelineRecord c, {
    required bool running,
  }) {
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
    if (widget.parentRecord.id.isEmpty) {
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
    final link = DatabaseService.instance.resolveParentLinkForChildren(
      widget.parentRecord.id,
    );
    _ensureChildStreams(link);
    return ListView(
      primary: false,
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        TextField(
          controller: _newTitleController,
          decoration: InputDecoration(
            labelText: t(currentLocale.value, 'title_label'),
            hintText: t(currentLocale.value, 'hint_record_example'),
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
        Text(
          t(currentLocale.value, 'child_records_running'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        StreamBuilder<List<TimelineRecord>>(
          stream: _runningChildrenStream,
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
        Text(
          t(currentLocale.value, 'child_records_completed'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        StreamBuilder<List<TimelineRecord>>(
          stream: _completedChildrenStream,
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

class ChildParallelEditBar extends StatefulWidget {
  const ChildParallelEditBar({required this.child, required this.onSaved});

  final TimelineRecord child;
  final VoidCallback onSaved;

  @override
  State<ChildParallelEditBar> createState() => ChildParallelEditBarState();
}

class ChildParallelEditBarState extends State<ChildParallelEditBar> {
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
        recordId: widget.child.id,
        title: title,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      if (u != null) {
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  Future<void> _stop() async {
    try {
      final ok = await DatabaseService.instance.stopRecordByDocId(
        widget.child.id,
      );
      if (!mounted) return;
      if (ok) {
        widget.onSaved();
      } else {
        debugPrint(
          'UI ERROR: stopRecordByDocId returned false (systemRowId=${widget.child.id})',
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
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
