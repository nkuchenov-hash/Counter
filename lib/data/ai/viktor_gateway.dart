import 'dart:convert';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'viktor_action_contract.dart';

/// Model selection is local preference. API keys are intentionally only kept
/// in process memory: they are NOT written to SharedPreferences or PocketBase.
class ViktorModelSettings {
  ViktorModelSettings._();
  static final ViktorModelSettings instance = ViktorModelSettings._();

  static const models = <String, List<String>>{
    'openai': ['gpt-4o-mini', 'gpt-4.1-mini'],
    'groq': ['llama-3.3-70b-versatile', 'openai/gpt-oss-20b'],
    'gemini': ['gemini-2.5-flash', 'gemini-2.5-flash-lite'],
    'openrouter': ['qwen/qwen3-32b', 'deepseek/deepseek-chat'],
  };

  String mode = 'byok';
  String provider = 'openai';
  String model = 'gpt-4o-mini';
  String sessionApiKey = '';
  bool _loaded = false;
  String? _credentialOwner;

  void ensureOwner(String userId) {
    final id = userId.trim();
    if (_credentialOwner != null && _credentialOwner != id) {
      sessionApiKey = '';
    }
    _credentialOwner = id;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('viktor_mode');
    if (savedMode == 'byok' || savedMode == 'hosted') mode = savedMode!;
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
    // Deliberately never persist the raw provider credential.
  }

  void selectProvider(String newProvider) {
    if (!models.containsKey(newProvider)) return;
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
    final activeId = service.canonicalPrimaryRunningBusinessId;
    final data = <String, Object?>{
      'text': input,
      'wall_day': dayKey,
      'request_id': reqId,
      'ui_locale': currentLocale.value,
      'mode': settings.mode,
      'provider': settings.mode == 'hosted' ? 'openai' : settings.provider,
      'model': settings.mode == 'hosted' ? 'gpt-4o-mini' : settings.model,
      if (settings.mode == 'byok') 'api_key': settings.sessionApiKey,
      'day_plans': [
        for (final p in plans)
          if (p.pocketRecordId != null && p.pocketRecordId!.isNotEmpty)
            {
              'id': p.pocketRecordId,
              'title': p.title,
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
