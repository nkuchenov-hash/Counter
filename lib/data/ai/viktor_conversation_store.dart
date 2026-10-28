import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:counter/data/database_service.dart';

/// Only explicit user/assistant turns are persisted; provider credentials,
/// system prompts and private tool-observation payloads are never stored here.
class ViktorDialogueTurn {
  const ViktorDialogueTurn({required this.role, required this.content,
    this.sentAtUtc, this.messageDay, this.messageTimezone});

  final String role;
  final String content;
  final DateTime? sentAtUtc;
  final String? messageDay;
  final String? messageTimezone;
  bool get isUser => role == 'user';

  /// Natural-language retries must resolve to a real prior user instruction.
  static bool isRepeatCommand(String value) {
    final normalized = value.toLowerCase().trim()
        .replaceAll(RegExp(r'[.!?]+$'), '').trim();
    return RegExp(
      r'^(?:повторить|повтори|выполни ещё раз|сделай ещё раз)'
      r'\s+(?:последнюю|предыдущую|последнюю мою)'
      r'\s+(?:команду|просьбу|задачу|запрос)$',
    ).hasMatch(normalized);
  }

  static String? lastRepeatableUserRequest(
      Iterable<ViktorDialogueTurn> turns) {
    for (final turn in turns.toList().reversed) {
      if (turn.isUser && turn.content.trim().isNotEmpty &&
          !isRepeatCommand(turn.content)) {
        return turn.content;
      }
    }
    return null;
  }

  /// Remote history is authoritative, but unacknowledged locally visible
  /// messages must remain on screen if they are absent on the server.
  static List<ViktorDialogueTurn> reconcileVisible(
      List<ViktorDialogueTurn> remote, List<ViktorDialogueTurn> visible) {
    final remaining = <int>{for (var i = 0; i < remote.length; i++) i};
    final unsynced = <ViktorDialogueTurn>[];
    for (final local in visible) {
      int? match;
      for (final index in remaining) {
        if (remote[index].role == local.role &&
            remote[index].content == local.content) {
          match = index;
          break;
        }
      }
      if (match != null) {
        remaining.remove(match);
      } else {
        unsynced.add(local);
      }
    }
    return [...remote, ...unsynced];
  }

  /// Pin the original user itinerary, the latest timed draft and the user's
  /// own timezone correction. Without these anchors, repeated tool errors can
  /// evict the exact original stops and switch the clock back to profile zone.
  /// All entries remain user/assistant turns (no synthetic system authority).
  static List<Map<String, String>> modelContext(
      Iterable<ViktorDialogueTurn> turns, {int maxTurns = 12}) {
    final accepted = turns.where((turn) =>
        (turn.role == 'user' || turn.role == 'assistant') &&
        turn.content.trim().isNotEmpty).map((turn) {
      final timedDraft = turn.role == 'assistant' &&
          RegExp(r'\b\d{1,2}:\d{2}\s*[-–—]\s*\d{1,2}:\d{2}')
              .allMatches(turn.content).length >= 3;
      final originalBrief = turn.role == 'user' &&
          turn.content.length > 150 &&
          RegExp(r'расплан|расписани|маршрут|суббот|встреч|itinerary|schedule',
              caseSensitive: false).hasMatch(turn.content);
      final cap = timedDraft ? 6000 : originalBrief ? 3000 : 1200;
      return <String, String>{
        'role': turn.role,
        'content': turn.content.length > cap
            ? turn.content.substring(0, cap) : turn.content,
        if (turn.sentAtUtc != null)
          'sent_at_utc': turn.sentAtUtc!.toUtc().toIso8601String(),
        if (turn.messageDay != null) 'message_day': turn.messageDay!,
        if (turn.messageTimezone != null)
          'message_timezone': turn.messageTimezone!,
      };
    }).toList();
    if (accepted.length <= maxTurns || maxTurns <= 3) {
      return accepted.length <= maxTurns
          ? accepted : accepted.sublist(accepted.length - maxTurns);
    }
    final recent = accepted.sublist(accepted.length - maxTurns);
    // Anchors are relevant ONLY while the latest turns discuss the itinerary.
    final latestUserTurns = accepted.reversed.where(
        (turn) => turn['role'] == 'user').take(4).toList();
    final continuingPlan = latestUserTurns.any((turn) => RegExp(
      r'план|расписани|встан|подъ[её]м|загс|тыкв|москв|мск|'
      r'часов|new york|дорог|бар|маршрут|встреч|schedule|itinerary',
      caseSensitive: false,
    ).hasMatch(turn['content'] ?? ''));
    if (!continuingPlan) return recent;

    bool isDraft(Map<String, String> turn) =>
        turn['role'] == 'assistant' &&
        RegExp(r'\b\d{1,2}:\d{2}\s*[-–—]\s*\d{1,2}:\d{2}')
            .allMatches(turn['content'] ?? '').length >= 3;
    final draftIndex = accepted.lastIndexWhere(isDraft);
    if (draftIndex < 0) return recent;
    final originalIndex = accepted.lastIndexWhere((turn) =>
        turn['role'] == 'user' &&
        (turn['content'] ?? '').length > 150 &&
        RegExp(r'расплан|расписани|суббот|маршрут|itinerary|schedule',
          caseSensitive: false).hasMatch(turn['content'] ?? ''), draftIndex);
    final timezoneIndex = accepted.lastIndexWhere((turn) =>
        turn['role'] == 'user' &&
        RegExp(r'по\s+москв|мск\b|время.{0,24}москв|'
          r'по\s+нью[- ]йорк|время.{0,24}new york|'
          r'по\s+берлин|время.{0,24}берлин',
          caseSensitive: false).hasMatch(turn['content'] ?? ''));
    final recentStart = accepted.length - maxTurns;
    final pinned = <int>{
      if (originalIndex >= 0 && originalIndex < recentStart) originalIndex,
      if (draftIndex < recentStart) draftIndex,
      if (timezoneIndex >= 0 && timezoneIndex < recentStart) timezoneIndex,
    }.toList()..sort();
    if (pinned.isEmpty) return recent;
    return [
      for (final i in pinned) accepted[i],
      ...accepted.skip(accepted.length - (maxTurns - pinned.length)),
    ];
  }
}

class ViktorThread {
  const ViktorThread({required this.id, required this.title,
    this.updatedAtUtc});
  final String id;
  final String title;
  final DateTime? updatedAtUtc;
}

/// Owner-scoped multi-thread history. Legacy 'main' remains untouched.
///
/// This is user-controlled PocketBase data, not long-term semantic memory.
class ViktorConversationStore {
  ViktorConversationStore(this.db);

  final DatabaseService db;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const int maxPendingTurns = 200;
  static const String collectionName = 'viktor_turns';
  static const String mainConversation = 'main';
  static const String threadsCollection = 'viktor_threads';
  String activeConversationId = mainConversation;
  final Set<String> _knownThreads = {};
  static bool validConversationId(String value) =>
      value == mainConversation ||
      RegExp(r'^chat_[0-9]+_[0-9]+$').hasMatch(value);
  static String newConversationId() =>
      'chat_${DateTime.now().microsecondsSinceEpoch}_'
      '${DateTime.now().millisecondsSinceEpoch % 1000000}';
  void selectConversation(String value) {
    if (!validConversationId(value)) {
      throw ArgumentError.value(value, 'conversation_id');
    }
    activeConversationId = value;
  }
  Future<void> _writeTail = Future<void>.value();
  int _sequence = 0;
  String? _pendingOwner;
  bool _secureStorageUnavailable = false;
  bool _outboxUnreadable = false;

  /// The original encrypted queue could not be read. Do not overwrite it
  /// before a later retry succeeds, even if server writes currently work.
  bool get localOutboxUnreadable => _outboxUnreadable;

  /// If encryption/storage fails and PocketBase is also unreachable,
  /// unsent turns can only survive while this page remains open.
  bool get pendingInMemoryOnly =>
      _secureStorageUnavailable && _pending.isNotEmpty;
  final List<({String owner, String id, String role, String body,
    String thread, String? sentUtc, String? messageDay, String? timezone})>
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
    if (_pendingOwner == owner &&
        (!_outboxUnreadable || _pending.isNotEmpty)) return;
    // Preserve the previous signed-in user's outbox across account switches.
    // Never send the old owner's turns using the new session.
    if (_pendingOwner != null && _pending.isNotEmpty) {
      await _saveOutbox();
    }
    String? raw;
    try {
      raw = await _secureStorage.read(key: _outboxKey(owner));
      _secureStorageUnavailable = false;
      _outboxUnreadable = false;
    } catch (_) {
      // A full or unavailable browser secure store must not prevent fetching
      // already-saved dialogue from PocketBase.
      if (_pending.isNotEmpty) {
        throw StateError('Невозможно сменить аккаунт с '
            'несохранённой локальной историей.');
      }
      _pendingOwner = owner;
      _secureStorageUnavailable = true;
      _outboxUnreadable = true;
      return;
    }
    final restored = <({String owner, String id, String role, String body,
      String thread, String? sentUtc, String? messageDay, String? timezone})>[];
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
        // Original encrypted outboxes did not include a thread or clock.
        final thread = (item['thread'] ?? mainConversation).toString();
        if (!validConversationId(thread)) {
          throw StateError('Некорректный диалог в очереди Виктора.');
        }
        restored.add((owner: owner, id: id, role: role as String,
            body: body, thread: thread,
            sentUtc: item['sentUtc']?.toString(),
            messageDay: item['messageDay']?.toString(),
            timezone: item['timezone']?.toString()));
      }
    }
    _pending..clear()..addAll(restored);
    _pendingOwner = owner;
  }

  Future<void> _saveOutbox() async {
    final owner = _pendingOwner;
    if (owner == null) throw StateError('Виктор не определил аккаунт.');
    if (_outboxUnreadable) {
      _secureStorageUnavailable = true;
      throw StateError('Предыдущая защищённая очередь недоступна для чтения. '
          'Не перезаписываем её до восстановления доступа.');
    }
    try {
      await _secureStorage.write(
        key: _outboxKey(owner),
        value: jsonEncode([
          for (final item in _pending)
            {'id': item.id, 'role': item.role, 'body': item.body,
             'thread': item.thread,
             if (item.sentUtc != null) 'sentUtc': item.sentUtc,
             if (item.messageDay != null) 'messageDay': item.messageDay,
             if (item.timezone != null) 'timezone': item.timezone},
        ]),
      );
      _secureStorageUnavailable = false;
    } catch (_) {
      _secureStorageUnavailable = true;
      rethrow;
    }
  }

  Future<void> _ensureThread(String owner, String thread, String title) async {
    if (thread == mainConversation || _knownThreads.contains(thread)) return;
    final collection = db.pocketBase.collection(threadsCollection);
    final filter = 'user_id = "$owner" && thread_key = "$thread"';
    final existing = await collection.getList(
        page: 1, perPage: 1, filter: filter);
    if (existing.items.isEmpty) {
      final clean = title.replaceAll(RegExp(r'\s+'), ' ').trim();
      final name = clean.isEmpty ? 'Новый разговор' :
          clean.substring(0, clean.length > 90 ? 90 : clean.length);
      try {
        await collection.create(body: {
          'user_id': owner, 'thread_key': thread, 'title': name,
        });
      } catch (_) {
        // A different device may already have created the same thread.
        final verified = await collection.getList(
            page: 1, perPage: 1, filter: filter);
        if (verified.items.isEmpty) rethrow;
      }
    }
    _knownThreads.add(thread);
  }

  Future<List<ViktorThread>> loadThreads() async {
    final owner = _owner();
    await _restoreOutbox(owner);
    final threads = <ViktorThread>[
      const ViktorThread(id: mainConversation, title: 'Общий чат'),
    ];
    try {
      await db.ensurePocketBaseReady();
      final result = await db.pocketBase.collection(threadsCollection).getList(
        page: 1, perPage: 100, sort: '-updated,-id',
        filter: 'user_id = "$owner"',
      );
      for (final record in result.items) {
        final id = (record.data['thread_key'] ?? '').toString();
        if (!validConversationId(id) || id == mainConversation) continue;
        _knownThreads.add(id);
        threads.add(ViktorThread(
          id: id, title: (record.data['title'] ?? 'Разговор').toString(),
          updatedAtUtc: DateTime.tryParse(record.updated)?.toUtc(),
        ));
      }
    } catch (_) {
      // Online history stays visible if the thread index is temporarily down.
    }
    for (final item in _pending) {
      if (item.owner != owner || item.thread == mainConversation ||
          threads.any((thread) => thread.id == item.thread)) continue;
      threads.add(ViktorThread(id: item.thread,
          title: item.body.length > 90
              ? item.body.substring(0, 90) : item.body));
    }
    if (activeConversationId != mainConversation &&
        !threads.any((thread) => thread.id == activeConversationId)) {
      threads.add(ViktorThread(id: activeConversationId,
          title: 'Новый разговор'));
    }
    return threads;
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
        await _ensureThread(owner, item.thread, item.body);
        await collection.create(body: {
          'user_id': owner,
          'conversation_id': item.thread,
          'client_turn_id': item.id,
          'role': item.role,
          'body': item.body,
          if (item.sentUtc != null) 'sent_at_utc': item.sentUtc,
          if (item.messageDay != null) 'message_day': item.messageDay,
          if (item.timezone != null) 'message_timezone': item.timezone,
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