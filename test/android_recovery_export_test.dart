import 'package:counter/data/local_sync/android_recovery_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Read-only Android recovery export', () {
    test('includes old offline caches without serializing auth or tokens', () {
      final source = <String, Object?>{
        'cache_records_flat_v1_user': '[{"title":"test"}]',
        'flutter.cache_plans_day_v1_user_2026-10-29': '[{"title":"october"}]',
        'cache_categories_raw_v1_user': '[]',
        'record_mutation_outbox_v1': '[{"operationId":"offline"}]',
        'plan_mutation_outbox_v1': '[]',
        'category_mutation_outbox_v1_user': '[]',
        'warm_plans_snapshots_v1_user': '[]',
        'pb_auth': '{"token":"DO_NOT_EXPORT"}',
        'flutter.pb_auth': 'DO_NOT_EXPORT',
        'cache_records_flat_v1_auth_token': 'DO_NOT_EXPORT',
        'api_key': 'DO_NOT_EXPORT',
        'unrelated': 'DO_NOT_EXPORT',
      };
      final exported =
          LifeOsAndroidRecoveryExport.snapshotFromPreferences(
            source,
            capturedAt: DateTime.utc(2026, 11, 4),
          );
      final values =
          exported['localStorage'] as Map<String, Object?>;
      expect(exported['type'], 'LIFE_OS_ANDROID_RECOVERY');
      expect(exported['source'], 'android-shared-preferences');
      expect(values['cache_records_flat_v1_user'], '[{"title":"test"}]');
      expect(
        values['flutter.cache_plans_day_v1_user_2026-10-29'],
        '[{"title":"october"}]',
      );
      expect(values['category_mutation_outbox_v1_user'], '[]');
      expect(values.containsKey('pb_auth'), isFalse);
      expect(values.containsKey('flutter.pb_auth'), isFalse);
      expect(values.containsKey('cache_records_flat_v1_auth_token'), isFalse);
      expect(values.values.any((x) => x == 'DO_NOT_EXPORT'), isFalse);
      // Original input map and embedded JSON text are unchanged.
      expect(source['pb_auth'], '{"token":"DO_NOT_EXPORT"}');
    });

    test('empty local recovery store cannot generate a misleading file', () {
      expect(
        () => LifeOsAndroidRecoveryExport.snapshotFromPreferences(
          {'pb_auth': 'PRIVATE'},
          capturedAt: DateTime.utc(2026, 11, 4),
        ),
        throwsStateError,
      );
    });
  });
}
