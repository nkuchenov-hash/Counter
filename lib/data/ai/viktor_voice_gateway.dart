import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:http/http.dart' as http;

import 'viktor_gateway.dart';

/// No model request can hold the UI in indefinite Yandex operation polling.
enum ViktorSpeechStage { uploading, waiting }

/// Hard wall-clock budget includes upload, server processing and every poll.
/// The model's response time is accounted separately by ViktorGateway.
abstract final class ViktorSpeechPollingPolicy {
  static const maxElapsed = Duration(seconds: 45);
  static const uploadTimeout = Duration(seconds: 25);

  static Duration delay(Duration elapsed) =>
      elapsed < const Duration(seconds: 6)
          ? const Duration(milliseconds: 600)
          : const Duration(milliseconds: 1100);

  static Duration pollTimeout(Duration elapsed) {
    final remaining = maxElapsed - elapsed;
    if (remaining <= Duration.zero) return Duration.zero;
    const limit = Duration(seconds: 8);
    return remaining < limit ? remaining : limit;
  }
}

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

  FormatException _failure(Map<String, dynamic> data,
      {required int httpStatus, required String stage}) {
    // PocketBase and reverse proxies can return {code, message} instead of
    // our hook's {error}. Never misreport that as a SpeechKit provider error.
    // Preserve HTTP status and request stage without echoing remote messages.
    final code = data['error'];
    final providerStatus = data['status'];
    if (code is String && code.trim().isNotEmpty) {
      final status = providerStatus is int &&
              providerStatus >= 400 && providerStatus <= 599
          ? providerStatus : httpStatus;
      return FormatException('$code (HTTP $status, stage $stage)');
    }
    if (httpStatus == 404) {
      return FormatException('speech_route_missing (HTTP 404, stage $stage)');
    }
    if (httpStatus == 401 || httpStatus == 403) {
      return FormatException('speech_auth_failed (HTTP $httpStatus, stage $stage)');
    }
    if (httpStatus >= 500) {
      return FormatException('speech_backend_failed (HTTP $httpStatus, stage $stage)');
    }
    return FormatException(
        'speech_unstructured_error (HTTP $httpStatus, stage $stage)');
  }

  Future<String> transcribe({
    required Uint8List wav,
    required ViktorModelSettings settings,
    void Function(ViktorSpeechStage stage, Duration elapsed)? onProgress,
  }) async {
    final clock = Stopwatch()..start();
    onProgress?.call(ViktorSpeechStage.uploading, Duration.zero);
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
    if (apiKey.isEmpty && !settings.speechConnected) {
      throw const FormatException('speech_api_key_required');
    }
    if (isYandex && settings.yandexFolderId.trim().isEmpty &&
        !settings.cloudProviders.contains('yandex')) {
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
        'model_provider': settings.provider,
        if (apiKey.isNotEmpty) 'api_key': apiKey,
        'audio_base64': base64Encode(wav),
        'language': currentLocale.value.toLowerCase().startsWith('ru')
            ? 'ru' : 'en',
        if (isYandex) 'yandex_folder_id': settings.yandexFolderId.trim(),
      }),
    ).timeout(ViktorSpeechPollingPolicy.uploadTimeout);

    final payload = _payload(response);
    if (isYandex && response.statusCode == 202) {
      final operationId = (payload['operation_id'] ?? '').toString();
      if (!RegExp(r'^[a-zA-Z0-9_-]{8,90}$').hasMatch(operationId)) {
        throw const FormatException('invalid_speech_response');
      }
      // The Yandex operation is asynchronous. Poll on the client with a
      // single bounded elapsed budget, never N * per-poll HTTP timeouts.
      // Fast first polls improve latency for short voice commands.
      while (true) {
        final timeout = ViktorSpeechPollingPolicy.pollTimeout(clock.elapsed);
        if (timeout <= Duration.zero) {
          throw const FormatException('speech_recognition_timeout');
        }
        onProgress?.call(ViktorSpeechStage.waiting, clock.elapsed);
        await Future<void>.delayed(
            ViktorSpeechPollingPolicy.delay(clock.elapsed));
        final requestTimeout =
            ViktorSpeechPollingPolicy.pollTimeout(clock.elapsed);
        if (requestTimeout <= Duration.zero) {
          throw const FormatException('speech_recognition_timeout');
        }
        late final http.Response check;
        try {
          check = await http.post(
            Uri.parse('$base/api/viktor/transcribe-yandex/status'),
            headers: headers,
            body: jsonEncode({
              'provider': 'yandex',
              if (apiKey.isNotEmpty) 'api_key': apiKey,
              'yandex_folder_id': settings.yandexFolderId.trim(),
              'operation_id': operationId,
            }),
          ).timeout(requestTimeout);
        } on TimeoutException {
          // A slow individual status request must never consume minutes.
          if (ViktorSpeechPollingPolicy.pollTimeout(clock.elapsed)
              <= Duration.zero) {
            throw const FormatException('speech_recognition_timeout');
          }
          continue;
        }
        final state = _payload(check);
        if (check.statusCode == 202) continue;
        if (check.statusCode != 200) {
          throw _failure(state, httpStatus: check.statusCode, stage: 'poll');
        }
        final transcript = (state['transcript'] ?? '').toString().trim();
        if (transcript.isEmpty) throw const FormatException('no_speech_detected');
        return transcript;
      }
    }
    if (response.statusCode != 200) {
      throw _failure(payload, httpStatus: response.statusCode, stage: 'submit');
    }
    final transcript = (payload['transcript'] ?? '').toString().trim();
    if (transcript.isEmpty) throw const FormatException('no_speech_detected');
    return transcript;
  }
}
