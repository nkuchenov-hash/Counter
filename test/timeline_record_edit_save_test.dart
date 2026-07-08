import 'package:counter/features/shared/edit_sheet/record_edit_save_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyRecordEditSaveMode', () {
    test('running with null end uses metadata mode even without system id', () {
      expect(
        classifyRecordEditSaveMode(
          hasPersistedOrClientRecordId: false,
          endTimeIsNull: true,
          status: 'running',
        ),
        RecordEditSaveMode.runningMetadata,
      );
    });

    test('running with business UUID key still uses metadata mode', () {
      expect(
        classifyRecordEditSaveMode(
          hasPersistedOrClientRecordId: true,
          endTimeIsNull: true,
          status: 'running',
        ),
        RecordEditSaveMode.runningMetadata,
      );
    });

    test('empty id + no end + empty status still treated as running metadata', () {
      expect(
        classifyRecordEditSaveMode(
          hasPersistedOrClientRecordId: false,
          endTimeIsNull: true,
          status: '',
        ),
        RecordEditSaveMode.runningMetadata,
      );
    });

    test('past-date create: no key + has end path is createCompletedInterval', () {
      expect(
        classifyRecordEditSaveMode(
          hasPersistedOrClientRecordId: false,
          endTimeIsNull: false,
          status: 'completed',
        ),
        RecordEditSaveMode.createCompletedInterval,
      );
    });

    test('stopped interval with key uses stoppedInterval', () {
      expect(
        classifyRecordEditSaveMode(
          hasPersistedOrClientRecordId: true,
          endTimeIsNull: false,
          status: 'completed',
        ),
        RecordEditSaveMode.stoppedInterval,
      );
    });
  });

  group('recordEditHasUpdatableRecordKey', () {
    test('accepts PB system id', () {
      expect(
        recordEditHasUpdatableRecordKey(
          systemOrOptimisticId: 'abc123def456789',
          businessRecordId: null,
        ),
        isTrue,
      );
    });

    test('accepts business UUID when system id empty (fromMap filtered UUID)', () {
      expect(
        recordEditHasUpdatableRecordKey(
          systemOrOptimisticId: '',
          businessRecordId: '11111111-2222-4333-8444-555555555555',
        ),
        isTrue,
      );
    });

    test('rejects true create placeholder with no keys', () {
      expect(
        recordEditHasUpdatableRecordKey(
          systemOrOptimisticId: '',
          businessRecordId: null,
        ),
        isFalse,
      );
    });
  });

  group('validateRecordEditSave — running category-only', () {
    DateTime toUtc(DateTime d) => DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);

    test('running category save does not require end time', () {
      final start = DateTime(2026, 7, 8, 9, 0);
      final v = validateRecordEditSave(
        title: '4U Mobility Sales reporting',
        hasUpdatableRecordKey: true,
        recordEndTimeIsNull: true,
        recordStatus: 'running',
        draftStartDisplay: start,
        draftEndDisplay: null,
        displayToUtc: toUtc,
      );
      expect(v.isOk, isTrue);
      expect(v.mode, RecordEditSaveMode.runningMetadata);
      expect(v.errorKey, isNull);
    });

    test('running save with empty system id but business UUID key still ok', () {
      expect(
        recordEditHasUpdatableRecordKey(
          systemOrOptimisticId: '',
          businessRecordId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        ),
        isTrue,
      );
      final v = validateRecordEditSave(
        title: '4U Mobility Sales reporting',
        hasUpdatableRecordKey: true,
        recordEndTimeIsNull: true,
        recordStatus: 'running',
        draftStartDisplay: DateTime(2026, 7, 8, 9, 0),
        draftEndDisplay: null,
        displayToUtc: toUtc,
      );
      expect(v.isOk, isTrue);
      expect(v.mode, RecordEditSaveMode.runningMetadata);
      expect(v.errorKey, isNot('edit_save_time_required'));
    });

    test('BUG REGRESSION: empty id + running must NOT force create time error', () {
      // Previously isCreate = id.isEmpty routed running rows into create path
      // which required start+end → snackbar edit_save_time_required.
      final wronglyAsCreate = validateRecordEditSave(
        title: '4U Mobility Sales reporting',
        hasUpdatableRecordKey: false,
        recordEndTimeIsNull: true,
        recordStatus: 'running',
        draftStartDisplay: DateTime(2026, 7, 8, 9, 0),
        draftEndDisplay: null,
        displayToUtc: toUtc,
      );
      expect(wronglyAsCreate.mode, RecordEditSaveMode.runningMetadata);
      expect(wronglyAsCreate.isOk, isTrue);
      expect(wronglyAsCreate.errorKey, isNull);
    });

    test('running metadata draft keeps end null and stays running', () {
      const life = 42;
      const fourU = 501;
      final draft = buildRunningRecordMetadataSaveDraft(
        title: '4U Mobility Sales reporting',
        categoryId: fourU,
        startUtc: DateTime.utc(2026, 7, 8, 13, 0),
      );
      expect(draft.categoryId, fourU);
      expect(draft.categoryId, isNot(life));
      expect(draft.endUtcIsNull, isTrue);
      expect(draft.statusRemainsRunning, isTrue);
    });

    test('running missing start still shows time required', () {
      final v = validateRecordEditSave(
        title: 'Task',
        hasUpdatableRecordKey: true,
        recordEndTimeIsNull: true,
        recordStatus: 'running',
        draftStartDisplay: null,
        draftEndDisplay: null,
        displayToUtc: toUtc,
      );
      expect(v.isOk, isFalse);
      expect(v.errorKey, 'edit_save_time_required');
    });
  });

  group('validateRecordEditSave — stopped / create intervals', () {
    DateTime toUtc(DateTime d) => DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);

    test('stopped missing end shows time required', () {
      final v = validateRecordEditSave(
        title: 'Done task',
        hasUpdatableRecordKey: true,
        recordEndTimeIsNull: false,
        recordStatus: 'completed',
        draftStartDisplay: DateTime(2026, 7, 8, 9, 0),
        draftEndDisplay: null,
        displayToUtc: toUtc,
      );
      expect(v.isOk, isFalse);
      expect(v.errorKey, 'edit_save_time_required');
    });

    test('stopped invalid end-before-start shows end_time_after_start', () {
      final v = validateRecordEditSave(
        title: 'Done task',
        hasUpdatableRecordKey: true,
        recordEndTimeIsNull: false,
        recordStatus: 'completed',
        draftStartDisplay: DateTime(2026, 7, 8, 10, 0),
        draftEndDisplay: DateTime(2026, 7, 8, 9, 0),
        displayToUtc: toUtc,
      );
      expect(v.isOk, isFalse);
      expect(v.errorKey, 'end_time_after_start');
    });

    test('create completed interval requires both times', () {
      final v = validateRecordEditSave(
        title: 'Past entry',
        hasUpdatableRecordKey: false,
        recordEndTimeIsNull: false,
        recordStatus: 'completed',
        draftStartDisplay: DateTime(2026, 7, 7, 9, 0),
        draftEndDisplay: null,
        displayToUtc: toUtc,
      );
      expect(v.isOk, isFalse);
      expect(v.errorKey, 'edit_save_time_required');
    });

    test('stopped valid interval save ok', () {
      final v = validateRecordEditSave(
        title: 'Done task',
        hasUpdatableRecordKey: true,
        recordEndTimeIsNull: false,
        recordStatus: 'completed',
        draftStartDisplay: DateTime(2026, 7, 8, 9, 0),
        draftEndDisplay: DateTime(2026, 7, 8, 10, 0),
        displayToUtc: toUtc,
      );
      expect(v.isOk, isTrue);
      expect(v.mode, RecordEditSaveMode.stoppedInterval);
      expect(v.startUtc, isNotNull);
      expect(v.endUtc, isNotNull);
    });

    test('empty title always fails first', () {
      final v = validateRecordEditSave(
        title: '  ',
        hasUpdatableRecordKey: true,
        recordEndTimeIsNull: true,
        recordStatus: 'running',
        draftStartDisplay: DateTime(2026, 7, 8, 9, 0),
        draftEndDisplay: null,
        displayToUtc: toUtc,
      );
      expect(v.errorKey, 'edit_save_title_required');
    });
  });
}
