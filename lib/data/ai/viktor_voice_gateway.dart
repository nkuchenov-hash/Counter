import 'dart:convert';
import 'dart:typed_data';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:http/http.dart' as http;

import 'viktor_gateway.dart';

/// BYOK speech transport. YandexGPT can reuse its API key for SpeechKit,
/// provided the service account has both model and STT permissions.
class ViktorVoiceGateway {
  const ViktorVoiceGateway();

  Map<String, dynamic> _payload(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw const FormatException('invalid_speech_response');
  }

  FormatException _failure(Map<String, dynamic> data) {
    final code = (data['error'] ?? 'speech_request_failed').toString();
    final status = data['status'];
    if (status is int && status >= 400 && status <= 599) {
      return FormatException('$code (HTTP $status)');
    }
    return FormatException(code);
  }

  Future<String> transcribe({
    required Uint8List wav,
    required ViktorModelSettings settings,
  }) async {
    final db = DatabaseService.instance;
    await db.ensurePocketBaseReady();
    final token = db.pocketBase.authStore.token.trim();
    settings.ensureOwner(db.pocketBase.authStore.record?.id ?? 'signed_out');
    if (token.isEmpty) throw const FormatException('auth_required');

    final isYandex = settings.provider == 'yandex';
    final externalSpeechProvider = const {'openrouter', 'gigachat'}
        .contains(settings.provider);
    final provider = isYandex ? 'yandex' : externalSpeechProvider
        ? settings.speechProvider : settings.provider;
    final apiKey = isYandex ? settings.sessionApiKey.trim()
        : externalSpeechProvider ? settings.sessionSpeechApiKey.trim()
        : settings.sessionApiKey.trim();
    if (!const {'openai', 'groq', 'gemini', 'yandex'}.contains(provider)) {
      throw const FormatException('speech_provider_unavailable');
    }
    if (apiKey.isEmpty) throw const FormatException('speech_api_key_required');
    if (isYandex && settings.yandexFolderId.trim().isEmpty) {
      throw const FormatException('yandex_folder_id_required');
    }

    final base = kPocketBaseUrl.replaceAll(RegExp(r'/$'), '');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final response = await http.post(
      Uri.parse('$base/api/viktor/${isYandex ? 'transcribe-yandex' : 'transcribe'}'),
      headers: headers,
      body: jsonEncode({
        'provider': provider,
        'api_key': apiKey,
        'audio_base64': base64Encode(wav),
        'language': currentLocale.value.toLowerCase().startsWith('ru')
            ? 'ru' : 'en',
        if (isYandex) 'yandex_folder_id': settings.yandexFolderId.trim(),
      }),
    ).timeout(const Duration(seconds: 55));

    final payload = _payload(response);
    if (isYandex && response.statusCode == 202) {
      final operationId = (payload['operation_id'] ?? '').toString();
      if (!RegExp(r'^[a-zA-Z0-9_-]{8,90}$').hasMatch(operationId)) {
        throw const FormatException('invalid_speech_response');
      }
      // The Yandex REST API processes recorded audio asynchronously.
      // Poll from Flutter so the PocketBase HTTP hook is never held open
      // waiting for transcription or blocking other app operations.
      for (var attempt = 0; attempt < 40; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        final check = await http.post(
          Uri.parse('$base/api/viktor/transcribe-yandex/status'),
          headers: headers,
          body: jsonEncode({
            'provider': 'yandex',
            'api_key': apiKey,
            'yandex_folder_id': settings.yandexFolderId.trim(),
            'operation_id': operationId,
          }),
        ).timeout(const Duration(seconds: 20));
        final state = _payload(check);
        if (check.statusCode == 202) continue;
        if (check.statusCode != 200) {
          throw _failure(state);
        }
        final transcript = (state['transcript'] ?? '').toString().trim();
        if (transcript.isEmpty) throw const FormatException('no_speech_detected');
        return transcript;
      }
      throw const FormatException('speech_recognition_timeout');
    }
    if (response.statusCode != 200) {
      throw _failure(payload);
    }
    final transcript = (payload['transcript'] ?? '').toString().trim();
    if (transcript.isEmpty) throw const FormatException('no_speech_detected');
    return transcript;
  }
}
