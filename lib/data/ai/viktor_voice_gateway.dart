import 'dart:convert';
import 'dart:typed_data';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:http/http.dart' as http;

import 'viktor_gateway.dart';

/// BYOK speech transcription transport. Always sends actual recorded WAV,
/// never uses the browser's unreliable SpeechRecognition backend.
/// Neither the audio nor the user provider key is saved in PocketBase.
class ViktorVoiceGateway {
  const ViktorVoiceGateway();

  Future<String> transcribe({
    required Uint8List wav,
    required ViktorModelSettings settings,
  }) async {
    final db = DatabaseService.instance;
    await db.ensurePocketBaseReady();
    final token = db.pocketBase.authStore.token.trim();
    settings.ensureOwner(db.pocketBase.authStore.record?.id ?? 'signed_out');
    if (token.isEmpty) throw const FormatException('auth_required');

    final provider = settings.provider == 'openrouter'
        ? settings.speechProvider
        : settings.provider;
    final apiKey = settings.provider == 'openrouter'
        ? settings.sessionSpeechApiKey.trim()
        : settings.sessionApiKey.trim();
    if (!const {'openai', 'groq', 'gemini'}.contains(provider)) {
      throw const FormatException('speech_provider_unavailable');
    }
    if (apiKey.isEmpty) {
      throw const FormatException('speech_api_key_required');
    }

    final response = await http.post(
      Uri.parse('${kPocketBaseUrl.replaceAll(RegExp(r'/$'), '')}/api/viktor/transcribe'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'provider': provider,
        'api_key': apiKey,
        'audio_base64': base64Encode(wav),
        'language': currentLocale.value.toLowerCase().startsWith('ru')
            ? 'ru' : 'en',
      }),
    ).timeout(const Duration(seconds: 55));

    Map<String, dynamic> payload;
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map) throw const FormatException('invalid_speech_response');
      payload = Map<String, dynamic>.from(json);
    } catch (_) {
      throw const FormatException('invalid_speech_response');
    }
    if (response.statusCode != 200) {
      throw FormatException((payload['error'] ?? 'speech_request_failed').toString());
    }
    final text = (payload['transcript'] ?? '').toString().trim();
    if (text.isEmpty) throw const FormatException('no_speech_detected');
    return text;
  }
}
