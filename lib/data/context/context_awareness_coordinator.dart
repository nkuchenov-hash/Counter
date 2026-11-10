import 'dart:async';

import 'package:counter/data/context/context_awareness_policy.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Android native geofences and motion updates continue while Flutter is closed.
/// Only after authentication/Brain hydration do we reconcile queued events.
/// Not a boot gate, not a Timeline rebuild listener, and not a GPS polling loop.
class ContextAwarenessCoordinator with WidgetsBindingObserver {
  ContextAwarenessCoordinator._();

  static final instance = ContextAwarenessCoordinator._();
  static const _channel = MethodChannel('counter/context_awareness');
  static const _pollInterval = Duration(minutes: 2);
  static const _maxEventAge = Duration(hours: 36);

  String? _profileId;
  Timer? _timer;
  bool _polling = false;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<Map<String, dynamic>> status() async {
    if (!supported) return const {'enabled': false, 'homeSet': false};
    final value = await _channel.invokeMapMethod<String, dynamic>('status');
    return value ?? const {'enabled': false, 'homeSet': false};
  }

  Future<Map<String, dynamic>> setHomeHere() async {
    if (!supported) throw StateError('Android location is required');
    final result = await _channel.invokeMapMethod<String, dynamic>('setHome');
    return result ?? const {};
  }

  Future<Map<String, dynamic>> enable(String profileId) async {
    if (!supported || profileId.trim().isEmpty) {
      throw StateError('An authenticated Android account is required');
    }
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'enable',
      {'profileId': profileId},
    );
    attach(profileId);
    return result ?? const {};
  }

  Future<void> disable() async {
    _timer?.cancel();
    _timer = null;
    final oldId = _profileId;
    _profileId = null;
    WidgetsBinding.instance.removeObserver(this);
    if (supported) await _channel.invokeMethod<void>('disable');
    if (oldId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeKey(oldId));
      await prefs.remove(_kindKey(oldId));
    }
  }

  /// Attach after first shell frame and on sign-in; zero work on app launch
  /// when disabled. Native registration is exclusively user-initiated in Settings.
  void attach(String profileId) {
    if (!supported || profileId.isEmpty) return;
    if (_profileId == profileId && _timer != null) return;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _profileId = profileId;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(poll()));
    unawaited(poll());
  }

  Future<void> stopForSignOut() async {
    try {
      await disable();
    } catch (_) {
      _timer?.cancel();
      _timer = null;
      _profileId = null;
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(poll());
  }

  static String _activeKey(String owner) => 'context_auto_record_$owner';
  static String _kindKey(String owner) => 'context_auto_kind_$owner';

  Future<void> poll() async {
    final owner = _profileId;
    final db = DatabaseService.instance;
    if (!supported || owner == null || _polling ||
        db.currentProfileId != owner || !db.isInitialized ||
        !db.pocketBase.authStore.isValid) return;
    _polling = true;
    try {
      final nativeStatus = await status();
      if (nativeStatus['enabled'] != true) return;
      final raw = await _channel.invokeMethod<String>(
        'events', {'profileId': owner},
      ) ?? '[]';
      for (final event in ContextAwarenessEvent.decode(raw)) {
        // Old signals cannot be applied safely to an already-edited Timeline.
        final age = DateTime.now().toUtc().difference(event.atUtc);
        if (age.isNegative || age > _maxEventAge) {
          await _ack(owner, event.id);
          continue;
        }
        final handled = await _reconcile(owner, event, db);
        if (!handled) break; // transient failure: leave event in durable native queue
        await _ack(owner, event.id);
      }
    } on PlatformException {
      // Location or sensor permissions may have been revoked. Retry when
      // Settings reopens; never affect normal record creation.
    } catch (_) {
      // Context awareness is strictly optional and cannot fail the shell.
    } finally {
      _polling = false;
    }
  }

  Future<void> _ack(String owner, String eventId) async {
    await _channel.invokeMethod<void>('acknowledge', {
      'profileId': owner,
      'eventId': eventId,
    });
  }

  static String _rowId(Map<String, dynamic> row) =>
      (row['record_id'] ?? row['id'] ?? '').toString().trim();

  static List<Map<String, dynamic>> _runningPrimaries(
      List<Map<String, dynamic>> records) =>
      records.where((row) {
        if (!ContextTimelinePolicy.isRunning(row)) return false;
        final parent = row['parent_id'];
        return parent == null || parent.toString().trim().isEmpty;
      }).toList();

  static bool _laterManualFactsExist(
      List<Map<String, dynamic>> records, DateTime atUtc,
      {String? activeAutoId}) {
    for (final row in records) {
      if (_rowId(row) == activeAutoId) continue;
      final start = ContextTimelinePolicy.startedAt(row);
      if (start != null && start.isAfter(atUtc)) return true;
    }
    return false;
  }

  Future<bool> _reconcile(
    String owner,
    ContextAwarenessEvent event,
    DatabaseService db,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final autoId = prefs.getString(_activeKey(owner));
    final autoKind = prefs.getString(_kindKey(owner));
    // No full-history projection or refresh after each row mutation.
    final rows = await db.fetchRecords();
    final running = _runningPrimaries(rows);
    if (running.length > 1) return true; // ambiguous: do not risk another record
    final active = running.isEmpty ? null : running.single;
    final activeId = active == null ? '' : _rowId(active);
    final ourActive = autoId != null && autoId == activeId &&
        (autoKind == 'travel'
            ? ContextTimelinePolicy.isAutoTravelTitle(
                (active?['title'] ?? '').toString())
            : (active?['title'] ?? '').toString().trim() == 'Вне дома' ||
              (active?['title'] ?? '').toString().trim() == 'Away from home');

    Future<bool> endAuto() async {
      if (!ourActive || active == null) return true;
      final started = ContextTimelinePolicy.startedAt(active);
      if (started == null || !event.atUtc.isAfter(started)) return true;
      final changed = await db.updateRecord(
        recordId: activeId, endTime: event.atUtc,
      );
      if (changed == null) return false;
      await prefs.remove(_activeKey(owner));
      await prefs.remove(_kindKey(owner));
      return true;
    }

    Future<bool> startAuto(String kind, String title) async {
      if (_laterManualFactsExist(rows, event.atUtc, activeAutoId: autoId)) {
        return true;
      }
      // The stable id makes replay after app/process failure idempotent.
      final id = const Uuid().v5(
        Namespace.url, 'lifeos/context/$owner/${event.id}/$kind',
      );
      final projected = db.applyUserOffset(event.atUtc);
      final dateKey = DateFormat('yyyy-MM-dd').format(projected);
      final written = await db.writeRecord(
        dateKey, title,
        explicitStartTime: event.atUtc,
        stableCreateBusinessId: id,
      );
      if (written == null) return false;
      await prefs.setString(_activeKey(owner), written);
      await prefs.setString(_kindKey(owner), kind);
      return true;
    }

    final russian = currentLocale.value.toLowerCase().startsWith('ru');
    switch (event.kind) {
      case 'left_home':
        if (active != null && !ourActive) {
          if (!ContextTimelinePolicy.canEndHomeRecord(active, event.atUtc)) {
            return true; // not a location-bound record: never overwrite it
          }
          final changed = await db.updateRecord(
            recordId: activeId, endTime: event.atUtc,
          );
          if (changed == null) return false;
        } else if (ourActive && !await endAuto()) {
          return false;
        }
        return startAuto(
          'travel', ContextTimelinePolicy.titleForTravel('', russian: russian));
      case 'moving':
        if (ourActive && autoKind == 'travel') {
          final title = ContextTimelinePolicy.titleForTravel(
            event.mode, russian: russian,
          );
          if (active?['title'] == title) return true;
          final changed = await db.updateRecord(
            recordId: activeId, title: title,
          );
          return changed != null;
        }
        if (ourActive && autoKind == 'visit') {
          if (!await endAuto()) return false;
          return startAuto('travel', ContextTimelinePolicy.titleForTravel(
            event.mode, russian: russian,
          ));
        }
        return true;
      case 'stationary_away':
        if (!ourActive || autoKind != 'travel') return true;
        if (!await endAuto()) return false;
        return startAuto('visit', ContextTimelinePolicy.visitTitle(russian: russian));
      case 'arrived_home':
        return endAuto();
      default:
        return true;
    }
  }
}
