import 'dart:async';

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
  static const String collectionName = 'viktor_turns';
  static const String mainConversation = 'main';
  Future<void> _writeTail = Future<void>.value();
  int _sequence = 0;
  final List<({String owner, String id, String role, String body})>
      _pending = [];

  /// Failed writes stay in memory and are retried, in order, with stable
  /// client_turn_id values. Until successfully synced they must remain
  /// visible to the user; closing the chat still discards this queue.
  int get pendingCount => _pending.length;

  String _owner() {
    final userId = db.pocketBase.authStore.record?.id ?? '';
    if (userId.isEmpty || db.pocketBase.authStore.token.trim().isEmpty) {
      throw StateError('Войдите в LIFE OS для истории Виктора.');
    }
    return userId;
  }

  Future<List<ViktorDialogueTurn>> load() async {
    await db.ensurePocketBaseReady();
    final ownerId = _owner();
    final rows = await db.pocketBase.collection(collectionName).getList(
      page: 1,
      perPage: 60,
      sort: '-created,-id',
      filter: 'user_id = "$ownerId" && conversation_id = "main"',
    );
    // Read only user/assistant roles, never reinterpret a stored row as a
    // system message even if a malformed historic record slips through.
    final turns = <ViktorDialogueTurn>[];
    for (final record in rows.items.reversed) {
      final data = record.data;
      final role = data['role']?.toString() ?? '';
      final body = data['body']?.toString() ?? '';
      if ((role == 'user' || role == 'assistant') && body.trim().isNotEmpty) {
        turns.add(ViktorDialogueTurn(role: role, content: body));
      }
    }
    return turns;
  }

  /// Serializes all writes and retries earlier failed turns before later
  /// ones. A server timeout may happen *after* PocketBase committed a row;
  /// check its unique client_turn_id before retrying so each turn is saved
  /// exactly once in the owner's conversation.
  Future<void> append(ViktorDialogueTurn turn) {
    if (turn.role != 'user' && turn.role != 'assistant') {
      throw ArgumentError.value(turn.role, 'role', 'Invalid dialogue role');
    }
    if (turn.content.trim().isEmpty) return Future<void>.value();
    final ownerAtSubmission = _owner();
    final body = turn.content.length <= 6000 ? turn.content
        : '${turn.content.substring(0, 5970)}\n[Сообщение обрезано при сохранении]';
    final sequence = ++_sequence;
    final id = 'turn_${DateTime.now().microsecondsSinceEpoch}_$sequence';
    _pending.add((owner: ownerAtSubmission, id: id,
      role: turn.role, body: body));
    final next = _writeTail.catchError((Object _) {}).then((_) async {
      await db.ensurePocketBaseReady();
      if (_owner() != ownerAtSubmission) {
        throw StateError('Аккаунт изменился; история не отправлена.');
      }
      while (_pending.isNotEmpty) {
        final item = _pending.first;
        if (item.owner != ownerAtSubmission) {
          throw StateError('Аккаунт изменился; прежняя очередь не отправлена.');
        }
        final collection = db.pocketBase.collection(collectionName);
        try {
          await collection.create(body: {
            'user_id': item.owner,
            'conversation_id': mainConversation,
            'client_turn_id': item.id,
            'role': item.role,
            'body': item.body,
          });
        } catch (_) {
          // A timeout could mean the server persisted the turn. An explicit
          // owner-scoped lookup disambiguates that from a failed mutation.
          // Never drop a turn when this confirmation is unavailable.
          final existing = await collection.getList(
            page: 1,
            perPage: 1,
            filter: 'user_id = "${item.owner}" && '
                'client_turn_id = "${item.id}"',
          );
          if (existing.items.isEmpty) rethrow;
        }
        _pending.removeAt(0);
      }
    });
    _writeTail = next;
    return next;
  }

}