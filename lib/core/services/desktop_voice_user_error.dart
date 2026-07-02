import 'package:counter/core/diagnostics/desktop_voice_log.dart';
import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';

/// Stage of the desktop voice overlay when an error occurred.
enum DesktopVoiceErrorStage {
  preparing,
  listening,
  transcribing,
  parsing,
}

/// User-safe desktop voice error — technical details stay in diagnostics only.
class DesktopVoiceUserError {
  const DesktopVoiceUserError({
    required this.message,
    required this.technicalDetail,
  });

  final String message;
  final String technicalDetail;

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

  static DesktopVoiceUserError fromException(
    Object? error, {
    required DesktopVoiceErrorStage stage,
    required String localeCode,
    String? fallbackTechnical,
  }) {
    final tech = (error?.toString() ?? fallbackTechnical ?? '').trim();
    if (tech.isNotEmpty && looksTechnical(tech)) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_RAW_EXCEPTION_SUPPRESSED', tech);
      DesktopVoiceLog.instance.mark('error_technical', tech);
    }
    DesktopVoicePipeline.mark('DESKTOP_VOICE_ERROR_MAPPED', stage.name);
    final message = _messageFor(stage, localeCode, tech);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_OVERLAY_FRIENDLY_ERROR_SHOWN', message);
    return DesktopVoiceUserError(message: message, technicalDetail: tech);
  }

  static String _messageFor(
    DesktopVoiceErrorStage stage,
    String localeCode,
    String technical,
  ) {
    final ru = localeCode == 'ru';
    final lower = technical.toLowerCase();

    if (stage == DesktopVoiceErrorStage.listening) {
      if (lower.contains('not enough audio') ||
          lower.contains('no audio') ||
          lower.contains('mic')) {
        return ru ? 'Микрофон не даёт сигнал' : 'No microphone signal';
      }
      return ru ? 'Попробуйте ещё раз' : 'Try again';
    }

    if (stage == DesktopVoiceErrorStage.transcribing ||
        stage == DesktopVoiceErrorStage.preparing) {
      if (lower.contains('not enough audio') ||
          lower.contains('no audio')) {
        return ru ? 'Микрофон не даёт сигнал' : 'No microphone signal';
      }
      if (lower.contains('empty transcript')) {
        return ru ? 'Не удалось распознать команду' : 'Could not recognize the command';
      }
      return ru ? 'Распознаватель недоступен' : 'Recognizer is unavailable';
    }

    if (stage == DesktopVoiceErrorStage.parsing) {
      return ru ? 'Не удалось распознать команду' : 'Could not recognize the command';
    }

    return ru ? 'Попробуйте ещё раз' : 'Try again';
  }

  /// Returns [message] if already user-safe; otherwise maps technical text.
  static DesktopVoiceUserError resolve({
    required String? message,
    Object? error,
    required DesktopVoiceErrorStage stage,
    required String localeCode,
  }) {
    final candidate = (message ?? '').trim();
    if (candidate.isNotEmpty && !looksTechnical(candidate)) {
      return DesktopVoiceUserError(
        message: candidate,
        technicalDetail: error?.toString() ?? candidate,
      );
    }
    return fromException(
      error ?? candidate,
      stage: stage,
      localeCode: localeCode,
      fallbackTechnical: candidate,
    );
  }
}
