import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('realtime reconnect performs authoritative catch-up without polling', () {
    final realtime = File(
      'lib/data/records/record_realtime.dart',
    ).readAsStringSync();
    final core = File('lib/data/db_core.dart').readAsStringSync();

    expect(realtime, contains("subscribe(\n          'PB_CONNECT'"));
    expect(realtime, contains('_realtimeTransportGapDetected = true;'));
    expect(realtime, contains('_onPocketBaseRealtimeConnect'));
    expect(realtime, contains('_scheduleRealtimeGapCatchUp()'));
    expect(realtime, contains('refreshForegroundData()'));
    expect(realtime, isNot(contains('Timer.periodic')));

    // Reconnect catch-up must use the existing authoritative foreground path,
    // not a records-only shortcut, so all shared app domains converge.
    final refreshStart = core.indexOf(
      'Future<void> _refreshForegroundDataBody() async',
    );
    final refreshEnd = core.indexOf(
      'Future<void> flushPendingLocalMutations()',
      refreshStart,
    );
    expect(refreshStart, greaterThanOrEqualTo(0));
    expect(refreshEnd, greaterThan(refreshStart));
    final refresh = core.substring(refreshStart, refreshEnd);

    expect(refresh, contains('_fetchRecordsIntoCache(forceNetwork: true)'));
    expect(refresh, contains('_reconcileDuplicatePrimaryRunningRecords()'));
    expect(refresh, contains('_ensureAllPlansUserCacheFresh(force: true)'));
    expect(refresh, contains('_loadPlanningTasksForToday()'));
    expect(refresh, contains('_loadRulesFromNoco()'));
    expect(refresh, contains('flushPendingLocalMutations()'));
    expect(refresh, isNot(contains('Timer.periodic')));
  });

  test('realtime gap guard distinguishes transport loss from intentional close', () {
    final realtime = File(
      'lib/data/records/record_realtime.dart',
    ).readAsStringSync();

    expect(realtime, contains("entry.key != 'PB_CONNECT'"));
    expect(realtime, contains('entry.value.isNotEmpty'));
    expect(
      realtime,
      contains(
        'authoritative catch-up armed subscriptions=\${subscriptions.length}',
      ),
    );
    expect(realtime, contains('_cancelRealtimeRecoverySubscription()'));
    expect(realtime, contains('!_hasAuthenticatedUserId'));
  });
}
