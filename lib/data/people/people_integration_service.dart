import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/data/people/people_models.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

@immutable
class PeopleIntegrationState {
  const PeopleIntegrationState({
    required this.connections,
    this.loading = false,
    this.actionProvider,
    this.error,
  });

  const PeopleIntegrationState.initial()
      : connections = const <PeopleIntegrationConnection>[],
        loading = false,
        actionProvider = null,
        error = null;

  final List<PeopleIntegrationConnection> connections;
  final bool loading;
  final PeopleSourceProvider? actionProvider;
  final String? error;

  PeopleIntegrationConnection? connectionFor(PeopleSourceProvider provider) {
    for (final connection in connections) {
      if (connection.provider == provider) return connection;
    }
    return null;
  }

  PeopleIntegrationState copyWith({
    List<PeopleIntegrationConnection>? connections,
    bool? loading,
    PeopleSourceProvider? actionProvider,
    bool clearActionProvider = false,
    String? error,
    bool clearError = false,
  }) {
    return PeopleIntegrationState(
      connections: connections ?? this.connections,
      loading: loading ?? this.loading,
      actionProvider:
          clearActionProvider ? null : (actionProvider ?? this.actionProvider),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PeopleIntegrationService {
  PeopleIntegrationService._();

  static final PeopleIntegrationService instance =
      PeopleIntegrationService._();

  final ValueNotifier<PeopleIntegrationState> state =
      ValueNotifier<PeopleIntegrationState>(
        const PeopleIntegrationState.initial(),
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
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Unexpected People integration response');
  }

  String _errorText(Object error) {
    if (error is StateError) return '${error.message}';
    if (error is FormatException) return error.message;
    return '$error';
  }

  Future<void> loadStatus() async {
    final headers = _headers();
    if (headers == null) {
      state.value = const PeopleIntegrationState.initial();
      return;
    }
    if (state.value.loading) return;
    state.value = state.value.copyWith(loading: true, clearError: true);
    try {
      final response = await http
          .get(_uri(PbAppApiRoutes.peopleIntegrationsStatus), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        state.value = state.value.copyWith(
          loading: false,
          error: 'server_people_integrations_not_deployed',
        );
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'People integration status failed (${response.statusCode})',
        );
      }
      final data = _decode(response);
      final raw = data['integrations'];
      final connections = <PeopleIntegrationConnection>[
        if (raw is List)
          for (final item in raw)
            if (item is Map)
              PeopleIntegrationConnection.fromJson(
                Map<String, dynamic>.from(item),
              ),
      ];
      state.value = PeopleIntegrationState(connections: connections);
    } catch (error) {
      state.value = state.value.copyWith(
        loading: false,
        error: _errorText(error),
      );
    }
  }

  Future<bool> connect(PeopleSourceProvider provider) async {
    if (!provider.usesServerOAuth) return false;
    final headers = _headers(json: true);
    if (headers == null) return false;
    state.value = state.value.copyWith(
      actionProvider: provider,
      clearError: true,
    );
    try {
      final response = await http
          .post(
            _uri(PbAppApiRoutes.peopleIntegrationConnect(provider.wireValue)),
            headers: headers,
            body: '{}',
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final payload = _decode(response);
        throw StateError(
          payload['error']?.toString() ??
              'People connection failed (${response.statusCode})',
        );
      }
      final authorizationUrl =
          _decode(response)['authorization_url']?.toString().trim() ?? '';
      final uri = Uri.tryParse(authorizationUrl);
      if (uri == null || !uri.hasScheme) {
        throw const FormatException('Missing People authorization URL');
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

  Future<bool> syncNow(PeopleSourceProvider provider) async {
    if (!provider.usesServerOAuth) return false;
    final headers = _headers(json: true);
    if (headers == null) return false;
    state.value = state.value.copyWith(
      actionProvider: provider,
      clearError: true,
    );
    try {
      final response = await http
          .post(
            _uri(PbAppApiRoutes.peopleIntegrationSync(provider.wireValue)),
            headers: headers,
            body: '{}',
          )
          .timeout(const Duration(seconds: 120));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final payload = _decode(response);
        throw StateError(
          payload['error']?.toString() ??
              'People sync failed (${response.statusCode})',
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

  Future<bool> disconnect(PeopleSourceProvider provider) async {
    if (!provider.usesServerOAuth) return false;
    final headers = _headers();
    if (headers == null) return false;
    state.value = state.value.copyWith(
      actionProvider: provider,
      clearError: true,
    );
    try {
      final response = await http
          .delete(
            _uri(PbAppApiRoutes.peopleIntegrationConnection(provider.wireValue)),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'People disconnect failed (${response.statusCode})',
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
}
