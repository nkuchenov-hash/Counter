import 'dart:convert';
import 'dart:io';

import 'package:counter/shared/voice/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/shared/voice/commands/desktop_stt_engine.dart';

/// Raw HTTP result from Brain-owned `/api/ai/transcribe-command` POST.
class DesktopSttCloudHttpResult {
  const DesktopSttCloudHttpResult({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

typedef DesktopSttCloudSessionReadyFn = Future<bool> Function();
typedef DesktopSttCloudPostTranscribeFn = Future<DesktopSttCloudHttpResult>
    Function({
  required String audioBase64,
  required String languageHint,
  required List<String> glossaryTerms,
  required String glossaryPrompt,
});

/// Injected from `main.dart` — keeps Core free of DatabaseService / pb_config.
abstract final class DesktopSttCloudBackendHooks {
  static DesktopSttCloudSessionReadyFn? isSessionReady;
  static DesktopSttCloudPostTranscribeFn? postTranscribeCommand;
}

/// Secure cloud STT — calls app-owned PocketBase route only (no client secrets).
class DesktopSttCloudService {
  DesktopSttCloudService._();

  static final DesktopSttCloudService instance = DesktopSttCloudService._();

  String? _lastError;
  String? get lastError => _lastError;

  /// True when user session exists — endpoint may still be unavailable server-side.
  Future<bool> isConfigured() async {
    try {
      final check = DesktopSttCloudBackendHooks.isSessionReady;
      if (check == null) return false;
      return await check();
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
      final sessionReady = DesktopSttCloudBackendHooks.isSessionReady;
      final post = DesktopSttCloudBackendHooks.postTranscribeCommand;
      if (sessionReady == null || post == null) {
        _lastError = 'auth_required';
        return DesktopSttEngineResult(
          engineId: 'cloud_best_quality',
          displayName: 'Cloud Best Quality',
          qualityTier: DesktopSttQualityTier.best,
          errorKind: 'auth_required',
          supportsGlossary: true,
        );
      }

      final ready = await sessionReady();
      if (!ready) {
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

      final res = await post(
        audioBase64: base64Encode(wavBytes),
        languageHint: context.languageHint,
        glossaryTerms: context.glossaryTerms,
        glossaryPrompt: context.glossaryPrompt,
      );

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
