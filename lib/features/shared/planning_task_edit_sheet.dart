import 'dart:async';
import 'dart:convert';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/omni_date_time_picker_dialog.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/features/shared/edit_sheet/category_edit_draft.dart';
import 'package:counter/shared/categories/picker/category_tree_picker.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:counter/features/planning/recurrence_scope_dialog.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:counter/features/shared/edit_sheet/checklist_helpers.dart';
import 'package:counter/features/shared/edit_sheet/parallel_record_panels.dart';
import 'package:counter/features/shared/edit_sheet/plan_repeat_helpers.dart';
import 'package:counter/features/shared/edit_sheet/quill_link_launcher.dart';
import 'package:counter/features/shared/edit_sheet/quill_toolbar_config.dart';
import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';
import 'package:counter/features/shared/edit_sheet/sheet_time_helpers.dart';
import 'package:counter/features/shared/edit_sheet/sheet_time_picker.dart';

class PlanningTaskEditSheet extends StatefulWidget {
  const PlanningTaskEditSheet({
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
  State<PlanningTaskEditSheet> createState() => PlanningTaskEditSheetState();
}

class PlanningTaskEditSheetState extends State<PlanningTaskEditSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late final QuillController _quillController;
  late final FocusNode _quillFocusNode;

  /// Separate from [scrollController] so plan-mode outer [ListView] does not fight Quill.
  late final ScrollController _quillScrollController;
  late int _categoryId;
  DateTime? _scheduledTime;
  DateTime? _endTime;
  late DateTime _date;

  /// Undated backlog / list item before any schedule is set (no wall date in [dateKey]).
  late final bool _startedAsUndatedBacklog;
  final List<TextEditingController> _checklistControllers = [];
  final List<bool> _checklistDone = [];

  /// Non-null only for list-item / Idea mode (3-tab Strike 19 layout).
  TabController? _tabController;

  /// Dated plan mode: Notes / Checklist / schedule & recurrence (Strike 24).
  TabController? _planTabController;
  List<Tag> _availableTags = [];

  /// True until [DatabaseService.fetchTagsForCurrentUser] completes (strip stays visible).
  bool _tagsLoading = true;
  late List<Tag> _selectedTags;
  int? _reminderMinutes;
  late PlanRepeatUi _repeatUi;
  String? _rruleCustomRaw;
  late final TextEditingController _rruleCustomController;
  late final PlanningTask _baselineTask;
  final EditSheetAutosaveGate _planAutosaveGate = EditSheetAutosaveGate();
  RecurrenceEditScope? _recurrenceEditScopeChosen;
  bool _recurrenceScopePromptOpen = false;
  StreamSubscription<DocChange>? _planQuillChangesSub;
  Timer? _titleAssistDebounce;

  bool get _isPersistedPlan =>
      widget.task.planRowIdForBackend.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _baselineTask = widget.task;
    _startedAsUndatedBacklog =
        widget.task.startTime == null && widget.task.dateKey.trim().length < 10;
    if (_startedAsUndatedBacklog) {
      _tabController = TabController(length: 4, vsync: this);
    } else {
      _planTabController = TabController(length: 4, vsync: this);
    }
    _titleController = TextEditingController(text: widget.task.title);
    final parsedNotes = _parseStoredNotesForLink(widget.task.notesPlain);
    _quillController = QuillController(
      document: _documentForPlanningNotes(
        parsedNotes.body,
        legacyUrl: parsedNotes.link,
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillFocusNode = FocusNode();
    _quillScrollController = ScrollController();
    _categoryId = widget.task.categoryId;
    _selectedTags = List<Tag>.from(widget.task.tags);
    _reminderMinutes = widget.task.reminderOffset;
    _repeatUi = planRepeatUiFromTask(widget.task);
    _rruleCustomRaw = _repeatUi == PlanRepeatUi.custom
        ? widget.task.rrule?.trim()
        : null;
    _rruleCustomController = TextEditingController(
      text: _repeatUi == PlanRepeatUi.custom
          ? (widget.task.rrule?.trim() ?? '')
          : '',
    );
    if (!_startedAsUndatedBacklog) {
      DatabaseService.instance
          .fetchTagsForCurrentUser(scope: TagCatalogScope.plan)
          .then((List<Tag> result) {
            if (!mounted) return;
            setState(() {
              _availableTags = result;
              _tagsLoading = false;
            });
          });
    } else {
      DatabaseService.instance
          .fetchTagsForCurrentUser(scope: TagCatalogScope.list)
          .then((List<Tag> result) {
            if (!mounted) return;
            setState(() {
              _availableTags = result;
              _tagsLoading = false;
            });
          });
    }
    // [PlanningTask.startTime] / [endDateTime] from Brain are profile wall components, not UTC.
    _scheduledTime = widget.task.startTime;
    _endTime = widget.task.endDateTime;
    _date =
        planningDateFromKey(widget.task.dateKey) ??
        widget.task.date ??
        DateTime.now();
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
    partitionChecklistRowsByDone(
      controllers: _checklistControllers,
      done: _checklistDone,
    );
    _planQuillChangesSub = _quillController.document.changes.listen((_) {
      if (!mounted) return;
      _onPlanFieldChanged();
    });
  }

  bool get _shouldShowGraduateUi =>
      _startedAsUndatedBacklog && _scheduledTime != null;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isPersistedPlan) {
      _planAutosaveGate.flush(() {
        final latest = _buildDraftTask();
        if (latest != null) {
          unawaited(_syncPlanDraftToNetwork(latest));
        }
      }, force: _planAutosaveGate.isDirty);
    }
    unawaited(_planQuillChangesSub?.cancel());
    _titleAssistDebounce?.cancel();
    _planAutosaveGate.dispose();
    _tabController?.dispose();
    _planTabController?.dispose();
    _titleController.dispose();
    _quillController.dispose();
    _quillFocusNode.dispose();
    _quillScrollController.dispose();
    _rruleCustomController.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    _flushDirtyPlanDraftForLifecycle();
  }

  void _flushDirtyPlanDraftForLifecycle() {
    if (!_isPersistedPlan || !_planAutosaveGate.isDirty) return;
    if (DatabaseService.instance.planningTaskIsRecurringForScope(
          _baselineTask,
        ) &&
        _recurrenceEditScopeChosen == null) {
      // Recurring edits still require the explicit scope decision; never guess
      // while the app is being backgrounded.
      return;
    }
    _planAutosaveGate.flush(() {
      final latest = _buildDraftTask();
      if (latest == null) return;
      _applyPlanDraftLocally(latest);
      unawaited(_syncPlanDraftToNetwork(latest));
    });
  }

  void _applyFuzzyCategoryFromTitle(String title) {
    final fuzzy = DatabaseService.instance.findCategoryByFuzzyMatch(title);
    if (fuzzy != null && fuzzy.id != _categoryId && mounted) {
      setState(() => _categoryId = fuzzy.id);
      _onPlanFieldChanged(immediate: true);
    }
  }

  void _onTitleChanged(String raw) {
    // Title input owns title/category only. A time selected on the Time View
    // grid may change only through an explicit time control. Debounce fuzzy
    // category matching so typing does not scan the category tree per key.
    _titleAssistDebounce?.cancel();
    _titleAssistDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _applyFuzzyCategoryFromTitle(
        raw.trim().isEmpty ? _titleController.text : raw,
      );
    });
    _onPlanFieldChanged();
  }

  Future<void> _openTagManagerAndReload() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => TagSettingsHub(
          tagCreateDomain: _startedAsUndatedBacklog ? 'list' : 'plan',
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _tagsLoading = true);
    final list = await DatabaseService.instance.fetchTagsForCurrentUser(
      scope: _startedAsUndatedBacklog
          ? TagCatalogScope.list
          : TagCatalogScope.plan,
    );
    if (!mounted) return;
    setState(() {
      _availableTags = list;
      _tagsLoading = false;
    });
  }

  void _toggleTag(Tag t) {
    setState(() {
      final next = List<Tag>.from(_selectedTags);
      final i = next.indexWhere((x) => x.tagId == t.tagId);
      if (i >= 0) {
        next.removeAt(i);
      } else {
        next.add(t);
      }
      _selectedTags = next;
    });
    _onPlanFieldChanged(immediate: true);
  }

  void _applyPlanDraftLocally(PlanningTask draft) {
    if (!_isPersistedPlan) return;
    DatabaseService.instance.applyOptimisticPlanningTask(draft);
    DatabaseService.instance.notifyPlanningRefresh();
  }

  Future<void> _syncPlanDraftToNetwork(PlanningTask draft) async {
    if (!_isPersistedPlan) return;
    if (DatabaseService.instance.planningTaskIsRecurringForScope(
      _baselineTask,
    )) {
      if (_recurrenceEditScopeChosen == null) {
        if (_recurrenceScopePromptOpen || !mounted) return;
        _recurrenceScopePromptOpen = true;
        final scope = await showRecurrenceScopeDialog(
          context,
          task: _baselineTask,
          isDelete: false,
        );
        _recurrenceScopePromptOpen = false;
        if (!mounted) return;
        if (scope == null) {
          _planAutosaveGate.markClean();
          return;
        }
        _recurrenceEditScopeChosen = scope;
      }
    }
    final baseline = _baselineTask;
    final anchorShort = DatabaseService.instance.planningAuditAnchorDateKey(
      baseline,
    );
    const minKeyLen = 10;
    final persistInitial = anchorShort.length >= minKeyLen
        ? anchorShort
        : DatabaseService.instance.planningWallScheduleDateKey(baseline);
    final newSk = DatabaseService.instance.planningWallScheduleDateKey(draft);
    final initForPatch = persistInitial.length >= minKeyLen
        ? persistInitial
        : (newSk.length >= minKeyLen ? newSk : '');
    final postponed =
        !draft.isDone &&
        initForPatch.length >= minKeyLen &&
        DatabaseService.instance.planningShouldMarkPostponed(
          anchorKey: initForPatch,
          newScheduleKey: newSk.length >= minKeyLen ? newSk : initForPatch,
        );
    await DatabaseService.instance.updatePlanningTaskWithRecurrenceScope(
      draft.planRowIdForBackend,
      scope: _recurrenceEditScopeChosen ?? RecurrenceEditScope.singleOccurrence,
      planBusinessId: draft.planRowId,
      title: draft.title,
      categoryId: draft.categoryId,
      isDone: draft.isDone,
      notesPlain: draft.notesPlain,
      notesDeltaJson: draft.notesDeltaJson,
      checklist: draft.checklist,
      parentPlanId: draft.parentPlanId,
      startTimeDisplay: draft.startTime,
      endDateTimeDisplay: draft.endDateTime,
      clearEnd: draft.endDateTime == null,
      tags: draft.tags,
      suppressAppSnack: true,
      planInitialDateKey: initForPatch.length >= minKeyLen
          ? initForPatch
          : null,
      planIsPostponed: postponed,
      patchPlanAlarmRecurrence: true,
      planRrule: draft.rrule,
      planReminderOffset: draft.reminderOffset,
      planExceptionDates:
          (draft.rrule != null && draft.rrule!.trim().isNotEmpty)
          ? draft.exceptionDates
          : const <String>[],
      recurrenceInstanceDateKey:
          draft.recurrenceInstanceDateKey ?? baseline.recurrenceInstanceDateKey,
    );
    _planAutosaveGate.markClean();
  }

  void _onPlanFieldChanged({bool immediate = false}) {
    // New drafts are committed once by the shell on explicit Save. Building a
    // Quill/checklist draft on every keypress is wasted work on web.
    if (!_isPersistedPlan) return;

    void applyAndSync(PlanningTask draft) {
      _applyPlanDraftLocally(draft);
      unawaited(_syncPlanDraftToNetwork(draft));
    }

    if (immediate) {
      final draft = _buildDraftTask();
      if (draft == null) return;
      _planAutosaveGate.markDirty();
      _planAutosaveGate.flush(() => applyAndSync(draft));
      return;
    }

    // Text/notes/checklist typing updates the visible field immediately, but
    // coalesces the expensive global optimistic merge + Planning refresh.
    _planAutosaveGate.schedule(() {
      final latest = _buildDraftTask();
      if (latest != null) {
        applyAndSync(latest);
      }
    });
  }

  bool _planDraftsSemanticallyEqual(PlanningTask a, PlanningTask b) {
    return a.title == b.title &&
        a.categoryId == b.categoryId &&
        a.dateKey == b.dateKey &&
        a.startTime == b.startTime &&
        a.endDateTime == b.endDateTime &&
        a.notesPlain == b.notesPlain &&
        a.notesDeltaJson == b.notesDeltaJson &&
        jsonEncode(a.checklist) == jsonEncode(b.checklist) &&
        jsonEncode(a.tags.map((t) => t.tagId).toList()) ==
            jsonEncode(b.tags.map((t) => t.tagId).toList()) &&
        a.rrule == b.rrule &&
        a.reminderOffset == b.reminderOffset;
  }

  /// Optional URL line prefix in [notesPlain] for backlog ideas (no separate PB field).
  static const String _kLifeOsLinkPrefix = 'LIFEOS_LINK::';

  ({String link, String body}) _parseStoredNotesForLink(String? raw) {
    final s = raw?.trim() ?? '';
    if (!s.startsWith(_kLifeOsLinkPrefix)) {
      return (link: '', body: s);
    }
    final rest = s.substring(_kLifeOsLinkPrefix.length);
    final nl = rest.indexOf('\n');
    if (nl < 0) {
      return (link: rest.trim(), body: '');
    }
    return (
      link: rest.substring(0, nl).trim(),
      body: rest.substring(nl + 1).trimRight(),
    );
  }

  /// Builds initial Quill [Document] from stored delta or legacy plain-only [legacyPlainBody].
  /// [legacyUrl] migrates old `LIFEOS_LINK::` first line into an inline Quill link op.
  Document _documentForPlanningNotes(
    String legacyPlainBody, {
    String? legacyUrl,
  }) {
    final deltaRaw = widget.task.notesDeltaJson?.trim() ?? '';
    if (deltaRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(deltaRaw);
        if (decoded is List) {
          return Document.fromJson(decoded);
        }
      } catch (_) {}
    }
    final url = legacyUrl?.trim() ?? '';
    final b = legacyPlainBody.trim();
    if (url.isNotEmpty) {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': url,
          'attributes': LinkAttribute(url).toJson(),
        },
        <String, dynamic>{'insert': '\n'},
      ];
      if (b.isNotEmpty) {
        ops.add(<String, dynamic>{'insert': '$b\n'});
      }
      return Document.fromJson(ops);
    }
    if (b.isNotEmpty) {
      return Document.fromJson([
        <String, dynamic>{'insert': '$b\n'},
      ]);
    }
    return Document();
  }

  bool _isTrivialEmptyNotes(String deltaJson, String plainTrimmed) {
    if (plainTrimmed.isNotEmpty) return false;
    try {
      final d = jsonDecode(deltaJson);
      if (d is! List) return true;
      if (d.isEmpty) return true;
      if (d.length == 1 && d[0] is Map) {
        final m = Map<String, dynamic>.from(d[0] as Map);
        if (m['insert'] == '\n' && m['attributes'] == null) return true;
      }
    } catch (_) {}
    return false;
  }

  String _dateKeyFromDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _shortMonth(int month) =>
      month >= 1 && month <= 12 ? kShortMonths[month - 1] : '';

  void _commitSave() {
    final updated = _buildDraftTask();
    if (updated == null) {
      AppSnack.warning(t(currentLocale.value, 'edit_save_title_required'));
      return;
    }
    // Explicit Save owns this draft snapshot (incl. newly created category).
    // Do not rebuild inside flush — autosave must not race with an older snapshot.
    _applyPlanDraftLocally(updated);
    if (_isPersistedPlan) {
      _planAutosaveGate.flush(() {
        unawaited(_syncPlanDraftToNetwork(updated));
      }, force: true);
    }
    AppSnack.changesSaved();
    if (widget.onSaved != null) {
      widget.onSaved!(updated);
    } else {
      Navigator.of(context).pop<PlanningTask?>(updated);
    }
  }

  PlanningTask? _buildDraftTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return null;
    final catId = resolvePlanningEditDraftCategoryId(
      draftCategoryId: _categoryId,
      originalTaskCategoryId: widget.task.categoryId,
      existsInTree: DatabaseService.instance.categoryExists(_categoryId),
      knownPairIds: DatabaseService.instance.allCategoryIdPathPairs.map(
        (p) => p.id,
      ),
    );
    final newDateKey = _dateKeyFromDate(_date);
    syncChecklistDoneLength(_checklistControllers, _checklistDone);
    final List<Map<String, dynamic>> checklist = [];
    for (var i = 0; i < _checklistControllers.length; i++) {
      final text = _checklistControllers[i].text.trim();
      if (text.isEmpty) continue;
      checklist.add(<String, dynamic>{
        'text': text,
        'isDone': i < _checklistDone.length ? _checklistDone[i] : false,
      });
    }
    if (_repeatUi == PlanRepeatUi.custom) {
      _rruleCustomRaw = _rruleCustomController.text.trim();
    }
    final rruleWire = rruleWireFromRepeatUi(_repeatUi, _rruleCustomRaw);
    final clearR = rruleWire == null;
    final deltaJson = jsonEncode(_quillController.document.toDelta().toJson());
    final plainTrimmed = _quillController.document
        .toPlainText()
        .replaceAll('\u200b', '')
        .trim();
    String? notesPlainOut;
    String? notesDeltaJsonOut;
    if (_startedAsUndatedBacklog) {
      notesPlainOut = plainTrimmed.isEmpty ? null : plainTrimmed;
      notesDeltaJsonOut = deltaJson;
    } else {
      notesPlainOut = plainTrimmed.isEmpty ? null : plainTrimmed;
      notesDeltaJsonOut = deltaJson;
    }
    final shouldClear =
        notesPlainOut == null && _isTrivialEmptyNotes(deltaJson, plainTrimmed);
    return shouldClear
        ? widget.task.copyWith(
            title: title,
            categoryId: catId,
            startTime: _scheduledTime,
            date: _date,
            dateKey: newDateKey,
            endDateTime: _endTime != null
                ? DateTime(
                    _date.year,
                    _date.month,
                    _date.day,
                    _endTime!.hour,
                    _endTime!.minute,
                  )
                : null,
            endDateKey: _endTime != null ? newDateKey : null,
            checklist: checklist,
            clearNotes: true,
            tags: List<Tag>.from(_selectedTags),
            rrule: rruleWire,
            clearRrule: clearR,
            exceptionDates: clearR
                ? const <String>[]
                : List<String>.from(widget.task.exceptionDates),
            reminderOffset: _reminderMinutes,
            clearReminderOffset: _reminderMinutes == null,
          )
        : widget.task.copyWith(
            title: title,
            categoryId: catId,
            startTime: _scheduledTime,
            date: _date,
            dateKey: newDateKey,
            endDateTime: _endTime != null
                ? DateTime(
                    _date.year,
                    _date.month,
                    _date.day,
                    _endTime!.hour,
                    _endTime!.minute,
                  )
                : null,
            endDateKey: _endTime != null ? newDateKey : null,
            checklist: checklist,
            notesPlain: notesPlainOut,
            notesDeltaJson: notesDeltaJsonOut,
            tags: List<Tag>.from(_selectedTags),
            rrule: rruleWire,
            clearRrule: clearR,
            exceptionDates: clearR
                ? const <String>[]
                : List<String>.from(widget.task.exceptionDates),
            reminderOffset: _reminderMinutes,
            clearReminderOffset: _reminderMinutes == null,
          );
  }

  @override
  Widget build(BuildContext context) {
    final dropdownValue = resolveEditFieldCategoryId(
      db: DatabaseService.instance,
      categoryId: _categoryId,
    );
    final kbBottom = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = kbBottom > 0;
    final compactChrome = keyboardOpen;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              compactChrome ? 6 : 12,
              16,
              compactChrome ? 4 : 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _titleController,
                    autofocus: _startedAsUndatedBacklog,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    minLines: 1,
                    maxLines: compactChrome ? 2 : 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: t(currentLocale.value, 'title_label'),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _onTitleChanged,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () =>
                      Navigator.of(context).pop<PlanningTask?>(null),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              compactChrome ? 4 : 8,
              16,
              compactChrome ? 2 : 4,
            ),
            child: CategoryTreeFormField(
              value: dropdownValue,
              decoration: InputDecoration(
                labelText: t(currentLocale.value, 'category_label'),
              ),
              onChanged: (id) {
                setState(() => _categoryId = id ?? _categoryId);
                _onPlanFieldChanged(immediate: true);
              },
            ),
          ),
          Expanded(
            child: Column(
              children: [
                if (_startedAsUndatedBacklog) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: kAppCompactControlHeight,
                      child: TabBar(
                        controller: _tabController!,
                        isScrollable: true,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.zero,
                        tabs: [
                          AppCompactTextTab(
                            text: t(currentLocale.value, 'notes_tab'),
                          ),
                          AppCompactTextTab(
                            text: t(currentLocale.value, 'checklist_tab'),
                          ),
                          AppCompactTextTab(
                            text: t(currentLocale.value, 'lists_subitems_tab'),
                          ),
                          AppCompactTextTab(
                            text: t(
                              currentLocale.value,
                              'plan_idea_tab_schedule',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController!,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            compactChrome ? 4 : 8,
                            16,
                            compactChrome ? 12 : 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: kPlanningEditQuillToolbarMinHeight,
                                ),
                                child: QuillSimpleToolbar(
                                  controller: _quillController,
                                  config: planningTaskEditQuillToolbarConfig(
                                    context,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: QuillEditor.basic(
                                    controller: _quillController,
                                    focusNode: _quillFocusNode,
                                    scrollController: _quillScrollController,
                                    config: QuillEditorConfig(
                                      expands: true,
                                      padding: const EdgeInsets.all(12),
                                      placeholder: t(
                                        currentLocale.value,
                                        'notes_hint_flat',
                                      ),
                                      onLaunchUrl: launchUrlFromQuillEditor,
                                      customStyles: DefaultStyles.getInstance(
                                        context,
                                      ),
                                      keyboardAppearance:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Brightness.dark
                                          : Brightness.light,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            compactChrome ? 8 : 12,
                            16,
                            compactChrome ? 12 : 24,
                          ),
                          children: [
                            ...List.generate(_checklistControllers.length, (i) {
                              final scheme = Theme.of(context).colorScheme;
                              final rowDone =
                                  i < _checklistDone.length &&
                                  _checklistDone[i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                horizontalTitleGap: 4,
                                leading: Checkbox(
                                  value: rowDone,
                                  onChanged: (v) {
                                    setState(() {
                                      syncChecklistDoneLength(
                                        _checklistControllers,
                                        _checklistDone,
                                      );
                                      _checklistDone[i] = v ?? false;
                                      partitionChecklistRowsByDone(
                                        controllers: _checklistControllers,
                                        done: _checklistDone,
                                      );
                                    });
                                    _onPlanFieldChanged(immediate: true);
                                  },
                                ),
                                title: TextField(
                                  controller: _checklistControllers[i],
                                  onChanged: (_) => _onPlanFieldChanged(),
                                  style: TextStyle(
                                    decoration: rowDone
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    color: rowDone
                                        ? scheme.onSurface.withValues(
                                            alpha: 0.5,
                                          )
                                        : scheme.onSurface,
                                    decorationColor: rowDone
                                        ? scheme.onSurface.withValues(
                                            alpha: 0.5,
                                          )
                                        : null,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: t(
                                      currentLocale.value,
                                      'checklist_item',
                                    ),
                                    hintStyle: TextStyle(
                                      color: scheme.onSurfaceVariant.withValues(
                                        alpha: rowDone ? 0.35 : 0.5,
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    filled: true,
                                    fillColor: scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: scheme.error,
                                  ),
                                  tooltip: t(currentLocale.value, 'delete'),
                                  onPressed: () {
                                    setState(() {
                                      removeChecklistRowAt(
                                        i,
                                        controllers: _checklistControllers,
                                        done: _checklistDone,
                                      );
                                    });
                                    _onPlanFieldChanged(immediate: true);
                                  },
                                ),
                              );
                            }),
                            ListTile(
                              leading: Icon(
                                Icons.add_circle_outline_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                t(currentLocale.value, 'add_checklist_item'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _checklistControllers.add(
                                    TextEditingController(),
                                  );
                                  _checklistDone.add(false);
                                });
                                _onPlanFieldChanged();
                              },
                            ),
                          ],
                        ),
                        BacklogSubItemsPanel(
                          parentTask: widget.task,
                          categoryId: _categoryId,
                        ),
                        ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            compactChrome ? 8 : 12,
                            16,
                            compactChrome ? 12 : 24,
                          ),
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _scheduledTime == null
                                    ? t(currentLocale.value, 'scheduled')
                                    : '${_date.day} ${_shortMonth(_date.month)} ${_date.year}, ${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                              ),
                              trailing: const Icon(Icons.schedule_rounded),
                              onTap: () async {
                                final initial = DateTime(
                                  _date.year,
                                  _date.month,
                                  _date.day,
                                  _scheduledTime?.hour ?? 9,
                                  _scheduledTime?.minute ?? 0,
                                );
                                final picked = await showAppDateTimePicker(
                                  context,
                                  initial: initial,
                                );
                                if (picked != null && mounted) {
                                  setState(() {
                                    _date = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                    );
                                    _scheduledTime = picked;
                                  });
                                  _onPlanFieldChanged(immediate: true);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _endTime == null
                                    ? t(currentLocale.value, 'no_end_time')
                                    : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
                              ),
                              trailing: const Icon(Icons.schedule_rounded),
                              onTap: () async {
                                final initial = DateTime(
                                  _date.year,
                                  _date.month,
                                  _date.day,
                                  _endTime?.hour ?? 10,
                                  _endTime?.minute ?? 0,
                                );
                                final picked = await showAppDateTimePicker(
                                  context,
                                  initial: initial,
                                );
                                if (picked != null && mounted) {
                                  setState(
                                    () => _endTime = DateTime(
                                      _date.year,
                                      _date.month,
                                      _date.day,
                                      picked.hour,
                                      picked.minute,
                                    ),
                                  );
                                  _onPlanFieldChanged(immediate: true);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int?>(
                              initialValue: _reminderMinutes,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: t(
                                  currentLocale.value,
                                  'plan_reminder_label',
                                ),
                              ),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    t(
                                      currentLocale.value,
                                      'plan_reminder_none',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 5,
                                  child: Text(
                                    t(currentLocale.value, 'plan_reminder_5m'),
                                  ),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 15,
                                  child: Text(
                                    t(currentLocale.value, 'plan_reminder_15m'),
                                  ),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 30,
                                  child: Text(
                                    t(currentLocale.value, 'plan_reminder_30m'),
                                  ),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 60,
                                  child: Text(
                                    t(currentLocale.value, 'plan_reminder_1h'),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => _reminderMinutes = v);
                                _onPlanFieldChanged(immediate: true);
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<PlanRepeatUi>(
                              initialValue: _repeatUi,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: t(
                                  currentLocale.value,
                                  'plan_repeat_label',
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: PlanRepeatUi.none,
                                  child: Text(
                                    t(currentLocale.value, 'plan_repeat_none'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: PlanRepeatUi.daily,
                                  child: Text(
                                    t(currentLocale.value, 'plan_repeat_daily'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: PlanRepeatUi.weekdays,
                                  child: Text(
                                    t(
                                      currentLocale.value,
                                      'plan_repeat_weekdays',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: PlanRepeatUi.weekly,
                                  child: Text(
                                    t(
                                      currentLocale.value,
                                      'plan_repeat_weekly',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: PlanRepeatUi.monthly,
                                  child: Text(
                                    t(
                                      currentLocale.value,
                                      'plan_repeat_monthly',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: PlanRepeatUi.yearly,
                                  child: Text(
                                    t(
                                      currentLocale.value,
                                      'plan_repeat_yearly',
                                    ),
                                  ),
                                ),
                                if (_repeatUi == PlanRepeatUi.custom)
                                  DropdownMenuItem(
                                    value: PlanRepeatUi.custom,
                                    child: Text(
                                      t(
                                        currentLocale.value,
                                        'plan_repeat_custom',
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _repeatUi = v;
                                  if (v != PlanRepeatUi.custom) {
                                    _rruleCustomRaw = null;
                                    _rruleCustomController.clear();
                                  } else {
                                    _rruleCustomRaw = widget.task.rrule?.trim();
                                    _rruleCustomController.text =
                                        _rruleCustomRaw ?? '';
                                  }
                                });
                                _onPlanFieldChanged(immediate: true);
                              },
                            ),
                            if (_repeatUi == PlanRepeatUi.custom) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _rruleCustomController,
                                minLines: 2,
                                maxLines: 5,
                                onChanged: (_) => _onPlanFieldChanged(),
                                decoration: InputDecoration(
                                  labelText: t(
                                    currentLocale.value,
                                    'plan_repeat_custom',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppEditSheetTimeButton(
                                  icon: Icons.calendar_month_rounded,
                                  label: t(
                                    currentLocale.value,
                                    'plan_start_time_full',
                                  ),
                                  value: _scheduledTime == null
                                      ? t(currentLocale.value, 'scheduled')
                                      : '${_date.day} ${_shortMonth(_date.month)} ${_date.year}, ${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                                  onPressed: () async {
                                    final initial = DateTime(
                                      _date.year,
                                      _date.month,
                                      _date.day,
                                      _scheduledTime?.hour ?? 9,
                                      _scheduledTime?.minute ?? 0,
                                    );
                                    final picked = await showAppDateTimePicker(
                                      context,
                                      initial: initial,
                                    );
                                    if (picked != null && mounted) {
                                      setState(() {
                                        _date = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                        );
                                        _scheduledTime = picked;
                                      });
                                      _onPlanFieldChanged(immediate: true);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppEditSheetTimeButton(
                                  icon: Icons.event_available_rounded,
                                  label: t(
                                    currentLocale.value,
                                    'plan_end_time_full',
                                  ),
                                  value: _endTime == null
                                      ? t(currentLocale.value, 'no_end_time')
                                      : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
                                  onPressed: () async {
                                    final initial = DateTime(
                                      _date.year,
                                      _date.month,
                                      _date.day,
                                      _endTime?.hour ?? 10,
                                      _endTime?.minute ?? 0,
                                    );
                                    final picked = await showAppDateTimePicker(
                                      context,
                                      initial: initial,
                                    );
                                    if (picked != null && mounted) {
                                      setState(
                                        () => _endTime = DateTime(
                                          _date.year,
                                          _date.month,
                                          _date.day,
                                          picked.hour,
                                          picked.minute,
                                        ),
                                      );
                                      _onPlanFieldChanged(immediate: true);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: SizedBox(
                            height: 40,
                            child: _tagsLoading
                                ? Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : _availableTags.isEmpty
                                ? Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: OutlinedButton.icon(
                                      onPressed: _openTagManagerAndReload,
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 20,
                                      ),
                                      label: Text(
                                        t(
                                          currentLocale.value,
                                          'tags_empty_create_first',
                                        ),
                                      ),
                                    ),
                                  )
                                : TagQuickPickStrip(
                                    tags: _availableTags,
                                    selected: _selectedTags,
                                    onToggle: _toggleTag,
                                    variant: CategoryChipVariant.largePicker,
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            height: kAppCompactControlHeight,
                            child: TabBar(
                              controller: _planTabController!,
                              isScrollable: true,
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              tabAlignment: TabAlignment.start,
                              padding: EdgeInsets.zero,
                              tabs: [
                                AppCompactTextTab(
                                  text: t(currentLocale.value, 'notes_tab'),
                                ),
                                AppCompactTextTab(
                                  text: t(currentLocale.value, 'checklist_tab'),
                                ),
                                AppCompactTextTab(
                                  text: t(
                                    currentLocale.value,
                                    'plan_repeat_label',
                                  ),
                                ),
                                AppCompactTextTab(
                                  text: t(
                                    currentLocale.value,
                                    'plan_parallel_plans_tab',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _planTabController!,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  compactChrome ? 4 : 8,
                                  16,
                                  compactChrome ? 12 : 24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight:
                                            kPlanningEditQuillToolbarMinHeight,
                                      ),
                                      child: QuillSimpleToolbar(
                                        controller: _quillController,
                                        config:
                                            planningTaskEditQuillToolbarConfig(
                                              context,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: QuillEditor.basic(
                                          controller: _quillController,
                                          focusNode: _quillFocusNode,
                                          scrollController:
                                              _quillScrollController,
                                          config: QuillEditorConfig(
                                            expands: true,
                                            padding: const EdgeInsets.all(12),
                                            placeholder: t(
                                              currentLocale.value,
                                              'notes_hint_flat',
                                            ),
                                            onLaunchUrl:
                                                launchUrlFromQuillEditor,
                                            customStyles:
                                                DefaultStyles.getInstance(
                                                  context,
                                                ),
                                            keyboardAppearance:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Brightness.dark
                                                : Brightness.light,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  24,
                                ),
                                children: [
                                  ...List.generate(
                                    _checklistControllers.length,
                                    (i) {
                                      final scheme = Theme.of(
                                        context,
                                      ).colorScheme;
                                      final rowDone =
                                          i < _checklistDone.length &&
                                          _checklistDone[i];
                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                        horizontalTitleGap: 4,
                                        leading: Checkbox(
                                          value: rowDone,
                                          onChanged: (v) => setState(() {
                                            syncChecklistDoneLength(
                                              _checklistControllers,
                                              _checklistDone,
                                            );
                                            _checklistDone[i] = v ?? false;
                                            partitionChecklistRowsByDone(
                                              controllers:
                                                  _checklistControllers,
                                              done: _checklistDone,
                                            );
                                          }),
                                        ),
                                        title: TextField(
                                          controller: _checklistControllers[i],
                                          style: TextStyle(
                                            decoration: rowDone
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                            color: rowDone
                                                ? scheme.onSurface.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : scheme.onSurface,
                                            decorationColor: rowDone
                                                ? scheme.onSurface.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : null,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: t(
                                              currentLocale.value,
                                              'checklist_item',
                                            ),
                                            hintStyle: TextStyle(
                                              color: scheme.onSurfaceVariant
                                                  .withValues(
                                                    alpha: rowDone ? 0.35 : 0.5,
                                                  ),
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            filled: true,
                                            fillColor: scheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.35),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: scheme.error,
                                          ),
                                          tooltip: t(
                                            currentLocale.value,
                                            'delete',
                                          ),
                                          onPressed: () => setState(() {
                                            removeChecklistRowAt(
                                              i,
                                              controllers:
                                                  _checklistControllers,
                                              done: _checklistDone,
                                            );
                                          }),
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    title: Text(
                                      t(
                                        currentLocale.value,
                                        'add_checklist_item',
                                      ),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onTap: () => setState(() {
                                      _checklistControllers.add(
                                        TextEditingController(),
                                      );
                                      _checklistDone.add(false);
                                    }),
                                  ),
                                ],
                              ),
                              ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  24,
                                ),
                                children: [
                                  DropdownButtonFormField<int?>(
                                    initialValue: _reminderMinutes,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: t(
                                        currentLocale.value,
                                        'plan_reminder_label',
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_reminder_none',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem<int?>(
                                        value: 5,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_reminder_5m',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem<int?>(
                                        value: 15,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_reminder_15m',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem<int?>(
                                        value: 30,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_reminder_30m',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem<int?>(
                                        value: 60,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_reminder_1h',
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      setState(() => _reminderMinutes = v);
                                      _onPlanFieldChanged(immediate: true);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<PlanRepeatUi>(
                                    initialValue: _repeatUi,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: t(
                                        currentLocale.value,
                                        'plan_repeat_label',
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: PlanRepeatUi.none,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_none',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: PlanRepeatUi.daily,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_daily',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: PlanRepeatUi.weekdays,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_weekdays',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: PlanRepeatUi.weekly,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_weekly',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: PlanRepeatUi.monthly,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_monthly',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: PlanRepeatUi.yearly,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_yearly',
                                          ),
                                        ),
                                      ),
                                      if (_repeatUi == PlanRepeatUi.custom)
                                        DropdownMenuItem(
                                          value: PlanRepeatUi.custom,
                                          child: Text(
                                            t(
                                              currentLocale.value,
                                              'plan_repeat_custom',
                                            ),
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _repeatUi = v;
                                        if (v != PlanRepeatUi.custom) {
                                          _rruleCustomRaw = null;
                                          _rruleCustomController.clear();
                                        } else {
                                          _rruleCustomRaw = widget.task.rrule
                                              ?.trim();
                                          _rruleCustomController.text =
                                              _rruleCustomRaw ?? '';
                                        }
                                      });
                                      _onPlanFieldChanged(immediate: true);
                                    },
                                  ),
                                  if (_repeatUi == PlanRepeatUi.custom) ...[
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _rruleCustomController,
                                      minLines: 2,
                                      maxLines: 5,
                                      onChanged: (_) => _onPlanFieldChanged(),
                                      decoration: InputDecoration(
                                        labelText: t(
                                          currentLocale.value,
                                          'plan_repeat_custom',
                                        ),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              BacklogSubItemsPanel(
                                parentTask: widget.task,
                                categoryId: _categoryId,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_shouldShowGraduateUi)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      keyboardOpen ? 4 : 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t(currentLocale.value, 'plan_graduate_warning'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    kPlanningEditActionBarPadH,
                    keyboardOpen
                        ? kPlanningEditActionBarPadVKeyboard
                        : kPlanningEditActionBarPadV,
                    kPlanningEditActionBarPadH,
                    keyboardOpen
                        ? kPlanningEditActionBarBottomPadKeyboard
                        : kPlanningEditActionBarBottomPad,
                  ),
                  child: Row(
                    children: [
                      if (widget.onDelete != null)
                        TextButton(
                          onPressed: () {
                            widget.onDelete!(widget.task);
                            Navigator.of(context).pop<PlanningTask?>(null);
                          },
                          child: Text(
                            t(currentLocale.value, 'delete'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop<PlanningTask?>(null),
                        child: Text(t(currentLocale.value, 'cancel')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _commitSave,
                        child: Text(
                          t(
                            currentLocale.value,
                            _shouldShowGraduateUi
                                ? 'plan_graduate_from_idea'
                                : 'save',
                          ),
                        ),
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
