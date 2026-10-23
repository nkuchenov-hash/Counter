import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Owner-scoped durable queue for category field edits.
///
/// Multiple edits to the same category merge into one PATCH. Revisions prevent
/// an earlier network acknowledgement from removing newer offline changes.
abstract final class CategoryMutationOutbox {
  static const String _keyPrefix = 'category_mutation_outbox_v1_';
  static Future<void> _writeChain = Future<void>.value();

  static String _key(String owner) => '$_keyPrefix$owner';

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return <Map<String, dynamic>>[];
      return <Map<String, dynamic>>[
        for (final item in json)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<T> _locked<T>(Future<T> Function() write) async {
    final previous = _writeChain;
    final complete = Completer<void>();
    _writeChain = complete.future;
    await previous;
    try {
      return await write();
    } finally {
      complete.complete();
    }
  }

  static Future<List<Map<String, dynamic>>> load(
    SharedPreferences prefs,
    String owner,
  ) async => _decode(prefs.getString(_key(owner)));

  static Future<void> enqueue(
    SharedPreferences prefs, {
    required String owner,
    required String pocketBaseId,
    required Map<String, dynamic> fields,
  }) => _locked(() async {
    final q = _decode(prefs.getString(_key(owner)));
    final index = q.indexWhere((e) => e['pocketBaseId'] == pocketBaseId);
    final old = index < 0 ? null : q[index];
    final oldFields = old?['fields'] is Map
        ? Map<String, dynamic>.from(old!['fields'] as Map)
        : <String, dynamic>{};
    final next = <String, dynamic>{
      'pocketBaseId': pocketBaseId,
      'revision': ((old?['revision'] as num?)?.toInt() ?? 0) + 1,
      'fields': <String, dynamic>{...oldFields, ...fields},
    };
    if (index < 0) {
      q.add(next);
    } else {
      q[index] = next;
    }
    await prefs.setString(_key(owner), jsonEncode(q));
  });

  /// Removes only the revision actually submitted to PocketBase.
  static Future<bool> acknowledge(
    SharedPreferences prefs, {
    required String owner,
    required String pocketBaseId,
    required int revision,
  }) => _locked(() async {
    final q = _decode(prefs.getString(_key(owner)));
    final index = q.indexWhere((e) => e['pocketBaseId'] == pocketBaseId);
    if (index < 0 || (q[index]['revision'] as num?)?.toInt() != revision) {
      return false;
    }
    q.removeAt(index);
    await prefs.setString(_key(owner), jsonEncode(q));
    return true;
  });
}
