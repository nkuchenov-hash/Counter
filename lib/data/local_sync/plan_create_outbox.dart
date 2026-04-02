import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-only queue for PocketBase **plans** `create` payloads when the network fails.
///
/// Bodies must be JSON-serializable (ISO strings, primitives, lists of strings).
abstract final class PlanCreateOutbox {
  static const String _prefsKey = 'plan_create_outbox_v1';

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final e in decoded)
          if (e is Map) Map<String, dynamic>.from(e as Map),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> load(SharedPreferences prefs) async =>
      _decode(prefs.getString(_prefsKey));

  static Future<void> save(
    SharedPreferences prefs,
    List<Map<String, dynamic>> items,
  ) async {
    await prefs.setString(_prefsKey, jsonEncode(items));
  }

  static Future<void> enqueue(
    SharedPreferences prefs,
    Map<String, dynamic> body,
  ) async {
    final q = await load(prefs);
    q.add(<String, dynamic>{
      'body': body,
      'enqueuedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await save(prefs, q);
  }

  static Future<void> replaceAll(
    SharedPreferences prefs,
    List<Map<String, dynamic>> items,
  ) =>
      save(prefs, items);
}
