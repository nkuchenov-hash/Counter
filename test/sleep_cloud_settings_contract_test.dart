import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android and Web use the same server-owned sleep connection', () {
    final settings = File(
      'lib/features/settings/health/health_connect_settings_section.dart',
    ).readAsStringSync();

    expect(settings, contains('CloudSleepSyncService.instance'));
    expect(settings, contains('await _cloud.loadStatus()'));
    expect(settings, contains('await _cloud.connectXiaomi()'));
    expect(settings, contains('await _cloud.syncNow()'));
    expect(settings, contains('await _cloud.setEnabled(enabled)'));
    expect(settings, contains('state.lastSyncUtc'));
    expect(settings, contains('state.lastSessionCount'));
    expect(settings, contains('state.lastImportedCount'));
    expect(settings, contains('state.error'));
    expect(settings, isNot(contains('HealthSleepSyncService.instance')));
    expect(settings, isNot(contains('_useDeviceSource')));
    expect(settings, isNot(contains('connectGoogleFit()')));
  });

  test('cloud client uses canonical Xiaomi route and can reuse a connection', () {
    final routes = File('lib/data/pb_config.dart').readAsStringSync();
    final client = File(
      'lib/data/health/cloud_sleep_sync_service.dart',
    ).readAsStringSync();
    final server = File('pb_hooks/sleep_sync.pb.js').readAsStringSync();

    expect(routes, contains("'/api/sleep-sync/xiaomi/connect'"));
    expect(client, contains('PbAppApiRoutes.sleepSyncXiaomiConnect'));
    expect(client, contains("payload.containsKey('configured')"));
    expect(client, contains('_applyStatus(payload)'));
    expect(client, contains('_refreshRecordsForNewServerSync()'));
    expect(client, contains('fetchRecords(forceNetwork: true)'));
    expect(server, contains('"/api/sleep-sync/xiaomi/connect"'));
    expect(server, contains('"/xiaomi_sleep_runtime.js"'));
  });

  test('setting exposes authentication, connection and no-data feedback', () {
    final settings = File(
      'lib/features/settings/health/health_connect_settings_section.dart',
    ).readAsStringSync();

    expect(settings, contains('Продолжить вход в Xiaomi'));
    expect(settings, contains('Синхронизировать сейчас'));
    expect(settings, contains('Последняя проверка'));
    expect(settings, contains('Найдено периодов сна'));
    expect(settings, contains('При последней проверке записей сна не получено'));
    expect(settings, contains('xiaomi_sleep_not_available_today'));
    expect(settings, contains('server_sleep_sync_not_deployed'));
  });
}
