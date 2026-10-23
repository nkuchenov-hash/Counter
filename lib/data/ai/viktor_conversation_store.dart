import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:counter/data/database_service.dart';

/// Only explicit user/assistant turns are persisted; provider credentials,
/// system prompts and private tool-observation payloads are never stored here.
class ViktorDialogueTurn {
  const ViktorDialogueTurn({required this.role, required this.content});

  final String role;
  final String content;
  bool get isUser => role == 'user';

  static List<Map<String, String>> modelContext(
    Iterable<ViktorDialogueTurn> turns, {int maxTurns = 12}) {
    final accepted = turns.where((turn) =>
        (turn.role == 'user' || turn.role == 'assistant') &&
        turn.content.trim().isNotEmpty).map((turn) => <String, String>{
      'role': turn.role,
      'content': turn.content.length > 1200
          ? turn.content.substring(0, 1200) : turn.content,
    }).toList();
    return accepted.length <= maxTurns ? accepted
        : accepted.sublist(accepted.length - maxTurns);
  }
}

/// Persistent single-conversation dialogue for the authenticated LIFE OS
/// owner. One immutable row per turn, rather than a shared JSON blob, keeps
/// messages from two devices from overwriting each other.
///
/// This is user-controlled PocketBase data, not long-term semantic memory.
class ViktorConversationStore {
  ViktorConversationStore(this.db);

  final DatabaseService db;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const int maxPendingTurns = 200;
  static const String collectionName = 'viktor_turns';
  static const String mainConversation = 'main';
  Future<void> _writeTail = Future<void>.value();
  int _sequence = 0;
  String? _pendingOwner;
  bool _secureStorageUnavailable = false;

  /// If encryption/storage fails and PocketBase is also unreachable,
  /// unsent turns can only survive while this page remains open.
  bool get pendingInMemoryOnly =>
      _secureStorageUnavailable && _pending.isNotEmpty;
  final List<({String owner, String id, String role, String body})>
      _pending = [];

  /// Unsent turns survive app restarts in account-scoped encrypted storage.
  /// Failed writes retain stable client_turn_id values for safe retries.
  int get pendingCount => _pending.length;

  String _owner() {
    final userId = db.pocketBase.authStore.record?.id ?? '';
    if (userId.isEmpty || db.pocketBase.authStore.token.trim().isEmpty) {
      throw StateError('Войдите в LIFE OS для истории Виктора.');
    }
    return userId;
  }

  String _outboxKey(String owner) => 'viktor_turn_outbox_v1_$owner';

  Future<void> _restoreOutbox(String owner) async {
    if (_pendingOwner == owner) return;
    // Preserve the previous signed-in user's outbox across account switches.
    // Never send the old owner's turns using the new session.
    if (_pendingOwner != null && _pending.isNotEmpty) {
      await _saveOutbox();
    }
    String? raw;
    try {
      raw = await _secureStorage.read(key: _outboxKey(owner));
      _secureStorageUnavailable = false;
    } catch (_) {
      // A full or unavailable browser secure store must not prevent fetching
      // already-saved dialogue from PocketBase.
      if (_pending.isNotEmpty) {
        throw StateError('Невозможно сменить аккаунт с '
            'несохранённой локальной историей.');
      }
      _pendingOwner = owner;
      _secureStorageUnavailable = true;
      return;
    }
    final restored = <({String owner, String id, String role, String body})>[];
    if (raw != null && raw.isNotEmpty) {
      final data = jsonDecode(raw);
      if (data is! List || data.length > maxPendingTurns) {
        throw StateError('Локальная очередь истории Виктора повреждена.');
      }
      final ids = <String>{};
      for (final item in data) {
        if (item is! Map) {
          throw StateError('Некорректная локальная очередь Виктора.');
        }
        final id = item['id'];
        final role = item['role'];
        final body = item['body'];
        if (id is! String || id.length > 96 ||
            !RegExp(r'^turn_[0-9]+_[0-9]+$').hasMatch(id) ||
            !ids.add(id) ||
            (role != 'user' && role != 'assistant') ||
            body is! String || body.isEmpty || body.length > 6000) {
          throw StateError('Некорректная реплика в очереди Виктора.');
        }
        restored.add((owner: owner, id: id, role: role as String,
            body: body));
      }
    }
    _pending..clear()..addAll(restored);
    _pendingOwner = owner;
  }

  Future<void> _saveOutbox() async {
    final owner = _pendingOwner;
    if (owner == null) throw StateError('Виктор не определил аккаунт.');
    try {
      await _secureStorage.write(
        key: _outboxKey(owner),
        value: jsonEncode([
          for (final item in _pending)
            {'id': item.id, 'role': item.role, 'body': item.body},
        ]),
      );
      _secureStorageUnavailable = false;
    } catch (_) {
      _secureStorageUnavailable = true;
      rethrow;
    }
  }

  /// Every successful remote write is removed from the encrypted queue.
  /// On an uncertain network response, read by the unique client ID before
  /// retrying. A failed lookup must not drop the turn.
  Future<void> _flush(String owner) async {
    if (_pending.isEmpty) return;
    await db.ensurePocketBaseReady();
    if (_owner() != owner || _pendingOwner != owner) {
      throw StateError('Аккаунт изменился; отправка истории остановлена.');
    }
    final collection = db.pocketBase.collection(collectionName);
    while (_pending.isNotEmpty) {
      final item = _pending.first;
      if (item.owner != owner) {
        throw StateError('Нельзя отправлять историю другого аккаунта.');
      }
      try {
        await collection.create(body: {
          'user_id': owner,
          'conversation_id': mainConversation,
          'client_turn_id': item.id,
          'role': item.role,
          'body': item.body,
        });
      } catch (_) {
        final existing = await collection.getList(
          page: 1,
          perPage: 1,
          filter: 'user_id = "$owner" && client_turn_id = "${item.id}"',
        );
        if (existing.items.isEmpty ||
            existing.items.single.data['role'] != item.role ||
            existing.items.single.data['body'] != item.body) {
          rethrow;
        }
      }
      // PocketBase already acknowledged (or deduplicated) this turn. Do
      // not classify a successful server write as unsynced merely because
      // the browser cannot rewrite its encrypted local cache.
      _pending.removeAt(0);
      try {
        await _saveOutbox();
      } catch (_) {
        // An older encrypted snapshot may still contain the turn.
        // Its stable client_turn_id is deduplicated on the next load.
        // Never reinsert an already-acknowledged row in the live queue.
      }
    }
  }

  Future<List<ViktorDialogueTurn>> load() async {
    final owner = _owner();
    await _restoreOutbox(owner);
    // Restore local turns even when the network is unavailable.
    try {
      await _flush(owner);
    } catch (_) {
      // Pending turns remain encrypted locally until the next retry.
    }
    try {
      await db.ensurePocketBaseReady();
      final rows = await db.pocketBase.collection(collectionName).getList(
        page: 1,
        perPage: 60,
        sort: '-created,-id',
        filter: 'user_id = "$owner" && conversation_id = "main"',
      );
      final serverIds = <String>{};
      final turns = <ViktorDialogueTurn>[];
      for (final record in rows.items.reversed) {
        final data = record.data;
        final role = data['role']?.toString() ?? '';
        final body = data['body']?.toString() ?? '';
        if (role != 'user' && role != 'assistant') continue;
        if (body.trim().isEmpty) continue;
        serverIds.add(data['client_turn_id']?.toString() ?? '');
        turns.add(ViktorDialogueTurn(role: role, content: body));
      }
      for (final item in _pending) {
        if (!serverIds.contains(item.id)) {
          turns.add(ViktorDialogueTurn(role: item.role, content: item.body));
        }
      }
      return turns;
    } catch (_) {
      if (_pending.isEmpty) rethrow;
      return [
        for (final item in _pending)
          ViktorDialogueTurn(role: item.role, content: item.body),
      ];
    }
  }

  /// Explicit retry does not enqueue a new conversational turn. Use the same
  /// serialized queue as regular appends to avoid races with user messages.
  Future<void> retryPending() {
    final owner = _owner();
    final next = _writeTail.catchError((Object _) {}).then((_) async {
      await _restoreOutbox(owner);
      await _flush(owner);
    });
    _writeTail = next;
    return next;
  }

  /// Enqueue encrypted before attempting the network write. Operations are
  /// serialized so two incoming turns cannot overwrite the same outbox.
  Future<void> append(ViktorDialogueTurn turn) {
    if (turn.role != 'user' && turn.role != 'assistant') {
      throw ArgumentError.value(turn.role, 'role', 'Invalid dialogue role');
    }
    if (turn.content.trim().isEmpty) return Future<void>.value();
    final ownerAtSubmission = _owner();
    final text = turn.content.length <= 6000 ? turn.content
        : '${turn.content.substring(0, 5950)}\n[Сообщение обрезано при сохранении]';
    final id = 'turn_${DateTime.now().microsecondsSinceEpoch}_${++_sequence}';
    final next = _writeTail.catchError((Object _) {}).then((_) async {
      await _restoreOutbox(ownerAtSubmission);
      if (_pending.length >= maxPendingTurns) {
        throw StateError('Очередь истории Виктора заполнена. '
            'Синхронизируйте её перед отправкой новых сообщений.');
      }
      _pending.add((owner: ownerAtSubmission, id: id,
          role: turn.role, body: text));
      try {
        await _saveOutbox();
      } catch (_) {
        // Browser storage quota/security failure is not a server error.
        // Still attempt to save the actual user message in PocketBase now.
        // If offline too, keep it in memory and expose the durability risk.
        try {
          await _flush(ownerAtSubmission);
          return;
        } catch (_) {
          throw StateError('История не сохранилась ни на сервере, '
              'ни в защищённом хранилище. Не закрывайте эту вкладку '
              'до восстановления синхронизации.');
        }
      }
      await _flush(ownerAtSubmission);
    });
    _writeTail = next;
    return next;
  }

}