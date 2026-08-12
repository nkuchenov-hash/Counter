import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

enum CalendarIntegrationProvider {
  microsoft('microsoft', 'Microsoft 365 / Teams'),
  google('google', 'Google Calendar');

  const CalendarIntegrationProvider(this.wireName, this.displayName);

  final String wireName;
  final String displayName;

  static CalendarIntegrationProvider? fromWire(String value) {
    for (final provider in values) {
      if (provider.wireName == value.trim().toLowerCase()) return provider;
    }
    return null;
  }
}

@immutable
class CalendarSourceConfig {
  const CalendarSourceConfig({
    required this.id,
    required this.name,
    required this.enabled,
    this.primary = false,
    this.fallbackCategoryId,
  });

  final String id;
  final String name;
  final bool enabled;
  final bool primary;
  final String? fallbackCategoryId;

  CalendarSourceConfig copyWith({
    bool? enabled,
    String? fallbackCategoryId,
    bool clearFallbackCategory = false,
  }) {
    return CalendarSourceConfig(
      id: id,
      name: name,
      enabled: enabled ?? this.enabled,
      primary: primary,
      fallbackCategoryId: clearFallbackCategory
          ? null
          : (fallbackCategoryId ?? this.fallbackCategoryId),
    );
  }

  factory CalendarSourceConfig.fromJson(Map<String, dynamic> json) {
    final rawFallback = json['fallback_category_id']?.toString().trim() ?? '';
    return CalendarSourceConfig(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      enabled: json['enabled'] == true,
      primary: json['primary'] == true,
      fallbackCategoryId: rawFallback.isEmpty ? null : rawFallback,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'enabled': enabled,
        'primary': primary,
        'fallback_category_id': fallbackCategoryId ?? '',
      };
}

@immutable
class CalendarProviderConnection {
  const CalendarProviderConnection({
    required this.provider,
    required this.configured,
    required this.enabled,
    required this.status,
    required this.calendars,
    this.accountLabel,
    this.lastSyncAt,
    this.lastError,
    this.serverConfigured = true,
  });

  final CalendarIntegrationProvider provider;
  final bool configured;
  final bool enabled;
  final bool serverConfigured;
  final String status;
  final String? accountLabel;
  final DateTime? lastSyncAt;
  final String? lastError;
  final List<CalendarSourceConfig> calendars;

  factory CalendarProviderConnection.fromJson(Map<String, dynamic> json) {
    final provider = CalendarIntegrationProvider.fromWire(
      json['provider']?.toString() ?? '',
    );
    if (provider == null) {
      throw const FormatException('Unknown calendar provider');
    }
    final rawCalendars = json['calendars'];
    final calendars = <CalendarSourceConfig>[
      if (rawCalendars is List)
        for (final item in rawCalendars)
          if (item is Map)
            CalendarSourceConfig.fromJson(
              Map<String, dynamic>.from(item),
            ),
    ];
    final lastSyncRaw = json['last_sync_at']?.toString().trim() ?? '';
    final error = json['last_error']?.toString().trim() ?? '';
    final account = json['account_label']?.toString().trim() ?? '';
    return CalendarProviderConnection(
      provider: provider,
      configured: json['configured'] == true,
      enabled: json['enabled'] != false,
      serverConfigured: json['server_configured'] != false,
      status: json['status']?.toString().trim() ?? 'disconnected',
      accountLabel: account.isEmpty ? null : account,
      lastSyncAt: lastSyncRaw.isEmpty
          ? null
          : DateTime.tryParse(lastSyncRaw)?.toUtc(),
      lastError: error.isEmpty ? null : error,
      calendars: calendars,
    );
  }
}

@immutable
class CalendarIntegrationState {
  const CalendarIntegrationState({
    required this.connections,
    this.loading = false,
    this.actionProvider,
    this.error,
  });

  const CalendarIntegrationState.initial()
      : connections = const <CalendarProviderConnection>[],
        loading = false,
        actionProvider = null,
        error = null;

  final List<CalendarProviderConnection> connections;
  final bool loading;
  final CalendarIntegrationProvider? actionProvider;
  final String? error;

  CalendarProviderConnection? connectionFor(
    CalendarIntegrationProvider provider,
  ) {
    for (final connection in connections) {
      if (connection.provider == provider) return connection;
    }
    return null;
  }

  CalendarIntegrationState copyWith({
    List<CalendarProviderConnection>? connections,
    bool? loading,
    CalendarIntegrationProvider? actionProvider,
    bool clearActionProvider = false,
    String? error,
    bool clearError = false,
  }) {
    return CalendarIntegrationState(
      connections: connections ?? this.connections,
      loading: loading ?? this.loading,
      actionProvider: clearActionProvider
          ? null
          : (actionProvider ?? this.actionProvider),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CalendarIntegrationService {
  CalendarIntegrationService._();

  static final CalendarIntegrationService instance =
      CalendarIntegrationService._();

  final ValueNotifier<CalendarIntegrationState> state =
      ValueNotifier<CalendarIntegrationState>(
        const CalendarIntegrationState.initial(),
      );

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
    throw const FormatException('Unexpected calendar integration response');
  }

  String _errorText(Object error) {
    if (error is StateError) return '${error.message}';
    if (error is FormatException) return error.message;
    return '$error';
  }

  Future<void> loadStatus() async {
    final headers = _headers();
    if (headers == null) {
      state.value = const CalendarIntegrationState.initial();
      return;
    }
    if (state.value.loading) return;
    state.value = state.value.copyWith(loading: true, clearError: true);
    try {
      final response = await http
          .get(_uri(PbAppApiRoutes.calendarIntegrationsStatus), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        state.value = state.value.copyWith(
          loading: false,
          error: 'server_calendar_integrations_not_deployed',
        );
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Calendar integration status failed (${response.statusCode})',
        );
      }
      final data = _decode(response);
      final raw = data['integrations'];
      final connections = <CalendarProviderConnection>[
        if (raw is List)
          for (final item in raw)
            if (item is Map)
              CalendarProviderConnection.fromJson(
                Map<String, dynamic>.from(item),
              ),
      ];
      state.value = CalendarIntegrationState(connections: connections);
    } catch (error) {
      state.value = state.value.copyWith(
        loading: false,
        error: _errorText(error),
      );
    }
  }

  Future<bool> connect(CalendarIntegrationProvider provider) async {
    final headers = _headers(json: true);
    if (headers == null) return false;
    state.value = state.value.copyWith(
      actionProvider: provider,
      clearError: true,
    );
    try {
      final response = await http
          .post(
            _uri(PbAppApiRoutes.calendarIntegrationConnect(provider.wireName)),
            headers: headers,
            body: '{}',
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        state.value = state.value.copyWith(
          error: 'server_calendar_integrations_not_deployed',
        );
        return false;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final payload = _decode(response);
        throw StateError(
          payload['error']?.toString() ??
              'Calendar connection failed (${response.statusCode})',
        );
      }
      final authorizationUrl =
          _decode(response)['authorization_url']?.toString().trim() ?? '';
      final uri = Uri.tryParse(authorizationUrl);
      if (uri == null || !uri.hasScheme) {
        throw const FormatException('Missing calendar authorization URL');
      }
      final launched = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!launched) throw StateError('Could not open provider authorization');
      return true;
    } catch (error) {
      state.value = state.value.copyWith(error: _errorText(error));
      return false;
    } finally {
      state.value = state.value.copyWith(clearActionProvider: true);
    }
  }

  Future<bool> saveCalendars(
    CalendarIntegrationProvider provider,
    List<CalendarSourceConfig> calendars,
  ) async {
    final headers = _headers(json: true);
    if (headers == null) return false;
    state.value = state.value.copyWith(
      actionProvider: provider,
      clearError: true,
    );
    try {
      final response = await http
          .post(
            _uri(PbAppApiRoutes.calendarIntegrationsSettings),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'provider': provider.wireName,
              'calendars': [for (final calendar in calendars) calendar.toJson()],
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Calendar settings failed (${response.statusCode})',
        );
      }
      await loadStatus();
      return true;
    } catch (error) {
      state.value = state.value.copyWith(error: _errorText(error));
      return false;
    } finally {
      state.value = state.value.copyWith(clearActionProvider: true);
    }
  }

  Future<bool> syncNow(CalendarIntegrationProvider provider) async {
    final headers = _headers(json: true);
    if (headers == null) return false;
    state.value = state.value.copyWith(
      actionProvider: provider,
      clearError: true,
    );
    try {
      final response = await http
          .post(
            _uri(PbAppApiRoutes.calendarIntegrationSync(provider.wireName)),
            headers: headers,
            body: '{}',
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Calendar sync failed (${response.statusCode})');
      }
      await loadStatus();
      DatabaseService.instance.notifyPlanningRefresh(
        scheduleNetworkRefresh: true,
        pumpNetworkNow: true,
      );
      return true;
    } catch (error) {
      state.value = state.value.copyWith(error: _errorText(error));
      return false;
    } finally {
      state.value = state.value.copyWith(clearActionProvider: true);
    }
  }

  Future<bool> disconnect(CalendarIntegrationProvider provider) async {
    final headers = _headers();
    if (headers == null) return false;
    state.value = state.value.copyWith(
      actionProvider: provider,
      clearError: true,
    );
    try {
      final response = await http
          .delete(
            _uri(PbAppApiRoutes.calendarIntegrationConnection(provider.wireName)),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Calendar disconnect failed (${response.statusCode})',
        );
      }
      await loadStatus();
      DatabaseService.instance.notifyPlanningRefresh(
        scheduleNetworkRefresh: true,
        pumpNetworkNow: true,
      );
      return true;
    } catch (error) {
      state.value = state.value.copyWith(error: _errorText(error));
      return false;
    } finally {
      state.value = state.value.copyWith(clearActionProvider: true);
    }
  }
}
