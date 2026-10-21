import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'viktor_action_contract.dart';
import 'viktor_schedule_planner.dart';

/// Model selection is local preference. API keys are intentionally only kept
/// in process memory: they are NOT written to SharedPreferences or PocketBase.
class ViktorModelSettings {
  ViktorModelSettings._();
  static final ViktorModelSettings instance = ViktorModelSettings._();

  static const models = <String, List<String>>{
    'yandex': ['yandexgpt/rc', 'yandexgpt/latest'],
    'gigachat': ['GigaChat-2', 'GigaChat-2-Pro', 'GigaChat-2-Max'],
    'openai': ['gpt-4o-mini', 'gpt-4.1-mini'],
    'groq': ['llama-3.3-70b-versatile', 'openai/gpt-oss-20b'],
    'gemini': ['gemini-2.5-flash', 'gemini-2.5-flash-lite'],
    'openrouter': ['qwen/qwen3-32b', 'deepseek/deepseek-chat'],
  };

  String mode = 'byok';
  String provider = 'yandex';
  String model = 'yandexgpt/rc';
  String yandexFolderId = '';
  String gigachatScope = 'pers';
  String sessionApiKey = '';
  // GigaChat and OpenRouter can use a separate STT provider. YandexGPT
  // shares its AI Studio service-account key with Yandex SpeechKit.
  // Both credentials are session-only and never saved in preferences.
  String speechProvider = 'groq';
  String sessionSpeechApiKey = '';
  final Set<String> cloudProviders = {};
  final Map<String, Map<String, dynamic>> cloudInfo = {};
  bool _loaded = false;
  String? _credentialOwner;

  void ensureOwner(String userId) {
    final id = userId.trim();
    if (_credentialOwner != null && _credentialOwner != id) {
      sessionApiKey = '';
      sessionSpeechApiKey = '';
      yandexFolderId = '';
      cloudProviders.clear();
      cloudInfo.clear();
    }
    _credentialOwner = id;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    // Until the hosted model has durable metering, beta only offers BYOK.
    // Ignore a pre-release stored hosted selection to avoid a dead first-run UI.
    mode = 'byok';
    final savedSpeech = prefs.getString('viktor_speech_provider');
    if (savedSpeech == 'groq' || savedSpeech == 'openai' ||
        savedSpeech == 'gemini') {
      speechProvider = savedSpeech!;
    }
    yandexFolderId = prefs.getString('viktor_yandex_folder_id') ?? '';
    final savedGigaScope = prefs.getString('viktor_gigachat_scope');
    if (const {'pers', 'b2b', 'corp'}.contains(savedGigaScope)) {
      gigachatScope = savedGigaScope!;
    }
    final savedProvider = prefs.getString('viktor_provider');
    if (models.containsKey(savedProvider)) provider = savedProvider!;
    final savedModel = prefs.getString('viktor_model');
    if (models[provider]!.contains(savedModel)) {
      model = savedModel!;
    } else {
      model = models[provider]!.first;
    }
    if (mode == 'hosted') {
      provider = 'openai';
      model = 'gpt-4o-mini';
    }
    _loaded = true;
  }

  /// Browser SharedPreferences writes into a small localStorage quota.
  /// Once the server confirms the connection, its account-scoped metadata
  /// is authoritative and no browser-local copy of these settings is needed.
  /// Never turn a successful server save into a failed UI state just because
  /// unrelated localStorage data has filled the browser quota.
  Future<bool> save() async {
    if (kIsWeb && cloudProviders.contains(provider)) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('viktor_mode', mode);
      await prefs.setString('viktor_provider', provider);
      await prefs.setString('viktor_model', model);
      await prefs.setString('viktor_speech_provider', speechProvider);
      await prefs.setString('viktor_yandex_folder_id', yandexFolderId);
      await prefs.setString('viktor_gigachat_scope', gigachatScope);
      // Deliberately never persist the raw provider credential.
      return true;
    } catch (_) {
      // Optional device-only convenience preferences may be unavailable.
      // Server BYOK state is unaffected, and the caller can distinguish it.
      return false;
    }
  }


  /// Whether Viktor can call a model without entering a key on this device.
  bool get modelConnected =>
      sessionApiKey.trim().isNotEmpty || cloudProviders.contains(provider);

  bool get speechConnected {
    if (const {'gigachat', 'openrouter'}.contains(provider)) {
      return sessionSpeechApiKey.trim().isNotEmpty ||
          cloudInfo[provider]?['has_speech_key'] == true;
    }
    return modelConnected;
  }

  Future<void> loadCloudConnection() async {
    final db = DatabaseService.instance;
    await db.ensurePocketBaseReady();
    final owner = db.pocketBase.authStore.record?.id ?? '';
    ensureOwner(owner);
    final token = db.pocketBase.authStore.token.trim();
    if (owner.isEmpty || token.isEmpty) return;
    final root = kPocketBaseUrl.endsWith('/')
        ? kPocketBaseUrl.substring(0, kPocketBaseUrl.length - 1)
        : kPocketBaseUrl;
    final response = await http.get(
      Uri.parse('$root/api/viktor/connection'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) {
      String reason = 'HTTP ${response.statusCode}';
      try {
        final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (errorBody is Map && errorBody['error'] is String) {
          reason = errorBody['error'] as String;
        }
      } catch (_) {}
      throw FormatException('cloud_connection_unavailable: $reason');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map || data['connections'] is! List) {
      throw const FormatException('invalid_cloud_connection');
    }
    final entries = (data['connections'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    cloudProviders.clear();
    cloudInfo.clear();
    for (final item in entries) {
      final p = item['provider']?.toString() ?? '';
      if (models.containsKey(p)) {
        cloudProviders.add(p);
        cloudInfo[p] = item;
      }
    }
    if (entries.isNotEmpty && !cloudProviders.contains(provider)) {
      final p = entries.first['provider']?.toString() ?? '';
      if (cloudProviders.contains(p)) provider = p;
    }
    final active = cloudInfo[provider];
    if (active == null) return;
    final savedModel = active['model']?.toString() ?? '';
    if (models[provider]!.contains(savedModel)) model = savedModel;
    if (provider == 'yandex') {
      final folder = active['folder_id']?.toString() ?? '';
      if (folder.isNotEmpty) yandexFolderId = folder;
    }
    final speech = active['speech_provider']?.toString() ?? '';
    if (const {'groq', 'openai', 'gemini'}.contains(speech)) {
      speechProvider = speech;
    }
  }

  Future<void> saveCloudConnection() async {
    final db = DatabaseService.instance;
    await db.ensurePocketBaseReady();
    final owner = db.pocketBase.authStore.record?.id ?? '';
    ensureOwner(owner);
    final token = db.pocketBase.authStore.token.trim();
    if (owner.isEmpty || token.isEmpty) {
      throw const FormatException('auth_required');
    }
    final root = kPocketBaseUrl.endsWith('/')
        ? kPocketBaseUrl.substring(0, kPocketBaseUrl.length - 1)
        : kPocketBaseUrl;
    final response = await http.post(
      Uri.parse('$root/api/viktor/connection'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'provider': provider,
        'model': model,
        if (sessionApiKey.trim().isNotEmpty)
          'api_key': sessionApiKey.trim(),
        if (sessionSpeechApiKey.trim().isNotEmpty)
          'speech_api_key': sessionSpeechApiKey.trim(),
        'folder_id': yandexFolderId.trim(),
        'speech_provider': speechProvider,
        'gigachat_scope': gigachatScope,
      }),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      String reason = 'HTTP ${response.statusCode}';
      try {
        final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (errorBody is Map && errorBody['error'] is String) {
          reason = errorBody['error'] as String;
        }
      } catch (_) {}
      throw FormatException('cloud_connection_save_failed: $reason');
    }
    // Prove persistence by fetching the account's server state, not by
    // trusting the POST response or inserting a fake local "connected" flag.
    final expectedProvider = provider;
    final expectedModel = model;
    final expectedFolder = yandexFolderId.trim();
    await loadCloudConnection();
    final actual = cloudInfo[expectedProvider];
    if (actual == null || actual['model'] != expectedModel ||
        (expectedProvider == 'yandex' &&
            actual['folder_id'] != expectedFolder)) {
      throw const FormatException(
          'cloud_connection_readback_failed');
    }
  }

  void selectProvider(String newProvider) {
    if (!models.containsKey(newProvider)) return;
    if (provider != newProvider) sessionApiKey = '';
    provider = newProvider;
    model = models[newProvider]!.first;
  }
}

class ViktorResponse {
  ViktorResponse({required this.message, required this.actions});
  final String message;
  final ViktorActionBatch? actions;
}

class ViktorGateway {
  const ViktorGateway();

  Future<ViktorResponse> propose({
    required String input,
    required DateTime wallDay,
    required List<PlanningTask> plans,
    required ViktorModelSettings settings,
    List<String> selectedPlanIds = const [],
  }) async {
    final service = DatabaseService.instance;
    await service.ensurePocketBaseReady();
    final token = service.pocketBase.authStore.token.trim();
    settings.ensureOwner(service.pocketBase.authStore.record?.id ?? '');
    if (token.isEmpty) throw const FormatException('Sign in to LIFE OS first.');
    if (settings.mode == 'byok' && !settings.modelConnected) {
      throw const FormatException('Set your provider API key in Viktor settings.');
    }
    final dayKey = '${wallDay.year.toString().padLeft(4, '0')}-'
        '${wallDay.month.toString().padLeft(2, '0')}-'
        '${wallDay.day.toString().padLeft(2, '0')}';
    final reqId = 'viktor_${DateTime.now().microsecondsSinceEpoch}';
    final lastTwo = ViktorSchedulePlanner.resolveLastTwoSwap(input, plans);
    if (lastTwo != null) {
      final earlier = plans.singleWhere((p) => p.pocketRecordId == lastTwo[0]);
      final later = plans.singleWhere((p) => p.pocketRecordId == lastTwo[1]);
      return ViktorResponse(
        message: 'Переставлю местами последние по времени планы: '
            '«${earlier.title}» и «${later.title}».',
        actions: ViktorActionBatch.fromJson({
          'version': 1,
          'request_id': reqId,
          'actions': [
            {'name': 'swap_plan_positions', 'arguments': {
              'first_plan_id': lastTwo[0],
              'second_plan_id': lastTwo[1],
              'wall_day': dayKey,
            }},
          ],
        }),
      );
    }
    final nextDay = DateTime(
      wallDay.year, wallDay.month, wallDay.day + 1);
    // The provider receives actual completion state and destination-day
    // obstacles. Never ask the user to find backend row IDs.
    final nextDayPlans = await service.getPlanningTasksForWallDate(nextDay);
    final activeId = service.canonicalPrimaryRunningBusinessId;
    final data = <String, Object?>{
      'text': input,
      'wall_day': dayKey,
      'request_id': reqId,
      'ui_locale': currentLocale.value,
      'profile_timezone': service.settings.preferredTimeZone,
      'next_day': '${nextDay.year.toString().padLeft(4, '0')}-'
          '${nextDay.month.toString().padLeft(2, '0')}-'
          '${nextDay.day.toString().padLeft(2, '0')}',
      'mode': settings.mode,
      'provider': settings.mode == 'hosted' ? 'openai' : settings.provider,
      'model': settings.mode == 'hosted' ? 'gpt-4o-mini' : settings.model,
      if (settings.mode == 'byok') 'api_key': settings.sessionApiKey,
      if (settings.provider == 'yandex') 'yandex_folder_id': settings.yandexFolderId,
      if (settings.provider == 'gigachat') 'gigachat_scope': settings.gigachatScope,
      // Only saved plans from this day can be selected as command referents.
      'selected_plan_ids': selectedPlanIds.where(
        (id) => plans.any((p) => p.pocketRecordId == id)).toSet().toList(),
      'day_plans': [
        for (final p in plans)
          if (p.pocketRecordId != null && p.pocketRecordId!.isNotEmpty)
            {
              'id': p.pocketRecordId,
              'title': p.title,
              'is_done': p.isDone,
              'category_id': p.categoryId,
              'duration_minutes': p.startTime != null && p.endDateTime != null
                  ? p.endDateTime!.difference(p.startTime!).inMinutes
                  : null,
              'start_time': p.startTime == null
                  ? null
                  : '${p.startTime!.hour.toString().padLeft(2, '0')}:'
                    '${p.startTime!.minute.toString().padLeft(2, '0')}',
              'recurrent': (p.rrule ?? '').isNotEmpty ||
                  (p.recurrenceInstanceDateKey ?? '').isNotEmpty,
            }
      ],
      'next_day_plans': [
        for (final p in nextDayPlans)
          if (p.pocketRecordId != null && p.pocketRecordId!.isNotEmpty)
            {
              'id': p.pocketRecordId,
              'title': p.title,
              'is_done': p.isDone,
              'start_time': p.startTime == null ? null :
                  '${p.startTime!.hour.toString().padLeft(2, '0')}:'
                  '${p.startTime!.minute.toString().padLeft(2, '0')}',
              'duration_minutes': p.startTime != null &&
                      p.endDateTime != null
                  ? p.endDateTime!.difference(p.startTime!).inMinutes
                  : null,
              'recurrent': (p.rrule ?? '').isNotEmpty ||
                  (p.recurrenceInstanceDateKey ?? '').isNotEmpty,
            }
      ],
      'active_record': activeId == null ? null : {
        'id': activeId,
        'title': service.cachedPrimaryRunningTitle ?? '',
      }
    };
    final base = kPocketBaseUrl.replaceAll(RegExp(r'/$'), '');
    // The provider credential is transient in this HTTPS body, never a URL or log.
    final reply = await http.post(
      Uri.parse('$base/api/viktor/propose'),
      headers: {'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 45));
    final decoded = jsonDecode(utf8.decode(reply.bodyBytes));
    if (decoded is! Map) throw const FormatException('Invalid server reply.');
    final map = Map<String, dynamic>.from(decoded);
    if (reply.statusCode != 200) {
      final reason = map['error']?.toString() ?? 'request_failed';
      throw FormatException('Viktor: $reason');
    }
    final raw = map['actions'];
    if (raw is! List) throw const FormatException('Invalid action list.');
    final actions = raw.isEmpty ? null : ViktorActionBatch.fromJson({
      'version': map['version'],
      'request_id': map['request_id'],
      'actions': raw,
    });
    return ViktorResponse(message: (map['message'] ?? '').toString(),
        actions: actions);
  }
}
