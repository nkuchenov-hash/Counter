import 'dart:async';
import 'dart:convert';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/omni_date_time_picker_dialog.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/features/categories/create_category_from_picker.dart';
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

import 'package:counter/features/shared/edit_sheet/checklist_helpers.dart';
import 'package:counter/features/shared/edit_sheet/parallel_record_panels.dart';
import 'package:counter/features/shared/edit_sheet/quill_link_launcher.dart';
import 'package:counter/features/shared/edit_sheet/quill_toolbar_config.dart';
import 'package:counter/features/shared/edit_sheet/record_edit_save_policy.dart';
import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';
import 'package:counter/features/shared/edit_sheet/sheet_time_helpers.dart';
import 'package:counter/features/shared/edit_sheet/sheet_time_picker.dart';

class TimelineRecordSheetContent extends StatefulWidget {
  const TimelineRecordSheetContent({
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
  State<TimelineRecordSheetContent> createState() =>
      TimelineRecordSheetContentState();
}

class TimelineRecordSheetContentState
    extends State<TimelineRecordSheetContent>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late QuillController _recordQuillController;
  late FocusNode _recordQuillFocus;
  late ScrollController _recordQuillScroll;
  int? _categoryId;
  DateTime? _startDisplay;
  DateTime? _endDisplay;
  final List<TextEditingController> _checklistControllers = [];
  final List<bool> _checklistDone = [];
  late TabController _tabController;

  /// PocketBase **plans** row id; empty = no link.
  late String _sourcePlanPbId;
  List<PlanningTask> _plansForLink = [];
  bool _plansLoading = true;
  final EditSheetAutosaveGate _recordAutosaveGate = EditSheetAutosaveGate();
  StreamSubscription<DocChange>? _recordQuillChangesSub;

  /// True when Save/autosave can PATCH an existing/optimistic row (not past-date create).
  /// Prefer [record.id]; fall back to business `record_id` when fromMap dropped a UUID id.
  bool get _isPersistedRecord => recordEditHasUpdatableRecordKey(
        systemOrOptimisticId: widget.record.id,
        businessRecordId: widget.record.recordId,
      );

  /// Prefer REST system / optimistic id; UUID `record_id` keeps updates working when id was filtered.
  String get _recordUpdateKey {
    final id = widget.record.id.trim();
    if (id.isNotEmpty) return id;
    return (widget.record.recordId ?? '').trim();
  }

  List<Map<String, dynamic>> _checklistForApi() {
    syncChecklistDoneLength(_checklistControllers, _checklistDone);
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

  void _applyFuzzyCategoryFromRecordTitle(String title) {
    final fuzzy = DatabaseService.instance.findCategoryByFuzzyMatch(title);
    if (fuzzy != null && fuzzy.id != _categoryId && mounted) {
      setState(() => _categoryId = fuzzy.id);
      _onRecordFieldChanged(immediate: true);
    }
  }

  TimelineRecord _buildOptimisticRecord({
    required String title,
    required String noteText,
    required List<Map<String, dynamic>> checklistPayload,
    required ({bool sync, bool clear, String? id}) planPatch,
    DateTime? startUtc,
    DateTime? endUtc,
  }) {
    return widget.record.copyWith(
      title: title,
      startTime: startUtc,
      endTime: endUtc,
      categoryId: _categoryId,
      note: noteText.isEmpty ? null : noteText,
      checklist: checklistPayload.isEmpty ? null : checklistPayload,
      sourcePlanId: planPatch.sync
          ? (planPatch.clear ? null : planPatch.id)
          : widget.record.sourcePlanId,
    );
  }

  void _applyRecordLocalEdit({
    required String title,
    required String noteText,
    required List<Map<String, dynamic>> checklistPayload,
    required ({bool sync, bool clear, String? id}) planPatch,
    DateTime? startUtc,
    DateTime? endUtc,
    int? categoryId,
  }) {
    if (!_isPersistedRecord) return;
    DatabaseService.instance.applyOptimisticRecordRowEdit(
      recordId: _recordUpdateKey,
      title: title,
      startTime: startUtc,
      endTime: endUtc,
      categoryId: categoryId ?? _categoryId,
      note: noteText,
      checklist: checklistPayload,
      syncSourcePlan: planPatch.sync,
      clearSourcePlan: planPatch.clear,
      sourcePlanPocketRecordId: planPatch.id,
    );
  }

  Future<void> _syncRecordToNetwork({
    required String title,
    required String noteText,
    required List<Map<String, dynamic>> checklistPayload,
    required ({bool sync, bool clear, String? id}) planPatch,
    DateTime? startUtc,
    DateTime? endUtc,
    int? categoryId,
  }) async {
    if (!_isPersistedRecord) return;
    await DatabaseService.instance.updateRecord(
      recordId: _recordUpdateKey,
      title: title,
      startTime: startUtc,
      endTime: endUtc,
      categoryId: categoryId ?? _categoryId,
      note: noteText,
      checklist: checklistPayload,
      syncSourcePlan: planPatch.sync,
      clearSourcePlan: planPatch.clear,
      sourcePlanPocketRecordId: planPatch.id,
      bypassConflictCheck: true,
    );
    if (!mounted) return;
    _recordAutosaveGate.markClean();
  }

  void _onRecordFieldChanged({bool immediate = false}) {
    if (!_isPersistedRecord) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final noteText = _recordQuillController.document
        .toPlainText()
        .replaceAll('\u200b', '')
        .trim();
    final checklistPayload = _checklistForApi();
    final planPatch = _sourcePlanPatchArgs();
    final isRunning = widget.record.endTime == null;
    final startUtc = _startDisplay != null ? displayToUtc(_startDisplay!) : null;
    DateTime? endUtc;
    if (!isRunning && _startDisplay != null && _endDisplay != null) {
      endUtc = displayToUtc(_endDisplay!);
    }
    _applyRecordLocalEdit(
      title: title,
      noteText: noteText,
      checklistPayload: checklistPayload,
      planPatch: planPatch,
      startUtc: startUtc,
      endUtc: endUtc,
    );
    _recordAutosaveGate.markDirty();
    void syncLatest() {
      final tTitle = _titleController.text.trim();
      if (tTitle.isEmpty) return;
      final tNote = _recordQuillController.document
          .toPlainText()
          .replaceAll('\u200b', '')
          .trim();
      final tChecklist = _checklistForApi();
      final tPlanPatch = _sourcePlanPatchArgs();
      final tRunning = widget.record.endTime == null;
      final tStartUtc =
          _startDisplay != null ? displayToUtc(_startDisplay!) : null;
      DateTime? tEndUtc;
      if (!tRunning && _startDisplay != null && _endDisplay != null) {
        tEndUtc = displayToUtc(_endDisplay!);
      }
      unawaited(
        _syncRecordToNetwork(
          title: tTitle,
          noteText: tNote,
          checklistPayload: tChecklist,
          planPatch: tPlanPatch,
          startUtc: tStartUtc,
          endUtc: tEndUtc,
        ),
      );
    }
    if (immediate) {
      _recordAutosaveGate.flush(syncLatest);
    } else {
      _recordAutosaveGate.schedule(syncLatest);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _titleController = TextEditingController(text: widget.record.title);
    _recordQuillController = QuillController(
      document: _documentForRecordPlain(widget.record.note),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _recordQuillFocus = FocusNode();
    _recordQuillScroll = ScrollController();
    _categoryId = widget.record.categoryId;
    _startDisplay = widget.record.startTime != null
        ? utcToDisplay(widget.record.startTime!)
        : null;
    _endDisplay = widget.record.endTime != null
        ? utcToDisplay(widget.record.endTime!)
        : null;
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
    partitionChecklistRowsByDone(
      controllers: _checklistControllers,
      done: _checklistDone,
    );
    _sourcePlanPbId =
        DatabaseService.pocketRelationIdOrNull(widget.record.sourcePlanId) ??
        '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPlansForLink());
    });
    _recordQuillChangesSub = _recordQuillController.document.changes.listen((_) {
      if (!mounted) return;
      _onRecordFieldChanged();
    });
  }

  /// Same wall-calendar day as [DatabaseService._profileWallFromUtc] / planning fetch —
  /// never [DateTime.toLocal] on raw UTC (that shifted links to the wrong day vs profile).
  DateTime _wallDayForRecord() {
    if (_startDisplay != null) {
      final d = _startDisplay!;
      return DateTime(d.year, d.month, d.day);
    }
    final st = widget.record.startTime;
    if (st != null) {
      final wall = utcToDisplay(st);
      return DateTime(wall.year, wall.month, wall.day);
    }
    final dk = widget.record.dateKey;
    if (dk.length >= 10) {
      final y = int.tryParse(dk.substring(0, 4));
      final m = int.tryParse(dk.substring(5, 7));
      final d = int.tryParse(dk.substring(8, 10));
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    final now = displayNow();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _loadPlansForLink() async {
    if (mounted) setState(() => _plansLoading = true);
    final list = await DatabaseService.instance.getPlanningTasksForWallDate(
      _wallDayForRecord(),
    );
    if (!mounted) return;
    setState(() {
      _plansForLink = list;
      _plansLoading = false;
    });
  }

  Future<void> _showPlanLinkPickerSheet(
    BuildContext context, {
    required List<MapEntry<String, String>> options,
    required String selectedKey,
  }) async {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final viewInsets = MediaQuery.viewInsetsOf(sheetCtx).bottom;
        final h = (MediaQuery.sizeOf(sheetCtx).height * 0.55).clamp(
          240.0,
          520.0,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets),
          child: SizedBox(
            height: h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    t(loc, 'record_link_plan_label'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 8,
                      bottom: 16,
                    ),
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final o = options[i];
                      return ListTile(
                        title: Text(
                          o.value,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: o.key == selectedKey,
                        onTap: () => Navigator.of(sheetCtx).pop(o.key),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _sourcePlanPbId = picked);
      _onRecordFieldChanged(immediate: true);
    }
  }

  /// Full-screen-width tap target; list opens in a sheet with a real [ListView] (always scrolls).
  Widget _buildPlanLinkDropdown(BuildContext context) {
    final loc = currentLocale.value;
    final options = <MapEntry<String, String>>[
      MapEntry('', t(loc, 'record_no_plan_link')),
    ];
    final seen = <String>{''};
    for (final p in _plansForLink) {
      final pid = DatabaseService.pocketRelationIdOrNull(p.pocketRecordId);
      if (pid == null || seen.contains(pid)) continue;
      seen.add(pid);
      options.add(MapEntry(pid, p.title));
    }
    var value = _sourcePlanPbId;
    if (value.isNotEmpty &&
        !seen.contains(value) &&
        DatabaseService.pocketRelationIdOrNull(value) != null) {
      final v = DatabaseService.pocketRelationIdOrNull(value)!;
      options.insert(1, MapEntry(v, '—'));
      seen.add(v);
      value = v;
    }
    if (value.isNotEmpty && !seen.contains(value)) {
      value = '';
    }
    final desired = value.isEmpty ? '' : value;
    final initial = options.any((e) => e.key == desired) ? desired : '';
    var displayLabel = t(loc, 'record_no_plan_link');
    for (final o in options) {
      if (o.key == initial) {
        displayLabel = o.value;
        break;
      }
    }
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        labelText: t(loc, 'record_link_plan_label'),
        helperText: _plansLoading ? t(loc, 'record_link_plan_loading') : null,
        suffixIcon: Icon(
          Icons.arrow_drop_down_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      child: InkWell(
        onTap: _plansLoading
            ? null
            : () => unawaited(
                _showPlanLinkPickerSheet(
                  context,
                  options: options,
                  selectedKey: initial,
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({bool sync, bool clear, String? id}) _sourcePlanPatchArgs() {
    final initial =
        DatabaseService.pocketRelationIdOrNull(widget.record.sourcePlanId) ??
        '';
    final sel = _sourcePlanPbId.isEmpty
        ? ''
        : (DatabaseService.pocketRelationIdOrNull(_sourcePlanPbId) ?? '');
    if (initial == sel) {
      return (sync: false, clear: false, id: null);
    }
    if (sel.isEmpty) {
      return (sync: true, clear: true, id: null);
    }
    return (sync: true, clear: false, id: sel);
  }

  Document _documentForRecordPlain(String? plain) {
    final b = plain?.trim() ?? '';
    if (b.isEmpty) return Document();
    return Document.fromJson([
      <String, dynamic>{'insert': '$b\n'},
    ]);
  }

  @override
  void dispose() {
    if (_isPersistedRecord) {
      _recordAutosaveGate.flush(
        () {
          final title = _titleController.text.trim();
          if (title.isEmpty) return;
          final noteText = _recordQuillController.document
              .toPlainText()
              .replaceAll('\u200b', '')
              .trim();
          final checklistPayload = _checklistForApi();
          final planPatch = _sourcePlanPatchArgs();
          final isRunning = widget.record.endTime == null;
          final startUtc =
              _startDisplay != null ? displayToUtc(_startDisplay!) : null;
          DateTime? endUtc;
          if (!isRunning && _startDisplay != null && _endDisplay != null) {
            endUtc = displayToUtc(_endDisplay!);
          }
          unawaited(
            _syncRecordToNetwork(
              title: title,
              noteText: noteText,
              checklistPayload: checklistPayload,
              planPatch: planPatch,
              startUtc: startUtc,
              endUtc: endUtc,
            ),
          );
        },
        force: _recordAutosaveGate.isDirty,
      );
    }
    unawaited(_recordQuillChangesSub?.cancel());
    _recordAutosaveGate.dispose();
    _tabController.dispose();
    _titleController.dispose();
    _recordQuillController.dispose();
    _recordQuillFocus.dispose();
    _recordQuillScroll.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStart() async {
    final initial = _startDisplay ?? displayNow();
    final picked = await showAppDateTimePicker(context, initial: initial);
    if (picked != null && mounted) {
      setState(() => _startDisplay = picked);
      unawaited(_loadPlansForLink());
      _onRecordFieldChanged(immediate: true);
    }
  }

  Future<void> _pickEnd() async {
    final initial = _endDisplay ?? displayNow();
    final picked = await showAppDateTimePicker(context, initial: initial);
    if (picked != null && mounted) {
      setState(() => _endDisplay = picked);
      _onRecordFieldChanged(immediate: true);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final noteText = _recordQuillController.document
        .toPlainText()
        .replaceAll('\u200b', '')
        .trim();
    final checklistPayload = _checklistForApi();
    final planPatch = _sourcePlanPatchArgs();

    final validation = validateRecordEditSave(
      title: title,
      hasUpdatableRecordKey: _isPersistedRecord,
      recordEndTimeIsNull: widget.record.endTime == null,
      recordStatus: widget.record.status,
      draftStartDisplay: _startDisplay,
      draftEndDisplay: _endDisplay,
      displayToUtc: displayToUtc,
    );
    if (!validation.isOk) {
      AppSnack.warning(t(currentLocale.value, validation.errorKey!));
      return;
    }

    final mode = validation.mode!;

    // CREATE path (past-date "New Record" entry): no existing row key.
    if (mode == RecordEditSaveMode.createCompletedInterval) {
      final startUtc = validation.startUtc!;
      final endUtc = validation.endUtc!;
      final overlap = await DatabaseService.instance
          .checkOverlapWithExistingRecords(startUtc, endUtc);
      if (overlap && mounted) {
        final conflict = await DatabaseService.instance
            .findFirstOverlappingRecord(startUtc, endUtc);
        if (!mounted) return;
        final loc = currentLocale.value;
        final rawTitle = (conflict?['title'] ?? '').toString().trim();
        final otherLabel = rawTitle.isNotEmpty ? rawTitle : t(loc, 'untitled');
        final msg = t(
          loc,
          'time_conflict_with_title',
        ).replaceFirst('%s', otherLabel);
        final sm = ScaffoldMessenger.maybeOf(context);
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          sm?.showSnackBar(SnackBar(content: Text(msg)));
        });
        return;
      }
      final ok = await DatabaseService.instance.writeCompletedRecord(
        title,
        startUtc,
        endUtc,
        categoryId: _categoryId,
      );
      if (!mounted) return;
      if (ok) {
        AppSnack.saved();
        widget.onSaved(null);
      } else {
        AppSnack.failed();
      }
      return;
    }

    // Fire-time category snapshot (picker/create), same ownership rule as Plans.
    final int? saveCategoryId = _categoryId == null
        ? null
        : resolvePlanningEditDraftCategoryId(
            draftCategoryId: _categoryId!,
            originalTaskCategoryId:
                widget.record.categoryId ??
                CategoryRule.uncategorizedSyntheticId,
            existsInTree:
                DatabaseService.instance.categoryExists(_categoryId!),
            knownPairIds: DatabaseService.instance.allCategoryIdPathPairs
                .map((p) => p.id),
          );

    // Running active record: metadata/category Save — end_time stays null.
    if (mode == RecordEditSaveMode.runningMetadata) {
      final startUtc = _startDisplay != null
          ? displayToUtc(_startDisplay!)
          : null;
      final draft = buildRunningRecordMetadataSaveDraft(
        title: title,
        categoryId: saveCategoryId,
        startUtc: startUtc,
      );
      assert(draft.endUtcIsNull);
      assert(draft.statusRemainsRunning);

      final originalCat = widget.record.categoryId;
      final requestedCat = draft.categoryId;
      final categoryOk = requestedCat == null ||
          DatabaseService.instance.canResolveRecordCategoryForPbPatch(
            requestedCat,
          );
      final uiOutcome = runningRecordCategorySaveUiOutcome(
        originalCategoryId: originalCat,
        requestedCategoryId: requestedCat,
        categoryResolvableForPbPatch: categoryOk,
      );
      if (uiOutcome == RunningRecordCategorySaveUiOutcome.categoryUnresolved) {
        // Do not show false success while card would keep Life / old category.
        AppSnack.failed();
        return;
      }

      _applyRecordLocalEdit(
        title: draft.title,
        noteText: noteText,
        checklistPayload: checklistPayload,
        planPatch: planPatch,
        startUtc: draft.startUtc,
        endUtc: null,
        categoryId: draft.categoryId,
      );
      final optimistic = _buildOptimisticRecord(
        title: draft.title,
        noteText: noteText,
        checklistPayload: checklistPayload,
        planPatch: planPatch,
        startUtc: draft.startUtc,
        endUtc: null,
      ).copyWith(
        status: 'running',
        categoryId: draft.categoryId,
      );
      _recordAutosaveGate.flush(
        () {
          unawaited(
            _syncRecordToNetwork(
              title: draft.title,
              noteText: noteText,
              checklistPayload: checklistPayload,
              planPatch: planPatch,
              startUtc: draft.startUtc,
              endUtc: null,
              categoryId: draft.categoryId,
            ),
          );
        },
        force: true,
      );
      AppSnack.changesSaved();
      widget.onSaved(optimistic);
      return;
    }

    // Stopped/completed interval Save.
    final startUtc = validation.startUtc!;
    final endUtc = validation.endUtc!;
    final planPatchStopped = _sourcePlanPatchArgs();
    final originalCatStopped = widget.record.categoryId;
    final categoryOkStopped = saveCategoryId == null ||
        DatabaseService.instance.canResolveRecordCategoryForPbPatch(
          saveCategoryId,
        );
    final uiOutcomeStopped = runningRecordCategorySaveUiOutcome(
      originalCategoryId: originalCatStopped,
      requestedCategoryId: saveCategoryId,
      categoryResolvableForPbPatch: categoryOkStopped,
    );
    if (uiOutcomeStopped ==
        RunningRecordCategorySaveUiOutcome.categoryUnresolved) {
      AppSnack.failed();
      return;
    }
    _applyRecordLocalEdit(
      title: title,
      noteText: noteText,
      checklistPayload: checklistPayload,
      planPatch: planPatchStopped,
      startUtc: startUtc,
      endUtc: endUtc,
      categoryId: saveCategoryId,
    );
    final optimisticStopped = _buildOptimisticRecord(
      title: title,
      noteText: noteText,
      checklistPayload: checklistPayload,
      planPatch: planPatchStopped,
      startUtc: startUtc,
      endUtc: endUtc,
    ).copyWith(categoryId: saveCategoryId);
    _recordAutosaveGate.flush(
      () {
        unawaited(
          _syncRecordToNetwork(
            title: title,
            noteText: noteText,
            checklistPayload: checklistPayload,
            planPatch: planPatchStopped,
            startUtc: startUtc,
            endUtc: endUtc,
            categoryId: saveCategoryId,
          ),
        );
      },
      force: true,
    );
    AppSnack.changesSaved();
    widget.onSaved(optimisticStopped);
    unawaited(
      Future<void>(() async {
        final conflict = DatabaseService.instance
            .findFirstOverlappingRecordInCache(
              startUtc,
              endUtc,
              excludeRecordId: _recordUpdateKey,
            );
        if (!mounted || conflict == null) return;
        final loc = currentLocale.value;
        final rawTitle = (conflict['title'] ?? '').toString().trim();
        final otherLabel = rawTitle.isNotEmpty ? rawTitle : t(loc, 'untitled');
        AppSnack.warning(
          t(loc, 'time_conflict_with_title').replaceFirst('%s', otherLabel),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    // ACTIVE_STATUS_LAW: running ⇔ end_time null (UI mirrors Brain).
    final isRunning = widget.record.endTime == null;
    final int catVal = _categoryId != null
        ? resolveEditFieldCategoryId(
            db: DatabaseService.instance,
            categoryId: _categoryId!,
          )
        : (pairs.isNotEmpty
            ? pairs.first.id
            : CategoryRule.uncategorizedSyntheticId);

    return Material(
      clipBehavior: Clip.none,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t(currentLocale.value, 'edit_record'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: t(currentLocale.value, 'title_label'),
                              hintText: t(
                                currentLocale.value,
                                'hint_record_example',
                              ),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (raw) {
                              _applyFuzzyCategoryFromRecordTitle(raw);
                              _onRecordFieldChanged();
                            },
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: CategoryTreeFormField(
                              value: catVal,
                              enabled: true,
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: t(
                                  currentLocale.value,
                                  'category_label',
                                ),
                              ),
                              onChanged: (id) {
                                if (id == null) return;
                                setState(() => _categoryId = id);
                                _onRecordFieldChanged(immediate: true);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildPlanLinkDropdown(context),
                          ),
                          if (_plansLoading)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
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
                              value: () {
                                final dt = _startDisplay;
                                if (dt == null) return '–';
                                return '${formatDate(dt)} ${formatTimeOfDay(dt)}';
                              }(),
                              onPressed: _pickStart,
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
                              value: isRunning
                                  ? t(currentLocale.value, 'running_label')
                                  : () {
                                      final dt = _endDisplay;
                                      if (dt == null) {
                                        return t(
                                          currentLocale.value,
                                          'no_end_time',
                                        );
                                      }
                                      return '${formatDate(dt)} ${formatTimeOfDay(dt)}';
                                    }(),
                              onPressed: isRunning ? null : _pickEnd,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: kAppCompactControlHeight,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelPadding: EdgeInsets.zero,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: [
                      AppCompactTextTab(
                        text: t(currentLocale.value, 'notes_tab'),
                      ),
                      AppCompactTextTab(
                        text: t(currentLocale.value, 'checklist_tab'),
                      ),
                      AppCompactTextTab(
                        text: t(currentLocale.value, 'parallel_activities_tab'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: kPlanningEditQuillToolbarMinHeight,
                              ),
                              child: QuillSimpleToolbar(
                                controller: _recordQuillController,
                                config: planningTaskEditQuillToolbarConfig(
                                  context,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
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
                                  controller: _recordQuillController,
                                  focusNode: _recordQuillFocus,
                                  scrollController: _recordQuillScroll,
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
                        primary: false,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          ...List.generate(_checklistControllers.length, (i) {
                            final scheme = Theme.of(context).colorScheme;
                            final rowDone =
                                i < _checklistDone.length && _checklistDone[i];
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
                                  _onRecordFieldChanged(immediate: true);
                                },
                              ),
                              title: TextField(
                                controller: _checklistControllers[i],
                                onChanged: (_) => _onRecordFieldChanged(),
                                style: TextStyle(
                                  decoration: rowDone
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: rowDone
                                      ? scheme.onSurface.withValues(alpha: 0.5)
                                      : scheme.onSurface,
                                  decorationColor: rowDone
                                      ? scheme.onSurface.withValues(alpha: 0.5)
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
                                  _onRecordFieldChanged(immediate: true);
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
                              _onRecordFieldChanged();
                            },
                          ),
                        ],
                      ),
                      ParallelActivitiesTab(
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
                          label: Text(t(currentLocale.value, 'stop')),
                        ),
                      TextButton(
                        onPressed: widget.onDelete,
                        child: Text(
                          t(currentLocale.value, 'delete'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _save,
                        child: Text(t(currentLocale.value, 'save')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
