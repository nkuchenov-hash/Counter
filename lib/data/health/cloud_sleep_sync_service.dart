import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

enum CloudSleepSyncPhase {
  disconnected,
  connecting,
  connected,
  syncing,
  error,
}

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

class CloudSleepSyncService {
  CloudSleepSyncService._();

  static final CloudSleepSyncService instance = CloudSleepSyncService._();

  final ValueNotifier<CloudSleepSyncState> state =
      ValueNotifier<CloudSleepSyncState>(const CloudSleepSyncState.initial());

  bool _loading = false;

  Map<String, String>? _headers({bool json = false}) {
    final token = DatabaseService.instance.pocketBase.authStore.token.trim();
    if (token.isEmpty) return null;
    return <String, String>{
      'Authorization': token,
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Uri _uri(String route) => Uri.parse('$kPocketBaseUrl$route');

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Unexpected sleep-sync response');
  }

  CloudSleepSyncPhase _phaseFromWire(String raw, bool configured) {
    return switch (raw.trim().toLowerCase()) {
      'connecting' => CloudSleepSyncPhase.connecting,
      'syncing' => CloudSleepSyncPhase.syncing,
      'error' => CloudSleepSyncPhase.error,
      'connected' => CloudSleepSyncPhase.connected,
      _ => configured
          ? CloudSleepSyncPhase.connected
          : CloudSleepSyncPhase.disconnected,
    };
  }

  void _applyStatus(Map<String, dynamic> data) {
    final configured = data['configured'] == true;
    final rawMinutes = data['daily_sync_minutes'];
    final minutes = rawMinutes is num
        ? rawMinutes.toInt().clamp(0, 1439).toInt()
        : 21 * 60;
    final lastSyncRaw = data['last_sync_at']?.toString().trim() ?? '';
    final lastSync = lastSyncRaw.isEmpty
        ? null
        : DateTime.tryParse(lastSyncRaw)?.toUtc();
    final error = data['last_error']?.toString().trim();
    state.value = CloudSleepSyncState(
      configured: configured,
      enabled: data['enabled'] == true,
      phase: _phaseFromWire(data['status']?.toString() ?? '', configured),
      dailySyncMinutes: minutes,
      lastSyncUtc: lastSync,
      lastSessionCount: (data['last_session_count'] as num?)?.toInt() ?? 0,
      lastImportedCount: (data['last_imported_count'] as num?)?.toInt() ?? 0,
      error: error?.isNotEmpty == true ? error : null,
    );
  }

  Future<void> loadStatus() async {
    if (_loading) return;
    final headers = _headers();
    if (headers == null) {
      state.value = const CloudSleepSyncState.initial();
      return;
    }
    _loading = true;
    try {
      final response = await http
          .get(_uri(PbAppApiRoutes.sleepSyncStatus), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        state.value = state.value.copyWith(
          phase: CloudSleepSyncPhase.error,
          error: 'server_sleep_sync_not_deployed',
        );
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Sleep sync status failed (${response.statusCode})');
      }
      _applyStatus(_decode(response));
    } catch (error) {
      state.value = state.value.copyWith(
        phase: CloudSleepSyncPhase.error,
        error: '$error',
      );
    } finally {
      _loading = false;
    }
  }

  Future<bool> connectGoogleHealth() async {
    final headers = _headers(json: true);
    if (headers == null) return false;
    state.value = state.value.copyWith(
      phase: CloudSleepSyncPhase.connecting,
      clearError: true,
    );
    try {
      final response = await http
          .post(
            _uri(PbAppApiRoutes.sleepSyncGoogleHealthConnect),
            headers: headers,
            body: '{}',
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Google Health connection failed (${response.statusCode})',
        );
      }
      final authorizationUrl =
          _decode(response)['authorization_url']?.toString().trim() ?? '';
      final uri = Uri.tryParse(authorizationUrl);
      if (uri == null || !uri.hasScheme) {
        throw const FormatException('Missing Google authorization URL');
      }
      final launched = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!launched) throw StateError('Could not open Google authorization');
      return true;
    } catch (error) {
      state.value = state.value.copyWith(
        phase: CloudSleepSyncPhase.error,
        error: '$error',
      );
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    return _updateSettings(<String, dynamic>{'enabled': enabled});
  }

  Future<bool> setDailySyncMinutes(int minutes) async {
    return _updateSettings(<String, dynamic>{
      'daily_sync_minutes': minutes.clamp(0, 1439),
    });
  }

  Future<bool> _updateSettings(Map<String, dynamic> body) async {
    final headers = _headers(json: true);
    if (headers == null) return false;
    try {
      final response = await http
          .post(
            _uri(PbAppApiRoutes.sleepSyncSettings),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Sleep sync settings failed (${response.statusCode})',
        );
      }
      _applyStatus(_decode(response));
      return true;
    } catch (error) {
      state.value = state.value.copyWith(
        phase: CloudSleepSyncPhase.error,
        error: '$error',
      );
      return false;
    }
  }

  Future<bool> syncNow() async {
    final headers = _headers(json: true);
    if (headers == null || !state.value.configured) return false;
    state.value = state.value.copyWith(
      phase: CloudSleepSyncPhase.syncing,
      clearError: true,
    );
    try {
      final response = await http
          .post(
            _uri(PbAppApiRoutes.sleepSyncRun),
            headers: headers,
            body: '{}',
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Sleep synchronization failed (${response.statusCode})',
        );
      }
      await loadStatus();
      return state.value.phase != CloudSleepSyncPhase.error;
    } catch (error) {
      state.value = state.value.copyWith(
        phase: CloudSleepSyncPhase.error,
        error: '$error',
      );
      return false;
    }
  }

  Future<bool> disconnect() async {
    final headers = _headers();
    if (headers == null) return false;
    try {
      final response = await http
          .delete(_uri(PbAppApiRoutes.sleepSyncConnection), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Sleep source disconnect failed (${response.statusCode})',
        );
      }
      state.value = const CloudSleepSyncState.initial();
      return true;
    } catch (error) {
      state.value = state.value.copyWith(
        phase: CloudSleepSyncPhase.error,
        error: '$error',
      );
      return false;
    }
  }
}
