import 'package:counter/core/diagnostics/desktop_voice_log.dart';
import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_delayed_transcribe.dart';

/// Stage of the desktop voice overlay when an error occurred.
enum DesktopVoiceErrorStage {
  preparing,
  listening,
  transcribing,
  parsing,
}

/// Product error classification for desktop voice (A–E).
enum DesktopVoiceFailureKind {
  micNoSignal,
  recognizerUnavailable,
  sttEmptyTranscript,
  parserRejected,
  writeFailed,
}

/// User-safe desktop voice error — technical details stay in diagnostics only.
class DesktopVoiceUserError {
  const DesktopVoiceUserError({
    required this.message,
    required this.technicalDetail,
    this.kind,
  });

  final String message;
  final String technicalDetail;
  final DesktopVoiceFailureKind? kind;

  static bool looksTechnical(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('clientexception')) return true;
    if (lower.contains('socketexception')) return true;
    if (lower.contains('httpexception')) return true;
    if (lower.contains('formatexception')) return true;
    if (lower.contains('connection closed before full header')) return true;
    if (lower.contains('stack trace') || lower.contains('stacktrace')) return true;
    if (lower.contains('uri=http') || lower.contains('127.0.0.1')) return true;
    if (lower.contains('localhost')) return true;
    if (RegExp(r'#\d+\s+\w+').hasMatch(text)) return true;
    return false;
  }

  static DesktopVoiceFailureKind classifySttFailure({
    required bool audioLevelSeen,
    String? errorText,
    String? transcribeErrorKind,
    bool helperExists = true,
    bool modelExists = true,
    bool helperReady = false,
    bool finalTranscribeReady = false,
    bool pendingWavAfterStop = false,
    bool helperReadyAfterRecording = false,
    bool delayedTranscribeCalled = false,
  }) {
    if (!audioLevelSeen) {
      return DesktopVoiceFailureKind.micNoSignal;
    }
    final lower = (errorText ?? '').toLowerCase();
    final kind = (transcribeErrorKind ?? '').toLowerCase();

    if (kind == 'empty_transcript' ||
        lower.contains('empty transcript') ||
        lower.contains('stt_empty')) {
      return DesktopVoiceFailureKind.sttEmptyTranscript;
    }

    if (lower.contains('not enough audio') || lower.contains('no audio')) {
      return DesktopVoiceFailureKind.micNoSignal;
    }

    // Valid WAV was kept pending and helper became ready — never classify a
    // cold-start race as "Recognizer unavailable" when delayed transcribe ran
    // (or should have run). Prefer empty-transcript / parser-style outcomes.
    if (DesktopVoiceDelayedTranscribe.suppressFalseRecognizerUnavailable(
          hasValidPendingWav: pendingWavAfterStop,
          helperReadyAfterRecording: helperReadyAfterRecording,
        ) ||
        (delayedTranscribeCalled && helperReadyAfterRecording)) {
      if (lower.contains('empty') || kind == 'empty_transcript') {
        return DesktopVoiceFailureKind.sttEmptyTranscript;
      }
      // Transcribe was attempted after ready; treat as empty rather than
      // falsely claiming the recognizer is unavailable.
      return DesktopVoiceFailureKind.sttEmptyTranscript;
    }

    if (!helperExists ||
        !modelExists ||
        lower.contains('not found') ||
        (!finalTranscribeReady && !helperReady) ||
        lower.contains('did not respond') ||
        lower.contains('timeout') ||
        lower.contains('connection closed') ||
        lower.contains('clientexception') ||
        lower.contains('socket') ||
        kind.contains('connection') ||
        kind.contains('timeout') ||
        kind.contains('http_status')) {
      return DesktopVoiceFailureKind.recognizerUnavailable;
    }

    if (lower.contains('not loaded') ||
        kind.contains('helper_error') ||
        !finalTranscribeReady) {
      return DesktopVoiceFailureKind.recognizerUnavailable;
    }

    return DesktopVoiceFailureKind.recognizerUnavailable;
  }

  static void markFailureKind(DesktopVoiceFailureKind kind) {
    switch (kind) {
      case DesktopVoiceFailureKind.micNoSignal:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_MIC_NO_SIGNAL');
      case DesktopVoiceFailureKind.recognizerUnavailable:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_RECOGNIZER_UNAVAILABLE');
      case DesktopVoiceFailureKind.sttEmptyTranscript:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_STT_EMPTY_TRANSCRIPT');
      case DesktopVoiceFailureKind.parserRejected:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_PARSER_REJECTED');
      case DesktopVoiceFailureKind.writeFailed:
        DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_WRITE_FAILED');
    }
  }

  static void markReadinessRace() {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_READINESS_RACE');
  }

  static DesktopVoiceUserError fromException(
    Object? error, {
    required DesktopVoiceErrorStage stage,
    required String localeCode,
    String? fallbackTechnical,
    DesktopVoiceFailureKind? kind,
  }) {
    final tech = (error?.toString() ?? fallbackTechnical ?? '').trim();
    if (tech.isNotEmpty && looksTechnical(tech)) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_RAW_EXCEPTION_SUPPRESSED', tech);
      DesktopVoiceLog.instance.mark('error_technical', tech);
    }
    DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_MAPPED', stage.name);
    final resolvedKind = kind ?? _inferKind(stage, tech);
    markFailureKind(resolvedKind);
    final message = _messageFor(resolvedKind, localeCode, tech);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_FRIENDLY_ERROR_SHOWN', message);
    return DesktopVoiceUserError(
      message: message,
      technicalDetail: tech,
      kind: resolvedKind,
    );
  }

  static DesktopVoiceFailureKind _inferKind(
    DesktopVoiceErrorStage stage,
    String technical,
  ) {
    final lower = technical.toLowerCase();
    if (stage == DesktopVoiceErrorStage.listening) {
      return DesktopVoiceFailureKind.micNoSignal;
    }
    if (stage == DesktopVoiceErrorStage.parsing) {
      return DesktopVoiceFailureKind.parserRejected;
    }
    if (lower.contains('empty transcript')) {
      return DesktopVoiceFailureKind.sttEmptyTranscript;
    }
    if (lower.contains('not enough audio') || lower.contains('no audio')) {
      return DesktopVoiceFailureKind.micNoSignal;
    }
    return DesktopVoiceFailureKind.recognizerUnavailable;
  }

  static String _messageFor(
    DesktopVoiceFailureKind kind,
    String localeCode,
    String technical,
  ) {
    final ru = localeCode == 'ru';
    switch (kind) {
      case DesktopVoiceFailureKind.micNoSignal:
        return ru ? 'Микрофон не даёт сигнал' : 'No microphone signal';
      case DesktopVoiceFailureKind.recognizerUnavailable:
        return ru ? 'Распознаватель недоступен' : 'Recognizer is unavailable';
      case DesktopVoiceFailureKind.sttEmptyTranscript:
        return ru ? 'Не удалось получить текст' : 'Could not get speech text';
      case DesktopVoiceFailureKind.parserRejected:
        return ru ? 'Не удалось распознать команду' : 'Could not recognize the command';
      case DesktopVoiceFailureKind.writeFailed:
        return ru ? 'Не удалось запустить запись' : 'Could not start the record';
    }
  }

  /// Returns [message] if already user-safe; otherwise maps technical text.
  static DesktopVoiceUserError resolve({
    required String? message,
    Object? error,
    required DesktopVoiceErrorStage stage,
    required String localeCode,
    DesktopVoiceFailureKind? kind,
  }) {
    final candidate = (message ?? '').trim();
    if (candidate.isNotEmpty && !looksTechnical(candidate)) {
      final resolvedKind = kind ?? _inferKind(stage, candidate);
      markFailureKind(resolvedKind);
      return DesktopVoiceUserError(
        message: candidate,
        technicalDetail: error?.toString() ?? candidate,
        kind: resolvedKind,
      );
    }
    return fromException(
      error ?? candidate,
      stage: stage,
      localeCode: localeCode,
      fallbackTechnical: candidate,
      kind: kind,
    );
  }
}
