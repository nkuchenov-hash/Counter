import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Durable per-user category PATCH journal. Newer revisions survive an older
/// in-flight server response, while edits to the same category coalesce.
abstract final class CategoryMutationOutbox {
  static const _prefix = 'category_mutation_outbox_v1_';
  static Future<void> _barrier = Future<void>.value();

  static String _key(String owner) {
    final scoped = owner.trim();
    if (scoped.isEmpty) {
      throw StateError('Cannot save a category edit without a profile');
    }
    return '$_prefix$scoped';
  }

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final data = jsonDecode(raw);
    if (data is! List || data.any((item) => item is! Map)) {
      throw const FormatException('Invalid category outbox journal');
    }
    return [for (final row in data) Map<String, dynamic>.from(row as Map)];
  }

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final next = _barrier.then((_) => action());
    _barrier = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  static Future<List<Map<String, dynamic>>> load(
      SharedPreferences prefs, String owner) async {
    await _barrier;
    return _decode(prefs.getString(_key(owner)));
  }

  static Future<void> enqueue(
    SharedPreferences prefs,
    String owner, {
    required int categoryId,
    required String pocketBaseId,
    required Map<String, dynamic> fields,
  }) => _serialize(() async {
    final key = _key(owner);
    final rows = _decode(prefs.getString(key));
    final i = rows.indexWhere((row) => row['categoryId'] == categoryId);
    final old = i < 0 ? <String, dynamic>{} : rows[i];
    final previous = old['fields'] is Map
        ? Map<String, dynamic>.from(old['fields'] as Map)
        : <String, dynamic>{};
    final revision = ((old['revision'] as num?)?.toInt() ?? 0) + 1;
    final value = <String, dynamic>{
      'categoryId': categoryId,
      'pocketBaseId': pocketBaseId,
      'fields': <String, dynamic>{...previous, ...fields},
      'revision': revision,
    };
    if (i < 0) {
      rows.add(value);
    } else {
      rows[i] = value;
    }
    if (!await prefs.setString(key, jsonEncode(rows))) {
      throw StateError('Failed to save category mutation locally');
    }
  });

  static Future<bool> acknowledge(
    SharedPreferences prefs,
    String owner, {
    required int categoryId,
    required int revision,
  }) => _serialize(() async {
    final key = _key(owner);
    final rows = _decode(prefs.getString(key));
    final count = rows.length;
    rows.removeWhere((row) =>
      row['categoryId'] == categoryId && row['revision'] == revision);
    if (rows.length == count) return false;
    if (!await prefs.setString(key, jsonEncode(rows))) {
      throw StateError('Failed to acknowledge category mutation');
    }
    return true;
  });
}
