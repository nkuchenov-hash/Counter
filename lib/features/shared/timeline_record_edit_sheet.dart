import 'dart:async';
import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/core/widgets/omni_date_time_picker_dialog.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/features/shared/edit_sheet/category_edit_draft.dart';
import 'package:counter/shared/categories/picker/category_picker_contracts.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/recurrence_edit_scope.dart';
import 'package:counter/data/smart_input_parser.dart';
import 'package:counter/features/planning/recurrence_scope_dialog.dart';
import 'package:counter/features/notes/note_editor_page.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';

import 'package:counter/features/shared/edit_sheet/parallel_record_panels.dart';
import 'package:counter/features/shared/edit_sheet/record_edit_save_policy.dart';
import 'package:counter/features/shared/edit_sheet/sheet_autosave_gate.dart';
import 'package:counter/features/shared/edit_sheet/sheet_time_helpers.dart';
import 'package:counter/features/shared/edit_sheet/sheet_time_picker.dart';
import 'package:counter/features/shared/edit_sheet/editor_v45_chrome.dart';

part 'edit_sheet/record_title_assist.dart';

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

class TimelineRecordSheetContentState extends State<TimelineRecordSheetContent>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TextEditingController _titleController;
  late NoteDocument _recordNoteDocument;
  int? _categoryId;
  DateTime? _startDisplay;
  DateTime? _endDisplay;
  late TabController _tabController;
  /// PocketBase **plans** row id; empty = no link.
  late String _sourcePlanPbId;
  List<PlanningTask> _plansForLink = [];
  bool _plansLoading = false;
  bool _plansLoaded = false;
  bool _notesEditorFocused = false;
  // Keep Record chrome stable across temporary IME focus changes.
  bool _notesImeSessionActive = false;
  final FocusNode _notesScopeFocusNode =
      FocusNode(debugLabel: 'record-notes-scope', skipTraversal: true);
  Timer? _notesFocusExitTimer;
  Timer? _titleAssistDebounce;
  final _recordAutosaveGate = EditSheetAutosaveGate(debounce: const Duration(milliseconds: 1500));
  /// Existing/optimistic record key for edits.
  bool get _isPersistedRecord => recordEditHasUpdatableRecordKey(
    systemOrOptimisticId: widget.record.id,
    businessRecordId: widget.record.recordId,
  );
  /// Supports REST ids and business ids.
  String get _recordUpdateKey {
    final id = widget.record.id.trim();
    if (id.isNotEmpty) return id;
    return (widget.record.recordId ?? '').trim();
  }
  List<Map<String, dynamic>> _checklistForApi() {
    return _recordNoteDocument.blocks
        .where((block) => block.type == NoteBlockType.checklist)
        .map(
          (block) => <String, dynamic>{
            'text': block.effectiveText,
            'isDone': block.checked,
          },
        )
        .where((item) => (item['text'] as String).trim().isNotEmpty)
        .toList();
  }
  RecordAutosaveTimePatch _autosaveTimePatch() => buildRecordAutosaveTimePatch(
    recordIsRunning: widget.record.endTime == null,
    draftStartDisplay: _startDisplay,
    draftEndDisplay: _endDisplay,
    originalStartTimeUtc: widget.record.startTime,
    originalEndTimeUtc: widget.record.endTime,
    displayToUtc: displayToUtc,
  );
  void _applyFuzzyCategoryFromRecordTitle(String title) {
    final fuzzy = DatabaseService.instance.findCategoryByFuzzyMatch(title);
    if (fuzzy != null && fuzzy.id != _categoryId && mounted) {
      setState(() => _categoryId = fuzzy.id);
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
      notesDeltaJson: _recordNoteDocument.isEmpty ? '' : _recordNoteDocument.encode(),
      checklist: checklistPayload.isEmpty ? null : checklistPayload,
      sourcePlanId: planPatch.sync
          ? (planPatch.clear ? null : planPatch.id)
          : widget.record.sourcePlanId,
    );
  }
  RecordOptimisticApplyResult _applyRecordLocalEdit({
    required String title,
    required String noteText,
    String? notesDeltaSnapshot,
    required List<Map<String, dynamic>> checklistPayload,
    required ({bool sync, bool clear, String? id}) planPatch,
    DateTime? startUtc,
    DateTime? endUtc,
    int? categoryId,
  }) {
    const noop = RecordOptimisticApplyResult(
      updatedFlatCache: false,
      updatedPendingMap: false,
      categoryApplied: false,
    );
    if (!_isPersistedRecord) return noop;
    return DatabaseService.instance.applyOptimisticRecordRowEdit(
      recordId: _recordUpdateKey,
      title: title,
      startTime: startUtc,
      endTime: endUtc,
      categoryId: categoryId ?? _categoryId,
      note: noteText,
      notesDeltaJson: notesDeltaSnapshot ??
          (_recordNoteDocument.isEmpty ? '' : _recordNoteDocument.encode()),
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
    String? notesDeltaSnapshot,
  }) async {
    if (!_isPersistedRecord) return;
    await DatabaseService.instance.updateRecord(
      recordId: _recordUpdateKey,
      title: title,
      startTime: startUtc,
      endTime: endUtc,
      categoryId: categoryId ?? _categoryId,
      note: noteText,
      notesDeltaJson: notesDeltaSnapshot ??
          (_recordNoteDocument.isEmpty ? '' : _recordNoteDocument.encode()),
      checklist: checklistPayload,
      syncSourcePlan: planPatch.sync,
      clearSourcePlan: planPatch.clear,
      sourcePlanPocketRecordId: planPatch.id,
      bypassConflictCheck: true,
      alreadyAppliedOptimistically: true,
    );
  }
  // Commit the latest Notes draft locally before background sync.
  void _commitRecordAutosave() {
    if (!_isPersistedRecord) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final noteText = _recordNoteDocument.toPlainText().trim();
    final notesDeltaSnapshot =
        _recordNoteDocument.isEmpty ? '' : _recordNoteDocument.encode();
    final checklistPayload = _checklistForApi();
    final planPatch = _sourcePlanPatchArgs();
    final timePatch = _autosaveTimePatch();
    _applyRecordLocalEdit(
      title: title,
      noteText: noteText,
      notesDeltaSnapshot: notesDeltaSnapshot,
      checklistPayload: checklistPayload,
      planPatch: planPatch,
      startUtc: timePatch.startUtc,
      endUtc: timePatch.endUtc,
    );
    unawaited(
      _syncRecordToNetwork(
        title: title,
        noteText: noteText,
        notesDeltaSnapshot: notesDeltaSnapshot,
        checklistPayload: checklistPayload,
        planPatch: planPatch,
        startUtc: timePatch.startUtc,
        endUtc: timePatch.endUtc,
      ),
    );
  }
  void _onRecordFieldChanged({bool immediate = false}) {
    if (!_isPersistedRecord) return;
    if (_titleController.text.trim().isEmpty) return;
    // Avoid Timeline rebuilding on every keystroke. Publish once per debounce,
    // and commit synchronously before leaving the sheet.
    _recordAutosaveGate.markDirty();
    if (immediate) {
      _recordAutosaveGate.flush(_commitRecordAutosave);
    } else {
      _recordAutosaveGate.schedule(_commitRecordAutosave);
    }
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleRecordTabChanged);
    _titleController = TextEditingController(text: widget.record.title);
    _recordNoteDocument = NoteDocument.tryParse(
      notesDeltaJson: widget.record.notesDeltaJson,
      notesPlain: widget.record.note,
      checklist: (widget.record.checklist ?? const <Map<String, dynamic>>[])
          .map(
            (item) => <String, dynamic>{
              'text': item['text']?.toString() ?? '',
              'done': item['isDone'] == true || item['done'] == true,
            },
          )
          .toList(),
    );
    _categoryId = widget.record.categoryId;
    _startDisplay = widget.record.startTime != null
        ? utcToDisplay(widget.record.startTime!)
        : null;
    _endDisplay = widget.record.endTime != null
        ? utcToDisplay(widget.record.endTime!)
        : null;
    _sourcePlanPbId =
        DatabaseService.pocketRelationIdOrNull(widget.record.sourcePlanId) ??
        '';
  }

  void _handleRecordTabChanged() {
    if (_tabController.index == 0) return;
    _recordAutosaveGate.flush(_commitRecordAutosave);
    _notesFocusExitTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_notesEditorFocused && mounted) {
      setState(() => _notesEditorFocused = false);
    }
  }

  void _handleNotesEditorFocusChanged(bool focused) {
    if (!mounted) return;
    _notesFocusExitTimer?.cancel();
    if (focused) {
      _notesImeSessionActive = true;
      if (!_notesEditorFocused) {
        setState(() => _notesEditorFocused = true);
      }
      return;
    }
    // Ignore transient focus changes inside Android IME.
    _notesFocusExitTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _notesScopeFocusNode.hasFocus || !_notesEditorFocused) {
        return;
      }
      final keyboardGone = MediaQuery.viewInsetsOf(context).bottom == 0;
      setState(() {
        _notesEditorFocused = false;
        if (keyboardGone) _notesImeSessionActive = false;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) _recordAutosaveGate.flush(_commitRecordAutosave);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Release session state only after the IME fully closes.
    if (MediaQuery.viewInsetsOf(context).bottom == 0 &&
        !_notesEditorFocused) {
      _notesImeSessionActive = false;
    }
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
    if (_plansLoading) return;
    if (mounted) setState(() => _plansLoading = true);
    try {
      final list = await DatabaseService.instance
          .getPlanningTasksForWallDate(_wallDayForRecord())
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _plansForLink = list;
        _plansLoaded = true;
      });
    } catch (e) {
      debugPrint('UI ERROR: failed to load plans for record link: $e');
    } finally {
      if (mounted) setState(() => _plansLoading = false);
    }
  }

  Future<void> _openPlanLinkPicker(BuildContext context) async {
    if (!_plansLoaded) {
      await _loadPlansForLink();
      if (!mounted) return;
    }
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
    var selectedKey = _sourcePlanPbId;
    if (selectedKey.isNotEmpty && !seen.contains(selectedKey)) {
      final normalized = DatabaseService.pocketRelationIdOrNull(selectedKey);
      if (normalized != null) {
        options.insert(1, MapEntry(normalized, '—'));
        selectedKey = normalized;
      } else {
        selectedKey = '';
      }
    }
    await _showPlanLinkPickerSheet(
      context,
      options: options,
      selectedKey: selectedKey,
    );
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
    return EditorV45MetadataRow(
      icon: Icons.link_rounded,
      label: t(loc, 'record_link_plan_label'),
      value: _plansLoading ? t(loc, 'record_link_plan_loading') : displayLabel,
      onTap: _plansLoading ? null : () => unawaited(_openPlanLinkPicker(context)),
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isPersistedRecord) {
      _recordAutosaveGate.flush(_commitRecordAutosave);
    }
    _recordAutosaveGate.dispose();
    _notesFocusExitTimer?.cancel();
    _titleAssistDebounce?.cancel();
    _notesScopeFocusNode.dispose();
    _tabController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final initial = _startDisplay ?? displayNow();
    final picked = await showAppDateTimePicker(context, initial: initial);
    if (picked != null && mounted) {
      setState(() {
        _startDisplay = picked;
        _plansLoaded = false;
        _plansForLink = [];
      });
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
    final noteText = _recordNoteDocument.toPlainText().trim();
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
        note: noteText,
        notesDeltaJson: _recordNoteDocument.isEmpty ? '' : _recordNoteDocument.encode(),
        checklist: checklistPayload,
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
            existsInTree: DatabaseService.instance.categoryExists(_categoryId!),
            knownPairIds: DatabaseService.instance.allCategoryIdPathPairs.map(
              (p) => p.id,
            ),
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
      final categoryOk =
          requestedCat == null ||
          DatabaseService.instance.canResolveRecordCategoryForPbPatch(
            requestedCat,
          );
      final applyResult = _applyRecordLocalEdit(
        title: draft.title,
        noteText: noteText,
        checklistPayload: checklistPayload,
        planPatch: planPatch,
        startUtc: draft.startUtc,
        endUtc: null,
        categoryId: draft.categoryId,
      );
      final visibleCat = DatabaseService.instance
          .visibleRecordCategoryLocalIdForKey(_recordUpdateKey);
      final patchDualOk =
          requestedCat == null ||
          requestedCat == originalCat ||
          DatabaseService.instance.recordDualCategoryRelationFields(
                requestedCat,
              ) !=
              null;
      final uiOutcome = recordCategorySaveUiOutcomeAfterApply(
        originalCategoryId: originalCat,
        requestedCategoryId: requestedCat,
        categoryResolvableForPbPatch: categoryOk,
        applyResult: applyResult,
        visibleCategoryAfterApply: visibleCat,
        patchDualFieldsAvailable: patchDualOk,
      );
      if (uiOutcome == RunningRecordCategorySaveUiOutcome.categoryUnresolved) {
        AppSnack.failed();
        return;
      }
      final optimistic = _buildOptimisticRecord(
        title: draft.title,
        noteText: noteText,
        checklistPayload: checklistPayload,
        planPatch: planPatch,
        startUtc: draft.startUtc,
        endUtc: null,
      ).copyWith(status: 'running', categoryId: draft.categoryId);
      _recordAutosaveGate.flush(() {
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
      }, force: true);
      AppSnack.changesSaved();
      widget.onSaved(optimistic);
      return;
    }
    // Stopped/completed interval Save.
    final startUtc = validation.startUtc!;
    final endUtc = validation.endUtc!;
    final planPatchStopped = _sourcePlanPatchArgs();
    final originalCatStopped = widget.record.categoryId;
    final categoryOkStopped =
        saveCategoryId == null ||
        DatabaseService.instance.canResolveRecordCategoryForPbPatch(
          saveCategoryId,
        );
    final applyStopped = _applyRecordLocalEdit(
      title: title,
      noteText: noteText,
      checklistPayload: checklistPayload,
      planPatch: planPatchStopped,
      startUtc: startUtc,
      endUtc: endUtc,
      categoryId: saveCategoryId,
    );
    final visibleCatStopped = DatabaseService.instance
        .visibleRecordCategoryLocalIdForKey(_recordUpdateKey);
    final patchDualOkStopped =
        saveCategoryId == null ||
        saveCategoryId == originalCatStopped ||
        DatabaseService.instance.recordDualCategoryRelationFields(
              saveCategoryId,
            ) !=
            null;
    final uiOutcomeStopped = recordCategorySaveUiOutcomeAfterApply(
      originalCategoryId: originalCatStopped,
      requestedCategoryId: saveCategoryId,
      categoryResolvableForPbPatch: categoryOkStopped,
      applyResult: applyStopped,
      visibleCategoryAfterApply: visibleCatStopped,
      patchDualFieldsAvailable: patchDualOkStopped,
    );
    if (uiOutcomeStopped ==
        RunningRecordCategorySaveUiOutcome.categoryUnresolved) {
      AppSnack.failed();
      return;
    }
    final optimisticStopped = _buildOptimisticRecord(
      title: title,
      noteText: noteText,
      checklistPayload: checklistPayload,
      planPatch: planPatchStopped,
      startUtc: startUtc,
      endUtc: endUtc,
    ).copyWith(categoryId: saveCategoryId);
    _recordAutosaveGate.flush(() {
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
    }, force: true);
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
    // Keep geometry stable while Gboard temporarily shifts focus.
    final notesEditing = recordNotesShouldUseCompactChrome(
      notesFocused: _notesEditorFocused,
      notesImeSessionActive: _notesImeSessionActive,
      keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
    );
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
          EditorV45Title(
            controller: _titleController,
            onChanged: (raw) => _handleRecordTitleInput(this, raw),
            onClose: () => Navigator.of(context).pop(),
            creating: !_isPersistedRecord,
            writing: notesEditing,
            contextLabel: currentLocale.value == 'ru' ? 'Заметка записи' : 'Record note',
            contextTime: editorV45Range(_startDisplay, _endDisplay),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!notesEditing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      EditorV45TimeCard(
                        start: _startDisplay, end: _endDisplay, fallbackDate: _startDisplay ?? displayNow(),
                        onStart: _pickStart, onEnd: isRunning ? null : _pickEnd, running: isRunning,
                      ),
                      const SizedBox(height: 18),
                      EditorV45CategoryRow(
                        value: catVal,
                        display: CategoryTreeSource.exists(catVal) ? CategoryTreeSource.pathLabel(catVal) : t(currentLocale.value, 'category_label'),
                        onChanged: (id) { setState(() => _categoryId = id); _onRecordFieldChanged(immediate: true); },
                      ),
                      _buildPlanLinkDropdown(context),
                      if (_plansLoading) const LinearProgressIndicator(minHeight: 2),
                    ]),
                  ),
                if (!notesEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    height: kAppCompactControlHeight,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                      tabAlignment: TabAlignment.start,
                      padding: EdgeInsets.zero,
                      tabs: [
                        AppCompactTextTab(
                          text: t(currentLocale.value, 'notes_tab'),
                        ),
                        AppCompactTextTab(
                          text: t(
                            currentLocale.value,
                            'parallel_activities_tab',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Focus(
                        focusNode: _notesScopeFocusNode,
                        onFocusChange: _handleNotesEditorFocusChanged,
                        child: NoteEditorPage(
                          inlineKeyboardActive: notesEditing,
                          task: PlanningTask(
                            id: 0,
                            planRowId: widget.record.recordId,
                            pocketRecordId: widget.record.id,
                            title: widget.record.title,
                            categoryId:
                                widget.record.categoryId ??
                                CategoryRule.uncategorizedSyntheticId,
                            dateKey: widget.record.dateKey,
                            checklist: const <Map<String, dynamic>>[],
                            notesPlain: widget.record.note,
                            notesDeltaJson: widget.record.notesDeltaJson,
                          ),
                          inlineBodyOnly: true,
                          initialDocument: _recordNoteDocument,
                          onDocumentChanged: (document) {
                            _recordNoteDocument = document;
                            _recordAutosaveGate.schedule(_commitRecordAutosave, delay: const Duration(seconds: 15));
                          },
                        ),
                      ),
                      ParallelActivitiesTab(
                        parentRecord: widget.record,
                        scrollController: widget.scrollController,
                        categoryId: catVal,
                      ),
                    ],
                  ),
                ),
                if (!notesEditing)
                  EditorV45Actions(
                    primaryLabel: _isPersistedRecord
                        ? (currentLocale.value == 'ru' ? 'Закрыть' : 'Close')
                        : (currentLocale.value == 'ru' ? 'Создать запись' : 'Create record'),
                    onPrimary: _save,
                    onCancel: _isPersistedRecord ? null : () => Navigator.of(context).pop(),
                    onDelete: _isPersistedRecord ? widget.onDelete : null,
                    onStop: isRunning ? widget.onStop : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
