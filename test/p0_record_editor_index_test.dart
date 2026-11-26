import 'package:counter/data/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService.instance;
  const owner = 'owner1234567890';
  const recordId = 'record123456789';
  const businessId = 'record-hotpath-regression';

  setUp(() {
    db.debugResetRecordBrainTestHarness();
    db.timelineDayBodyCache.invalidateAll();
    db.debugActivateRecordBrainTestHarness(userId: owner, categories: []);
  });
  tearDown(() {
    db.timelineDayBodyCache.invalidateAll();
    db.debugResetRecordBrainTestHarness();
  });

  void seed(DateTime start) {
    db.debugSeedFlatRecordRowForTest({
      'id': recordId,
      '_pb_record_id': recordId,
      'record_id': businessId,
      'user_id': owner,
      'title': 'Original',
      'type': 'record',
      'status': 'stopped',
      'start_time': start.toUtc().toIso8601String(),
      'end_time': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
      'note': '',
    });
  }

  test('metadata edit preserves unrelated ready day projection', () async {
    final start = DateTime(2026, 11, 20, 12);
    final day = DateTime(2026, 11, 20);
    final other = DateTime(2026, 11, 19);
    seed(start);
    expect(db.peekTimelineRecordsForDate(day).single['title'], 'Original');
    final unrelated = db.peekTimelineRowVmsForDate(other);
    db.timelineWarmSnapshotForDate(day);
    db.timelineBodyEntryForDate(day);
    var emissions = 0;
    final sub = db.timeUpdates.listen((_) => emissions++);
    try {
      final applied = db.applyOptimisticRecordRowEdit(
        recordId: recordId,
        title: 'Edited',
        note: 'Changed notes',
      );
      expect(applied.updatedFlatCache, isTrue);
      final row = db.peekTimelineRecordsForDate(day).single;
      expect(row['title'], 'Edited');
      expect(row['note'], 'Changed notes');
      expect(identical(unrelated, db.peekTimelineRowVmsForDate(other)), isTrue);
      expect(db.timelineWarmSnapshotForDate(day).records.single['title'], 'Edited');
      expect(db.timelineBodyEntryForDate(day).records.single['title'], 'Edited');
      await Future<void>.delayed(Duration.zero);
      expect(emissions, 1);
    } finally {
      await sub.cancel();
    }
  });

  test('interval move evicts old and destination derived day bodies', () {
    final start = DateTime(2026, 11, 21, 12);
    final oldDay = DateTime(2026, 11, 21);
    final nextDay = DateTime(2026, 11, 22);
    seed(start);
    expect(db.timelineBodyEntryForDate(oldDay).records, hasLength(1));
    expect(db.timelineBodyEntryForDate(nextDay).records, isEmpty);
    db.applyOptimisticRecordRowEdit(
      recordId: recordId,
      startTime: DateTime(2026, 11, 22, 12).toUtc(),
      endTime: DateTime(2026, 11, 22, 13).toUtc(),
    );
    expect(db.peekTimelineRecordsForDate(oldDay), isEmpty);
    expect(db.peekTimelineRecordsForDate(nextDay).single['title'], 'Original');
    expect(db.timelineBodyEntryForDate(oldDay).records, isEmpty);
    expect(db.timelineBodyEntryForDate(nextDay).records, hasLength(1));
  });
}
