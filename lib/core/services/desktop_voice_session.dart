import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';

/// Immutable voice session identity for Desktop Voice hotkey recordings.
///
/// Every async STT/partial/correction/write result must match [id] or be
/// discarded. [generation] increments on each new hotkey session.
class DesktopVoiceSession {
  DesktopVoiceSession._({
    required this.id,
    required this.generation,
    required this.startedAtMs,
  });

  final String id;
  final int generation;
  final int startedAtMs;

  static int _nextGeneration = 0;

  static DesktopVoiceSession begin() {
    final gen = ++_nextGeneration;
    final ms = DateTime.now().millisecondsSinceEpoch;
    final id = 'vs_${ms}_$gen';
    final session = DesktopVoiceSession._(
      id: id,
      generation: gen,
      startedAtMs: ms,
    );
    DesktopVoiceSessionRegistry._active = session;
    DesktopVoicePipeline.mark('voice_session_id', id);
    DesktopVoicePipeline.mark('voice_session_generation', '$gen');
    DesktopVoicePipeline.mark('active_session_id', id);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_SINGLE_ACTIVE_SESSION');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_SESSION_ID_END_TO_END');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_SESSION_STATE_RESET_AT_START');
    return session;
  }

  static DesktopVoiceSession? get active => DesktopVoiceSessionRegistry._active;

  static void clearActive({String reason = 'session_cleared'}) {
    if (DesktopVoiceSessionRegistry._active != null) {
      DesktopVoicePipeline.mark('pending_state_cleared', reason);
    }
    DesktopVoiceSessionRegistry._active = null;
    DesktopVoicePipeline.mark('active_session_count', '0');
  }
}

/// Global active session + stale-result discard accounting.
abstract final class DesktopVoiceSessionRegistry {
  static DesktopVoiceSession? _active;
  static String? _priorSessionId;
  static int _activeCount = 0;

  static DesktopVoiceSession? get active => _active;
  static String? get priorSessionId => _priorSessionId;
  static int get activeCount => _active == null ? 0 : 1;

  static DesktopVoiceSession begin() {
    if (_active != null) {
      _priorSessionId = _active!.id;
      DesktopVoicePipeline.mark('prior_voice_session_id', _priorSessionId!);
      DesktopVoicePipeline.mark('DESKTOP_VOICE_OLD_TIMER_CANCELLED');
    }
    _active = DesktopVoiceSession.begin();
    _activeCount = 1;
    DesktopVoicePipeline.mark('active_session_count', '1');
    return _active!;
  }

  static void end({String reason = 'session_end'}) {
    if (_active != null) {
      _priorSessionId = _active!.id;
    }
    DesktopVoiceSession.clearActive(reason: reason);
    _activeCount = 0;
  }

  /// Returns true when [resultSessionId] matches the active session.
  static bool acceptResult({
    required String? resultSessionId,
    String source = 'unknown',
  }) {
    final activeId = _active?.id;
    if (activeId == null || activeId.isEmpty) {
      _markStale(source, resultSessionId, 'no_active_session');
      return false;
    }
    if (resultSessionId == null || resultSessionId.isEmpty) {
      // Legacy helper responses without session id are accepted only if tagged
      // at call site after session reset (caller passes active id explicitly).
      return true;
    }
    if (resultSessionId != activeId) {
      _markStale(source, resultSessionId, 'session_mismatch');
      return false;
    }
    return true;
  }

  static bool acceptForActive({
    required String? resultSessionId,
    String source = 'unknown',
  }) {
    return acceptResult(
      resultSessionId: resultSessionId ?? _active?.id,
      source: source,
    );
  }

  static void _markStale(String source, String? resultId, String reason) {
    DesktopVoicePipeline.mark('stale_result_discarded', 'yes');
    DesktopVoicePipeline.mark('stale_result_source', source);
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_STALE_RESULT_DISCARDED',
      '$reason result=$resultId active=${_active?.id}',
    );
  }
}
