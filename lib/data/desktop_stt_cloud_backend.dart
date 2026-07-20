import 'dart:convert';

import 'package:counter/core/services/desktop_stt_cloud_service.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:http/http.dart' as http;

/// Brain-owned cloud command STT transport.
///
/// Owns PocketBase readiness, auth token, base URL, route, Authorization,
/// HTTP POST, JSON payload, and the 25-second timeout. Core maps the HTTP
/// result into [DesktopSttEngineResult] without importing Brain modules.
abstract final class DesktopSttCloudBackend {
  /// True when PocketBase is ready and the session token is non-empty.
  /// Propagates [ensurePocketBaseReady] failures to the caller.
  static Future<bool> isSessionReady() async {
    await DatabaseService.instance.ensurePocketBaseReady();
    final token =
        DatabaseService.instance.pocketBase.authStore.token.trim();
    return token.isNotEmpty;
  }

  /// POST `/api/ai/transcribe-command` with glossary context.
  static Future<DesktopSttCloudHttpResult> postTranscribeCommand({
    required String audioBase64,
    required String languageHint,
    required List<String> glossaryTerms,
    required String glossaryPrompt,
  }) async {
    await DatabaseService.instance.ensurePocketBaseReady();
    final token =
        DatabaseService.instance.pocketBase.authStore.token.trim();
    if (token.isEmpty) {
      throw StateError('auth_required');
    }

    final base = kPocketBaseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base${PbAppApiRoutes.aiTranscribeCommand}');
    final payload = <String, dynamic>{
      'audio_base64': audioBase64,
      'language_hint': languageHint,
      'command_mode': true,
      'glossary_terms': glossaryTerms.take(64).toList(),
      if (glossaryPrompt.isNotEmpty) 'glossary_prompt': glossaryPrompt,
    };

    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    return DesktopSttCloudHttpResult(
      statusCode: res.statusCode,
      body: res.body,
    );
  }
}
