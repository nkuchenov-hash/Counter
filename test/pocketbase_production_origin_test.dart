import 'dart:convert';
import 'dart:io';

import 'package:counter/data/pb_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android and Web production use the same restored PocketBase', () {
    expect(kPocketBaseProductionUrl, kPocketBaseRecoveredWebUrl);
    expect(kPocketBaseProductionUrl, 'https://137-22-146-109.sslip.io');
    final uri = Uri.parse(kPocketBaseProductionUrl);
    expect(uri.scheme, 'https');
    expect(uri.path, isEmpty);
    expect(uri.hasPort, isFalse);
  });
  test('only explicit auth rejection invalidates an existing session', () {
    expect(isPocketBaseSessionRejected(401), isTrue);
    for (final code in [0, 400, 403, 404, 408, 425, 429, 500, 502, 503, 504]) {
      expect(isPocketBaseSessionRejected(code), isFalse, reason: 'HTTP $code');
    }
    for (final path in ['lib/data/db_core.dart', 'lib/data/auth_bridge.dart']) {
      final source = File(path).readAsStringSync();
      expect(source, contains('isPocketBaseSessionRejected(e.statusCode)'));
      expect(source, isNot(contains('e.statusCode >= 400 && e.statusCode < 500')));
    }
  });

  test('browser companion uses canonical PocketBase origin and permissions', () {
    final manifest = jsonDecode(
      File('browser_extension/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final worker = File('browser_extension/service_worker.js').readAsStringSync();
    expect(worker, contains("const POCKETBASE_BASE = '$kPocketBaseProductionUrl';"));
    expect(manifest['host_permissions'], contains('$kPocketBaseProductionUrl/*'));
    expect(manifest['content_security_policy']['extension_pages'],
        contains('connect-src \'self\' $kPocketBaseProductionUrl'));
    expect(worker, isNot(contains('217-114-0-201.sslip.io')));
    expect(jsonEncode(manifest), isNot(contains('217-114-0-201.sslip.io')));
  });

  test('Wear timer retains its subscription across visual ticks', () {
    final source = File('lib/features/wear/wear_timer_screen.dart').readAsStringSync();
    expect(source, contains('late final Stream<Map<String, dynamic>?> _activeRecordStream;'));
    expect(source, contains('_activeRecordStream = DatabaseService.instance.activeRecordStream;'));
    expect(source, contains('stream: _activeRecordStream,'));
    expect(source, isNot(contains('stream: DatabaseService.instance.activeRecordStream,')));
  });

  test('sleep catch-up does not force full history every thirty seconds', () {
    final source = File('lib/data/health/sleep_foreground_reconcile_service.dart')
        .readAsStringSync();
    final periodic = source.split('Future<void> _catchUpFromPocketBase()')[1]
        .split('Future<void> _syncDeviceSleep()')[0];
    expect(periodic, isNot(contains('forceNetwork: true')));
    expect(periodic, contains('service.loadStatus()'));
    expect(periodic, contains('_missingSleepPullInterval'));
    expect(source, contains('db.contextAwarenessCachedRecords()'));
  });

  test('Android contacts use bulk reads and Windows voice log uses async IO', () {
    final contacts = File('android/app/src/main/kotlin/com/example/counter/MainActivity.kt')
        .readAsStringSync();
    expect(contacts, isNot(contains('firstContactValue(')));
    expect(contacts, contains('readContactValues('));
    expect(contacts, contains('peopleContactsReadInProgress'));
    final voice = File('lib/shared/voice/diagnostics/desktop_voice_pipeline.dart')
        .readAsStringSync();
    expect(voice, isNot(contains('writeAsStringSync(')));
    expect(voice, contains('_fileTail.then('));
  });

  test('Viktor client budget covers server authentication and generation', () {
    final source = File('lib/data/ai/viktor_gateway.dart').readAsStringSync();
    final start = source.indexOf('/api/viktor/propose');
    expect(start, greaterThanOrEqualTo(0));
    expect(source.substring(start, start + 650),
        contains('Duration(seconds: 65)'));
  });
}
