import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Read-only recovery snapshot from the app's own private Android preferences.
///
/// No PocketBase/network access and no mutation of application preferences.
/// The export excludes auth stores, passwords and session/token keys. Keep the
/// resulting JSON private: records/notes/plans may contain personal information.
///
/// WARNING: A new APK must NOT be installed over the existing user installation
/// unless its Android signing certificate is confirmed identical. The former
/// release signing key is still awaiting recovery from the old Beget server.
abstract final class LifeOsAndroidRecoveryExport {
  static const _cachePrefixes = <String>[
    'cache_records_flat_v1',
    'cache_categories_raw_v1',
    'cache_plans_day_v1',
    'warm_plans_snapshots_v1',
    'warm_timeline_snapshots_v1',
    'record_mutation_outbox_v1',
    'plan_mutation_outbox_v1',
    'plan_create_outbox_v1',
    'category_mutation_outbox_v1_',
  ];

  static bool shouldInclude(String rawKey) {
    final key = rawKey.startsWith('flutter.')
        ? rawKey.substring('flutter.'.length)
        : rawKey;
    final lower = key.toLowerCase();
    // Future settings must never export unrelated auth/session material.
    if (RegExp(r'auth|token|secret|password|credential|session|api[_-]?key')
        .hasMatch(lower)) {
      return false;
    }
    return _cachePrefixes.any((prefix) => key.startsWith(prefix));
  }

  static Map<String, Object?> snapshotFromPreferences(
    Map<String, Object?> prefs, {
    required DateTime capturedAt,
  }) {
    final selected = <String, Object?>{};
    for (final key in prefs.keys.toList()..sort()) {
      if (shouldInclude(key)) {
        selected[key] = prefs[key];
      }
    }
    final recordCacheCount = selected.keys
        .where((key) => key.contains('cache_records_flat_v1'))
        .length;
    final planCacheCount = selected.keys
        .where((key) => key.contains('cache_plans_day_v1'))
        .length;
    if (selected.isEmpty) {
      throw StateError('No local LIFE OS recovery data found');
    }
    return <String, Object?>{
      'type': 'LIFE_OS_ANDROID_RECOVERY',
      'version': 1,
      'createdUtc': capturedAt.toUtc().toIso8601String(),
      'source': 'android-shared-preferences',
      'notice':
          'PRIVATE USER DATA. Keep offline, never commit to a public repository.',
      'localStorage': selected,
      'summary': <String, int>{
        'selectedPreferenceKeys': selected.length,
        'recordCacheKeys': recordCacheCount,
        'planDayCacheKeys': planCacheCount,
      },
    };
  }

  /// Requires an explicit user tap and Android Storage Access Framework save
  /// dialog. The user chooses a destination OUTSIDE the app's private sandbox.
  /// Returns null on user cancellation. Does not alter any data.
  static Future<String?> exportToChosenFile() async {
    final prefs = await SharedPreferences.getInstance();
    final values = <String, Object?>{
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };
    final snapshot = snapshotFromPreferences(
      values,
      capturedAt: DateTime.now().toUtc(),
    );
    final encoded = utf8.encode(jsonEncode(snapshot));
    final stamp = DateTime.now().toUtc().toIso8601String()
        .substring(0, 10);
    return FileSaver.instance.saveAs(
      name: 'LIFEOS-ANDROID-RECOVERY-$stamp',
      bytes: Uint8List.fromList(encoded),
      fileExtension: 'json',
      mimeType: MimeType.custom,
      customMimeType: 'application/json',
    );
  }
}
