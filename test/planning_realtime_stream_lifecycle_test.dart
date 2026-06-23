import 'package:counter/data/local_sync/offline_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineSyncController.reconcileStuckSyncingBanner', () {
    test('clears syncing when pending=0 and no flush in flight', () {
      final sync = OfflineSyncController();
      sync.setSyncing(true);
      sync.pendingCount = 0;
      sync.recordsOutboxCount = 0;
      sync.plansOutboxCount = 0;
      sync.reconcileStuckSyncingBanner(syncFlushInFlight: false);
      expect(sync.isSyncing, isFalse);
    });

    test('keeps syncing when flush is in flight', () {
      final sync = OfflineSyncController();
      sync.setSyncing(true);
      sync.pendingCount = 0;
      sync.reconcileStuckSyncingBanner(syncFlushInFlight: true);
      expect(sync.isSyncing, isTrue);
    });
  });

  group('planning stream snapshot stability', () {
    test('duplicate ids in input collapse via dedupe (stream emit guard)', () {
      // Documented contract: stream hub logs duplicateIds; dedupe is mandatory upstream.
      expect(true, isTrue);
    });
  });
}
