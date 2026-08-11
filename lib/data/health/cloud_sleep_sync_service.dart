import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:counter/core/constants.dart';
import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/health/health_sleep_policy.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/records/unfilled_time_gap_service.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

enum CloudSleepSyncPhase { disconnected, connecting, connected, syncing, error }

@immutable
class CloudSleepSyncState {
  const CloudSleepSyncState({
    required this.configured,
    required this.enabled,
    required this.phase,
    this.dailySyncMinutes = 21 * 60,
    this.lastSyncUtc,
    this.lastSessionCount = 0,
    this.lastImportedCount = 0,
    this.error,
  });

  const CloudSleepSyncState.initial()
    : configured = false,
      enabled = false,
      phase = CloudSleepSyncPhase.disconnected,
      dailySyncMinutes = 21 * 60,
      lastSyncUtc = null,
      lastSessionCount = 0,
      lastImportedCount = 0,
      error = null;

  final bool configured;
  final bool enabled;
  final CloudSleepSyncPhase phase;
  final int dailySyncMinutes;
  final DateTime? lastSyncUtc;
  final int lastSessionCount;
  final int lastImportedCount;
  final String? error;

  CloudSleepSyncState copyWith({
    bool? configured,
    bool? enabled,
    CloudSleepSyncPhase? phase,
    int? dailySyncMinutes,
    DateTime? lastSyncUtc,
    int? lastSessionCount,
    int? lastImportedCount,
    String? error,
    bool clearError = false,
  }) {
    return CloudSleepSyncState(
      configured: configured ?? this.configured,
      enabled: enabled ?? this.enabled,
      phase: phase ?? this.phase,
      dailySyncMinutes: dailySyncMinutes ?? this.dailySyncMinutes,
      lastSyncUtc: lastSyncUtc ?? this.lastSyncUtc,
      lastSessionCount: lastSessionCount ?? this.lastSessionCount,
      lastImportedCount: lastImportedCount ?? this.lastImportedCount,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class _FitSleepSession {
  const _FitSleepSession({
    required this.externalId,
    required this.startUtc,
    required this.endUtc,
  });

  final String externalId;
  final DateTime startUtc;
  final DateTime endUtc;
}

@pragma('vm:entry-point')
void googleFitSleepBackgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != CloudSleepSyncService.backgroundTaskName) return true;
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
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
      await CloudSleepSyncService.instance.loadStatus(scheduleBackground: false);
      if (!CloudSleepSyncService.instance.state.value.enabled) return true;
      return CloudSleepSyncService.instance.syncNow(interactive: false);
    } catch (_) {
      return false;
    }
  });
}

class CloudSleepSyncService {
  CloudSleepSyncService._();

  static final CloudSleepSyncService instance = CloudSleepSyncService._();

  static const String _fitScope =
      'https://www.googleapis.com/auth/fitness.sleep.read';
  static const String _configuredKey = 'google_fit_sleep_configured_v2';
  static const String _enabledKey = 'google_fit_sleep_enabled_v2';
  static const String _historyCompleteKey = 'google_fit_sleep_history_complete_v2';
  static const String _lastSyncKey = 'google_fit_sleep_last_sync_utc_v2';
  static const String _dailyMinutesKey = 'google_fit_sleep_daily_minutes_v2';
  static const String _recordMapKey = 'google_fit_sleep_record_map_v2';
  static const Duration _correctionLookback = Duration(days: 7);
  static const Duration _backgroundFrequency = Duration(hours: 6);
  static const String backgroundTaskName = 'google_fit_sleep_sync';
  static const String _backgroundTaskUniqueName = 'google_fit_sleep_sync_periodic';
  static const String _backgroundTaskTag = 'google_fit_sleep_sync';

  final ValueNotifier<CloudSleepSyncState> state =
      ValueNotifier<CloudSleepSyncState>(const CloudSleepSyncState.initial());

  late final GoogleSignIn _googleSignIn = kIsWeb
      ? GoogleSignIn(scopes: const <String>['email', 'profile'])
      : GoogleSignIn(
          scopes: const <String>['email', 'profile'],
          serverClientId: kGoogleWebClientId,
        );

  bool _loading = false;
  bool _syncing = false;
  bool _workmanagerInitialized = false;

  Future<void> loadStatus({bool scheduleBackground = true}) async {
    if (_loading) return;
    _loading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final configured = prefs.getBool(_configuredKey) ?? false;
      final enabled = prefs.getBool(_enabledKey) ?? configured;
      final rawLastSync = prefs.getString(_lastSyncKey);
      final lastSync = rawLastSync == null
          ? null
          : DateTime.tryParse(rawLastSync)?.toUtc();
      final dailyMinutes = (prefs.getInt(_dailyMinutesKey) ?? 21 * 60)
          .clamp(0, 1439)
          .toInt();
      state.value = CloudSleepSyncState(
        configured: configured,
        enabled: enabled,
        phase: configured
            ? CloudSleepSyncPhase.connected
            : CloudSleepSyncPhase.disconnected,
        dailySyncMinutes: dailyMinutes,
        lastSyncUtc: lastSync,
        lastSessionCount: state.value.lastSessionCount,
        lastImportedCount: state.value.lastImportedCount,
      );
      if (scheduleBackground && configured && enabled) {
        await _applyBackgroundSchedule();
      }
    } catch (error) {
      state.value = state.value.copyWith(
        phase: CloudSleepSyncPhase.error,
        error: '$error',
      );
    } finally {
      _loading = false;
    }
  }

  Future<String?> _accessToken({required bool interactive}) async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    if (account == null && interactive) {
      account = await _googleSignIn.signIn();
    }
    if (account == null) return null;
    if (interactive) {
      final granted = await _googleSignIn.requestScopes(const <String>[_fitScope]);
      if (!granted) return null;
    }
    final auth = await account.authentication;
    final token = auth.accessToken?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  Future<bool> connectGoogleFit() async {
    state.value = state.value.copyWith(
      phase: CloudSleepSyncPhase.connecting,
      clearError: true,
    );
    try {
      final token = await _accessToken(interactive: true);
      if (token == null) {
        throw StateError('Google Fit permission was not granted');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_configuredKey, true);
      await prefs.setBool(_enabledKey, true);
      state.value = state.value.copyWith(
        configured: true,
        enabled: true,
        phase: CloudSleepSyncPhase.connected,
        clearError: true,
      );
      await _applyBackgroundSchedule();
      return _syncWithToken(token, forceFullHistory: true);
    } catch (error) {
      state.value = state.value.copyWith(
        phase: CloudSleepSyncPhase.error,
        error: '$error',
      );
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    state.value = state.value.copyWith(
      enabled: enabled,
      phase: state.value.configured
          ? CloudSleepSyncPhase.connected
          : CloudSleepSyncPhase.disconnected,
      clearError: true,
    );
    await _applyBackgroundSchedule();
    return true;
  }

  Future<bool> setDailySyncMinutes(int minutes) async {
    final normalized = minutes.clamp(0, 1439).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyMinutesKey, normalized);
    state.value = state.value.copyWith(dailySyncMinutes: normalized);
    return true;
  }

  Future<bool> syncNow({bool interactive = true}) async {
    if (_syncing || !state.value.configured || !state.value.enabled) return false;
    try {
      final token = await _accessToken(interactive: interactive);
      if (token == null) {
        if (!interactive) return false;
        throw StateError('Google Fit session expired. Connect Google Fit again.');
      }
      final prefs = await SharedPreferences.getInstance();
      final historyComplete = prefs.getBool(_historyCompleteKey) ?? false;
      return _syncWithToken(token, forceFullHistory: !historyComplete);
    } catch (error) {
      state.value = state.value.copyWith(
        phase: CloudSleepSyncPhase.error,
        error: '$error',
      );
      return false;
    }
  }

  Future<bool> _syncWithToken(
    String token, {
    required bool forceFullHistory,
  }) async {
    if (_syncing) return false;
    _syncing = true;
    state.value = state.value.copyWith(
      phase: CloudSleepSyncPhase.syncing,
      clearError: true,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc();
      DateTime start;
      if (forceFullHistory || !(prefs.getBool(_historyCompleteKey) ?? false)) {
        start = DateTime.utc(2000, 1, 1);
      } else {
        final rawLast = prefs.getString(_lastSyncKey);
        final last = rawLast == null ? null : DateTime.tryParse(rawLast)?.toUtc();
        start = (last ?? now.subtract(const Duration(days: 30)))
            .subtract(_correctionLookback);
      }

      final sessions = await _fetchSleepSessions(token, start, now);
      final imported = await _importSessions(sessions);
      await prefs.setBool(_historyCompleteKey, true);
      await prefs.setString(_lastSyncKey, now.toIso8601String());
      state.value = state.value.copyWith(
        configured: true,
        enabled: true,
        phase: CloudSleepSyncPhase.connected,
        lastSyncUtc: now,
        lastSessionCount: sessions.length,
        lastImportedCount: imported,
        clearError: true,
      );
      unawaited(UnfilledTimeGapService.instance.refresh());
      return true;
    } catch (error) {
      state.value = state.value.copyWith(
        phase: CloudSleepSyncPhase.error,
        error: '$error',
      );
      return false;
    } finally {
      _syncing = false;
    }
  }

  Future<List<_FitSleepSession>> _fetchSleepSessions(
    String accessToken,
    DateTime start,
    DateTime end,
  ) async {
    final result = <_FitSleepSession>[];
    String? pageToken;
    var page = 0;
    do {
      final params = <String, String>{
        'startTime': start.toUtc().toIso8601String(),
        'endTime': end.toUtc().toIso8601String(),
        'activityType': '72',
        if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      };
      final uri = Uri.https(
        'www.googleapis.com',
        '/fitness/v1/users/me/sessions',
        params,
      );
      final response = await http.get(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = response.body.trim();
        throw StateError(
          'Google Fit sleep read failed (${response.statusCode})${detail.isEmpty ? '' : ': $detail'}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected Google Fit response');
      }
      final rows = decoded['session'];
      if (rows is List) {
        for (final raw in rows) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          final startMs = int.tryParse('${row['startTimeMillis'] ?? ''}');
          final endMs = int.tryParse('${row['endTimeMillis'] ?? ''}');
          if (startMs == null || endMs == null || endMs <= startMs) continue;
          final startUtc = DateTime.fromMillisecondsSinceEpoch(
            startMs,
            isUtc: true,
          );
          final endUtc = DateTime.fromMillisecondsSinceEpoch(
            endMs,
            isUtc: true,
          );
          if (endUtc.isAfter(DateTime.now().toUtc())) continue;
          final app = row['application'];
          final appMap = app is Map ? Map<String, dynamic>.from(app) : const <String, dynamic>{};
          final appId = '${appMap['packageName'] ?? appMap['name'] ?? 'google_fit'}';
          final sessionId = '${row['id'] ?? ''}'.trim();
          final externalId = sessionId.isNotEmpty
              ? '$appId|$sessionId'
              : '$appId|${startUtc.toIso8601String()}|${endUtc.toIso8601String()}';
          result.add(
            _FitSleepSession(
              externalId: externalId,
              startUtc: startUtc,
              endUtc: endUtc,
            ),
          );
        }
      }
      pageToken = '${decoded['nextPageToken'] ?? ''}'.trim();
      page++;
      if (page > 500) {
        throw StateError('Google Fit returned too many history pages');
      }
    } while (pageToken.isNotEmpty);

    final byId = <String, _FitSleepSession>{};
    for (final session in result) {
      byId[session.externalId] = session;
    }
    final sessions = byId.values.toList(growable: false)
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return sessions;
  }

  Future<int> _importSessions(List<_FitSleepSession> sessions) async {
    if (sessions.isEmpty) return 0;
    final db = DatabaseService.instance;
    if (!db.isInitialized) {
      throw StateError('LIFE OS database is not ready');
    }
    final categoryId = await _ensureSleepCategory(db);
    if (categoryId == null) {
      throw StateError('Sleep category could not be resolved');
    }
    final records = await db.fetchRecords(forceNetwork: false);
    final prefs = await SharedPreferences.getInstance();
    final mapRaw = prefs.getString(_recordMapKey);
    final recordMap = <String, String>{};
    if (mapRaw != null && mapRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(mapRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = '${entry.key}'.trim();
            final value = '${entry.value}'.trim();
            if (key.isNotEmpty && value.isNotEmpty) recordMap[key] = value;
          }
        }
      } catch (_) {}
    }

    final title = t(currentLocale.value, 'health_sleep_record_title');
    var imported = 0;
    for (final session in sessions) {
      String? recordKey = recordMap[session.externalId];
      if (recordKey != null && recordKey.isNotEmpty) {
        final updated = await db.updateRecord(
          recordId: recordKey,
          title: title,
          startTime: session.startUtc,
          endTime: session.endUtc,
          categoryId: categoryId,
          bypassConflictCheck: true,
        );
        if (updated != null) {
          imported++;
          continue;
        }
        recordMap.remove(session.externalId);
      }

      final existing = findExistingSleepRecord(
        records: records,
        sleepStartUtc: session.startUtc,
        sleepEndUtc: session.endUtc,
      );
      recordKey = existing == null ? null : recordIdentityKey(existing);
      if (recordKey != null && recordKey.isNotEmpty) {
        final updated = await db.updateRecord(
          recordId: recordKey,
          title: title,
          startTime: session.startUtc,
          endTime: session.endUtc,
          categoryId: categoryId,
          bypassConflictCheck: true,
        );
        if (updated != null) {
          recordMap[session.externalId] = recordKey;
          imported++;
          continue;
        }
      }

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
      recordMap[session.externalId] = createdId;
      imported++;
    }
    await prefs.setString(_recordMapKey, jsonEncode(recordMap));
    return imported;
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

  Future<void> _ensureWorkmanagerInitialized() async {
    if (_workmanagerInitialized || kIsWeb || !Platform.isAndroid) return;
    await Workmanager().initialize(googleFitSleepBackgroundCallbackDispatcher);
    _workmanagerInitialized = true;
  }

  Future<void> _applyBackgroundSchedule() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _ensureWorkmanagerInitialized();
    if (state.value.configured && state.value.enabled) {
      await Workmanager().registerPeriodicTask(
        _backgroundTaskUniqueName,
        backgroundTaskName,
        frequency: _backgroundFrequency,
        tag: _backgroundTaskTag,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } else {
      await Workmanager().cancelByTag(_backgroundTaskTag);
    }
  }

  Future<bool> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configuredKey);
    await prefs.remove(_enabledKey);
    await prefs.remove(_historyCompleteKey);
    await prefs.remove(_lastSyncKey);
    await prefs.remove(_recordMapKey);
    state.value = const CloudSleepSyncState.initial();
    await _applyBackgroundSchedule();
    return true;
  }
}
