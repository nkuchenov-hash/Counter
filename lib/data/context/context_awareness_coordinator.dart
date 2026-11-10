import 'dart:async';
import 'dart:convert';

import 'package:counter/data/context/context_awareness_policy.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    _profileId = profileId;
    unawaited(_attachIfEnabled(profileId));
  }

  Future<void> _attachIfEnabled(String profileId) async {
    try {
      final current = await status();
      if (_profileId != profileId || current['enabled'] != true) return;
      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.addObserver(this);
      _timer?.cancel();
      _timer = Timer.periodic(_pollInterval, (_) => unawaited(poll()));
      unawaited(poll());
    } catch (_) {
      // Optional feature: never hold the shell or throw on a missing bridge.
    }
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
  static String _visitReviewKey(String owner) => 'context_visit_reviews_$owner';
  static String _transportReviewKey(String owner) => 'context_transport_reviews_$owner';

  String? get _ownerForReview =>
      _profileId ?? DatabaseService.instance.currentProfileId;

  Future<List<Map<String, dynamic>>> pendingTransportReviews() async {
    final owner = _ownerForReview;
    if (owner == null || owner.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    try {
      final rows = jsonDecode(prefs.getString(_transportReviewKey(owner)) ?? '[]');
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          if (row is Map<String, dynamic>) Map<String, dynamic>.from(row),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _queueTransportReview(
      String owner, ContextAwarenessEvent event, String recordId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await pendingTransportReviews();
    if (all.any((row) => row['eventId'] == event.id)) return;
    all.add({
      'eventId': event.id,
      'recordId': recordId,
      'atUtc': event.atUtc.toIso8601String(),
    });
    if (all.length > 40) all.removeRange(0, all.length - 40);
    await prefs.setString(_transportReviewKey(owner), jsonEncode(all));
  }

  Future<void> dismissTransportReview(String eventId) async {
    final owner = _ownerForReview;
    if (owner == null) return;
    final prefs = await SharedPreferences.getInstance();
    final all = await pendingTransportReviews();
    all.removeWhere((row) => row['eventId'] == eventId);
    await prefs.setString(_transportReviewKey(owner), jsonEncode(all));
  }

  Future<bool> labelTransport(String eventId, String title) async {
    final owner = _ownerForReview;
    if (owner == null || owner != DatabaseService.instance.currentProfileId ||
        !ContextTimelinePolicy.isSpecificTransportTitle(title)) return false;
    final all = await pendingTransportReviews();
    final found = all.where((row) => row['eventId'] == eventId);
    if (found.isEmpty) return false;
    final id = found.first['recordId']?.toString() ?? '';
    if (id.isEmpty) return false;
    final updated = await DatabaseService.instance.updateRecord(
      recordId: id, title: title,
    );
    if (updated == null) return false;
    await dismissTransportReview(eventId);
    return true;
  }

  Future<List<Map<String, dynamic>>> pendingVisitReviews() async {
    final owner = _ownerForReview;
    if (owner == null || owner.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    try {
      final decoded = jsonDecode(prefs.getString(_visitReviewKey(owner)) ?? '[]');
      if (decoded is! List) return const [];
      return [
        for (final row in decoded)
          if (row is Map<String, dynamic>) Map<String, dynamic>.from(row),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _queueVisitReview(
      String owner, ContextAwarenessEvent event, String recordId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await pendingVisitReviews();
    if (all.any((row) => row['eventId'] == event.id)) return;
    all.add({
      'eventId': event.id,
      'recordId': recordId,
      'atUtc': event.atUtc.toIso8601String(),
      if (event.latitude != null) 'latitude': event.latitude,
      if (event.longitude != null) 'longitude': event.longitude,
      if (event.accuracy != null) 'accuracy': event.accuracy,
    });
    // Bound the local review inbox; old items remain ordinary editable records.
    if (all.length > 40) all.removeRange(0, all.length - 40);
    await prefs.setString(_visitReviewKey(owner), jsonEncode(all));
  }

  Future<void> dismissVisitReview(String eventId) async {
    final owner = _ownerForReview;
    if (owner == null) return;
    final prefs = await SharedPreferences.getInstance();
    final all = await pendingVisitReviews();
    all.removeWhere((row) => row['eventId'] == eventId);
    await prefs.setString(_visitReviewKey(owner), jsonEncode(all));
  }

  Future<List<String>> suggestVisitAddresses(Map<String, dynamic> review) async {
    if (!supported) return const [];
    final lat = review['latitude'];
    final lng = review['longitude'];
    if (lat is! num || lng is! num) return const [];
    try {
      return await _channel.invokeListMethod<String>('suggestPlaces', {
        'latitude': lat.toDouble(),
        'longitude': lng.toDouble(),
      }) ?? const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<bool> labelVisit(String eventId, String title) async {
    final owner = _ownerForReview;
    final cleaned = title.trim();
    if (owner == null || cleaned.isEmpty || cleaned.length > 160 ||
        owner != DatabaseService.instance.currentProfileId) return false;
    final reviews = await pendingVisitReviews();
    final matches = reviews.where((row) => row['eventId'] == eventId);
    if (matches.isEmpty) return false;
    final recordId = matches.first['recordId']?.toString() ?? '';
    if (recordId.isEmpty) return false;
    final updated = await DatabaseService.instance.updateRecord(
      recordId: recordId, title: cleaned,
    );
    if (updated == null) return false;
    await dismissVisitReview(eventId);
    return true;
  }

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
      final events = ContextAwarenessEvent.decode(raw);
      // Hydrate only once per batch; never fetch all history for every signal.
      if (events.isNotEmpty) await db.fetchRecords();
      for (final event in events) {
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
        final parentText = parent?.toString().trim() ?? '';
        return parentText.isEmpty || parentText == '0';
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
    final rows = db.contextAwarenessCachedRecords();
    final running = _runningPrimaries(rows);
    if (running.length > 1) return true; // ambiguous: do not risk another record
    final active = running.isEmpty ? null : running.single;
    final activeId = active == null ? '' : _rowId(active);
    final ourActive = autoId != null && autoId == activeId &&
        (autoKind == 'travel'
            ? ContextTimelinePolicy.isAutoTravelTitle(
                (active?['title'] ?? '').toString())
            : autoKind == 'visit');

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
        Namespace.url.value, 'lifeos/context/$owner/${event.id}/$kind',
      );
      final projected = db.applyUserOffset(event.atUtc);
      final dateKey = DateFormat('yyyy-MM-dd').format(projected);
      final written = await db.writeRecord(
        dateKey, title,
        explicitStartTime: event.atUtc,
        stableCreateBusinessId: id,
      );
      if (written == null) return false;
      if (kind == 'visit') await _queueVisitReview(owner, event, written);
      if (kind == 'travel' && event.mode == 'vehicle') {
        await _queueTransportReview(owner, event, written);
      }
      await prefs.setString(_activeKey(owner), written);
      await prefs.setString(_kindKey(owner), kind);
      return true;
    }

    final russian = currentLocale.value.toLowerCase().startsWith('ru');
    switch (event.kind) {
      case 'left_home':
        // Signals can be delivered late: never rewrite newer manual facts.
        if (_laterManualFactsExist(rows, event.atUtc, activeAutoId: autoId)) return true;
        // The same native event can replay after a crash before acknowledgement.
        // Never terminate and recreate its already-running inferred trip.
        if (ourActive && autoKind == 'travel') return true;
        if (active != null && !ourActive) {
          if (!ContextTimelinePolicy.canEndOnDeparture(active, event.atUtc)) {
            return true; // never overwrite a later or non-running record
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
        final title = ContextTimelinePolicy.titleForTravel(
          event.mode, russian: russian,
        );
        if (ourActive && autoKind == 'travel') {
          final currentTitle = (active?['title'] ?? '').toString().trim();
          if (currentTitle == title) return true;
          // A confirmed user label such as 'Metro' is more precise than the
          // vehicle classifier. Do not erase it with generic 'Vehicle trip'.
          if (event.mode == 'vehicle' &&
              ContextTimelinePolicy.isSpecificTransportTitle(currentTitle)) {
            return true;
          }
          if (currentTitle == 'В пути' || currentTitle == 'Travel') {
            // The first mode resolves the initial undifferentiated segment.
            final changed = await db.updateRecord(
              recordId: activeId, title: title,
            );
            if (changed == null) return false;
            if (event.mode == 'vehicle') {
              await _queueTransportReview(owner, event, activeId);
            }
            return true;
          }
          // Preserve each leg (walk -> vehicle -> walk) as a real interval.
          if (!await endAuto()) return false;
          return startAuto('travel', title);
        }
        if (ourActive && autoKind == 'visit') {
          if (!await endAuto()) return false;
          return startAuto('travel', title);
        }
        return true;
      case 'stationary_away':
        if (ourActive && autoKind == 'visit') return true;
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
