import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/health/health_sleep_policy.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/records/unfilled_time_gap_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/health_connect/health_connect_sleep_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HealthSleepSyncPhase {
  disabled,
  unsupported,
  needsPermission,
  idle,
  syncing,
  synced,
  error,
}

@immutable
class HealthSleepSyncState {
  const HealthSleepSyncState({
    required this.enabled,
    required this.phase,
    this.lastSyncUtc,
    this.lastImportedStartUtc,
    this.lastImportedEndUtc,
    this.error,
  });

  const HealthSleepSyncState.initial()
    : enabled = false,
      phase = HealthSleepSyncPhase.disabled,
      lastSyncUtc = null,
      lastImportedStartUtc = null,
      lastImportedEndUtc = null,
      error = null;

  final bool enabled;
  final HealthSleepSyncPhase phase;
  final DateTime? lastSyncUtc;
  final DateTime? lastImportedStartUtc;
  final DateTime? lastImportedEndUtc;
  final String? error;

  HealthSleepSyncState copyWith({
    bool? enabled,
    HealthSleepSyncPhase? phase,
    DateTime? lastSyncUtc,
    DateTime? lastImportedStartUtc,
    DateTime? lastImportedEndUtc,
    String? error,
    bool clearError = false,
  }) {
    return HealthSleepSyncState(
      enabled: enabled ?? this.enabled,
      phase: phase ?? this.phase,
      lastSyncUtc: lastSyncUtc ?? this.lastSyncUtc,
      lastImportedStartUtc: lastImportedStartUtc ?? this.lastImportedStartUtc,
      lastImportedEndUtc: lastImportedEndUtc ?? this.lastImportedEndUtc,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HealthSleepSyncService with WidgetsBindingObserver {
  HealthSleepSyncService._();

  static final HealthSleepSyncService instance = HealthSleepSyncService._();

  static const String _enabledKey = 'health_sleep_sync_enabled_v1';
  static const String _lastSyncKey = 'health_sleep_last_sync_utc_v1';
  static const Duration _automaticSyncThrottle = Duration(minutes: 10);
  static const Duration _firstSyncLookback = Duration(days: 14);
  static const Duration _correctionLookback = Duration(days: 2);

  final ValueNotifier<HealthSleepSyncState> state =
      ValueNotifier<HealthSleepSyncState>(const HealthSleepSyncState.initial());

  bool _started = false;
  bool _syncing = false;
  DateTime? _lastAttemptAt;

  bool get isSupported => HealthConnectSleepService.instance.isSupported;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final lastSyncRaw = prefs.getString(_lastSyncKey);
    final lastSync = lastSyncRaw == null
        ? null
        : DateTime.tryParse(lastSyncRaw)?.toUtc();
    state.value = HealthSleepSyncState(
      enabled: enabled,
      phase: !isSupported
          ? HealthSleepSyncPhase.unsupported
          : enabled
          ? HealthSleepSyncPhase.idle
          : HealthSleepSyncPhase.disabled,
      lastSyncUtc: lastSync,
    );
    if (enabled && isSupported) unawaited(sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed && state.value.enabled) {
      unawaited(sync());
    }
  }

  Future<bool> requestAuthorizationAndEnable() async {
    await start();
    if (!isSupported) {
      state.value = state.value.copyWith(
        enabled: false,
        phase: HealthSleepSyncPhase.unsupported,
        clearError: true,
      );
      return false;
    }
    try {
      final granted = await HealthConnectSleepService.instance
          .requestAuthorization();
      if (!granted) {
        state.value = state.value.copyWith(
          enabled: false,
          phase: HealthSleepSyncPhase.needsPermission,
          clearError: true,
        );
        return false;
      }
      await setEnabled(true, syncNow: false);
      await sync(force: true);
      return true;
    } catch (e) {
      state.value = state.value.copyWith(
        enabled: false,
        phase: HealthSleepSyncPhase.error,
        error: '$e',
      );
      return false;
    }
  }

  Future<void> setEnabled(bool enabled, {bool syncNow = true}) async {
    await start();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    state.value = state.value.copyWith(
      enabled: enabled,
      phase: !isSupported
          ? HealthSleepSyncPhase.unsupported
          : enabled
          ? HealthSleepSyncPhase.idle
          : HealthSleepSyncPhase.disabled,
      clearError: true,
    );
    if (enabled && syncNow && isSupported) {
      unawaited(sync(force: true));
    }
  }

  Future<void> sync({bool force = false}) async {
    await start();
    if (_syncing || !state.value.enabled || !isSupported) return;
    final now = DateTime.now().toUtc();
    if (!force &&
        _lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < _automaticSyncThrottle) {
      return;
    }
    final db = DatabaseService.instance;
    if (!db.isInitialized || (db.currentProfileId?.isNotEmpty != true)) return;

    _syncing = true;
    _lastAttemptAt = now;
    state.value = state.value.copyWith(
      phase: HealthSleepSyncPhase.syncing,
      clearError: true,
    );
    try {
      final authorized = await HealthConnectSleepService.instance
          .hasAuthorization();
      if (!authorized) {
        state.value = state.value.copyWith(
          phase: HealthSleepSyncPhase.needsPermission,
          clearError: true,
        );
        return;
      }

      final previousSync = state.value.lastSyncUtc;
      final readStart = previousSync == null
          ? now.subtract(_firstSyncLookback)
          : previousSync.subtract(_correctionLookback);
      final sessions = await HealthConnectSleepService.instance.readSessions(
        startUtc: readStart,
        endUtc: now,
      );
      final finished = sessions
          .where((session) => !session.endUtc.isAfter(now))
          .toList(growable: false)
        ..sort((a, b) => a.endUtc.compareTo(b.endUtc));
      for (final session in finished) {
        await _importSession(session);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, now.toIso8601String());
      state.value = state.value.copyWith(
        phase: HealthSleepSyncPhase.synced,
        lastSyncUtc: now,
        clearError: true,
      );
      unawaited(UnfilledTimeGapService.instance.refresh());
    } catch (e) {
      state.value = state.value.copyWith(
        phase: HealthSleepSyncPhase.error,
        error: '$e',
      );
    } finally {
      _syncing = false;
    }
  }

  Future<void> _importSession(HealthSleepSession session) async {
    final db = DatabaseService.instance;
    final records = await db.fetchRecords(forceNetwork: false);
    final existing = findExistingSleepRecord(
      records: records,
      sleepStartUtc: session.startUtc,
      sleepEndUtc: session.endUtc,
    );
    final existingKey = existing == null ? null : recordIdentityKey(existing);

    final actions = planSleepConflictActions(
      records: records,
      sleepStartUtc: session.startUtc,
      sleepEndUtc: session.endUtc,
      existingSleepRecordKey: existingKey,
    );
    for (final action in actions) {
      switch (action.kind) {
        case SleepConflictKind.trimToSleepStart:
          await db.updateRecord(
            recordId: action.recordKey,
            endTime: session.startUtc,
            bypassConflictCheck: true,
          );
          break;
        case SleepConflictKind.delete:
          await db.deleteRecordByDocId(action.recordKey);
          break;
      }
    }

    final categoryId = await _ensureSleepCategory(db);
    if (categoryId == null) {
      throw StateError('Sleep category could not be resolved');
    }
    final title = t(currentLocale.value, 'health_sleep_record_title');

    if (existingKey != null && existingKey.isNotEmpty) {
      final updated = await db.updateRecord(
        recordId: existingKey,
        title: title,
        startTime: session.startUtc,
        endTime: session.endUtc,
        categoryId: categoryId,
        bypassConflictCheck: true,
      );
      if (updated == null) {
        throw StateError('Existing sleep record could not be updated');
      }
    } else {
      final wall = db.applyUserOffset(session.startUtc);
      final dateKey =
          '${wall.year}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';
      final businessId = await db.writeRecord(
        dateKey,
        title,
        categoryId: categoryId,
        explicitStartTime: session.startUtc,
      );
      if (businessId == null || businessId.isEmpty) {
        throw StateError('Sleep record could not be created');
      }
      await db.primaryRecordWriteNetworkChain.timeout(
        const Duration(seconds: 20),
      );
      final updated = await db.updateRecord(
        recordId: businessId,
        endTime: session.endUtc,
        categoryId: categoryId,
        bypassConflictCheck: true,
      );
      if (updated == null) {
        throw StateError('Sleep record could not be finalized');
      }
    }

    state.value = state.value.copyWith(
      lastImportedStartUtc: session.startUtc,
      lastImportedEndUtc: session.endUtc,
    );
  }

  Future<int?> _ensureSleepCategory(DatabaseService db) async {
    final english = db.getCategoryIdByParentAndTag(null, 'Sleep');
    if (english != null) return english;
    final russian = db.getCategoryIdByParentAndTag(null, 'Сон');
    if (russian != null) return russian;
    final name = currentLocale.value == 'ru' ? 'Сон' : 'Sleep';
    final tempId = -DateTime.now().microsecondsSinceEpoch;
    return db.addNestedCategory(
      null,
      CategoryRule(id: tempId, name: name, normalizedId: 'sleep'),
    );
  }
}
