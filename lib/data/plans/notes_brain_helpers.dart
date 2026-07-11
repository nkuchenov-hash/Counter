// Part of lib/data/database_service.dart — Notes (block-document) Brain helpers.
//
// Bridges the versioned [NoteDocument] envelope with the existing
// `plans.notes_delta` / `notes_plain` / `checklist` / `is_done` fields and the
// optimistic + debounced-autosave paths. UI never touches PocketBase directly;
// it calls these helpers, which keep the Brain cache + mirrors coherent and
// schedule a single PATCH per debounce window.
//
// No UI imports. No second autosave system — reuses [EditSheetAutosaveGate].

part of '../database_service.dart';

/// Brain-side extension for the Life OS Notes block editor.
///
/// All methods are local-first: they mutate the Brain cache immediately, notify
/// the UI stream, and schedule a background PATCH. Failures keep optimistic
/// state and are retried via the existing plan mutation outbox.
extension NotesBrainExtension on DatabaseService {
  /// Returns the latest cached [PlanningTask] for a given row id, or null.
  /// Public read accessor for editor/library so they can refresh after a
  /// background sync without triggering a full refetch.
  PlanningTask? getCachedPlanningTaskForEdit(String planRowIdForBackend) {
    return _findCachedPlanningTaskForEdit(planRowIdForBackend);
  }

  /// Parses a [PlanningTask]'s stored `notes_delta` (+ legacy fallbacks) into
  /// a typed [NoteDocument]. Pure read — does not mutate state.
  NoteDocument parseNoteDocument(PlanningTask task) {
    return NoteDocument.tryParse(
      notesDeltaJson: task.notesDeltaJson,
      notesPlain: task.notesPlain,
      checklist: task.checklist,
    );
  }

  /// Returns the pin state for a note. Stored in [NoteDocumentMeta.pinned].
  bool isNotePinned(PlanningTask task) {
    return parseNoteDocument(task).meta.pinned;
  }

  /// Toggle a note's pin. Local-first: applies optimistically, then schedules
  /// a background PATCH with the full document envelope.
  void toggleNotePin(String planRowIdForBackend) {
    final task = _findCachedPlanningTaskForEdit(planRowIdForBackend);
    if (task == null) return;
    final doc = parseNoteDocument(task);
    final next = doc.copyWith(meta: doc.meta.copyWith(pinned: !doc.meta.pinned));
    _applyNoteDocument(task, next, title: task.title, categoryId: task.categoryId);
  }

  /// Toggle a note's whole-note done state. Local-first.
  void toggleNoteDone(String planRowIdForBackend) {
    final task = _findCachedPlanningTaskForEdit(planRowIdForBackend);
    if (task == null) return;
    final updated = task.copyWith(isDone: !task.isDone);
    applyOptimisticPlanningTask(updated);
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    unawaited(
      updatePlanningTask(
        updated.planRowIdForBackend,
        planBusinessId: updated.planRowId,
        isDone: updated.isDone,
        suppressAppSnack: true,
      ),
    );
  }

  /// Applies a full note document edit (blocks, meta, title, category, tags,
  /// done) to the Brain cache and schedules a single debounced PATCH.
  ///
  /// Called by the editor on every block mutation / title edit / metadata
  /// change. The [EditSheetAutosaveGate] in the editor owns the debounce; this
  /// helper performs the local apply + the network sync.
  ///
  /// [title], [categoryId], [tags], [isDone] are the latest scalar values
  /// (passed from the editor's live state). Only [doc] is required.
  void applyNoteEdit({
    required String planRowIdForBackend,
    required NoteDocument doc,
    String? title,
    int? categoryId,
    List<Tag>? tags,
    bool? isDone,
  }) {
    final task = _findCachedPlanningTaskForEdit(planRowIdForBackend);
    if (task == null) return;
    _applyNoteDocument(
      task,
      doc,
      title: title,
      categoryId: categoryId,
      tags: tags,
      isDone: isDone,
    );
  }

  /// Internal: encodes the document, updates the Brain cache with mirrored
  /// projections (notes_plain, checklist), then fires a background PATCH.
  void _applyNoteDocument(
    PlanningTask task,
    NoteDocument doc, {
    String? title,
    int? categoryId,
    List<Tag>? tags,
    bool? isDone,
  }) {
    final encoded = doc.encode();
    final plain = doc.toPlainText(title: title ?? task.title);
    final checklistProjection = doc.toChecklistProjection();

    final updated = task.copyWith(
      title: title ?? task.title,
      categoryId: categoryId ?? task.categoryId,
      isDone: isDone ?? task.isDone,
      notesDeltaJson: doc.blocks.isEmpty && plain.isEmpty ? null : encoded,
      notesPlain: plain.isEmpty ? null : plain,
      checklist: checklistProjection,
      tags: tags ?? task.tags,
      clearNotes: doc.blocks.isEmpty && plain.isEmpty,
      updatedAt: DateTime.now(),
    );
    applyOptimisticPlanningTask(updated);
    notifyPlanningRefresh(scheduleNetworkRefresh: false);

    unawaited(
      updatePlanningTask(
        updated.planRowIdForBackend,
        planBusinessId: updated.planRowId,
        title: updated.title,
        categoryId: updated.categoryId,
        notesPlain: updated.notesPlain,
        notesDeltaJson: updated.notesDeltaJson,
        checklist: updated.checklist,
        isDone: updated.isDone,
        tags: updated.tags,
        suppressAppSnack: true,
      ),
    );
  }

  /// Creates a new empty note (plan) and returns the row id for editing.
  /// Local-first: inserts an optimistic row immediately so the editor can
  /// open without waiting for PocketBase.
  ///
  /// Returns the [planRowIdForBackend] of the new row, or null on failure.
  Future<String?> createEmptyNote({
    required int categoryId,
    String title = '',
  }) async {
    final now = DateTime.now();
    final clientPlanId = DatabaseService._newClientRecordUuid();
    final optimisticId = 'optimistic-$clientPlanId';
    final order = await nextBacklogPlanningOrder();
    final doc = NoteDocument(
      blocks: [
        NoteBlock(
          id: generateNoteBlockId(),
          type: NoteBlockType.paragraph,
          text: '',
        ),
      ],
    );
    final trimmedTitle = title.trim();
    final task = PlanningTask(
      id: 0,
      planRowId: optimisticId,
      title: trimmedTitle,
      categoryId: categoryId,
      isDone: false,
      dateKey: '',
      order: order,
      notesDeltaJson: doc.encode(),
      notesPlain: trimmedTitle.isEmpty ? '' : trimmedTitle,
      isSynced: false,
      createdAt: now,
      updatedAt: now,
    );
    applyOptimisticPlanningTask(task);
    notifyPlanningRefresh(scheduleNetworkRefresh: false);

    // Persist in the background; reconcile the system id when it lands.
    final created = PlanningTask(
      id: 0,
      planRowId: clientPlanId,
      title: trimmedTitle,
      categoryId: categoryId,
      isDone: false,
      dateKey: '',
      order: order,
      notesDeltaJson: doc.encode(),
      isSynced: false,
      createdAt: now,
      updatedAt: now,
    );
    final ok = await addPlanningTask(created, clientPlanId: clientPlanId);
    if (!ok) return optimisticId;
    return optimisticId;
  }

  /// Deletes a note (plan) optimistically: removes from local cache first,
  /// then schedules a background DELETE. The editor calls this and pops.
  Future<void> deleteNote(String planRowIdForBackend) async {
    final task = _findCachedPlanningTaskForEdit(planRowIdForBackend);
    if (task == null) return;
    final pid = task.planRowIdForBackend;
    _removePlanFromUserCache(pid);
    clearOptimisticPlanningForPlanRow(pid);
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    unawaited(deletePlanningTask(pid));
  }
}
