import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

final class PlanMutationReceipt {
  const PlanMutationReceipt({
    required this.operationId,
    required this.revision,
    required this.kind,
    required this.businessId,
  });

  final String operationId;
  final int revision;
  final String kind;
  final String businessId;
}

/// Local-only queue for PocketBase **plans** mutations (Planning + Lists).
///
/// Writes are serialized. Every coalesced mutation carries a monotonically
/// increasing revision so an older network response cannot acknowledge a newer
/// edit for the same plan.
abstract final class PlanMutationOutbox {
  static const String _prefsKey = 'plan_mutation_outbox_v1';
  static const String _legacyCreateKey = 'plan_create_outbox_v1';

  static const String kindPlanCreate = 'plan_create';
  static const String kindPlanUpdate = 'plan_update';
  static const String kindPlanDelete = 'plan_delete';

  static const String syncStatusPending = 'pending';
  static const String syncStatusPausedAuth = 'paused_auth';

  /// Reserved local payload keys. They are removed before scalar PocketBase writes.
  static const String payloadTagsLinkKey = '__tags_link_pb_ids';
  static const String payloadTagsSnapshotKey = '__tags_snapshot';

  static Future<void> _writeChain = Future<void>.value();

  static Future<T> _withWriteLock<T>(Future<T> Function() action) async {
    final previous = _writeChain;
    final release = Completer<void>();
    _writeChain = release.future;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }

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

  static Future<List<Map<String, dynamic>>> load(SharedPreferences prefs) async {
    final current = _decode(prefs.getString(_prefsKey));
    if (current.isNotEmpty) return current;
    return _migrateLegacyCreates(prefs);
  }

  static Future<List<Map<String, dynamic>>> _migrateLegacyCreates(
    SharedPreferences prefs,
  ) async {
    final legacy = _decode(prefs.getString(_legacyCreateKey));
    if (legacy.isEmpty) return [];
    final migrated = <Map<String, dynamic>>[];
    for (final item in legacy) {
      final wrapped = item['body'];
      if (wrapped is! Map) continue;
      final body = Map<String, dynamic>.from(wrapped);
      final biz = (body['plan_id'] ?? '').toString().trim();
      if (biz.isEmpty) continue;
      migrated.add(
        newPlanCreateItem(
          businessId: biz,
          payload: body,
          createdAt: (item['enqueuedAt'] as num?)?.toInt(),
        ),
      );
    }
    if (migrated.isNotEmpty) {
      await save(prefs, migrated);
      await prefs.remove(_legacyCreateKey);
    }
    return migrated;
  }

  static Future<void> save(
    SharedPreferences prefs,
    List<Map<String, dynamic>> items,
  ) async {
    await prefs.setString(_prefsKey, jsonEncode(items));
  }

  static Future<void> replaceAll(
    SharedPreferences prefs,
    List<Map<String, dynamic>> items,
  ) => _withWriteLock(() => save(prefs, items));

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
    return kind == kindPlanDelete || op == 'delete';
  }

  static bool _isCreateItem(Map<String, dynamic> item) =>
      (item['kind'] ?? '').toString() == kindPlanCreate;

  static bool _isUpdateItem(Map<String, dynamic> item) =>
      (item['kind'] ?? '').toString() == kindPlanUpdate;

  static int _revisionOf(Map<String, dynamic> item) =>
      (item['revision'] as num?)?.toInt() ?? 1;

  static List<Map<String, dynamic>> coalesceQueue(List<Map<String, dynamic>> q) {
    final out = <Map<String, dynamic>>[];
    final updateIndexByBiz = <String, int>{};

    for (final raw in q) {
      final item = Map<String, dynamic>.from(raw);
      final biz = _bizKey(item);

      if (_isCreateItem(item) && biz.isNotEmpty) {
        final existingIndex = out.indexWhere(
          (e) => _bizKey(e) == biz && _isCreateItem(e),
        );
        if (existingIndex >= 0) {
          final existing = out[existingIndex];
          item['operationId'] = existing['operationId'];
          item['createdAt'] = existing['createdAt'];
          item['revision'] = _revisionOf(existing) + 1;
          out[existingIndex] = item;
          continue;
        }
      }

      if (_isDeleteItem(item)) {
        if (biz.isNotEmpty) {
          out.removeWhere((e) => _bizKey(e) == biz);
          updateIndexByBiz.clear();
          for (var i = 0; i < out.length; i++) {
            final candidate = out[i];
            if (_isUpdateItem(candidate)) {
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

      if (_isUpdateItem(item)) {
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
          existing['revision'] = _revisionOf(existing) + 1;
          existing['syncStatus'] = item['syncStatus'];
          if (item.containsKey('lastError')) {
            existing['lastError'] = item['lastError'];
          }
          out[idx] = existing;
          continue;
        }
        if (biz.isNotEmpty) updateIndexByBiz[biz] = out.length;
        out.add(item);
        continue;
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
    int? createdAt,
  }) {
    return <String, dynamic>{
      'operationId': _newOperationId(),
      'revision': 1,
      'collection': 'plans',
      'operationType': operationType,
      'businessId': businessId,
      if (pocketBaseId != null && pocketBaseId.isNotEmpty)
        'pocketBaseId': pocketBaseId,
      'kind': kind,
      'payload': payload,
      if (originalQueryId != null && originalQueryId.isNotEmpty)
        'originalQueryId': originalQueryId,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
      if (error != null) 'lastError': error.toString(),
      'syncStatus': syncStatus,
    };
  }

  static Map<String, dynamic> newPlanCreateItem({
    required String businessId,
    required Map<String, dynamic> payload,
    Object? error,
    String syncStatus = syncStatusPending,
    int? createdAt,
  }) =>
      _baseItem(
        operationType: 'create',
        businessId: businessId,
        kind: kindPlanCreate,
        payload: payload,
        originalQueryId: businessId,
        error: error,
        syncStatus: syncStatus,
        createdAt: createdAt,
      );

  static Map<String, dynamic> newPlanUpdateItem({
    required String businessId,
    required Map<String, dynamic> patchFields,
    String? pocketBaseId,
    required String originalQueryId,
    List<String>? tagsLinkPbIds,
    Object? error,
    String syncStatus = syncStatusPending,
  }) {
    final payload = Map<String, dynamic>.from(patchFields);
    if (tagsLinkPbIds != null) {
      payload[payloadTagsLinkKey] = tagsLinkPbIds;
    }
    return _baseItem(
      operationType: 'update',
      businessId: businessId,
      pocketBaseId: pocketBaseId,
      originalQueryId: originalQueryId,
      kind: kindPlanUpdate,
      payload: payload,
      error: error,
      syncStatus: syncStatus,
    );
  }

  static Map<String, dynamic> newPlanDeleteItem({
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
        kind: kindPlanDelete,
        payload: const <String, dynamic>{},
        error: error,
        syncStatus: syncStatus,
      );

  static PlanMutationReceipt? receiptForItem(Map<String, dynamic> item) {
    final operationId = (item['operationId'] ?? '').toString().trim();
    final kind = (item['kind'] ?? '').toString().trim();
    final businessId = _bizKey(item);
    if (operationId.isEmpty || kind.isEmpty || businessId.isEmpty) return null;
    return PlanMutationReceipt(
      operationId: operationId,
      revision: _revisionOf(item),
      kind: kind,
      businessId: businessId,
    );
  }

  static bool _matchesReceipt(
    Map<String, dynamic> item,
    PlanMutationReceipt receipt,
  ) =>
      (item['operationId'] ?? '').toString() == receipt.operationId &&
      _revisionOf(item) == receipt.revision &&
      (item['kind'] ?? '').toString() == receipt.kind &&
      _bizKey(item) == receipt.businessId;

  static Future<PlanMutationReceipt?> enqueue(
    SharedPreferences prefs,
    Map<String, dynamic> item,
  ) => _withWriteLock(() async {
    final q = await load(prefs);
    q.add(item);
    final next = coalesceQueue(q);
    await save(prefs, next);
    final businessId = _bizKey(item);
    final kind = (item['kind'] ?? '').toString();
    for (final candidate in next.reversed) {
      if (_bizKey(candidate) == businessId &&
          (candidate['kind'] ?? '').toString() == kind) {
        return receiptForItem(candidate);
      }
    }
    return null;
  });

  static Future<bool> acknowledge(
    SharedPreferences prefs,
    PlanMutationReceipt? receipt,
  ) => _withWriteLock(() async {
    if (receipt == null) return false;
    final q = await load(prefs);
    final next = q.where((item) => !_matchesReceipt(item, receipt)).toList();
    if (next.length == q.length) return false;
    await save(prefs, next);
    return true;
  });

  static Future<bool> markRetryIfCurrent(
    SharedPreferences prefs,
    PlanMutationReceipt? receipt, {
    required String lastError,
    String? syncStatus,
  }) => _withWriteLock(() async {
    if (receipt == null) return false;
    final q = await load(prefs);
    var changed = false;
    final next = <Map<String, dynamic>>[];
    for (final raw in q) {
      final item = Map<String, dynamic>.from(raw);
      if (_matchesReceipt(item, receipt)) {
        item['retryCount'] = ((item['retryCount'] as num?)?.toInt() ?? 0) + 1;
        item['lastError'] = lastError;
        if (syncStatus != null) item['syncStatus'] = syncStatus;
        changed = true;
      }
      next.add(item);
    }
    if (changed) await save(prefs, next);
    return changed;
  });

  static Future<void> removePendingForBusinessId(
    SharedPreferences prefs,
    String businessId,
  ) => _withWriteLock(() async {
    final biz = businessId.trim();
    if (biz.isEmpty) return;
    final q = await load(prefs);
    if (q.isEmpty) return;
    final next = q.where((e) => _bizKey(e) != biz).toList();
    if (next.length != q.length) {
      await save(prefs, next);
    }
  });
}
