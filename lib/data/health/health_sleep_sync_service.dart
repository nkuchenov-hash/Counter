import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/health/health_sleep_policy.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/records/unfilled_time_gap_service.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/health_connect/health_connect_sleep_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

enum SleepSyncSourceTransport {
  deviceHealth,
  cloudOAuth,
  webhook,
  fileImport,
  manual,
}

/// Stable adapter identifiers. New brands plug into one of the transports
/// above without changing Timeline persistence or the daily scheduler.
const Set<String> knownSleepSourceAdapterIds = <String>{
  'health_connect',
  'apple_health',
  'oura',
  'fitbit',
  'garmin',
  'whoop',
  'polar',
  'withings',
  'samsung_health',
  'huawei_health',
  'zepp',
  'mi_fitness',
};

enum HealthSleepSyncPhase {
  disabled,
  unsupported,
  needsPermission,
  idle,
  syncing,
  synced,
  noData,
  error,
}

@immutable
class HealthSleepSyncState {
  const HealthSleepSyncState({
    required this.enabled,
    required this.phase,
    this.dailySyncMinutes = 1260,
    this.backgroundReadAvailable = false,
    this.backgroundReadAuthorized = false,
    this.lastSyncUtc,
    this.lastImportedStartUtc,
    this.lastImportedEndUtc,
    this.lastReadSessionCount,
    this.lastImportedSessionCount,
    this.lastSourceSummary,
    this.error,
  });

  const HealthSleepSyncState.initial()
    : enabled = false,
      phase = HealthSleepSyncPhase.disabled,
      dailySyncMinutes = 1260,
      backgroundReadAvailable = false,
      backgroundReadAuthorized = false,
      lastSyncUtc = null,
      lastImportedStartUtc = null,
      lastImportedEndUtc = null,
      lastReadSessionCount = null,
      lastImportedSessionCount = null,
      lastSourceSummary = null,
      error = null;

  final bool enabled;
  final HealthSleepSyncPhase phase;
  final int dailySyncMinutes;
  final bool backgroundReadAvailable;
  final bool backgroundReadAuthorized;
  final DateTime? lastSyncUtc;
  final DateTime? lastImportedStartUtc;
  final DateTime? lastImportedEndUtc;
  final int? lastReadSessionCount;
  final int? lastImportedSessionCount;
  final String? lastSourceSummary;
  final String? error;

  HealthSleepSyncState copyWith({
    bool? enabled,
    HealthSleepSyncPhase? phase,
    int? dailySyncMinutes,
    bool? backgroundReadAvailable,
    bool? backgroundReadAuthorized,
    DateTime? lastSyncUtc,
    DateTime? lastImportedStartUtc,
    DateTime? lastImportedEndUtc,
    int? lastReadSessionCount,
    int? lastImportedSessionCount,
    String? lastSourceSummary,
    String? error,
    bool clearError = false,
  }) {
    return HealthSleepSyncState(
      enabled: enabled ?? this.enabled,
      phase: phase ?? this.phase,
      dailySyncMinutes: dailySyncMinutes ?? this.dailySyncMinutes,
      backgroundReadAvailable:
          backgroundReadAvailable ?? this.backgroundReadAvailable,
      backgroundReadAuthorized:
          backgroundReadAuthorized ?? this.backgroundReadAuthorized,
      lastSyncUtc: lastSyncUtc ?? this.lastSyncUtc,
      lastImportedStartUtc: lastImportedStartUtc ?? this.lastImportedStartUtc,
      lastImportedEndUtc: lastImportedEndUtc ?? this.lastImportedEndUtc,
      lastReadSessionCount: lastReadSessionCount ?? this.lastReadSessionCount,
      lastImportedSessionCount:
          lastImportedSessionCount ?? this.lastImportedSessionCount,
      lastSourceSummary: lastSourceSummary ?? this.lastSourceSummary,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@pragma('vm:entry-point')
void healthSleepBackgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != HealthSleepSyncService.backgroundTaskName &&
        taskName != Workmanager.iOSBackgroundTask) {
      return true;
    }

    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(HealthSleepSyncService.enabledPrefsKey) ?? false)) {
        return true;
      }

      final db = DatabaseService.instance;
      await db.ensurePocketBaseReady();
      final profileId = await AuthBridge.checkSession();
      if (profileId == null || profileId.isEmpty) return true;

      db.currentProfileId = profileId;
      final loaded = await db.loadInitialData(profileId);
      if (!loaded || !db.isInitialized) return false;

      final language = db.settings.primaryLanguage.trim();
      if (language.isNotEmpty) {
        currentLocale.value = resolvedUiLanguageCode(language);
      }

      await HealthSleepSyncService.instance.start(
        manageBackgroundSchedule: false,
      );
      await HealthSleepSyncService.instance.sync(force: true);
      return HealthSleepSyncService.instance.state.value.phase !=
          HealthSleepSyncPhase.error;
    } catch (_) {
      return false;
    }
  });
}

class HealthSleepSyncService {
  HealthSleepSyncService._();

  static final HealthSleepSyncService instance = HealthSleepSyncService._();

  static const String enabledPrefsKey = 'health_sleep_sync_enabled_v1';
  static const String _lastSyncKey = 'health_sleep_last_sync_utc_v1';
  static const String _dailySyncMinutesKey =
      'health_sleep_daily_sync_minutes_v1';
  static const int defaultDailySyncMinutes = 21 * 60;
  static const String iosBackgroundTaskIdentifier =
      'com.example.counter.sleep-sync';
  static const String backgroundTaskName = 'health_sleep_background_sync_v1';
  static const String _androidBackgroundTaskUniqueName =
      'health_sleep_background_periodic_v1';
  static const String _backgroundTaskTag = 'health_sleep_background_tag_v1';
  static const Duration _automaticSyncThrottle = Duration(minutes: 10);
  static const Duration _firstSyncLookback = Duration(days: 30);
  static const Duration _correctionLookback = Duration(days: 2);
  static const Duration _backgroundFrequency = Duration(minutes: 30);

  final ValueNotifier<HealthSleepSyncState> state =
      ValueNotifier<HealthSleepSyncState>(const HealthSleepSyncState.initial());

  bool _started = false;
  bool _syncing = false;
  bool _workmanagerInitialized = false;
  DateTime? _lastAttemptAt;

  bool get isSupported => DeviceHealthSleepService.instance.isSupported;

  String get activeDeviceSourceName =>
      DeviceHealthSleepService.instance.sourceName;

  String get _backgroundTaskUniqueName => Platform.isIOS
      ? iosBackgroundTaskIdentifier
      : _androidBackgroundTaskUniqueName;

  Future<void> start({bool manageBackgroundSchedule = true}) async {
    if (!_started) {
      _started = true;
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(enabledPrefsKey) ?? false;
      final lastSyncRaw = prefs.getString(_lastSyncKey);
      final lastSync = lastSyncRaw == null
          ? null
          : DateTime.tryParse(lastSyncRaw)?.toUtc();
      final storedMinutes =
          prefs.getInt(_dailySyncMinutesKey) ?? defaultDailySyncMinutes;
      final dailySyncMinutes = storedMinutes.clamp(0, 1439).toInt();
      state.value = HealthSleepSyncState(
        enabled: enabled,
        phase: !isSupported
            ? HealthSleepSyncPhase.unsupported
            : enabled
            ? HealthSleepSyncPhase.idle
            : HealthSleepSyncPhase.disabled,
        dailySyncMinutes: dailySyncMinutes,
        lastSyncUtc: lastSync,
      );
    }

    if (manageBackgroundSchedule && isSupported) {
      await _ensureWorkmanagerInitialized();
      await _refreshBackgroundAccessAndSchedule();
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
      final granted = await DeviceHealthSleepService.instance
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
      await requestBackgroundAuthorizationAndSchedule();
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

  Future<bool> requestBackgroundAuthorizationAndSchedule() async {
    await start();
    if (!isSupported || !state.value.enabled) return false;
    try {
      final available = await DeviceHealthSleepService.instance
          .isBackgroundReadAvailable();
      var authorized = false;
      if (available) {
        authorized = await DeviceHealthSleepService.instance
            .requestBackgroundAuthorization();
      }
      state.value = state.value.copyWith(
        backgroundReadAvailable: available,
        backgroundReadAuthorized: authorized,
        clearError: true,
      );
      await _applyBackgroundSchedule();
      return authorized;
    } catch (e) {
      state.value = state.value.copyWith(error: '$e');
      return false;
    }
  }

  Future<void> setEnabled(bool enabled, {bool syncNow = false}) async {
    await start();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledPrefsKey, enabled);
    state.value = state.value.copyWith(
      enabled: enabled,
      phase: !isSupported
          ? HealthSleepSyncPhase.unsupported
          : enabled
          ? HealthSleepSyncPhase.idle
          : HealthSleepSyncPhase.disabled,
      clearError: true,
    );
    await _refreshBackgroundAccessAndSchedule();
    if (enabled && syncNow && isSupported) {
      unawaited(sync(force: true));
    }
  }

  Future<void> sync({bool force = false}) async {
    await start(manageBackgroundSchedule: false);
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
      final authorized = await DeviceHealthSleepService.instance
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
      final sessions = await DeviceHealthSleepService.instance.readSessions(
        startUtc: readStart,
        endUtc: now,
      );
      final finished =
          sessions
              .where((session) => !session.endUtc.isAfter(now))
              .toList(growable: false)
            ..sort((a, b) => a.endUtc.compareTo(b.endUtc));

      var importedCount = 0;
      for (final session in finished) {
        await _importSession(session);
        importedCount++;
      }

      final sourceNames =
          finished
              .map((session) => session.sourceName.trim())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList(growable: false)
            ..sort();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, now.toIso8601String());
      state.value = state.value.copyWith(
        phase: finished.isEmpty
            ? HealthSleepSyncPhase.noData
            : HealthSleepSyncPhase.synced,
        lastSyncUtc: now,
        lastReadSessionCount: finished.length,
        lastImportedSessionCount: importedCount,
        lastSourceSummary: sourceNames.join(', '),
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

  Future<void> setDailySyncMinutes(int minutes) async {
    await start();
    final normalized = minutes.clamp(0, 1439).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailySyncMinutesKey, normalized);
    state.value = state.value.copyWith(dailySyncMinutes: normalized);
    await _applyBackgroundSchedule();
  }

  Future<void> _ensureWorkmanagerInitialized() async {
    if (_workmanagerInitialized ||
        kIsWeb ||
        !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    await Workmanager().initialize(healthSleepBackgroundCallbackDispatcher);
    _workmanagerInitialized = true;
  }

  Future<void> _refreshBackgroundAccessAndSchedule() async {
    if (!isSupported || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    try {
      final available = await DeviceHealthSleepService.instance
          .isBackgroundReadAvailable();
      final authorized = available
          ? await DeviceHealthSleepService.instance.hasBackgroundAuthorization()
          : false;
      state.value = state.value.copyWith(
        backgroundReadAvailable: available,
        backgroundReadAuthorized: authorized,
      );
      await _applyBackgroundSchedule();
    } catch (e) {
      state.value = state.value.copyWith(error: '$e');
    }
  }

  Future<void> _applyBackgroundSchedule() async {
    if (kIsWeb ||
        !(Platform.isAndroid || Platform.isIOS) ||
        !_workmanagerInitialized) {
      return;
    }
    if (state.value.enabled && state.value.backgroundReadAuthorized) {
      await Workmanager().registerPeriodicTask(
        _backgroundTaskUniqueName,
        backgroundTaskName,
        frequency: _backgroundFrequency,
        initialDelay: Duration.zero,
        tag: _backgroundTaskTag,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      return;
    }
    await Workmanager().cancelByTag(_backgroundTaskTag);
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
      final createdId = await db.writeRecord(
        dateKey,
        title,
        categoryId: categoryId,
        explicitStartTime: session.startUtc,
        explicitEndTime: session.endUtc,
      );
      if (createdId == null || createdId.isEmpty) {
        throw StateError('Sleep record could not be created');
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
