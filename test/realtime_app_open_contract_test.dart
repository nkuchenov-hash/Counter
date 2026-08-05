import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/data/db_core.dart').readAsStringSync();

  test('cold start arms live sync without waiting for a user gesture', () {
    final ready = source.indexOf('unawaited(refreshForegroundData());');
    final deferred = source.indexOf(
      "StartupLog.scheduleAfterFirstFrame(\n      'deferredBootWork'",
    );
    expect(ready, greaterThanOrEqualTo(0));
    expect(deferred, greaterThan(ready));
  });

  test('temporary startup backoff schedules one automatic retry', () {
    expect(source, contains('_scheduleAppOpenSyncRetry();'));
    expect(source, contains('delay + const Duration(milliseconds: 250)'));
  });

  test('app-open sync is push-first and contains no periodic polling', () {
    final body = source.substring(
      source.indexOf('Future<void> _refreshForegroundDataBody()'),
    );
    final subscribe = body.indexOf('await Future.wait<void>');
    final outbox = body.indexOf('await offlineSync.bootstrapFromOutboxes');
    expect(subscribe, greaterThanOrEqualTo(0));
    expect(outbox, greaterThan(subscribe));
    expect(source, isNot(contains('Timer.periodic')));
  });
}
