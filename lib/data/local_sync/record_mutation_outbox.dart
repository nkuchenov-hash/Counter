import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-only queue for PocketBase **records** mutations when the network fails.
///
/// Bodies must be JSON-serializable (ISO strings, primitives, lists of strings).
///
/// ## O1 manual verification scenarios
/// - **Edit offline → restart → reconnect:** PATCH payload persists in prefs;
///   `flushPendingRecordMutations` replays; server row merges into cache.
/// - **Delete offline → restart → reconnect:** DELETE queued with `businessId`;
///   replay resolves PB id (or uses stored `pocketBaseId`) then deletes.
/// - **Delete already-deleted server row:** replay DELETE returns 404 → treated as
///   successful purge (ghost reconciliation).
/// - **Auth expired (401/403):** mutation enqueued with `syncStatus: paused_auth`;
///   `offlineSync.authPaused` blocks flush; mutation stays pending until re-auth.
///
/// ## Ordering / coalescing (`coalesceQueue`)
/// - FIFO preserved across distinct records.
/// - **Delete** drops all earlier pending ops for the same `businessId` (create,
///   update, stop) — local tombstone wins.
/// - **Update** merges into one pending update per `businessId` (payload union).
/// - **Start before stop** for the same record: distinct kinds are kept in order
///   unless superseded by delete.
abstract final class RecordMutationOutbox {
  static const String _prefsKey = 'record_mutation_outbox_v1';

  static const String kindHighlanderStart = 'highlander_start';
  static const String kindStopPatch = 'stop_patch';
  static const String kindRecordUpdate = 'record_update';
  static const String kindRecordDelete = 'record_delete';

  static const String syncStatusPending = 'pending';
  static const String syncStatusPausedAuth = 'paused_auth';

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final e in decoded)
          if (e is Map) Map<String, dynamic>.from(e),
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

  static Future<void> replaceAll(
    SharedPreferences prefs,
    List<Map<String, dynamic>> items,
  ) =>
      save(prefs, items);

  static String _newOperationId() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    const hex = '0123456789abcdef';
    String h2(int x) => '${hex[(x >> 4) & 15]}${hex[x & 15]}';
    return '${h2(b[0])}${h2(b[1])}${h2(b[2])}${h2(b[3])}-'
        '${h2(b[4])}${h2(b[5])}-'
        '${h2(b[6])}${h2(b[7])}-'
        '${h2(b[8])}${h2(b[9])}-'
        '${h2(b[10])}${h2(b[11])}${h2(b[12])}${h2(b[13])}${h2(b[14])}${h2(b[15])}';
  }

  static String _bizKey(Map<String, dynamic> item) =>
      (item['businessId'] ?? '').toString().trim();

  static bool _isDeleteItem(Map<String, dynamic> item) {
    final kind = (item['kind'] ?? '').toString();
    final op = (item['operationType'] ?? '').toString();
    return kind == kindRecordDelete || op == 'delete';
  }

  static bool _isRecordUpdateItem(Map<String, dynamic> item) {
    final kind = (item['kind'] ?? '').toString();
    return kind == kindRecordUpdate;
  }

  /// Collapse redundant pending work per record while preserving global FIFO order.
  ///
  /// Ordering rules (O1.4):
  /// - **highlander_start → stop_patch:** both kept in order for the same `businessId`
  ///   (Singleton Timeline: server stops old primaries on start replay, then stop PATCH).
  /// - **record_update:** merges payloads per `businessId` (edits after start in queue order).
  /// - **record_delete:** drops all earlier pending ops for the same `businessId`.
  /// - Non-retriable HTTP codes drop the item on flush (no infinite retry loop).
  static List<Map<String, dynamic>> coalesceQueue(List<Map<String, dynamic>> q) {
    final out = <Map<String, dynamic>>[];
    final updateIndexByBiz = <String, int>{};

    for (final raw in q) {
      final item = Map<String, dynamic>.from(raw);
      final biz = _bizKey(item);
      final kind = (item['kind'] ?? '').toString();

      if (_isDeleteItem(item)) {
        if (biz.isNotEmpty) {
          out.removeWhere((e) => _bizKey(e) == biz);
          updateIndexByBiz.clear();
          for (var i = 0; i < out.length; i++) {
            final candidate = out[i];
            if (_isRecordUpdateItem(candidate)) {
              updateIndexByBiz[_bizKey(candidate)] = i;
            }
          }
        }
        out.add(item);
        continue;
      }

      if (biz.isNotEmpty &&
          out.any((e) => _bizKey(e) == biz && _isDeleteItem(e))) {
        continue;
      }

      if (_isRecordUpdateItem(item)) {
        if (biz.isNotEmpty && updateIndexByBiz.containsKey(biz)) {
          final idx = updateIndexByBiz[biz]!;
          final existing = Map<String, dynamic>.from(out[idx]);
          final prevPayload = existing['payload'] is Map
              ? Map<String, dynamic>.from(existing['payload'] as Map)
              : <String, dynamic>{};
          final nextPayload = item['payload'] is Map
              ? Map<String, dynamic>.from(item['payload'] as Map)
              : <String, dynamic>{};
          existing['payload'] = <String, dynamic>{...prevPayload, ...nextPayload};
          final pb = (item['pocketBaseId'] ?? '').toString().trim();
          if (pb.isNotEmpty) existing['pocketBaseId'] = pb;
          out[idx] = existing;
          continue;
        }
        if (biz.isNotEmpty) updateIndexByBiz[biz] = out.length;
        out.add(item);
        continue;
      }

      if (kind == kindStopPatch && biz.isNotEmpty) {
        updateIndexByBiz.remove(biz);
      }
      out.add(item);
    }
    return out;
  }

  static Map<String, dynamic> _baseItem({
    required String operationType,
    required String businessId,
    required String kind,
    required Map<String, dynamic> payload,
    String? pocketBaseId,
    String? originalQueryId,
    Object? error,
    String syncStatus = syncStatusPending,
  }) {
    return <String, dynamic>{
      'operationId': _newOperationId(),
      'collection': 'records',
      'operationType': operationType,
      'businessId': businessId,
      if (pocketBaseId != null && pocketBaseId.isNotEmpty)
        'pocketBaseId': pocketBaseId,
      'kind': kind,
      'payload': payload,
      if (originalQueryId != null && originalQueryId.isNotEmpty)
        'originalQueryId': originalQueryId,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
      if (error != null) 'lastError': error.toString(),
      'syncStatus': syncStatus,
    };
  }

  static Map<String, dynamic> newHighlanderStartItem({
    required String businessId,
    required Map<String, dynamic> runningFields,
    Object? error,
    String syncStatus = syncStatusPending,
  }) =>
      _baseItem(
        operationType: 'create',
        businessId: businessId,
        kind: kindHighlanderStart,
        payload: runningFields,
        error: error,
        syncStatus: syncStatus,
      );

  static Map<String, dynamic> newStopPatchItem({
    required String businessId,
    required String pocketBaseId,
    required String originalQueryId,
    Object? error,
    String syncStatus = syncStatusPending,
  }) =>
      _baseItem(
        operationType: 'update',
        businessId: businessId,
        pocketBaseId: pocketBaseId,
        originalQueryId: originalQueryId,
        kind: kindStopPatch,
        payload: const <String, dynamic>{'status': 'stopped'},
        error: error,
        syncStatus: syncStatus,
      );

  static Map<String, dynamic> newRecordUpdateItem({
    required String businessId,
    required Map<String, dynamic> patchFields,
    String? pocketBaseId,
    required String originalQueryId,
    Object? error,
    String syncStatus = syncStatusPending,
  }) =>
      _baseItem(
        operationType: 'update',
        businessId: businessId,
        pocketBaseId: pocketBaseId,
        originalQueryId: originalQueryId,
        kind: kindRecordUpdate,
        payload: patchFields,
        error: error,
        syncStatus: syncStatus,
      );

  static Map<String, dynamic> newRecordDeleteItem({
    required String businessId,
    String? pocketBaseId,
    required String originalQueryId,
    Object? error,
    String syncStatus = syncStatusPending,
  }) =>
      _baseItem(
        operationType: 'delete',
        businessId: businessId,
        pocketBaseId: pocketBaseId,
        originalQueryId: originalQueryId,
        kind: kindRecordDelete,
        payload: const <String, dynamic>{},
        error: error,
        syncStatus: syncStatus,
      );

  static Future<void> enqueue(
    SharedPreferences prefs,
    Map<String, dynamic> item,
  ) async {
    final q = await load(prefs);
    q.add(item);
    await save(prefs, coalesceQueue(q));
  }
}
