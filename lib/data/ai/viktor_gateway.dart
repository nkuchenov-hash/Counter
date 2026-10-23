import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'viktor_action_contract.dart';
import 'viktor_date_scope.dart';
import 'viktor_agent_capabilities.dart';
import 'package:counter/data/paths/path_repository.dart';
import 'viktor_schedule_planner.dart';

/// A cloud-connected web client must not write optional prefs into the
/// browser's small and possibly full localStorage. The encrypted account
/// connection and model choice come from PocketBase.
bool shouldPersistViktorLocalPreferences({
  required bool isWeb,
  required bool hasCloudConnection,
}) => !isWeb || !hasCloudConnection;

/// Model and folder selection come from the encrypted, account-scoped vault
/// whenever connected. Optional local device preferences are best-effort.
/// API keys are never stored in SharedPreferences or exposed by vault GET.
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
    if (!shouldPersistViktorLocalPreferences(
      isWeb: kIsWeb,
      hasCloudConnection: cloudProviders.contains(provider),
    )) return true;
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
  ViktorResponse({
    required this.message,
    required this.actions,
    this.needsMoreContext = false,
  });
  final String message;
  final ViktorActionBatch? actions;
  /// Model requested another read-only observation before its final action.
  final bool needsMoreContext;
}

class ViktorGateway {
  const ViktorGateway();

  Future<ViktorResponse> propose({
    required String input,
    required DateTime wallDay,
    required List<PlanningTask> plans,
    required ViktorModelSettings settings,
    List<String> selectedPlanIds = const [],
    List<String> toolObservations = const [],
    String? requestId,
    String? proposalFeedback,
    List<Map<String, String>> conversationHistory = const [],
    bool allowRepair = true,
  }) async {
    final service = DatabaseService.instance;
    await service.ensurePocketBaseReady();
    final token = service.pocketBase.authStore.token.trim();
    settings.ensureOwner(service.pocketBase.authStore.record?.id ?? '');
    if (token.isEmpty) throw const FormatException('Sign in to LIFE OS first.');
    if (settings.mode == 'byok' && !settings.modelConnected) {
      throw const FormatException('Set your provider API key in Viktor settings.');
    }
    final dayKey = ViktorDateScope.key(wallDay);
    // The profile clock, not the opened calendar tab or device time zone,
    // defines relative dates in user language (today/yesterday/tomorrow).
    final today = service.getProjectedToday();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final reqId = requestId ?? 'viktor_${DateTime.now().microsecondsSinceEpoch}';
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
    // Domain metadata is supplied from the same Brain visible to the UI.
    // Only send the relevant catalogs, never the provider key as context.
    final q = input.toLowerCase();
    final wantTags = RegExp(r'тег|метк|ярлык|tag|label',
        caseSensitive: false).hasMatch(q);
    final wantLists = RegExp(r'спис|дела|чеклист|list|backlog|задач',
        caseSensitive: false).hasMatch(q);
    final wantNotes = RegExp(r'замет|note|текст замет|конспект',
        caseSensitive: false).hasMatch(q);
    final wantPaths = RegExp(r'пути|путь|пут[ье]|path|этап|цель',
        caseSensitive: false).hasMatch(q);
    final allTags = wantTags
        ? [...await service.fetchTagsForCurrentUser(
            scope: TagCatalogScope.plan),
           ...await service.fetchTagsForCurrentUser(
            scope: TagCatalogScope.list)]
        : <Tag>[];
    final backlog = (wantNotes || wantLists)
        ? await service.fetchBacklogPlans(
            categoryId: null, includeCompleted: true)
        : <PlanningTask>[];
    final notes = wantNotes ? backlog : <PlanningTask>[];
    final paths = wantPaths
        ? (await PathRepository(database: service).loadActivePaths()).paths
        : <ProjectPathSnapshot>[];
    final categoryRows = <Map<String, Object?>>[];
    void addCategory(CategoryRule rule) {
      if (!rule.isArchived && categoryRows.length < 80) {
        categoryRows.add({
          'id': rule.backendRowId,
          'name': rule.name,
          'default_plan_time': rule.defaultPlanTime,
        });
      }
      for (final child in rule.children ?? <CategoryRule>[]) {
        addCategory(child);
      }
    }
    for (final category in service.rules) { addCategory(category); }
    final data = <String, Object?>{
      'text': input,
      'wall_day': dayKey,
      'today_day': ViktorDateScope.key(today),
      'yesterday_day': ViktorDateScope.key(yesterday),
      'tomorrow_day': ViktorDateScope.key(tomorrow),
      'request_id': reqId,
      'ui_locale': currentLocale.value,
      if (proposalFeedback != null) 'proposal_feedback': proposalFeedback,
      'tool_observations': toolObservations.take(4)
          .map((entry) => entry.length > 4500 ?
             entry.substring(0, 4500) : entry).toList(),
      // Account-session conversation; bounded and transmitted only to the
      // already selected BYOK model. No credentials or hidden app state.
      'conversation_history': conversationHistory.take(12).map((turn) => {
        'role': turn['role'],
        'content': (turn['content'] ?? '').length > 1200
            ? turn['content']!.substring(0, 1200)
            : turn['content'],
      }).toList(),
      'profile_timezone': service.settings.preferredTimeZone,
      'available_tools': ViktorAgentCapabilities.tools
          .map((tool) => tool.name).toList(growable: false),
      'categories': categoryRows,
      'tags_catalog': [
        for (final tag in allTags.take(80)) {
          'id': tag.pbRecordId,
          'name': tag.name,
          'domain': tag.domain,
        }
      ],
      'backlog_catalog': [
        if (wantLists)
          for (final p in backlog.where((p) =>
              p.pocketRecordId != null &&
              p.startTime == null &&
              (p.notesDeltaJson?.trim().isEmpty ?? true) &&
              (p.rrule?.trim().isEmpty ?? true) &&
              (p.recurrenceInstanceDateKey?.trim().isEmpty ?? true)).take(60))
            {
              'id': p.pocketRecordId,
              'title': p.title,
              'is_done': p.isDone,
            }
      ],
      'notes_catalog': [
        for (final p in notes.where((p) =>
            p.startTime == null && (p.notesDeltaJson ?? '').isNotEmpty).take(60))
          {
            'id': p.pocketRecordId,
            'title': p.title,
            'text_preview': (p.notesPlain ?? '').length > 1000
                ? (p.notesPlain ?? '').substring(0, 1000)
                : p.notesPlain,
          }
      ],
      'paths_catalog': [
        for (final path in paths.take(30)) {
          'id': path.pathId,
          'name': path.name,
          'goal': path.goal.length > 250
              ? path.goal.substring(0, 250) : path.goal,
          'stages': path.stages.length,
        }
      ],
      'current_profile_settings': {
        'theme_mode': service.settings.themeMode,
        'preferred_timezone': service.settings.preferredTimeZone,
        'primary_language': service.settings.primaryLanguage,
        'list_completion_behavior': service.settings.listCompletionBehavior,
        'display_name': service.settings.displayName,
      },
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
      final errorCode = map['error']?.toString() ?? 'request_failed';
      if (errorCode == 'invalid_model_response' ||
          errorCode == 'invalid_action_proposal') {
        final reason = map['reason']?.toString() ?? '';
        const details = <String, String>{
          'response_truncated': 'ответ модели был обрезан',
          'empty_model_content': 'модель вернула пустой ответ',
          'non_json_model_content': 'модель не вернула корректный JSON',
          'invalid_provider_envelope': 'поставщик вернул повреждённый ответ',
          'missing_model_message': 'в ответе отсутствует сообщение модели',
          'invalid_action_proposal': 'модель вернула неверную структуру действий',
          'provider_content_filter':
              'YandexGPT заблокировал ответ своим фильтром содержимого',
          'explicit_model_refusal':
              'YandexGPT явно отказался выполнять запрос',
          'model_refusal': 'модель отклонила запрос',
        };
        throw FormatException(
          'Виктор: ' +
          (details[reason] ?? 'не удалось разобрать ответ ИИ') +
          '. Изменения не выполнялись.');
      }
      throw FormatException('Viktor: $errorCode');
    }
    final raw = map['actions'];
    if (raw is! List) throw const FormatException('Invalid action list.');
    ViktorActionBatch? actions;
    try {
      actions = raw.isEmpty ? null : ViktorActionBatch.fromJson({
        'version': map['version'],
        'request_id': map['request_id'],
        'actions': raw,
      });
    } on FormatException catch (error) {
      // Model output is untrusted. Give the model one schema correction turn
      // rather than asking the user to repair the model's mistake.
      if (!allowRepair) rethrow;
      return propose(
        input: input,
        wallDay: wallDay,
        plans: plans,
        settings: settings,
        selectedPlanIds: selectedPlanIds,
        toolObservations: toolObservations,
        requestId: reqId,
        proposalFeedback: error.message.toString(),
        conversationHistory: conversationHistory,
        allowRepair: false,
      );
    }
    return ViktorResponse(message: (map['message'] ?? '').toString(),
        actions: actions,
        needsMoreContext: map['continue'] == true);
  }
}
