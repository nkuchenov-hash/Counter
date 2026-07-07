import 'dart:convert';
import 'dart:io';

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_stt_engine.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/pb_config.dart';
import 'package:http/http.dart' as http;

/// Secure cloud STT — calls app-owned PocketBase route only (no client secrets).
class DesktopSttCloudService {
  DesktopSttCloudService._();

  static final DesktopSttCloudService instance = DesktopSttCloudService._();

  String? _lastError;
  String? get lastError => _lastError;

  /// True when user session exists — endpoint may still be unavailable server-side.
  Future<bool> isConfigured() async {
    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final token = DatabaseService.instance.pocketBase.authStore.token.trim();
      return token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<DesktopSttEngineResult> transcribeCommandWav(
    DesktopSttEngineContext context,
  ) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CLOUD_STT_BACKEND_ENDPOINT');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CLOUD_STT_NO_CLIENT_SECRET');
    _lastError = null;
    final t0 = DateTime.now();

    try {
      await DatabaseService.instance.ensurePocketBaseReady();
      final token =
          DatabaseService.instance.pocketBase.authStore.token.trim();
      if (token.isEmpty) {
        _lastError = 'auth_required';
        return DesktopSttEngineResult(
          engineId: 'cloud_best_quality',
          displayName: 'Cloud Best Quality',
          qualityTier: DesktopSttQualityTier.best,
          errorKind: 'auth_required',
          supportsGlossary: true,
        );
      }

      final wavBytes = await _readWavBytes(context.wavPath);
      if (wavBytes == null || wavBytes.isEmpty) {
        _lastError = 'wav_missing';
        return DesktopSttEngineResult(
          engineId: 'cloud_best_quality',
          displayName: 'Cloud Best Quality',
          qualityTier: DesktopSttQualityTier.best,
          errorKind: 'wav_missing',
          supportsGlossary: true,
        );
      }

      if (context.glossaryTerms.isNotEmpty) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_GLOSSARY_CONTEXT_SENT_TO_STT');
      }

      final base = kPocketBaseUrl.replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$base${PbAppApiRoutes.aiTranscribeCommand}');
      final payload = <String, dynamic>{
        'audio_base64': base64Encode(wavBytes),
        'language_hint': context.languageHint,
        'command_mode': true,
        'glossary_terms': context.glossaryTerms.take(64).toList(),
        if (context.glossaryPrompt.isNotEmpty)
          'glossary_prompt': context.glossaryPrompt,
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

      final latencyMs = DateTime.now().difference(t0).inMilliseconds;

      if (res.statusCode == 404 || res.statusCode == 503) {
        _lastError = 'best_quality_unavailable';
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_BEST_QUALITY_UNAVAILABLE_FALLBACK_LOCAL',
          'HTTP ${res.statusCode}',
        );
        return DesktopSttEngineResult(
          engineId: 'cloud_best_quality',
          displayName: 'Cloud Best Quality',
          qualityTier: DesktopSttQualityTier.best,
          latencyMs: latencyMs,
          errorKind: 'best_quality_unavailable',
          supportsGlossary: true,
        );
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        _lastError = 'http_${res.statusCode}';
        return DesktopSttEngineResult(
          engineId: 'cloud_best_quality',
          displayName: 'Cloud Best Quality',
          qualityTier: DesktopSttQualityTier.best,
          latencyMs: latencyMs,
          errorKind: _lastError,
          supportsGlossary: true,
        );
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        _lastError = 'invalid_response';
        return DesktopSttEngineResult(
          engineId: 'cloud_best_quality',
          displayName: 'Cloud Best Quality',
          qualityTier: DesktopSttQualityTier.best,
          latencyMs: latencyMs,
          errorKind: _lastError,
          supportsGlossary: true,
        );
      }

      final map = Map<String, dynamic>.from(decoded);
      final err = map['error']?.toString();
      if (err != null && err.isNotEmpty) {
        _lastError = err;
        return DesktopSttEngineResult(
          engineId: 'cloud_best_quality',
          displayName: 'Cloud Best Quality',
          qualityTier: DesktopSttQualityTier.best,
          latencyMs: latencyMs,
          errorKind: err,
          supportsGlossary: true,
          providerModelId: map['model']?.toString(),
        );
      }

      final raw = (map['raw_transcript'] ?? map['transcript'] ?? '')
          .toString()
          .trim();
      if (raw.isEmpty) {
        _lastError = 'empty_transcript';
        return DesktopSttEngineResult(
          engineId: 'cloud_best_quality',
          displayName: 'Cloud Best Quality',
          qualityTier: DesktopSttQualityTier.best,
          latencyMs: latencyMs,
          errorKind: _lastError,
          supportsGlossary: true,
          providerModelId: map['model']?.toString(),
        );
      }

      DesktopVoicePipeline.mark('DESKTOP_VOICE_CLOUD_STT_TRANSCRIPT_SUCCESS');
      return DesktopSttEngineResult(
        engineId: 'cloud_best_quality',
        displayName: 'Cloud Best Quality',
        qualityTier: DesktopSttQualityTier.best,
        rawTranscript: raw,
        latencyMs: latencyMs,
        supportsGlossary: true,
        providerModelId: map['model']?.toString(),
      );
    } catch (e) {
      _lastError = e.toString();
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_BEST_QUALITY_UNAVAILABLE_FALLBACK_LOCAL',
        _lastError!,
      );
      return DesktopSttEngineResult(
        engineId: 'cloud_best_quality',
        displayName: 'Cloud Best Quality',
        qualityTier: DesktopSttQualityTier.best,
        errorKind: 'exception',
        supportsGlossary: true,
      );
    }
  }

  Future<List<int>?> _readWavBytes(String wavPath) async {
    try {
      final f = File(wavPath);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}

/// Cloud STT engine adapter.
class DesktopSttCloudEngine implements DesktopSttEngine {
  @override
  String get id => 'cloud_best_quality';

  @override
  String get displayName => 'Cloud Best Quality';

  @override
  DesktopSttQualityTier get qualityTier => DesktopSttQualityTier.best;

  @override
  bool get supportsGlossary => true;

  @override
  Future<bool> isAvailable() => DesktopSttCloudService.instance.isConfigured();

  @override
  Future<DesktopSttEngineResult> transcribeCommandWav(
    DesktopSttEngineContext context,
  ) =>
      DesktopSttCloudService.instance.transcribeCommandWav(context);
}
