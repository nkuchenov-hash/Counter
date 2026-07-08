import 'package:flutter/foundation.dart';

import 'package:counter/data/models.dart';

/// How [TimelineRecord] edit Save validates and patches times.
enum RecordEditSaveMode {
  /// Past-date create: require start+end, write completed interval.
  createCompletedInterval,

  /// Active running row: metadata/category save; end_time may stay null.
  runningMetadata,

  /// Stopped/completed interval: require valid start+end when saving times.
  stoppedInterval,
}

/// Result of [validateRecordEditSave].
@immutable
class RecordEditSaveValidation {
  const RecordEditSaveValidation.ok(this.mode)
      : errorKey = null,
        startUtc = null,
        endUtc = null;

  const RecordEditSaveValidation.okWithTimes({
    required this.mode,
    required this.startUtc,
    required this.endUtc,
  }) : errorKey = null;

  const RecordEditSaveValidation.error(this.errorKey)
      : mode = null,
        startUtc = null,
        endUtc = null;

  final RecordEditSaveMode? mode;
  final String? errorKey;
  final DateTime? startUtc;
  final DateTime? endUtc;

  bool get isOk => errorKey == null && mode != null;
}

/// Classify Save path from record identity + running state — **not** from
/// whether `id` happens to look empty after UUID→REST id filtering.
@visibleForTesting
RecordEditSaveMode classifyRecordEditSaveMode({
  required bool hasPersistedOrClientRecordId,
  required bool endTimeIsNull,
  required String status,
}) {
  final running =
      endTimeIsNull && (status.trim().isEmpty || status.trim() == 'running');
  if (!hasPersistedOrClientRecordId && !running) {
    return RecordEditSaveMode.createCompletedInterval;
  }
  if (running) return RecordEditSaveMode.runningMetadata;
  return RecordEditSaveMode.stoppedInterval;
}

/// True when the sheet has a usable row key for update (PB id, optimistic-*,
/// or legacy business `record_id` UUID). Empty synthetic create has none.
@visibleForTesting
bool recordEditHasUpdatableRecordKey({
  required String systemOrOptimisticId,
  required String? businessRecordId,
}) {
  if (systemOrOptimisticId.trim().isNotEmpty) return true;
  final biz = (businessRecordId ?? '').trim();
  return biz.isNotEmpty;
}

/// Validation for explicit Save. Running metadata saves require start only.
@visibleForTesting
RecordEditSaveValidation validateRecordEditSave({
  required String title,
  required bool hasUpdatableRecordKey,
  required bool recordEndTimeIsNull,
  required String recordStatus,
  required DateTime? draftStartDisplay,
  required DateTime? draftEndDisplay,
  required DateTime Function(DateTime display) displayToUtc,
}) {
  if (title.trim().isEmpty) {
    return const RecordEditSaveValidation.error('edit_save_title_required');
  }
  final mode = classifyRecordEditSaveMode(
    hasPersistedOrClientRecordId: hasUpdatableRecordKey,
    endTimeIsNull: recordEndTimeIsNull,
    status: recordStatus,
  );

  switch (mode) {
    case RecordEditSaveMode.runningMetadata:
      if (draftStartDisplay == null) {
        // Running row must keep a start; missing start is a real time error.
        return const RecordEditSaveValidation.error('edit_save_time_required');
      }
      // end_time may be null — do not require end for category/metadata Save.
      return RecordEditSaveValidation.ok(mode);

    case RecordEditSaveMode.createCompletedInterval:
    case RecordEditSaveMode.stoppedInterval:
      if (draftStartDisplay == null || draftEndDisplay == null) {
        return const RecordEditSaveValidation.error('edit_save_time_required');
      }
      final startUtc = displayToUtc(draftStartDisplay);
      final endUtc = displayToUtc(draftEndDisplay);
      if (endUtc.isBefore(startUtc) || endUtc.isAtSameMomentAs(startUtc)) {
        return const RecordEditSaveValidation.error('end_time_after_start');
      }
      return RecordEditSaveValidation.okWithTimes(
        mode: mode,
        startUtc: startUtc,
        endUtc: endUtc,
      );
  }
}

/// Local optimistic + network payload snapshot for a running metadata Save.
@immutable
class RunningRecordMetadataSaveDraft {
  const RunningRecordMetadataSaveDraft({
    required this.title,
    required this.categoryId,
    required this.startUtc,
    required this.endUtcIsNull,
    required this.statusRemainsRunning,
  });

  final String title;
  final int? categoryId;
  final DateTime? startUtc;
  final bool endUtcIsNull;
  final bool statusRemainsRunning;
}

/// Build the draft that Save applies for a running record (category/title/etc.).
@visibleForTesting
RunningRecordMetadataSaveDraft buildRunningRecordMetadataSaveDraft({
  required String title,
  required int? categoryId,
  required DateTime? startUtc,
}) {
  return RunningRecordMetadataSaveDraft(
    title: title.trim(),
    categoryId: categoryId,
    startUtc: startUtc,
    endUtcIsNull: true,
    statusRemainsRunning: true,
  );
}

/// Outcome gate for "Changes saved" after a running-record category edit.
enum RunningRecordCategorySaveUiOutcome {
  /// Category actually applied (or no category change requested).
  saved,

  /// User selected/created a category that cannot be patched yet — do not toast success.
  categoryUnresolved,
}

/// Outcome of applying a record edit to local Brain caches (flat + pending).
/// Defined in [RecordOptimisticApplyResult] (`lib/data/models/record.dart`).

/// When [requestedCategoryId] differs from [originalCategoryId], Save may only
/// show success if resolver, local apply, and visible category all agree.
@visibleForTesting
RunningRecordCategorySaveUiOutcome recordCategorySaveUiOutcomeAfterApply({
  required int? originalCategoryId,
  required int? requestedCategoryId,
  required bool categoryResolvableForPbPatch,
  required RecordOptimisticApplyResult applyResult,
  required int? visibleCategoryAfterApply,
}) {
  if (requestedCategoryId == null) {
    return RunningRecordCategorySaveUiOutcome.saved;
  }
  if (originalCategoryId != null && requestedCategoryId == originalCategoryId) {
    return RunningRecordCategorySaveUiOutcome.saved;
  }
  if (!categoryResolvableForPbPatch) {
    return RunningRecordCategorySaveUiOutcome.categoryUnresolved;
  }
  if (!applyResult.success) {
    return RunningRecordCategorySaveUiOutcome.categoryUnresolved;
  }
  if (!applyResult.categoryApplied) {
    return RunningRecordCategorySaveUiOutcome.categoryUnresolved;
  }
  if (visibleCategoryAfterApply != requestedCategoryId) {
    return RunningRecordCategorySaveUiOutcome.categoryUnresolved;
  }
  return RunningRecordCategorySaveUiOutcome.saved;
}

/// Legacy resolver-only gate (superseded by [recordCategorySaveUiOutcomeAfterApply]).
@visibleForTesting
RunningRecordCategorySaveUiOutcome runningRecordCategorySaveUiOutcome({
  required int? originalCategoryId,
  required int? requestedCategoryId,
  required bool categoryResolvableForPbPatch,
}) {
  if (requestedCategoryId == null) {
    return RunningRecordCategorySaveUiOutcome.saved;
  }
  if (originalCategoryId != null && requestedCategoryId == originalCategoryId) {
    return RunningRecordCategorySaveUiOutcome.saved;
  }
  if (!categoryResolvableForPbPatch) {
    return RunningRecordCategorySaveUiOutcome.categoryUnresolved;
  }
  return RunningRecordCategorySaveUiOutcome.saved;
}

/// Shape of records category PATCH keys after duality resolve.
@visibleForTesting
({String? categoryId, String? categoryLink})?
    recordCategoryPatchFieldsFromRelationId({
  required String? pocketBaseCategoryRowId,
}) {
  final pb = (pocketBaseCategoryRowId ?? '').trim();
  if (pb.isEmpty) return null;
  if (pb.length < 14 || pb.length > 17) return null;
  if (pb.contains('-')) return null;
  if (!RegExp(r'^[a-z0-9]+$').hasMatch(pb)) return null;
  return (categoryId: pb, categoryLink: pb);
}

/// Local cache row category after optimistic apply must use the same PB relation
/// id for both columns (not business slug in category_id).
@visibleForTesting
bool optimisticRecordCategoryRowMatchesSelection({
  required int selectedLocalCategoryId,
  required int? cacheLocalCategoryId,
  required String? cacheCategoryIdField,
  required String? cacheCategoryLinkField,
  required String? selectedPocketBaseCategoryRowId,
}) {
  if (cacheLocalCategoryId != selectedLocalCategoryId) return false;
  final pb = (selectedPocketBaseCategoryRowId ?? '').trim();
  if (pb.isEmpty) return false;
  final idField = (cacheCategoryIdField ?? '').trim();
  final linkField = (cacheCategoryLinkField ?? '').trim();
  return idField == pb && linkField == pb;
}

/// After records PATCH hydrate: preserve prior category ONLY when the server
/// row cannot resolve a concrete local category. Never restore an older
/// category over a different concrete server id (create→Save new category).
@visibleForTesting
bool shouldPreservePriorRecordCategoryOnUpsert({
  required bool priorLocalIsConcrete,
  required bool mergedLocalIsConcrete,
  required int? priorLocalId,
  required int? mergedLocalId,
}) {
  if (!priorLocalIsConcrete) return false;
  if (!mergedLocalIsConcrete) return true;
  // Distinct concrete ids → honor server (intentional category change).
  return false;
}

/// Pure mirror of record PATCH dual category keys (before PocketBase write).
@visibleForTesting
Map<String, String>? recordPatchCategoryFieldsForResolvedLocal({
  required int? localCategoryId,
  required String? pocketBaseCategoryRowId,
}) {
  if (localCategoryId == null) return null;
  if (localCategoryId == 0) return null;
  if (localCategoryId == -1) return null;
  final fields = recordCategoryPatchFieldsFromRelationId(
    pocketBaseCategoryRowId: pocketBaseCategoryRowId,
  );
  if (fields == null) return null;
  return <String, String>{
    'category_id': fields.categoryId!,
    'category_link': fields.categoryLink!,
  };
}

/// When normalize cannot re-resolve local id but PATCH already carries dual
/// 15-char relation ids, keep them (no Life fallback / strip).
@visibleForTesting
bool keepVerbatimRecordCategoryRelationIds({
  required bool allowFallback,
  required String? categoryIdField,
  required String? categoryLinkField,
}) {
  if (allowFallback) return false;
  final cat = (categoryIdField ?? '').trim();
  final link = (categoryLinkField ?? '').trim();
  if (cat.isEmpty || cat != link) return false;
  if (cat.length < 14 || cat.length > 17) return false;
  if (cat.contains('-')) return false;
  return RegExp(r'^[a-z0-9]+$').hasMatch(cat);
}
