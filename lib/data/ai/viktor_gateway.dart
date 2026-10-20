import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'viktor_action_contract.dart';
import 'viktor_schedule_planner.dart';

/// Model and folder preferences are local. BYOK credentials can optionally be
/// retained in OS/browser-backed secure storage, scoped to LIFE OS user ID.
/// Never put API keys into SharedPreferences or PocketBase.
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
  // One Yandex key may be used for YandexGPT and SpeechKit.
  String speechProvider = 'groq';
  String sessionSpeechApiKey = '';
  /// Default on for new connections. User can opt out in Viktor settings.
  bool rememberConnection = true;
  static const _secrets = FlutterSecureStorage();
  bool _loaded = false;
  String? _credentialOwner;

  // Secure storage is scoped by authenticated user AND provider, never shared
  // between accounts or between distinct model/speech vendors.
  String _apiKeyId(String owner, String provider) =>
      'viktor/byok/$owner/model/$provider';
  String _speechKeyId(String owner, String provider) =>
      'viktor/byok/$owner/speech/$provider';
  String _folderId(String owner) => 'viktor/byok/$owner/yandex_folder';

  Future<void> restoreConnectionForOwner(String userId) async {
    final id = userId.trim();
    ensureOwner(id);
    if (id.isEmpty || id == 'signed_out') return;
    final prefs = await SharedPreferences.getInstance();
    rememberConnection =
        prefs.getBool('viktor_remember_connection_$id') ?? true;
    if (!rememberConnection) return;
    try {
      // Never overwrite a newly typed in-memory credential with an older
      // persisted value (e.g. during account hydration).
      if (sessionApiKey.trim().isEmpty) {
        sessionApiKey = await _secrets.read(
            key: _apiKeyId(id, provider)) ?? '';
      }
      if (sessionSpeechApiKey.trim().isEmpty) {
        sessionSpeechApiKey = await _secrets.read(
            key: _speechKeyId(id, speechProvider)) ?? '';
      }
      final backupFolder = await _secrets.read(key: _folderId(id));
      if (yandexFolderId.trim().isEmpty && backupFolder != null) {
        yandexFolderId = backupFolder;
        await prefs.setString('viktor_yandex_folder_id', backupFolder);
      }
    } catch (_) {
      // Storage may be unavailable (private browsing, denied browser crypto).
      // Keep current-session functionality and never delete an existing key.
    }
  }

  Future<void> deleteSavedConnection() async {
    final owner = _credentialOwner?.trim() ?? '';
    if (owner.isEmpty || owner == 'signed_out') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('viktor_remember_connection_$owner', false);
    rememberConnection = false;
    // Opting out removes ALL locally remembered provider keys for this LIFE OS
    // account, not just the currently selected model.
    for (final vendor in models.keys) {
      await _secrets.delete(key: _apiKeyId(owner, vendor));
    }
    for (final vendor in const ['groq', 'openai', 'gemini']) {
      await _secrets.delete(key: _speechKeyId(owner, vendor));
    }
    await _secrets.delete(key: _folderId(owner));
  }

  void ensureOwner(String userId) {
    final id = userId.trim();
    if (_credentialOwner != null && _credentialOwner != id) {
      sessionApiKey = '';
      sessionSpeechApiKey = '';
      yandexFolderId = '';
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

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('viktor_mode', mode);
    await prefs.setString('viktor_provider', provider);
    await prefs.setString('viktor_model', model);
    await prefs.setString('viktor_speech_provider', speechProvider);
    // Never erase a previously saved folder when the editor submits an empty
    // value accidentally. Explicit disconnect is a separate user action.
    if (yandexFolderId.trim().isNotEmpty) {
      await prefs.setString('viktor_yandex_folder_id', yandexFolderId);
    }
    await prefs.setString('viktor_gigachat_scope', gigachatScope);
    final owner = _credentialOwner?.trim() ?? '';
    if (owner.isEmpty || owner == 'signed_out') return;
    await prefs.setBool('viktor_remember_connection_$owner',
        rememberConnection);
    if (rememberConnection) {
      // A failed secure write must be visible to the caller; do not claim
      // persistence when the browser rejects it.
      if (sessionApiKey.trim().isNotEmpty) {
        await _secrets.write(key: _apiKeyId(owner, provider),
          value: sessionApiKey.trim());
      }
      if (sessionSpeechApiKey.trim().isNotEmpty) {
        await _secrets.write(key: _speechKeyId(owner, speechProvider),
          value: sessionSpeechApiKey.trim());
      }
      if (yandexFolderId.trim().isNotEmpty) {
        await _secrets.write(key: _folderId(owner),
          value: yandexFolderId.trim());
      }
    } else {
      await deleteSavedConnection();
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
    if (settings.mode == 'byok' && settings.sessionApiKey.trim().isEmpty) {
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
